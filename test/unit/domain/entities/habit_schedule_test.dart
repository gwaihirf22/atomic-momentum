import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/habit_schedule.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';

void main() {
  // 2026-10-16 is a Friday
  final fri16 = DateTime(2026, 10, 16);

  HabitSchedule daily({int interval = 1, Iterable<int>? weekdays, DateTime? anchor}) =>
      HabitSchedule(frequency: ResetFrequency.daily, interval: interval, anchor: anchor ?? fri16, weekdays: weekdays);

  group('every N days', () {
    final every2 = daily(interval: 2);

    test('periods are 2-day blocks counted from the start date', () {
      expect(every2.periodStart(DateTime(2026, 10, 16, 9)), DateTime(2026, 10, 16));
      expect(every2.periodStart(DateTime(2026, 10, 17, 23)), DateTime(2026, 10, 16));
      expect(every2.periodStart(DateTime(2026, 10, 18)), DateTime(2026, 10, 18));
      expect(every2.nextPeriodStart(DateTime(2026, 10, 17)), DateTime(2026, 10, 18));
    });

    test('dates before the start date fall into earlier blocks', () {
      expect(every2.periodStart(DateTime(2026, 10, 15)), DateTime(2026, 10, 14));
      expect(every2.periodStart(DateTime(2026, 10, 14)), DateTime(2026, 10, 14));
    });

    test('resets only when a new block starts', () {
      expect(every2.shouldReset(DateTime(2026, 10, 16, 8), DateTime(2026, 10, 17, 20)), isFalse);
      expect(every2.shouldReset(DateTime(2026, 10, 17, 20), DateTime(2026, 10, 18, 1)), isTrue);
    });

    test('blocks stay aligned across daylight-saving changes', () {
      // US DST ends 2026-11-01; 3-day blocks from Oct 16: ... Oct 31, Nov 3
      final every3 = daily(interval: 3);
      expect(every3.periodStart(DateTime(2026, 11, 2)), DateTime(2026, 10, 31));
      expect(every3.nextPeriodStart(DateTime(2026, 11, 2)), DateTime(2026, 11, 3));
    });
  });

  group('every N weeks and months', () {
    test('every 2 weeks from a Friday', () {
      final s = HabitSchedule(frequency: ResetFrequency.weekly, interval: 2, anchor: fri16);
      expect(s.periodStart(DateTime(2026, 10, 29)), fri16);
      expect(s.periodStart(DateTime(2026, 10, 30)), DateTime(2026, 10, 30));
      expect(s.nextPeriodStart(fri16), DateTime(2026, 10, 30));
      expect(s.periodStart(DateTime(2026, 10, 10)), DateTime(2026, 10, 2));
    });

    test('every 3 months on the 31st clamps to short months', () {
      final s = HabitSchedule(frequency: ResetFrequency.monthly, interval: 3, anchor: DateTime(2026, 1, 31));
      expect(s.periodStart(DateTime(2026, 4, 29)), DateTime(2026, 1, 31));
      expect(s.periodStart(DateTime(2026, 4, 30)), DateTime(2026, 4, 30));
      expect(s.nextPeriodStart(DateTime(2026, 5, 1)), DateTime(2026, 7, 31));
      expect(s.periodStart(DateTime(2025, 12, 1)), DateTime(2025, 10, 31));
    });
  });

  group('specific weekdays', () {
    final monWedFri = daily(weekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday]);

    test('due only on the chosen days', () {
      expect(monWedFri.isDueOn(DateTime(2026, 10, 16)), isTrue); // Fri
      expect(monWedFri.isDueOn(DateTime(2026, 10, 17)), isFalse); // Sat
      expect(monWedFri.isDueOn(DateTime(2026, 10, 19)), isTrue); // Mon
    });

    test('previous and next due days skip rest days', () {
      expect(monWedFri.previousDuePeriodStart(DateTime(2026, 10, 19)), DateTime(2026, 10, 16));
      expect(monWedFri.nextDuePeriodStart(DateTime(2026, 10, 16)), DateTime(2026, 10, 19));
    });

    test('weekdays are ignored where they do not apply', () {
      expect(daily(weekdays: [1, 2, 3, 4, 5, 6, 7]).weekdays, isNull);
      expect(daily(weekdays: const []).weekdays, isNull);
      expect(daily(interval: 2, weekdays: [1]).weekdays, isNull);
      expect(HabitSchedule(frequency: ResetFrequency.weekly, anchor: fri16, weekdays: [1]).weekdays, isNull);
    });
  });

  group('labels', () {
    test('describe', () {
      expect(daily().describe(), 'Resets every day');
      expect(daily(interval: 2).describe(), 'Resets every 2 days, starting Fri, Oct 16');
      expect(daily(weekdays: [5, 1, 3]).describe(), 'Due Mon, Wed, Fri; other days are rest days');
      expect(HabitSchedule(frequency: ResetFrequency.weekly, anchor: fri16).describe(), 'Resets every Friday');
      expect(HabitSchedule(frequency: ResetFrequency.weekly, interval: 2, anchor: fri16).describe(),
          'Resets every 2 weeks on Fridays, starting Fri, Oct 16');
      expect(HabitSchedule(frequency: ResetFrequency.monthly, interval: 3, anchor: fri16).describe(),
          'Resets every 3 months on the 16th, starting Fri, Oct 16');
      expect(HabitSchedule(frequency: ResetFrequency.never, anchor: fri16).describe(), 'Never resets');
    });

    test('periodLabel and shortLabel', () {
      expect(daily().periodLabel, 'per day');
      expect(HabitSchedule(frequency: ResetFrequency.weekly, anchor: fri16).periodLabel, 'per week');
      expect(HabitSchedule(frequency: ResetFrequency.weekly, interval: 2, anchor: fri16).periodLabel, 'per 2 weeks');
      expect(HabitSchedule(frequency: ResetFrequency.never, anchor: fri16).periodLabel, 'in total');

      expect(daily().shortLabel, 'Daily');
      expect(daily(interval: 2).shortLabel, 'Every 2 days');
      expect(daily(weekdays: [1, 3, 5]).shortLabel, 'Mon, Wed, Fri');
    });

    test('streakLabel', () {
      expect(daily().streakLabel(3), '3 day streak');
      expect(HabitSchedule(frequency: ResetFrequency.weekly, anchor: fri16).streakLabel(2), '2 week streak');
      expect(daily(interval: 2).streakLabel(4), '4 in a row');
    });
  });
}
