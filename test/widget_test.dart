import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vortextech_appdev_week4/main.dart';

void main() {
  testWidgets('App loads splash screen title', (WidgetTester tester) async {
    await tester.pumpWidget(const LifeDashboardApp());
    expect(find.text('Life Dashboard'), findsOneWidget);
  });
}
