import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Feeds the "Today" home-screen widget (Android).
class LifeWidget {
  LifeWidget._();

  static String? _last;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Sends today's numbers to the widget; skips when nothing changed.
  static Future<void> update({required int done, required int total, String? nextTask}) async {
    if (!supported) return;
    final left = total - done;
    final percent = total == 0 ? 0 : (done * 100 / total).round();
    final status = total == 0
        ? 'Nothing planned yet'
        : left == 0
            ? 'All done for today 🎉'
            : '$left left · $done of $total done';
    final next = left == 0 || nextTask == null ? 'Open Life to plan tomorrow' : 'Next: $nextTask';
    final payload = '$percent|$status|$next';
    if (payload == _last) return;
    _last = payload;
    try {
      await HomeWidget.saveWidgetData<int>('percent', percent);
      await HomeWidget.saveWidgetData<String>('status', status);
      await HomeWidget.saveWidgetData<String>('next', next);
      await HomeWidget.updateWidget(qualifiedAndroidName: 'com.example.vortextech_appdev_week4.TodayWidget');
    } catch (_) {
      _last = null;
    }
  }
}
