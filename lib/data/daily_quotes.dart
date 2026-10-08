import 'quotes_good.dart';
import 'quotes_great.dart';
import 'quotes_low.dart';
import 'quotes_okay.dart';
import 'quotes_sad.dart';

/// 1,000+ daily thoughts, about 200 per mood. Each mood has its own list,
/// so the five moods always show five different quotes, and each one
/// changes at midnight.
const Map<String, List<String>> quotesByMood = {
  '😄': quotesGreat,
  '😊': quotesGood,
  '😐': quotesOkay,
  '😔': quotesLow,
  '😭': quotesSad,
};

int _dayNumber(DateTime date) => DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(2024)).inDays;

/// Today's quote for [mood] (defaults to 😊 for unknown moods).
String quoteForMood(String mood, [DateTime? date]) {
  final list = quotesByMood[mood] ?? quotesGood;
  return list[_dayNumber(date ?? DateTime.now()) % list.length];
}

/// A "quote of the day" drawn from all moods, offset so it doesn't repeat
/// the mood card's quote.
String quoteOfTheDay([DateTime? date]) {
  final all = quotesByMood.values.expand((l) => l).toList();
  return all[(_dayNumber(date ?? DateTime.now()) * 7 + 101) % all.length];
}
