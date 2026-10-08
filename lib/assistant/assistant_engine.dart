import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/journal_entry.dart';
import '../models/task.dart';
import '../providers/activity_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/task_provider.dart';
import '../screens/medicines_screen.dart';
import '../screens/money_screen.dart';
import '../services/app_events.dart';
import '../services/hive_service.dart';
import '../services/money_store.dart';
import '../services/notification_service.dart';
import 'assistant_memory.dart';
import 'intent_parser.dart';
import 'lang_util.dart';
import 'time_parser.dart';

/// Something the assistant did, shown as a card with Undo.
class DoneAction {
  final IconData icon;
  final String summary;
  final Future<void> Function()? undo;

  const DoneAction(this.icon, this.summary, [this.undo]);
}

/// The assistant's answer to one message.
class AssistantReply {
  final String text;
  final ChatLang lang;
  final List<DoneAction> actions;

  /// True when it didn't understand and should offer "what did you mean?".
  final bool askTeach;

  const AssistantReply(this.text, this.lang, {this.actions = const [], this.askTeach = false});
}

/// Meanings offered when the assistant didn't understand.
const teachOptions = <(String, IconData)>[
  ('task', Icons.add_task_rounded),
  ('reminder', Icons.alarm_rounded),
  ('journal', Icons.auto_stories_rounded),
  ('water', Icons.water_drop_rounded),
  ('habit', Icons.loop_rounded),
  ('chat', Icons.chat_bubble_outline_rounded),
];

/// Rule-based assistant: understands commands, acts in the app, and
/// learns phrases the user teaches it. Runs on the phone, instantly.
class AssistantEngine {
  final BuildContext context;
  AssistantEngine(this.context);

  /// A reminder waiting for its time ("When should I remind you?").
  String? _pendingReminder;

  /// What the user said that wasn't a command (for journal highlights).
  final List<String> chatLines = [];

  /// The style the user has been chatting in (e.g. Roman Pashto), used
  /// when a message alone doesn't show it.
  ChatLang? _style = AssistantMemory.chatLang;

  TaskProvider get _tasks => Provider.of<TaskProvider>(context, listen: false);
  HabitProvider get _habits => Provider.of<HabitProvider>(context, listen: false);
  JournalProvider get _journal => Provider.of<JournalProvider>(context, listen: false);
  ActivityProvider get _activity => Provider.of<ActivityProvider>(context, listen: false);
  Box get _box => Hive.box(HiveService.settingsBox);
  String get _user => HiveService.getCurrentUser();

  String get _name => AssistantMemory.style.name ?? (_user.isEmpty ? '' : _user[0].toUpperCase() + _user.substring(1));

  // --- Main entry ---

  Future<AssistantReply> handle(String raw) async {
    final text = AssistantMemory.applyCorrections(raw.trim());
    final detected = detectLang(text);
    if (detected != ChatLang.en) {
      _style = detected;
      AssistantMemory.setChatLang(detected);
    }
    // Keep replying in the user's style unless this message is clearly English.
    var lang = detected == ChatLang.en && !looksEnglish(text) && _style != null ? _style! : detected;
    _noteAddress(text);

    // A lesson: "sanga chal de = how are you", "... and reply like ...".
    final lesson = parseTeach(text);
    if (lesson != null) return _learn(lesson, lang);

    // Swap in taught meanings so the rest can be understood (the reply
    // still comes back in the user's own style).
    final understood = AssistantMemory.applyMeanings(text);
    if (understood != text && lang == ChatLang.en) lang = AssistantMemory.meaningLangIn(text) ?? _style ?? lang;
    AssistantMemory.learnWords(lang, text);

    if (_pendingReminder != null) {
      final t = parseTime(understood);
      if (t != null) {
        final title = _pendingReminder!;
        _pendingReminder = null;
        return _reminder(title, t.when, lang);
      }
      _pendingReminder = null;
    }

    final intent = parseIntent(
      understood,
      habits: _habits.habits.map((h) => h.title).toList(),
      medicines: MedicineStore.all.map((m) => m.name).toList(),
    );
    final custom = AssistantMemory.replyFor(text);
    const chatty = {IntentType.unknown, IntentType.smallTalk, IntentType.greeting, IntentType.thanks, IntentType.help};

    // A reply the user taught for these words.
    if (custom != null && chatty.contains(intent.type)) {
      chatLines.add(text);
      return AssistantReply(custom, lang);
    }

    if (intent.type == IntentType.unknown) {
      // Tapped meanings ("A task", "Just chatting") from earlier.
      final learned = AssistantMemory.match(text) ?? AssistantMemory.match(understood);
      if (learned != null) return _runLearned(understood, learned.$2, lang);
      if (understood != text) {
        chatLines.add(text);
        return AssistantReply(_t(lang, 'chat'), lang);
      }
    }
    final reply = await _run(intent, understood, lang);
    if (custom != null) return AssistantReply('${reply.text}\n$custom', reply.lang, actions: reply.actions, askTeach: reply.askTeach);
    return reply;
  }

  /// Saves a lesson; a new lesson replaces older ones for the same words.
  Future<AssistantReply> _learn(TeachLesson lesson, ChatLang current) async {
    final phraseLang = detectLang(lesson.phrase);
    final lang = phraseLang != ChatLang.en ? phraseLang : (_style ?? current);
    if (lang != ChatLang.en) _style = lang;
    await AssistantMemory.forgetPhraseText(lesson.phrase);
    if (lesson.meaning != null) await AssistantMemory.addMeaning(lesson.phrase, lesson.meaning!, lang: lang == ChatLang.en ? null : lang);
    if (lesson.reply != null) await AssistantMemory.addReply(lesson.phrase, lesson.reply!);
    final parts = [
      if (lesson.meaning != null) _t(lang, 'meaningLearned', {'phrase': lesson.phrase, 'meaning': lesson.meaning!}),
      if (lesson.reply != null) _t(lang, 'replyLearned', {'phrase': lesson.phrase, 'reply': lesson.reply!}),
    ];
    final summary = [if (lesson.meaning != null) '= ${lesson.meaning}', if (lesson.reply != null) '↩ ${lesson.reply}'].join('  ');
    return AssistantReply(parts.join(' '), lang, actions: [
      DoneAction(Icons.translate_rounded, '${lesson.phrase}  $summary', () async {
        await AssistantMemory.removeMeaning(lesson.phrase);
        await AssistantMemory.removeReply(lesson.phrase);
      }),
    ]);
  }

  static const _addressWords = ['yara', 'yaara', 'yaar', 'yar', 'bhai', 'bhaijan', 'bhaijaan', 'dost', 'wrora', 'janana', 'jani', 'jaani', 'lala', 'malgaria'];

  /// Remembers how the user addresses the assistant, to say it back.
  void _noteAddress(String text) {
    final w = tokens(text).where(_addressWords.contains).firstOrNull;
    if (w != null && w != AssistantMemory.address) AssistantMemory.setAddress(w == 'yar' ? 'yaar' : w);
  }

  /// "Za ham kha yam, manana!" → "Za ham kha yam, manana yara!"
  String _friendly(String text) {
    final a = AssistantMemory.address;
    if (a == null || text.contains(a)) return text;
    // Put it at the end of the first phrase: before "!", "?", "." or an emoji.
    final m = RegExp(r'[!?.؟۔]|[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true).firstMatch(text);
    if (m == null) return '$text $a';
    final head = text.substring(0, m.start).trimRight();
    return '$head $a${m.start < text.length && text[m.start] == ' ' ? '' : (RegExp(r'[!?.؟۔]').hasMatch(text[m.start]) ? '' : ' ')}${text.substring(m.start)}';
  }

  /// The user explained what [text] meant; do it and remember.
  Future<AssistantReply> teach(String text, String type, {String? habit}) async {
    final lang = detectLang(text);
    final meaning = LearnedMeaning(type, {'habit': ?habit});
    await AssistantMemory.teach(text, meaning);
    final reply = await _runLearned(text, meaning, lang);
    return AssistantReply('${_t(lang, 'taught')} ${reply.text}', lang, actions: reply.actions, askTeach: reply.askTeach);
  }

  Future<AssistantReply> _runLearned(String text, LearnedMeaning m, ChatLang lang) {
    switch (m.type) {
      case 'task':
        final t = parseTime(text);
        return _task(_shorten(t?.rest ?? text), t, lang);
      case 'reminder':
        final t = parseTime(text);
        if (t == null || !t.hasTime) {
          _pendingReminder = _shorten(t?.rest ?? text);
          return Future.value(AssistantReply(_t(lang, 'askTime'), lang));
        }
        return _reminder(_shorten(t.rest), t.when, lang);
      case 'journal':
        return _journalNote(text, lang);
      case 'water':
        return _water(1, lang);
      case 'habit':
        return _habitDone(m.params['habit'] as String? ?? '', lang);
      case 'mood':
        return _mood(m.params['emoji'] as String? ?? '😊', lang);
      default:
        chatLines.add(text);
        return Future.value(AssistantReply(_t(lang, 'chat'), lang));
    }
  }

  Future<AssistantReply> _run(ChatIntent i, String text, ChatLang lang) async {
    final p = i.params;
    switch (i.type) {
      case IntentType.reminder:
        final title = (p['title'] as String).isEmpty ? text : p['title'] as String;
        if (p['hasTime'] != true || p['when'] == null) {
          _pendingReminder = title;
          return AssistantReply(_t(lang, 'askTime'), lang);
        }
        return _reminder(title, p['when'] as DateTime, lang);
      case IntentType.task:
        final when = p['when'] as DateTime?;
        return _task(p['title'] as String, when == null ? null : ParsedTime(when, p['hasTime'] == true, ''), lang);
      case IntentType.water:
        return _water(p['glasses'] as int, lang);
      case IntentType.mood:
        return _mood(p['emoji'] as String, lang);
      case IntentType.expense:
        return _expense((p['amount'] as num).toDouble(), p['category'] as String, p['note'] as String, lang);
      case IntentType.income:
        final amount = (p['amount'] as num).toDouble();
        final id = await addIncome(amount, p['note'] as String);
        final label = '${MoneyStore.currency} ${NumberFormat('#,##0.##').format(amount)} · ${MoneyStore.current.name}';
        return AssistantReply(_t(lang, 'income', {'amount': label}), lang, actions: [DoneAction(Icons.savings_rounded, '+ $label', () => removeExpense(id))]);
      case IntentType.habitDone:
        return _habitDone(p['name'] as String, lang);
      case IntentType.medicineTaken:
        return _medicine(p['name'] as String, lang);
      case IntentType.journal:
        return _journalNote(p['content'] as String, lang);
      case IntentType.rememberFact:
        final fact = p['text'] as String;
        await AssistantMemory.addFact(fact);
        return AssistantReply(_t(lang, 'fact', {'text': fact}), lang,
            actions: [DoneAction(Icons.psychology_rounded, fact, () => AssistantMemory.removeFact(fact))]);
      case IntentType.style:
        var s = AssistantMemory.style;
        s = s.copyWith(
          name: p['name'] as String?,
          short: p['short'] as bool?,
          emoji: p['emoji'] as bool?,
          casual: p['casual'] as bool?,
          speak: p['speak'] as bool?,
        );
        await AssistantMemory.setStyle(s);
        return AssistantReply(p.containsKey('name') ? _t(lang, 'nameSaved', {'name': s.name ?? ''}) : _t(lang, 'styleSaved'), lang);
      case IntentType.askToday:
        return AssistantReply(_todaySummary(lang), lang);
      case IntentType.askSteps:
        final a = _activity;
        return AssistantReply(
            a.isTracking
                ? _t(lang, 'steps', {'steps': NumberFormat.decimalPattern().format(a.steps), 'goal': NumberFormat.decimalPattern().format(a.goal)})
                : _t(lang, 'stepsOff'),
            lang);
      case IntentType.askSpending:
        final (total, cur) = spentThisMonth();
        return AssistantReply(_t(lang, 'spending', {'amount': '$cur ${NumberFormat('#,##0').format(total)}'}), lang);
      case IntentType.askMemory:
        final facts = AssistantMemory.facts.map((f) => '• ${f.text}').take(8).join('\n');
        return AssistantReply(facts.isEmpty ? _t(lang, 'noMemory') : '${_t(lang, 'memory')}\n$facts', lang);
      case IntentType.greeting:
        return AssistantReply(_friendly(greeting(lang)), lang);
      case IntentType.smallTalk:
        final kind = p['kind'] as String;
        if (!{'ack', 'no', 'joke'}.contains(kind)) chatLines.add(text);
        if (kind == 'joke') {
          final jokes = _t(lang, 'jokes').split('|');
          return AssistantReply(jokes[DateTime.now().millisecondsSinceEpoch % jokes.length], lang);
        }
        final reply = _friendly(_t(lang, switch (kind) { 'both' => 'smallBoth', 'asked' => 'smallAsked', 'fine' => 'smallFine', _ => kind }));
        // Feelings also go into today's mood (with Undo).
        final emoji = switch (kind) { 'tired' || 'sick' || 'sad' || 'stressed' => '😔', 'happy' => '😊', _ => null };
        if (emoji != null) {
          final mood = await _mood(emoji, lang);
          return AssistantReply(reply, lang, actions: mood.actions);
        }
        return AssistantReply(reply, lang);
      case IntentType.thanks:
        return AssistantReply(_friendly(_t(lang, 'thanks')), lang);
      case IntentType.help:
        return AssistantReply(_t(lang, 'help'), lang);
      case IntentType.unknown:
        return AssistantReply(_t(lang, 'unknown'), lang, askTeach: true);
    }
  }

  // --- Actions ---

  Future<AssistantReply> _reminder(String title, DateTime when, ChatLang lang) async {
    await NotificationService.requestPermission();
    final task = Task(id: 'a${DateTime.now().microsecondsSinceEpoch}', title: title, dueDate: when, hasReminder: true, category: 'Reminder');
    await _tasks.addTask(task);
    final time = _when(when, lang);
    return AssistantReply(_t(lang, 'reminderSet', {'time': time, 'title': title}), lang,
        actions: [DoneAction(Icons.alarm_rounded, '$title · $time', () => _tasks.deleteTask(task.id))]);
  }

  Future<AssistantReply> _task(String title, ParsedTime? t, ChatLang lang) async {
    if (t != null && t.hasTime) await NotificationService.requestPermission();
    final now = DateTime.now();
    final task = Task(
      id: 'a${now.microsecondsSinceEpoch}',
      title: title,
      dueDate: t?.when ?? DateTime(now.year, now.month, now.day, 23, 59),
      hasReminder: t?.hasTime ?? false,
    );
    await _tasks.addTask(task);
    return AssistantReply(_t(lang, 'taskAdded', {'title': title}) + (t?.hasTime == true ? ' (${_when(t!.when, lang)})' : ''), lang,
        actions: [DoneAction(Icons.add_task_rounded, title, () => _tasks.deleteTask(task.id))]);
  }

  Future<AssistantReply> _water(int glasses, ChatLang lang) async {
    final key = '${_user}_waterIntake';
    final before = (_box.get(key, defaultValue: 0) as int);
    final after = (before + glasses).clamp(0, 8);
    await _box.put(key, after);
    _tasks.syncWaterTask(after);
    notifyLifeDataChanged();
    return AssistantReply(_t(lang, 'water', {'n': '$glasses', 'total': '$after'}), lang, actions: [
      DoneAction(Icons.water_drop_rounded, '+$glasses 💧 ($after/8)', () async {
        await _box.put(key, before);
        _tasks.syncWaterTask(before);
        notifyLifeDataChanged();
      }),
    ]);
  }

  Future<AssistantReply> _mood(String emoji, ChatLang lang) async {
    final before = _box.get('${_user}_moodToday') as String?;
    await _setMood(emoji);
    return AssistantReply(_t(lang, 'mood', {'emoji': emoji}), lang, actions: [
      DoneAction(Icons.mood_rounded, emoji, () => _setMood(before ?? '😊')),
    ]);
  }

  Future<void> _setMood(String emoji) async {
    await _box.put('${_user}_moodToday', emoji);
    final log = Map<String, dynamic>.from((_box.get('${_user}_moodLog') as Map?) ?? const {});
    log[DateFormat('yyyy-MM-dd').format(DateTime.now())] = emoji;
    await _box.put('${_user}_moodLog', log);
    notifyLifeDataChanged();
  }

  Future<AssistantReply> _expense(double amount, String category, String note, ChatLang lang) async {
    final id = await addExpense(amount, category, note);
    final (_, cur) = spentThisMonth();
    final label = '$cur ${NumberFormat('#,##0.##').format(amount)} · ${expenseCategoryLabel(category)}';
    return AssistantReply(_t(lang, 'expense', {'amount': label}), lang, actions: [DoneAction(Icons.payments_rounded, label, () => removeExpense(id))]);
  }

  Future<AssistantReply> _habitDone(String name, ChatLang lang) async {
    final habit = _habits.habits.where((h) => h.title.toLowerCase() == name.toLowerCase()).firstOrNull;
    if (habit == null) return AssistantReply(_t(lang, 'unknown'), lang, askTeach: true);
    if (habit.isCompletedToday) return AssistantReply(_t(lang, 'habitAlready', {'name': habit.title}), lang);
    await _habits.toggleHabitCompletion(habit.id);
    final streak = _habits.habits.firstWhere((h) => h.id == habit.id).streak;
    return AssistantReply(_t(lang, 'habitDone', {'name': habit.title, 'streak': '$streak'}), lang,
        actions: [DoneAction(Icons.local_fire_department_rounded, '${habit.title} · 🔥 $streak', () => _habits.toggleHabitCompletion(habit.id))]);
  }

  Future<AssistantReply> _medicine(String name, ChatLang lang) async {
    final med = MedicineStore.all.where((m) => m.name == name).firstOrNull;
    if (med == null) return AssistantReply(_t(lang, 'unknown'), lang, askTeach: true);
    final taken = MedicineStore.takenOn(DateTime.now());
    final open = med.times.where((t) => !taken.contains('${med.id}@$t')).toList();
    if (open.isEmpty) return AssistantReply(_t(lang, 'medAlready', {'name': med.name}), lang);
    // The dose closest to now.
    final now = TimeOfDay.now();
    int mins(String t) => (parseTimeOfDay(t)?.hour ?? 0) * 60 + (parseTimeOfDay(t)?.minute ?? 0);
    open.sort((a, b) => (mins(a) - (now.hour * 60 + now.minute)).abs().compareTo((mins(b) - (now.hour * 60 + now.minute)).abs()));
    await MedicineStore.toggleTaken(med, open.first);
    return AssistantReply(_t(lang, 'medicine', {'name': med.name}), lang,
        actions: [DoneAction(Icons.medication_rounded, '${med.name} · ${open.first}', () => MedicineStore.toggleTaken(med, open.first))]);
  }

  Future<AssistantReply> _journalNote(String content, ChatLang lang) async {
    final entry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _shorten(content, words: 6),
      content: content,
      mood: (_box.get('${_user}_moodToday') as String?) ?? '😊',
      date: DateTime.now(),
    );
    await _journal.addEntry(entry);
    return AssistantReply(_t(lang, 'journal'), lang, actions: [DoneAction(Icons.auto_stories_rounded, entry.title, () => _journal.deleteEntry(entry.id))]);
  }

  // --- Summaries and suggestions ---

  String _todaySummary(ChatLang lang) {
    final open = _tasks.todayTasks.where((t) => !t.isDoneOn(DateTime.now())).map((t) => t.title).toList();
    final habits = _habits.habits.where((h) => !h.isCompletedToday).map((h) => h.title).toList();
    if (open.isEmpty && habits.isEmpty) return _t(lang, 'allDone');
    final b = StringBuffer(_t(lang, 'todayIntro'));
    for (final t in open.take(5)) {
      b.write('\n• $t');
    }
    for (final h in habits.take(5)) {
      b.write('\n• 🔁 $h');
    }
    return b.toString();
  }

  /// Opening message with up to two suggestions from today's data.
  String greeting(ChatLang lang) {
    final hour = DateTime.now().hour;
    final s = <String>[];
    final water = (_box.get('${_user}_waterIntake', defaultValue: 0) as int);
    if (hour >= 13 && water < 4) s.add(_t(lang, 'sugWater', {'n': '$water'}));
    final habitsLeft = _habits.habits.where((h) => !h.isCompletedToday).length;
    if (hour >= 17 && habitsLeft > 0) s.add(_t(lang, 'sugHabits', {'n': '$habitsLeft'}));
    final a = _activity;
    if (a.isTracking && hour >= 16 && a.steps < a.goal / 2) s.add(_t(lang, 'sugWalk', {'n': NumberFormat.decimalPattern().format(a.goal - a.steps)}));
    if (_box.get('${_user}_moodLog') is Map && !(_box.get('${_user}_moodLog') as Map).containsKey(DateFormat('yyyy-MM-dd').format(DateTime.now()))) {
      s.add(_t(lang, 'sugMood'));
    }
    final hello = _t(lang, hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'evening', {'name': _name});
    final short = AssistantMemory.style.short;
    if (s.isEmpty) return short ? hello : '$hello ${_t(lang, 'howHelp')}';
    return '$hello\n${s.take(short ? 1 : 2).map((x) => '💡 $x').join('\n')}';
  }

  /// At the end of a chat: the funny, amazing or important things the
  /// user said, saved as one journal entry. Returns it (for Undo) or null.
  Future<JournalEntry?> saveHighlights() async {
    final picked = pickHighlights(chatLines);
    if (picked.isEmpty) return null;
    final entry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Chat highlights · ${DateFormat('d MMM').format(DateTime.now())}',
      content: picked.map((l) => '• $l').join('\n'),
      mood: (_box.get('${_user}_moodToday') as String?) ?? '😊',
      date: DateTime.now(),
    );
    await _journal.addEntry(entry);
    chatLines.clear();
    return entry;
  }

  static String _shorten(String s, {int words = 12}) {
    final w = s.trim().split(RegExp(r'\s+'));
    return w.length <= words ? s.trim() : '${w.take(words).join(' ')}…';
  }

  String _when(DateTime when, ChatLang lang) {
    final now = DateTime.now();
    final d = DateTime(when.year, when.month, when.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final time = DateFormat('h:mm a').format(when);
    final day = switch (d) {
      0 => _t(lang, 'today'),
      1 => _t(lang, 'tomorrow'),
      _ => DateFormat('EEE d MMM').format(when),
    };
    return '$day $time';
  }

  String _t(ChatLang lang, String key, [Map<String, String> args = const {}]) {
    final style = AssistantMemory.style;
    var s = (_strings[lang] ?? _strings[ChatLang.en]!)[key] ?? _strings[ChatLang.en]![key] ?? key;
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    if (!style.emoji) s = s.replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]️?', unicode: true), '').trim();
    return s;
  }
}

/// Picks up to three lines worth keeping: funny, amazing or important.
List<String> pickHighlights(List<String> lines) {
  const strong = [
    'haha', 'lol', 'funny', 'hilarious', 'amazing', 'awesome', 'wow', 'best', 'great', 'important', 'never forget', 'proud', 'love',
    'maza', 'mazay', 'zabardast', 'kamaal', 'zaroori', 'khush',
    'مزہ', 'زبردست', 'کمال', 'ضروری', 'اہم', 'خوشی',
    'خندا', 'ډېر ښه', 'زبردست', 'مهم', 'خوشحاله', 'عجیب', 'وياړ',
  ];
  final scored = <(String, int)>[];
  for (final l in lines) {
    final words = l.split(RegExp(r'\s+')).length;
    if (words < 3) continue;
    var score = 0;
    if (hasAny(l, strong)) score += 3;
    if (l.contains('!')) score += 1;
    if (words >= 8) score += 1;
    if (RegExp(r'[\u{1F600}-\u{1F64F}]', unicode: true).hasMatch(l)) score += 1;
    if (score >= 2) scored.add((l, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return scored.take(3).map((e) => e.$1).toList();
}

const _strings = <ChatLang, Map<String, String>>{
  ChatLang.en: {
    'income': 'Added {amount} to Cash In 💰',
    'whatDoing': 'Just here, ready to help you 😄 What are you up to?',
    'tired': 'Sounds like a long day 😔 Take a short break and drink some water.',
    'sleepy': 'Then get some rest 😴 Tomorrow you\'ll wake up fresh!',
    'hungry': 'Go grab something healthy to eat 🍎',
    'sick': 'Sorry you\'re not feeling well 🤒 Rest, drink water, and see a doctor if it gets worse.',
    'bored': 'How about a short walk or 5 minutes of reading? 🚶',
    'sad': 'I\'m sorry you feel this way 💙 Want to write about it in your journal?',
    'happy': 'That\'s wonderful! 😄 Keep it up!',
    'stressed': 'Take a deep breath 🌿 Try the Breathe exercise for 2 minutes.',
    'busy': 'Busy day! 💪 Tell me what to remind you and I\'ll keep track.',
    'seeYou': 'See you! Take care 👋',
    'alhamdulillah': 'Alhamdulillah 🤲',
    'understand': 'Great 👍',
    'love': 'Aww, thank you! 😊 I\'m always here for you.',
    'ack': '👍',
    'no': 'Okay 🙂',
    'jokes': 'Why did the phone go to school? To get a little smarter! 📱😄|Why are fish so smart? They live in schools! 🐟😄|I told my bed a secret. Now it\'s covered up! 🛏️😄',
    'replyLearned': 'When you say "{phrase}", I\'ll answer: "{reply}".',
    'smallBoth': 'I\'m good too, thanks! 😊',
    'smallAsked': 'I\'m doing well, thanks! How are you?',
    'smallFine': 'Glad to hear it! 😊 How can I help?',
    'who': 'I\'m Buddy, your Life assistant 🤖 I help with reminders, tasks, your journal and more.',
    'bye': 'Bye! Take care 👋',
    'night': 'Good night! Sleep well 🌙',
    'meaningLearned': 'Got it! "{phrase}" means "{meaning}". I\'ll understand it from now on.',
    'morning': 'Good morning, {name}!',
    'afternoon': 'Good afternoon, {name}!',
    'evening': 'Good evening, {name}!',
    'howHelp': 'How can I help? You can say things like "remind me to call Abu at 6".',
    'reminderSet': 'Done! I\'ll remind you {time}: {title} ⏰',
    'askTime': 'When should I remind you?',
    'taskAdded': 'Added to your tasks: {title} ✅',
    'water': 'Logged {n} glass(es) of water 💧 That\'s {total} of 8 today.',
    'mood': 'Got it, I\'ve noted your mood {emoji}',
    'expense': 'Saved {amount} 💸',
    'habitDone': 'Nice! {name} is done, {streak}-day streak 🔥',
    'habitAlready': '{name} is already done today 👍',
    'medicine': 'Marked {name} as taken 💊',
    'medAlready': 'All of today\'s {name} doses are already taken.',
    'journal': 'Saved to your journal ✍️',
    'fact': 'I\'ll remember that: {text}',
    'nameSaved': 'Okay, I\'ll call you {name} 😊',
    'styleSaved': 'Got it, I\'ll talk that way from now on.',
    'steps': 'You\'ve walked {steps} steps today. Your goal is {goal}.',
    'stepsOff': 'Step counting is off. Open Health to turn it on.',
    'spending': 'You\'ve spent {amount} this month.',
    'memory': 'Here\'s what I remember about you:',
    'noMemory': 'Nothing yet. Tell me "remember that…" and I\'ll keep it.',
    'thanks': 'Anytime! 😊',
    'help': 'I can set reminders, add tasks, log water, mood, spending, habits and medicines, save notes to your journal, and remember things about you. Just talk naturally.',
    'unknown': 'I didn\'t understand that yet. What did you mean? Pick below, or teach me by typing: "your words = English meaning".',
    'taught': 'Got it, I\'ll remember that.',
    'chat': 'I hear you 🙂',
    'todayIntro': 'Still to do today:',
    'allDone': 'Everything is done for today. Great job! 🎉',
    'today': 'today at',
    'tomorrow': 'tomorrow at',
    'sugWater': 'Only {n} glasses of water so far. Have one now?',
    'sugHabits': '{n} habit(s) still open today.',
    'sugWalk': '{n} more steps to reach your goal. A short walk?',
    'sugMood': 'How are you feeling today?',
  },
  ChatLang.romanUrdu: {
    'income': '{amount} Cash In mein likh diya 💰',
    'whatDoing': 'Bas aap ki madad ke liye haazir hoon 😄 Aap kya kar rahe hain?',
    'tired': 'Lagta hai lamba din tha 😔 Thora aaram karein, paani piyein.',
    'sleepy': 'Toh so jaiye 😴 Kal fresh uthenge!',
    'hungry': 'Kuch acha sa kha lijiye 🍎',
    'sick': 'Allah shifa de 🤲 Aaram karein, paani piyein, zaroorat ho toh doctor ko dikhayen.',
    'bored': 'Thori walk kar lein ya kuch parh lein? 🚶',
    'sad': 'Mujhe afsos hai 💙 Diary mein likhna chahenge?',
    'happy': 'Wah, zabardast! 😄',
    'stressed': 'Lambi saans lein 🌿 2 minute Breathe try karein.',
    'busy': 'Masroof din! 💪 Bataiye kya yaad dilana hai.',
    'seeYou': 'Phir milenge! Khayal rakhiye 👋',
    'alhamdulillah': 'Alhamdulillah 🤲',
    'understand': 'Zabardast 👍',
    'love': 'Shukriya! 😊 Main hamesha aap ke saath hoon.',
    'ack': 'Theek hai 👍',
    'no': 'Koi baat nahi 🙂',
    'jokes': 'Doctor: Aap roz walk karte hain? Mareez: Ji haan, fridge tak! 😄|Teacher: Homework kahan hai? Student: Sir, woh ghar par hi rehta hai, isi liye toh homework kehte hain! 😄',
    'replyLearned': 'Jab aap "{phrase}" kahenge, main kahoon ga: "{reply}".',
    'smallBoth': 'Main bhi theek hoon, shukriya! 😊',
    'smallAsked': 'Main theek hoon, shukriya! Aap kaise hain?',
    'smallFine': 'Achi baat hai! 😊 Bataiye, kya madad karoon?',
    'who': 'Main Buddy hoon, aap ka Life assistant 🤖 Reminder, kaam aur diary mein madad karta hoon.',
    'bye': 'Allah hafiz! Apna khayal rakhiye 👋',
    'night': 'Shab bakhair! Achi neend lein 🌙',
    'meaningLearned': 'Samajh gaya! "{phrase}" ka matlab hai "{meaning}". Ab yaad rahega.',
    'morning': 'Subah bakhair, {name}!',
    'afternoon': 'Salam, {name}!',
    'evening': 'Shaam bakhair, {name}!',
    'howHelp': 'Bataiye, kya madad karoon? Jaise "kal 6 baje yaad dilana".',
    'reminderSet': 'Ho gaya! {time} yaad dila doon ga: {title} ⏰',
    'askTime': 'Kis waqt yaad dilaoon?',
    'taskAdded': 'Task add kar diya: {title} ✅',
    'water': '{n} glass paani likh diya 💧 Aaj {total}/8.',
    'mood': 'Theek hai, aap ka mood note kar liya {emoji}',
    'expense': '{amount} save kar diya 💸',
    'habitDone': 'Zabardast! {name} ho gaya, {streak} din ki streak 🔥',
    'habitAlready': '{name} aaj pehle hi ho chuka hai 👍',
    'medicine': '{name} le li, note kar liya 💊',
    'medAlready': 'Aaj ki {name} ki saari doses ho chuki hain.',
    'journal': 'Diary mein likh diya ✍️',
    'fact': 'Yaad rakhoon ga: {text}',
    'nameSaved': 'Theek hai, aap ko {name} bulaoon ga 😊',
    'styleSaved': 'Samajh gaya, ab aise hi baat karoon ga.',
    'steps': 'Aaj aap {steps} qadam chale hain. Goal {goal} hai.',
    'stepsOff': 'Step counting band hai. Health khol ke on karein.',
    'spending': 'Is mahine aap ne {amount} kharch kiye hain.',
    'memory': 'Mujhe aap ke baare mein yeh yaad hai:',
    'noMemory': 'Abhi kuch nahi. "Yaad rakhna ke…" kahein.',
    'thanks': 'Koi baat nahi! 😊',
    'help': 'Main reminder, task, paani, mood, kharcha, habits aur dawai note kar sakta hoon, diary mein likh sakta hoon aur aap ki baatein yaad rakh sakta hoon.',
    'unknown': 'Yeh abhi samajh nahi aaya. Aap ka matlab kya tha? Neeche chunein, ya likhein: "aap ke alfaz = English meaning".',
    'taught': 'Samajh gaya, yaad rakhoon ga.',
    'chat': 'Achha 🙂',
    'todayIntro': 'Aaj abhi baqi hai:',
    'allDone': 'Aaj ka sab kaam ho gaya. Shabash! 🎉',
    'today': 'aaj',
    'tomorrow': 'kal',
    'sugWater': 'Abhi tak sirf {n} glass paani. Ek abhi pee lein?',
    'sugHabits': 'Aaj {n} habit(s) baqi hain.',
    'sugWalk': 'Goal ke liye {n} qadam aur. Thori walk?',
    'sugMood': 'Aaj aap ka mood kaisa hai?',
  },
  ChatLang.romanPashto: {
    'income': '{amount} Cash In ke me wlikal 💰',
    'whatDoing': 'Sta da madad la para tayar yam 😄 Ta sa kawe?',
    'tired': 'Dera stray wraz wa 😔 Lag aram wakra, oba wskha.',
    'sleepy': 'Nu biya wuweda sha 😴 Saba ba taza pasege!',
    'hungry': 'Sa kha shay wokhra 🍎',
    'sick': 'Khuday de shifa darkri 🤲 Aram wakra, oba wskha, ka zyat sho doctor ta lar sha.',
    'bored': 'Lag qadam wawaha ya sa wolwala? 🚶',
    'sad': 'Afsos 💙 Ghwaray che pa diary ke ye wlikay?',
    'happy': 'Dera kha! 😄',
    'stressed': 'Ugd sah wakhla 🌿 Dwa minute Breathe wazmaya.',
    'busy': 'Bokht wraz! 💪 Wawaya sa dar yaad kram.',
    'seeYou': 'Biya ba sara wogoro! Khayal sata 👋',
    'alhamdulillah': 'Alhamdulillah 🤲',
    'understand': 'Dera kha 👍',
    'love': 'Manana! 😊 Za hamesha sta sara yam.',
    'ack': 'Sha 👍',
    'no': 'Sha, kha da 🙂',
    'jokes': 'Doctor: Ta har wraz qadam wahe? Naroogh: Ho, tar fridge pore! 😄|Ustaz: Kor kaar de wlo na kro? Shagird: Ustaza, kor kaar kor ke pate sho! 😄',
    'replyLearned': 'Che ta "{phrase}" wawaye, za ba wayam: "{reply}".',
    'morning': 'Sahar mo pa khair, {name}!',
    'afternoon': 'Salam, {name}!',
    'evening': 'Makham mo pa khair, {name}!',
    'howHelp': 'Wawaya, tsa madad dar sara wakram?',
    'reminderSet': 'Sha! {time} ba dar yaad kram: {title} ⏰',
    'askTime': 'Tsa wakht dar yaad kram?',
    'taskAdded': 'Kaar me zyat kro: {title} ✅',
    'water': '{n} gilasa oba me wlikal 💧 Nan {total}/8.',
    'mood': 'Sha, sta hal me wlikalo {emoji}',
    'expense': '{amount} me wlikal 💸',
    'habitDone': 'Shabash! {name} nan pura sho, {streak} wrazay 🔥',
    'habitAlready': '{name} nan da mkhkay pura shaway 👍',
    'medicine': '{name} me wlikala 💊',
    'medAlready': 'Da {name} da nan tol doses shawi di.',
    'journal': 'Sta pa diary ke me wlikal ✍️',
    'fact': 'Pa yaad ba ye satam: {text}',
    'nameSaved': 'Sha, ta ta ba {name} wayam 😊',
    'styleSaved': 'Poh shwam, os ba daase khabare kawam.',
    'steps': 'Nan de {steps} gamuna wahali. Hadaf de {goal} de.',
    'stepsOff': 'Gamuna na shmerale kege. Health khlas kra.',
    'spending': 'Pa de miasht ke de {amount} lagawali.',
    'memory': 'Sta pa hakla ma ta da yaad di:',
    'noMemory': 'La hes na. Wawaya "pa yaad sata che…".',
    'thanks': 'Har kala! 😊',
    'help': 'Za yaadawane, kaarona, oba, hal, lagakht, adatuna aw dawai likalay sham, diary ke likalay sham aw sta khabare pa yaad satalay sham.',
    'unknown': 'Pa de la poh na shwam. Matlab de tsa wo? Ma ta ye zda kra, ya wlika: "sta jumla = English meaning".',
    'taught': 'Poh shwam, pa yaad ba ye satam.',
    'chat': 'Sha 🙂',
    'todayIntro': 'Nan la pate di:',
    'allDone': 'Da nan tol kaarona pura shwal. Shabash! 🎉',
    'today': 'nan',
    'tomorrow': 'saba',
    'sugWater': 'Tar osa sirf {n} gilasa oba. Yaw os wskha?',
    'sugHabits': 'Nan {n} adatuna pate di.',
    'sugWalk': 'Hadaf ta {n} nor gamuna. Lag qadam wawaha?',
    'sugMood': 'Nan de hal tsanga de?',
    'smallBoth': 'Za ham kha yam, manana! 😊',
    'smallAsked': 'Za kha yam, manana! Ta sanga ye?',
    'smallFine': 'Dera kha da! 😊 Tsa madad dar sara wakram?',
    'who': 'Za Buddy yam, sta Life assistant 🤖 Pa yaadawano, kaarono aw diary ke dar sara madad kawam.',
    'bye': 'Pa makha de kha! Khayal sata 👋',
    'night': 'Shpa de pa khair! Kha khob wakra 🌙',
    'meaningLearned': 'Poh shwam! "{phrase}" yani "{meaning}". Os ba ye pohegam.',
  },
  ChatLang.ur: {
    'income': '{amount} آمدن میں لکھ دیا 💰',
    'whatDoing': 'بس آپ کی مدد کے لیے حاضر ہوں 😄 آپ کیا کر رہے ہیں؟',
    'tired': 'لگتا ہے لمبا دن تھا 😔 تھوڑا آرام کریں، پانی پیئیں۔',
    'sleepy': 'تو سو جائیے 😴',
    'hungry': 'کچھ اچھا سا کھا لیجیے 🍎',
    'sick': 'اللہ شفا دے 🤲 آرام کریں، پانی پیئیں۔',
    'bored': 'تھوڑی سیر کر لیں؟ 🚶',
    'sad': 'مجھے افسوس ہے 💙 ڈائری میں لکھنا چاہیں گے؟',
    'happy': 'واہ، زبردست! 😄',
    'stressed': 'لمبی سانس لیں 🌿',
    'busy': 'مصروف دن! 💪 بتائیے کیا یاد دلانا ہے۔',
    'seeYou': 'پھر ملیں گے! 👋',
    'alhamdulillah': 'الحمدللہ 🤲',
    'understand': 'زبردست 👍',
    'love': 'شکریہ! 😊',
    'ack': 'ٹھیک ہے 👍',
    'no': 'کوئی بات نہیں 🙂',
    'jokes': 'ڈاکٹر: آپ روز سیر کرتے ہیں؟ مریض: جی ہاں، فریج تک! 😄',
    'replyLearned': 'جب آپ "{phrase}" کہیں گے، میں کہوں گا: "{reply}"۔',
    'smallBoth': 'میں بھی ٹھیک ہوں، شکریہ! 😊',
    'smallAsked': 'میں ٹھیک ہوں، شکریہ! آپ کیسے ہیں؟',
    'smallFine': 'اچھی بات ہے! 😊 بتائیے، کیا مدد کروں؟',
    'who': 'میں بڈی ہوں، آپ کا لائف اسسٹنٹ 🤖',
    'bye': 'اللہ حافظ! اپنا خیال رکھیں 👋',
    'night': 'شب بخیر! 🌙',
    'meaningLearned': 'سمجھ گیا! "{phrase}" کا مطلب ہے "{meaning}"۔',
    'morning': 'صبح بخیر، {name}!',
    'afternoon': 'السلام علیکم، {name}!',
    'evening': 'شام بخیر، {name}!',
    'howHelp': 'بتائیے، کیا مدد کروں؟',
    'reminderSet': 'ہو گیا! {time} یاد دلاؤں گا: {title} ⏰',
    'askTime': 'کس وقت یاد دلاؤں؟',
    'taskAdded': 'کام شامل کر دیا: {title} ✅',
    'water': '{n} گلاس پانی درج کر دیا 💧 آج {total}/8۔',
    'mood': 'ٹھیک ہے، آپ کا موڈ درج کر لیا {emoji}',
    'expense': '{amount} محفوظ کر دیا 💸',
    'habitDone': 'زبردست! {name} مکمل، {streak} دن کی سٹریک 🔥',
    'habitAlready': '{name} آج پہلے ہی ہو چکا ہے 👍',
    'medicine': '{name} لے لی، درج کر لیا 💊',
    'medAlready': 'آج کی {name} کی سب خوراکیں ہو چکی ہیں۔',
    'journal': 'ڈائری میں لکھ دیا ✍️',
    'fact': 'یاد رکھوں گا: {text}',
    'nameSaved': 'ٹھیک ہے، آپ کو {name} کہوں گا 😊',
    'styleSaved': 'سمجھ گیا، اب ایسے ہی بات کروں گا۔',
    'steps': 'آج آپ {steps} قدم چلے ہیں۔ ہدف {goal} ہے۔',
    'stepsOff': 'قدم گننا بند ہے۔ Health کھول کر چالو کریں۔',
    'spending': 'اس مہینے آپ نے {amount} خرچ کیے ہیں۔',
    'memory': 'مجھے آپ کے بارے میں یہ یاد ہے:',
    'noMemory': 'ابھی کچھ نہیں۔ "یاد رکھنا کہ…" کہیں۔',
    'thanks': 'کوئی بات نہیں! 😊',
    'help': 'میں یاد دہانی، کام، پانی، موڈ، خرچہ، عادتیں اور دوائی درج کر سکتا ہوں، ڈائری میں لکھ سکتا ہوں اور آپ کی باتیں یاد رکھ سکتا ہوں۔',
    'unknown': 'یہ ابھی سمجھ نہیں آیا۔ آپ کا مطلب کیا تھا؟ ایک بار سکھا دیں، یاد رکھوں گا۔',
    'taught': 'سمجھ گیا، یاد رکھوں گا۔',
    'chat': 'اچھا 🙂',
    'todayIntro': 'آج ابھی باقی ہے:',
    'allDone': 'آج کا سب کام ہو گیا۔ شاباش! 🎉',
    'today': 'آج',
    'tomorrow': 'کل',
    'sugWater': 'ابھی تک صرف {n} گلاس پانی۔ ایک ابھی پی لیں؟',
    'sugHabits': 'آج {n} عادتیں باقی ہیں۔',
    'sugWalk': 'ہدف کے لیے {n} قدم اور۔ تھوڑی سیر؟',
    'sugMood': 'آج آپ کا موڈ کیسا ہے؟',
  },
  ChatLang.ps: {
    'income': '{amount} په عاید کې ثبت شو 💰',
    'whatDoing': 'ستا د مرستې لپاره تیار یم 😄 ته څه کوې؟',
    'tired': 'ډېره ستړې ورځ وه 😔 لږ آرام وکړه، اوبه وڅښه.',
    'sleepy': 'نو بیا ویده شه 😴',
    'hungry': 'څه ښه شی وخوره 🍎',
    'sick': 'خدای دې شفا درکړي 🤲 آرام وکړه، اوبه وڅښه.',
    'bored': 'لږ قدم ووهه؟ 🚶',
    'sad': 'افسوس 💙 غواړې چې په ډایري کې یې ولیکې؟',
    'happy': 'ډېره ښه! 😄',
    'stressed': 'اوږده ساه واخله 🌿',
    'busy': 'بوخته ورځ! 💪 ووایه څه درته یاد کړم.',
    'seeYou': 'بیا به سره ووینو! 👋',
    'alhamdulillah': 'الحمدلله 🤲',
    'understand': 'ډېره ښه 👍',
    'love': 'مننه! 😊',
    'ack': 'سمه ده 👍',
    'no': 'ښه، سمه ده 🙂',
    'jokes': 'ډاکټر: ته هره ورځ قدم وهې؟ ناروغ: هو، تر فریج پورې! 😄',
    'replyLearned': 'چې ته "{phrase}" ووایې، زه به ووایم: "{reply}".',
    'smallBoth': 'زه هم ښه یم، مننه! 😊',
    'smallAsked': 'زه ښه یم، مننه! ته څنګه یې؟',
    'smallFine': 'ډېره ښه ده! 😊 څه مرسته درسره وکړم؟',
    'who': 'زه بډي یم، ستا د لایف مرستندوی 🤖',
    'bye': 'په مخه دې ښه! 👋',
    'night': 'شپه دې پخیر! 🌙',
    'meaningLearned': 'پوه شوم! "{phrase}" یعنې "{meaning}".',
    'morning': 'سهار مو پخیر، {name}!',
    'afternoon': 'السلام علیکم، {name}!',
    'evening': 'ماښام مو پخیر، {name}!',
    'howHelp': 'ووایه، څه مرسته درسره وکړم؟',
    'reminderSet': 'ښه! {time} به در یاد کړم: {title} ⏰',
    'askTime': 'څه وخت در یاد کړم؟',
    'taskAdded': 'کار مې ور زیات کړ: {title} ✅',
    'water': '{n} ګیلاسه اوبه ثبت شوې 💧 نن {total}/8.',
    'mood': 'ښه، ستا حال مې ثبت کړ {emoji}',
    'expense': '{amount} ثبت شو 💸',
    'habitDone': 'شاباش! {name} نن پوره شو، {streak} ورځې 🔥',
    'habitAlready': '{name} نن دمخه پوره شوی 👍',
    'medicine': '{name} ثبت شوه، دوا دې وخوړه 💊',
    'medAlready': 'د {name} د نن ټولې خوراکونه شوي دي.',
    'journal': 'ستا په ډایري کې مې ولیکل ✍️',
    'fact': 'په یاد به یې ولرم: {text}',
    'nameSaved': 'ښه، تا ته به {name} وایم 😊',
    'styleSaved': 'پوه شوم، له اوس به داسې خبرې کوم.',
    'steps': 'نن دې {steps} ګامونه وهلي. موخه دې {goal} ده.',
    'stepsOff': 'ګامونه نه شمېرل کېږي. Health پرانیزه او چالان یې کړه.',
    'spending': 'په دې میاشت کې دې {amount} لګولي.',
    'memory': 'ستا په اړه ما ته دا یاد دي:',
    'noMemory': 'لا هېڅ نه. ووایه "په یاد ولره چې…".',
    'thanks': 'هر کله! 😊',
    'help': 'زه یادونې، کارونه، اوبه، حال، لګښت، عادتونه او درمل ثبتولی شم، ډایري کې لیکلی شم او ستا خبرې په یاد ساتلی شم.',
    'unknown': 'په دې لا پوه نه شوم. مطلب دې څه و؟ یو ځل مې زده کړه، بیا به یې په یاد ولرم.',
    'taught': 'پوه شوم، په یاد به یې ولرم.',
    'chat': 'ښه 🙂',
    'todayIntro': 'نن لا پاتې دي:',
    'allDone': 'د نن ټول کارونه پوره شول. شاباش! 🎉',
    'today': 'نن',
    'tomorrow': 'سبا',
    'sugWater': 'تر اوسه یوازې {n} ګیلاسه اوبه. یو اوس وڅښه؟',
    'sugHabits': 'نن {n} عادتونه پاتې دي.',
    'sugWalk': 'موخې ته {n} نور ګامونه. لږ قدم ووهه؟',
    'sugMood': 'نن دې حال څنګه دی؟',
  },
};
