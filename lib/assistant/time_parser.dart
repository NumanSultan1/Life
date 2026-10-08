import 'lang_util.dart';

/// A date/time found in a sentence, plus the text with it removed.
class ParsedTime {
  final DateTime when;
  final bool hasTime;
  final String rest;

  const ParsedTime(this.when, this.hasTime, this.rest);
}

// Words for days and parts of the day in each language.
const _today = ['today', 'tonight', 'aaj', 'aj', 'nan', 'nun', 'آج', 'نن', 'ننن'];
const _tomorrow = ['tomorrow', 'tmrw', 'kal', 'saba', 'sabaa', 'sabah', 'کل', 'سبا'];
const _dayAfter = ['day after tomorrow', 'parson', 'parso', 'bal saba', 'bal sabaa', 'پرسوں', 'بل سبا', 'لبل سبا'];
const _morning = ['morning', 'am', 'a.m.', 'subah', 'subha', 'savere', 'sahar', 'sahar pa', 'صبح', 'سهار', 'سحر'];
const _noon = ['noon', 'afternoon', 'dopahar', 'dopehar', 'gharma', 'maspakhin', 'دوپہر', 'غرمه', 'ماسپښین'];
const _evening = ['evening', 'pm', 'p.m.', 'shaam', 'sham', 'makham', 'maakham', 'maxam', 'mazigar', 'شام', 'ماښام', 'مازیګر'];
const _night = ['night', 'tonight', 'raat', 'shpa', 'shpe', 'رات', 'شپه', 'شپې'];
const _hourWords = ['baje', 'bajay', 'bajey', 'bajy', 'baji', 'bajo', "o'clock", 'oclock', 'بجے', 'بجې', 'بجی', 'بجه'];
const _weekdays = {
  'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4, 'friday': 5, 'saturday': 6, 'sunday': 7,
  'peer': 1, 'mangal': 2, 'budh': 3, 'jumeraat': 4, 'jumma': 5, 'hafta': 6, 'itwar': 7,
  'پیر': 1, 'منگل': 2, 'بدھ': 3, 'جمعرات': 4, 'جمعہ': 5, 'ہفتہ': 6, 'اتوار': 7,
  'دوشنبه': 1, 'سه شنبه': 2, 'چهارشنبه': 3, 'پنجشنبه': 4, 'جمعه': 5, 'شنبه': 6, 'یکشنبه': 7,
};

/// Finds a time ("at 6 pm", "kal 6 baje", "سبا ماښام شپږ بجې", "in 2 hours")
/// in [input]. Returns null if there is none.
ParsedTime? parseTime(String input, {DateTime? now}) {
  final base = now ?? DateTime.now();
  var text = normalizeDigits(input);
  var lower = text.toLowerCase();
  var day = DateTime(base.year, base.month, base.day);
  var dateFound = false;

  // "in 20 minutes", "2 ghante baad", "۲ ساعته وروسته", "20 منټه وروسته"
  final rel = RegExp(r'(?:in|after)?\s*(\d+|[a-z]+|\S+)\s*(minutes?|mins?|hours?|hrs?|minute|ghante|ghanta|ghanton|minat|minta|sahata|saata|منٹ|گھنٹے|گھنٹہ|ساعته|ساعت|ګړۍ|منټه|دقیقې)\s*(baad|bad|wrusta|warusta|pas|بعد|وروسته|later)?', caseSensitive: false);
  for (final m in rel.allMatches(lower)) {
    final hasPrefix = RegExp(r'^\s*(in|after)', caseSensitive: false).hasMatch(m.group(0)!);
    if (!hasPrefix && m.group(3) == null) continue;
    final n = parseNumber(m.group(1)!);
    if (n == null) continue;
    final unit = m.group(2)!.toLowerCase();
    final minutes = RegExp(r'^(h|ghant|sahat|saat|گھنٹ|ساعت|ګړۍ)').hasMatch(unit) ? n * 60 : n;
    final when = base.add(Duration(minutes: minutes));
    return ParsedTime(when, true, _clean(text.replaceRange(m.start, m.end, ' ')));
  }

  // Day words (longest first so "day after tomorrow" wins over "tomorrow").
  for (final entry in [(_dayAfter, 2), (_tomorrow, 1), (_today, 0)]) {
    if (hasAny(lower, entry.$1)) {
      day = day.add(Duration(days: entry.$2));
      text = removeAny(text, entry.$1);
      lower = text.toLowerCase();
      dateFound = true;
      break;
    }
  }
  if (!dateFound) {
    for (final w in _weekdays.entries) {
      if (hasAny(lower, [w.key, 'on ${w.key}'])) {
        var add = (w.value - day.weekday) % 7;
        if (add == 0) add = 7;
        day = day.add(Duration(days: add));
        text = removeAny(text, ['on ${w.key}', w.key]);
        lower = text.toLowerCase();
        dateFound = true;
        break;
      }
    }
  }

  // Part of day.
  int? period; // 0 morning, 1 noon, 2 evening, 3 night
  for (final p in [(_morning, 0), (_noon, 1), (_evening, 2), (_night, 3)]) {
    if (hasAny(lower, p.$1)) {
      period = p.$2;
      break;
    }
  }

  // Clock time: "6", "6:30", "6.30", "at 6", "6 baje", "شپږ بجې".
  int? hour, minute;
  final clock = RegExp(r'(?:\bat\s+|\bko\s+)?(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?');
  final hourWordPattern = _hourWords.map(RegExp.escape).join('|');
  final wordClock = RegExp('(\\S+)\\s*($hourWordPattern)');
  RegExpMatch? m;
  for (final c in clock.allMatches(lower)) {
    final h = int.parse(c.group(1)!);
    final after = lower.substring(c.end);
    final before = lower.substring(0, c.start);
    final isTime = c.group(2) != null ||
        c.group(3) != null ||
        RegExp(r'^\s*(' + hourWordPattern + r')').hasMatch(after) ||
        RegExp(r'(\bat|\bko)\s*$').hasMatch(before) ||
        c.group(0)!.trimLeft().startsWith('at ');
    if (isTime && h <= 23) {
      m = c;
      hour = h;
      minute = c.group(2) == null ? 0 : int.parse(c.group(2)!);
      if (c.group(3) != null) period = c.group(3)!.startsWith('a') ? 0 : 2;
      break;
    }
  }
  if (hour == null) {
    final w = wordClock.firstMatch(lower);
    if (w != null) {
      final n = parseNumber(w.group(1)!);
      if (n != null && n >= 1 && n <= 12) {
        hour = n;
        minute = 0;
        text = text.replaceRange(w.start, w.end, ' ');
        lower = text.toLowerCase();
      }
    }
  } else {
    text = text.replaceRange(m!.start, m.end, ' ');
    lower = text.toLowerCase();
    text = removeAny(text, _hourWords);
  }
  text = removeAny(text, [..._morning.where((w) => w.length > 2), ..._noon, ..._evening.where((w) => w.length > 2), ..._night]);
  // A dangling "at"/"ko" left next to where the time was.
  text = text.replaceAll(RegExp(r'(^|\s)(at|ko)\s*$', caseSensitive: false), ' ').replaceAll(RegExp(r'^\s*(at)\s', caseSensitive: false), ' ');

  if (hour == null && !dateFound && period == null) return null;
  final explicitTime = hour != null || period != null;

  if (hour == null) {
    // Only a day or part of day: pick a sensible time.
    hour = switch (period) { 0 => 8, 1 => 13, 2 => 18, 3 => 21, _ => 9 };
    minute = 0;
  } else if (hour <= 12) {
    if (period == 2 || period == 3) {
      if (hour < 12) hour += 12;
    } else if (period == 1) {
      if (hour < 11) hour += 12;
    } else if (period == 0) {
      if (hour == 12) hour = 0;
    } else if (hour >= 1 && hour <= 6) {
      // "at 6" with no am/pm usually means the evening.
      hour += 12;
    } else if (!dateFound) {
      // 7-11 with no hint: the next time it comes round today.
      final am = DateTime(day.year, day.month, day.day, hour, minute!);
      if (am.isBefore(base) && hour < 12) hour += 12;
    }
  }

  var when = DateTime(day.year, day.month, day.day, hour, minute!);
  if (!dateFound && when.isBefore(base)) when = when.add(const Duration(days: 1));
  return ParsedTime(when, explicitTime, _clean(text));
}

String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
