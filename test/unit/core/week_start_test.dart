import 'dart:ui' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/locale/week_start.dart';

void main() {
  test('first day of the week follows the region', () {
    expect(regionalFirstDayOfWeek(const Locale('en', 'US')), DateTime.sunday);
    expect(regionalFirstDayOfWeek(const Locale('en', 'CA')), DateTime.sunday);
    expect(regionalFirstDayOfWeek(const Locale('ja', 'JP')), DateTime.sunday);
    expect(regionalFirstDayOfWeek(const Locale('en', 'GB')), DateTime.monday);
    expect(regionalFirstDayOfWeek(const Locale('de', 'DE')), DateTime.monday);
    expect(regionalFirstDayOfWeek(const Locale('ar')), DateTime.saturday);
  });

  test('falls back to the language, then to Monday', () {
    expect(regionalFirstDayOfWeek(const Locale('en', 'ZZ')), DateTime.sunday);
    expect(regionalFirstDayOfWeek(const Locale('xx')), DateTime.monday);
  });

  test('weekdaysStartingOn orders the week', () {
    expect(weekdaysStartingOn(DateTime.sunday), [7, 1, 2, 3, 4, 5, 6]);
    expect(weekdaysStartingOn(DateTime.monday), [1, 2, 3, 4, 5, 6, 7]);
    expect(weekdaysStartingOn(DateTime.saturday), [6, 7, 1, 2, 3, 4, 5]);
  });
}
