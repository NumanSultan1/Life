import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vortextech_appdev_week4/services/hive_service.dart';
import 'package:vortextech_appdev_week4/main.dart';
import 'package:vortextech_appdev_week4/widgets/life_logo.dart';

void main() {
  setUp(() async {
    Hive.init('.');
    await Hive.openBox(HiveService.tasksBox);
    await Hive.openBox(HiveService.habitsBox);
    await Hive.openBox(HiveService.journalBox);
    await Hive.openBox(HiveService.goalsBox);
    await Hive.openBox(HiveService.settingsBox);
    await Hive.openBox(HiveService.usersBox);
  });

  tearDown(() async {
    await Hive.close();
  });

  testWidgets('App loads splash screen logo', (WidgetTester tester) async {
    await tester.pumpWidget(const LifeDashboardApp());
    expect(find.byType(LifeLogo), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Tasks · Habits · Goals · Journal'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
