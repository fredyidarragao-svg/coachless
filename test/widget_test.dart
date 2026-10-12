import 'package:coachless/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('las fechas se convierten ida y vuelta', () {
    final k = dkey(DateTime(2026, 10, 12));
    expect(k, '2026-10-12');
    expect(weekdayOf(k), 0); // lunes
    expect(addDays(k, 1), '2026-10-13');
  });
}
