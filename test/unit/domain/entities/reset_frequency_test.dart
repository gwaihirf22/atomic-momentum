import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';

void main() {
  // 2024-01-15 is a Monday
  final mondayAnchor = DateTime(2024, 1, 15);
  final thursdayAnchor = DateTime(2024, 1, 18);

  group('ResetFrequency.shouldReset', () {
    group('daily', () {
      const frequency = ResetFrequency.daily;

      test('resets at the start of the next calendar day, even under 24 hours later', () {
        final lateNight = DateTime(2024, 1, 15, 23, 0);
        final nextMorning = DateTime(2024, 1, 16, 8, 0);

        expect(frequency.shouldReset(lateNight, nextMorning, anchor: mondayAnchor), isTrue);
      });

      test('does not reset later on the same day', () {
        final morning = DateTime(2024, 1, 15, 0, 5);
        final night = DateTime(2024, 1, 15, 23, 55);

        expect(frequency.shouldReset(morning, night, anchor: mondayAnchor), isFalse);
      });

      test('resets after several missed days', () {
        expect(
          frequency.shouldReset(DateTime(2024, 1, 10), DateTime(2024, 1, 15), anchor: mondayAnchor),
          isTrue,
        );
      });

      test('ignores the anchor', () {
        expect(
          frequency.periodStart(DateTime(2024, 1, 20, 14), anchor: thursdayAnchor),
          DateTime(2024, 1, 20),
        );
      });
    });

    group('weekly', () {
      const frequency = ResetFrequency.weekly;

      test('resets when crossing into the anchor weekday', () {
        final wednesday = DateTime(2024, 1, 24, 20, 0);
        final thursday = DateTime(2024, 1, 25, 7, 0);

        expect(frequency.shouldReset(wednesday, thursday, anchor: thursdayAnchor), isTrue);
      });

      test('does not reset within the same anchor-to-anchor week', () {
        final thursday = DateTime(2024, 1, 18, 7, 0);
        final nextWednesday = DateTime(2024, 1, 24, 22, 0);

        expect(frequency.shouldReset(thursday, nextWednesday, anchor: thursdayAnchor), isFalse);
      });

      test('a Monday anchor gives Monday-to-Sunday weeks', () {
        final sunday = DateTime(2024, 1, 14, 20, 0);
        final monday = DateTime(2024, 1, 15, 7, 0);

        expect(frequency.shouldReset(sunday, monday, anchor: mondayAnchor), isTrue);
      });

      test('resets across a month boundary', () {
        expect(
          frequency.shouldReset(DateTime(2024, 1, 31), DateTime(2024, 2, 5), anchor: mondayAnchor),
          isTrue,
        );
      });

      test('uses only the weekday of an anchor far in the past', () {
        final oldThursday = DateTime(2020, 3, 5);

        expect(
          frequency.periodStart(DateTime(2024, 1, 22), anchor: oldThursday),
          DateTime(2024, 1, 18),
        );
      });
    });

    group('monthly', () {
      const frequency = ResetFrequency.monthly;

      test('resets on the anchor day of the next month', () {
        final anchor15th = DateTime(2024, 1, 15);

        expect(
          frequency.shouldReset(DateTime(2024, 2, 14, 23), DateTime(2024, 2, 15, 1), anchor: anchor15th),
          isTrue,
        );
        expect(
          frequency.shouldReset(DateTime(2024, 1, 31), DateTime(2024, 2, 14), anchor: anchor15th),
          isFalse,
        );
      });

      test('a 1st-of-month anchor gives calendar months', () {
        final anchor1st = DateTime(2024, 1, 1);

        expect(
          frequency.shouldReset(DateTime(2024, 1, 31, 23), DateTime(2024, 2, 1, 1), anchor: anchor1st),
          isTrue,
        );
        expect(
          frequency.shouldReset(DateTime(2024, 1, 1), DateTime(2024, 1, 31, 23), anchor: anchor1st),
          isFalse,
        );
      });

      test('clamps a 31st anchor to the last day of shorter months', () {
        final anchor31st = DateTime(2024, 1, 31);

        // Leap-year February ends on the 29th
        expect(frequency.periodStart(DateTime(2024, 3, 10), anchor: anchor31st), DateTime(2024, 2, 29));
        expect(frequency.periodStart(DateTime(2024, 3, 31), anchor: anchor31st), DateTime(2024, 3, 31));
        expect(frequency.periodStart(DateTime(2024, 5, 1), anchor: anchor31st), DateTime(2024, 4, 30));
      });

      test('resets across a year boundary', () {
        final anchor15th = DateTime(2023, 6, 15);

        expect(frequency.periodStart(DateTime(2024, 1, 2), anchor: anchor15th), DateTime(2023, 12, 15));
        expect(
          frequency.shouldReset(DateTime(2023, 12, 20), DateTime(2024, 1, 16), anchor: anchor15th),
          isTrue,
        );
      });
    });

    test('never does not reset', () {
      expect(
        ResetFrequency.never.shouldReset(DateTime(2020, 1, 1), DateTime(2024, 1, 1), anchor: mondayAnchor),
        isFalse,
      );
    });

    test('does not reset when the clock moves backwards', () {
      expect(
        ResetFrequency.daily.shouldReset(DateTime(2024, 1, 16), DateTime(2024, 1, 15), anchor: mondayAnchor),
        isFalse,
      );
    });
  });

  test('periodUnit names what a streak counts', () {
    expect(ResetFrequency.daily.periodUnit, 'day');
    expect(ResetFrequency.weekly.periodUnit, 'week');
    expect(ResetFrequency.monthly.periodUnit, 'month');
  });

  test('periodStart keeps the calendar day of a UTC midnight date', () {
    expect(ResetFrequency.daily.periodStart(DateTime.utc(2024, 1, 16), anchor: mondayAnchor),
        DateTime(2024, 1, 16));
    // Monday 15th anchors the week; a UTC Monday must not slip to Sunday's week
    expect(ResetFrequency.weekly.periodStart(DateTime.utc(2024, 1, 15), anchor: mondayAnchor),
        DateTime(2024, 1, 15));
    expect(ResetFrequency.monthly.periodStart(DateTime.utc(2024, 2, 1), anchor: DateTime(2024, 1, 1)),
        DateTime(2024, 2, 1));
  });

  group('ResetFrequency.describeResetDay', () {
    test('weekly names the weekday', () {
      expect(ResetFrequency.weekly.describeResetDay(thursdayAnchor), 'Resets every Thursday');
    });

    test('monthly names the day with the right ordinal', () {
      expect(ResetFrequency.monthly.describeResetDay(DateTime(2024, 1, 1)), 'Resets on the 1st of each month');
      expect(ResetFrequency.monthly.describeResetDay(DateTime(2024, 1, 2)), 'Resets on the 2nd of each month');
      expect(ResetFrequency.monthly.describeResetDay(DateTime(2024, 1, 13)), 'Resets on the 13th of each month');
      expect(ResetFrequency.monthly.describeResetDay(DateTime(2024, 1, 23)), 'Resets on the 23rd of each month');
    });

    test('monthly mentions shorter months for days after the 28th', () {
      expect(
        ResetFrequency.monthly.describeResetDay(DateTime(2024, 1, 31)),
        'Resets on the 31st of each month (or the last day of shorter months)',
      );
    });

    test('daily and never have no reset day', () {
      expect(ResetFrequency.daily.describeResetDay(mondayAnchor), isNull);
      expect(ResetFrequency.never.describeResetDay(mondayAnchor), isNull);
    });
  });

  group('ResetFrequency.nextPeriodStart', () {
    final wednesdayAfternoon = DateTime(2024, 1, 17, 15, 30);

    test('daily returns the next midnight', () {
      expect(
        ResetFrequency.daily.nextPeriodStart(wednesdayAfternoon, anchor: mondayAnchor),
        DateTime(2024, 1, 18),
      );
    });

    test('weekly returns the next anchor weekday at midnight', () {
      expect(
        ResetFrequency.weekly.nextPeriodStart(wednesdayAfternoon, anchor: mondayAnchor),
        DateTime(2024, 1, 22),
      );
      expect(
        ResetFrequency.weekly.nextPeriodStart(wednesdayAfternoon, anchor: thursdayAnchor),
        DateTime(2024, 1, 18),
      );
    });

    test('monthly returns the next anchor day, clamped', () {
      expect(
        ResetFrequency.monthly.nextPeriodStart(DateTime(2024, 12, 10), anchor: DateTime(2024, 1, 1)),
        DateTime(2025, 1, 1),
      );
      expect(
        ResetFrequency.monthly.nextPeriodStart(DateTime(2024, 1, 31), anchor: DateTime(2024, 1, 31)),
        DateTime(2024, 2, 29),
      );
    });

    test('never throws', () {
      expect(
        () => ResetFrequency.never.nextPeriodStart(wednesdayAfternoon, anchor: mondayAnchor),
        throwsStateError,
      );
    });
  });
}
