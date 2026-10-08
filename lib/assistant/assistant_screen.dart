import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/habit_provider.dart';
import '../providers/journal_provider.dart';
import '../services/voice_languages.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import '../widgets/liquid/liquid.dart';
import '../widgets/voice_input_button.dart';
import '../widgets/life_buddy.dart';
import 'assistant_engine.dart';
import 'assistant_memory.dart';
import 'lang_util.dart';
import 'memory_screen.dart';
import 'voice_out.dart';

class _Message {
  final bool fromUser;
  String text;
  final ChatLang lang;
  final List<DoneAction> actions;
  final Set<int> undone = {};
  final bool askTeach;
  final String? teachText; // what the user said, for teaching
  bool taught = false;
  bool? rated;

  /// For a user message: the reply it produced (to undo on a fix).
  _Message? reply;

  _Message.user(this.text) : fromUser = true, lang = detectLang(text), actions = const [], askTeach = false, teachText = null;

  _Message.bot(AssistantReply r, {this.teachText}) : fromUser = false, text = r.text, lang = r.lang, actions = r.actions, askTeach = r.askTeach;
}

const _teachLabels = <ChatLang, Map<String, String>>{
  ChatLang.en: {'task': 'A task', 'reminder': 'A reminder', 'journal': 'Journal note', 'water': 'Drank water', 'habit': 'A habit', 'chat': 'Just chatting'},
  ChatLang.romanUrdu: {'task': 'Task', 'reminder': 'Reminder', 'journal': 'Diary', 'water': 'Paani piya', 'habit': 'Habit', 'chat': 'Bas baat'},
  ChatLang.romanPashto: {'task': 'Kaar', 'reminder': 'Yaadawana', 'journal': 'Diary', 'water': 'Oba me wskale', 'habit': 'Adat', 'chat': 'Sirf khabare'},
  ChatLang.ur: {'task': 'کام', 'reminder': 'یاد دہانی', 'journal': 'ڈائری', 'water': 'پانی پیا', 'habit': 'عادت', 'chat': 'بس بات'},
  ChatLang.ps: {'task': 'کار', 'reminder': 'یادونه', 'journal': 'ډایري', 'water': 'اوبه مې وڅښلې', 'habit': 'عادت', 'chat': 'یوازې خبرې'},
};

/// Talk or type to Life. It acts in the app, replies by voice, learns
/// your phrases, and saves the best parts of the chat to your journal.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  late final AssistantEngine _engine = AssistantEngine(context);
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [];
  bool _busy = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    AssistantMemory.loadLearnedWords();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Greet in the style the user chats in (remembered), else the voice language.
      final lang = AssistantMemory.chatLang ?? _langFromSetting();
      if (AssistantMemory.style.speak) VoiceOut.warmUp(lang);
      final hello = AssistantReply(_engine.greeting(lang), lang);
      setState(() => _messages.add(_Message.bot(hello)));
      _say(hello);
    });
  }

  @override
  void dispose() {
    VoiceOut.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ChatLang _langFromSetting() => switch (VoiceLanguageSetting.current.lang) {
    'ur' => ChatLang.ur,
    'ps' => ChatLang.ps,
    _ => ChatLang.en,
  };

  void _say(AssistantReply r) {
    if (AssistantMemory.style.speak) VoiceOut.speak(r.text, r.lang);
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    final userMsg = _Message.user(text);
    setState(() {
      _messages.add(userMsg);
      _busy = true;
    });
    _scrollDown();
    try {
      final reply = await _engine.handle(text);
      if (!mounted) return;
      final bot = _Message.bot(reply, teachText: reply.askTeach ? text : null);
      userMsg.reply = bot;
      setState(() => _messages.add(bot));
      _say(reply);
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollDown();
    }
  }

  Future<void> _teach(_Message m, String type) async {
    String? habit;
    if (type == 'habit') {
      final habits = Provider.of<HabitProvider>(context, listen: false).habits;
      if (habits.isEmpty) {
        showInfoSnackBar(context, 'You have no habits yet. Create one in the Habits tab first.');
        return;
      }
      habit = await showLiquidActions<String>(context, title: 'Which habit?', actions: [for (final h in habits) LiquidAction(h.title, h.title, Icons.loop_rounded)]);
      if (habit == null) return;
    }
    final reply = await _engine.teach(m.teachText!, type, habit: habit);
    if (!mounted) return;
    setState(() {
      m.taught = true;
      _messages.add(_Message.bot(reply));
    });
    _say(reply);
    _scrollDown();
  }

  /// The user corrects what speech recognition heard: undo what that
  /// message did, learn the word fixes, and run it again.
  Future<void> _fix(_Message m) async {
    final controller = TextEditingController(text: m.text);
    final fixed = await showLiquidDialog<String>(
      context: context,
      title: 'Fix what I heard',
      icon: Icons.edit_rounded,
      builder: (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SmartTextField(controller: controller, hint: 'What you said', maxLines: 3),
          const SizedBox(height: 8),
          Text('I\'ll remember the corrected words next time.', style: Theme.of(c).textTheme.bodyMedium?.copyWith(fontSize: 12)),
          const SizedBox(height: 18),
          LiquidDialogActions(confirmLabel: 'Fix', onCancel: () => Navigator.pop(c), onConfirm: () => Navigator.pop(c, controller.text.trim())),
        ],
      ),
    );
    controller.dispose();
    if (fixed == null || fixed.isEmpty || fixed == m.text) return;
    final reply = m.reply;
    if (reply != null) {
      for (var i = 0; i < reply.actions.length; i++) {
        if (!reply.undone.contains(i)) await reply.actions[i].undo?.call();
        reply.undone.add(i);
      }
    }
    await AssistantMemory.learnFromEdit(m.text, fixed);
    if (!mounted) return;
    setState(() => m.text = fixed);
    final r = await _engine.handle(fixed);
    if (!mounted) return;
    final bot = _Message.bot(r, teachText: r.askTeach ? fixed : null);
    m.reply = bot;
    setState(() => _messages.add(bot));
    _say(r);
    _scrollDown();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    VoiceOut.stop();
    final nav = Navigator.of(context);
    final below = nav.context;
    final journals = Provider.of<JournalProvider>(context, listen: false);
    final journal = await _engine.saveHighlights();
    nav.pop();
    // Shown on the screen underneath, which stays mounted.
    if (journal != null && below.mounted) showUndoSnackBar(below, 'Saved chat highlights to your journal ✍️', () => journals.deleteEntry(journal.id));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final speaking = AssistantMemory.style.speak;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        body: AmbientBackground(
          child: Column(
            children: [
              LiquidHeader(
                title: 'Life Assistant',
                subtitle: 'Talk or type · it learns your way',
                leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: _finish),
                actions: [
                  Tooltip(
                    message: speaking ? 'Mute voice replies' : 'Read replies aloud',
                    child: GlassIconButton(
                      icon: speaking ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      onTap: () async {
                        await AssistantMemory.setStyle(AssistantMemory.style.copyWith(speak: !speaking));
                        if (speaking) VoiceOut.stop();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'What I remember',
                    child: GlassIconButton(
                      icon: Icons.psychology_rounded,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryScreen())),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _messages.length + 1 + (_busy ? 1 : 0),
                  itemBuilder: (context, i) {
                    // Buddy at the top, arriving from the floating button.
                    if (i == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 4),
                        child: Center(
                          child: Hero(tag: 'life-buddy', child: LifeBuddy(size: 84)),
                        ),
                      );
                    }
                    i -= 1;
                    if (i == _messages.length) return const _Typing();
                    final m = _messages[i];
                    return m.fromUser ? _UserBubble(m: m, onFix: () => _fix(m)) : _BotBubble(m: m, onTeach: (t) => _teach(m, t), onChanged: () => setState(() {}));
                  },
                ),
              ),
              _InputBar(controller: _input, onSend: _send, busy: _busy),
              Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom > 0 ? 0 : 4),
                child: Text('Tap your message to fix what I heard', style: textTheme.bodyMedium?.copyWith(fontSize: 10.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final _Message m;
  final VoidCallback onFix;

  const _UserBubble({required this.m, required this.onFix});

  @override
  Widget build(BuildContext context) {
    final rtl = m.lang == ChatLang.ur || m.lang == ChatLang.ps;
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: onFix,
        child: Container(
          margin: const EdgeInsets.only(top: 10, left: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(6)),
          ),
          child: Text(
            m.text,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(color: Colors.white, fontSize: rtl ? 16.5 : 15, height: 1.45),
          ),
        ),
      ),
    );
  }
}

class _BotBubble extends StatelessWidget {
  final _Message m;
  final ValueChanged<String> onTeach;
  final VoidCallback onChanged;

  const _BotBubble({required this.m, required this.onTeach, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final rtl = m.lang == ChatLang.ur || m.lang == ChatLang.ps;
    final textTheme = Theme.of(context).textTheme;
    final labels = _teachLabels[m.lang] ?? _teachLabels[ChatLang.en]!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Padding(padding: EdgeInsets.only(right: 6, bottom: 2), child: LifeBuddy(size: 30, animate: false)),
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(top: 10, right: 30),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.text,
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    style: TextStyle(fontSize: rtl ? 16.5 : 15, height: 1.45),
                  ),
                  for (var i = 0; i < m.actions.length; i++)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                      decoration: BoxDecoration(color: (m.undone.contains(i) ? AppColors.textSecondary : AppColors.success).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Icon(m.actions[i].icon, size: 18, color: m.undone.contains(i) ? AppColors.textSecondary : AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              m.actions[i].summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, decoration: m.undone.contains(i) ? TextDecoration.lineThrough : null),
                            ),
                          ),
                          if (m.actions[i].undo != null && !m.undone.contains(i))
                            TextButton(
                              onPressed: () async {
                                await m.actions[i].undo!();
                                m.undone.add(i);
                                onChanged();
                              },
                              child: const Text('Undo'),
                            )
                          else if (m.undone.contains(i))
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text('Undone', style: textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
                            ),
                        ],
                      ),
                    ),
                  if (m.askTeach && !m.taught) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (type, icon) in teachOptions)
                          ActionChip(
                            avatar: Icon(icon, size: 16, color: AppColors.accentOn(context)),
                            label: Text(labels[type] ?? type, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                            onPressed: () => onTeach(type),
                          ),
                      ],
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final good in [true, false])
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          tooltip: good ? 'Good reply' : 'Not helpful',
                          onPressed: m.rated != null
                              ? null
                              : () async {
                                  m.rated = good;
                                  await AssistantMemory.addFeedback(good);
                                  onChanged();
                                  if (!good && context.mounted) {
                                    showInfoSnackBar(context, 'Thanks. Tap your message to fix it, or say "talk less" / "be more formal".');
                                  }
                                },
                          icon: Icon(
                            good ? (m.rated == true ? Icons.thumb_up_rounded : Icons.thumb_up_outlined) : (m.rated == false ? Icons.thumb_down_rounded : Icons.thumb_down_outlined),
                            color: m.rated == good ? AppColors.accentOn(context) : textTheme.bodyMedium?.color,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(top: 12, left: 6),
        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function([String?]) onSend;
  final bool busy;

  const _InputBar({required this.controller, required this.onSend, required this.busy});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                textDirection: isRtlText(value.text) ? TextDirection.rtl : TextDirection.ltr,
                decoration: const InputDecoration(hintText: 'Say or type anything…', border: InputBorder.none, filled: false, isDense: true),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                VoiceInputButton(controller: controller, onFinished: () => onSend(), speechHints: AssistantMemory.speechHints, quick: true),
                const Spacer(),
                Semantics(
                  button: true,
                  label: 'Send',
                  child: GestureDetector(
                    onTap: busy ? null : () => onSend(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.primaryGradient),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
