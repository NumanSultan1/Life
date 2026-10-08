import 'package:flutter_test/flutter_test.dart';
import 'package:vortextech_appdev_week4/screens/achievements_screen.dart';

void main() {
  test('there are 100+ badges with unique ids and names', () {
    expect(achievements.length, greaterThanOrEqualTo(100));
    expect(achievements.map((a) => a.id).toSet().length, achievements.length);
    expect(achievements.map((a) => a.title).toSet().length, achievements.length);
    expect(achievements.every((a) => a.category.isNotEmpty), isTrue);
  });
}
