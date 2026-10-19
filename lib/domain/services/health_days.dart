import 'dart:math' as math;
import '../entities/habit.dart';
import '../entities/reset_frequency.dart';

/// A stretch of time Health recorded (a sleep stage, a workout, a mindful
/// session).
typedef HealthSpan = ({DateTime start, DateTime end});

/// Turns Health samples into whole numbers per day. Pure: the plugin's
/// samples go in, a day → amount map comes out.
class HealthDays {
  const HealthDays._();

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static Iterable<DateTime> _days(DateTime from, DateTime to) sync* {
    for (var d = _day(from); !d.isAfter(_day(to)); d = DateTime(d.year, d.month, d.day + 1)) {
      yield d;
    }
  }

  /// Minutes covered by [spans] within [from]–[to], overlaps counted once
  /// (the iPhone and the Watch recording one session count as one).
  static int unionMinutes(Iterable<HealthSpan> spans, {required DateTime from, required DateTime to}) {
    final clipped = [
      for (final s in spans)
        if (s.end.isAfter(from) && s.start.isBefore(to))
          (start: s.start.isBefore(from) ? from : s.start, end: s.end.isAfter(to) ? to : s.end),
    ]..sort((a, b) => a.start.compareTo(b.start));
    var total = Duration.zero;
    DateTime? runStart;
    DateTime? runEnd;
    for (final s in clipped) {
      if (runEnd == null || s.start.isAfter(runEnd)) {
        if (runStart != null) total += runEnd!.difference(runStart);
        runStart = s.start;
        runEnd = s.end;
      } else if (s.end.isAfter(runEnd)) {
        runEnd = s.end;
      }
    }
    if (runStart != null) total += runEnd!.difference(runStart);
    return total.inSeconds ~/ 60;
  }

  /// Minutes per calendar day (exercise, mindful minutes).
  static Map<DateTime, int> minutesByDay(Iterable<HealthSpan> spans, DateTime from, DateTime to) => {
        for (final day in _days(from, to))
          day: unionMinutes(spans, from: day, to: DateTime(day.year, day.month, day.day + 1)),
      };

  /// Exercise per day: the higher of Apple's Exercise minutes (Watch only)
  /// and the time spent in workouts any app logged.
  static Map<DateTime, int> exerciseMinutesByDay({
    required Iterable<HealthSpan> exercise,
    required Iterable<HealthSpan> workouts,
    required DateTime from,
    required DateTime to,
  }) {
    final watch = minutesByDay(exercise, from, to);
    final logged = minutesByDay(workouts, from, to);
    return {for (final day in watch.keys) day: math.max(watch[day]!, logged[day] ?? 0)};
  }

  /// Minutes asleep per day, counted toward the day you wake up: from 6 PM
  /// the evening before to 6 PM that day.
  static Map<DateTime, int> sleepMinutesByDay(Iterable<HealthSpan> asleep, DateTime from, DateTime to) => {
        for (final day in _days(from, to))
          day: unionMinutes(asleep,
              from: DateTime(day.year, day.month, day.day - 1, 18), to: DateTime(day.year, day.month, day.day, 18)),
      };

  /// Workouts per day, by the day each began. Workouts that overlap are
  /// one session (a Watch run and the copy another app keeps of it).
  static Map<DateTime, int> sessionsByStartDay(Iterable<HealthSpan> workouts, DateTime from, DateTime to) {
    final sorted = [...workouts]..sort((a, b) => a.start.compareTo(b.start));
    final starts = <DateTime>[];
    DateTime? runEnd;
    for (final w in sorted) {
      if (runEnd == null || !w.start.isBefore(runEnd)) {
        starts.add(w.start);
        runEnd = w.end;
      } else if (w.end.isAfter(runEnd)) {
        runEnd = w.end;
      }
    }
    return countByStartDay(starts, from, to);
  }

  /// How many began on each day (workouts).
  static Map<DateTime, int> countByStartDay(Iterable<DateTime> starts, DateTime from, DateTime to) {
    final counts = {for (final day in _days(from, to)) day: 0};
    for (final start in starts) {
      final day = _day(start);
      if (counts.containsKey(day)) counts[day] = counts[day]! + 1;
    }
    return counts;
  }

  /// Milliliters of water per day, from samples in liters.
  static Map<DateTime, int> waterMlByDay(Iterable<({DateTime at, double liters})> samples, DateTime from, DateTime to) {
    final liters = {for (final day in _days(from, to)) day: 0.0};
    for (final s in samples) {
      final day = _day(s.at);
      if (liters.containsKey(day)) liters[day] = liters[day]! + s.liters;
    }
    return {for (final e in liters.entries) e.key: (e.value * 1000).round()};
  }
}

/// Which days of a linked habit to fill in from Health.
class HealthMerge {
  const HealthMerge._();

  /// How many days back each sync looks (today included).
  static const window = 7;

  /// The first day a sync looks at: a week back, never before the habit
  /// was linked or started counting.
  static DateTime firstDay(Habit habit, DateTime today) {
    final day = DateTime(today.year, today.month, today.day - (window - 1));
    final linked = habit.health?.linkedOn ?? day;
    var first = day.isBefore(linked) ? linked : day;
    if (first.isBefore(habit.trackedFrom)) first = habit.trackedFrom;
    return first;
  }

  /// Days whose amount should change: the higher of what's logged and
  /// what Health says (Health never lowers a day), from [firstDay] to
  /// [today], kept within the most a period can hold.
  static Map<DateTime, int> daysToSet(Habit habit, Map<DateTime, int> health, DateTime today) {
    if (habit.health == null || habit.isBreak) return const {};
    final todayDay = DateTime(today.year, today.month, today.day);
    final history = Map<DateTime, int>.from(habit.history);
    final changes = <DateTime, int>{};

    DateTime periodOf(DateTime day) =>
        habit.resetFrequency == ResetFrequency.never ? DateTime(0) : habit.schedule.periodStart(day);
    int periodTotal(DateTime start) =>
        history.entries.where((e) => periodOf(e.key) == start).fold(0, (sum, e) => sum + e.value);

    final first = firstDay(habit, todayDay);
    for (var day = first; !day.isAfter(todayDay); day = DateTime(day.year, day.month, day.day + 1)) {
      final fromHealth = health[day] ?? 0;
      final logged = history[day] ?? 0;
      if (fromHealth <= logged) continue;
      final room = habit.maxPeriodTotal - (periodTotal(periodOf(day)) - logged);
      final value = math.min(fromHealth, room);
      if (value <= logged) continue;
      history[day] = value;
      changes[day] = value;
    }
    return changes;
  }
}
