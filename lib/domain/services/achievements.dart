import '../entities/habit.dart';
import '../entities/habit_goal.dart';
import '../entities/momentum.dart';
import '../entities/reset_frequency.dart';
import 'insights.dart';
import 'recent_periods.dart';

enum AchievementKind {
  /// Momentum reached 80.
  formed,

  /// A habit being broken, kept for a while ("30 days without smoking").
  clean,

  /// A streak reached a milestone (7, 21, 66 days…).
  streak,

  /// A new streak built to 7 after one ended.
  comeback,

  /// Every habit kept, every day of a week.
  perfectWeek,

  /// Two-minute days, counted across habits.
  showedUp,

  /// Coming straight back after a miss, counted across habits.
  neverTwice,

  /// The current streak passed the habit's longest. A moment, not kept on
  /// the shelf.
  personalBest,
}

/// Something earned: a milestone a habit (or all of them) reached.
class Achievement {
  /// Stable, so it's celebrated once ("streak_21_<habitId>").
  final String id;
  final AchievementKind kind;
  final String title;

  /// What the medal shows: a number ("21") and a word under it ("DAYS").
  final String badge;
  final String unit;

  /// A line to go with it.
  final String message;

  final String? habitId;
  final String? habitName;

  /// The day it was reached.
  final DateTime earnedOn;

  const Achievement({
    required this.id,
    required this.kind,
    required this.title,
    required this.badge,
    required this.unit,
    required this.message,
    required this.earnedOn,
    this.habitId,
    this.habitName,
  });

  /// Whether it belongs on the shelf (a personal best is only a moment).
  bool get onShelf => kind != AchievementKind.personalBest;

  /// Which to celebrate first when several arrive together (lower first).
  int get rank => kind.index;

  @override
  String toString() => 'Achievement($id, $title, $earnedOn)';
}

/// The next milestone and how far along it is.
class AchievementProgress {
  final String title;
  final String? habitName;
  final String badge;
  final String unit;
  final int current;
  final int goal;

  const AchievementProgress({
    required this.title,
    required this.badge,
    required this.unit,
    required this.current,
    required this.goal,
    this.habitName,
  });

  double get fraction => goal == 0 ? 0 : (current / goal).clamp(0.0, 1.0);

  @override
  String toString() => 'AchievementProgress($title, $current of $goal)';
}

/// The achievements catalogue, worked out from history: nothing is stored
/// but which ones have been celebrated.
class Achievements {
  const Achievements._();

  static const showedUpGoals = [10, 50, 100];
  static const neverTwiceGoals = [5, 25];
  static const perfectWeekGoals = [1, 4, 12];
  static const comebackLength = 7;

  /// Streaks shorter than this aren't worth a "new best".
  static const minBest = 3;

  /// Streak milestones for [habit], in its periods.
  static List<int> streakGoals(Habit habit) => switch (habit.resetFrequency) {
        ResetFrequency.daily => habit.isBreak ? const [1, 7, 30, 90, 365] : const [7, 21, 66, 100, 365],
        ResetFrequency.weekly => const [4, 12, 26, 52],
        ResetFrequency.monthly => const [3, 6, 12],
        ResetFrequency.never => const [],
      };

  /// The last [earned] and [next], with what they were worked out from: the
  /// main screen, Insights and the Achievements page ask with the same habits.
  static ({List<Habit> habits, DateTime day, int weekStart, List<Achievement> earned})? _lastEarned;
  static ({List<Habit> habits, DateTime day, List<AchievementProgress> next})? _lastNext;

  static bool _same(List<Habit> a, List<Habit> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /// Everything earned up to [now], oldest first.
  static List<Achievement> earned(List<Habit> habits, DateTime now, {int weekStart = DateTime.monday}) {
    final day = DateTime(now.year, now.month, now.day);
    final last = _lastEarned;
    if (last != null && last.day == day && last.weekStart == weekStart && _same(last.habits, habits)) return last.earned;
    final result = List<Achievement>.unmodifiable(_earned(habits, now, weekStart));
    _lastEarned = (habits: List.of(habits), day: day, weekStart: weekStart, earned: result);
    return result;
  }

  static List<Achievement> _earned(List<Habit> habits, DateTime now, int weekStart) {
    final earned = <Achievement>[];
    final tinyDays = <DateTime>[];
    final comebackDays = <DateTime>[];

    for (final habit in habits) {
      if (!habit.schedule.isPeriodic) continue;
      final walk = _walk(habit, now);
      tinyDays.addAll(walk.tinyDays);
      comebackDays.addAll(walk.comebacks);

      for (final goal in streakGoals(habit)) {
        final day = walk.reached[goal];
        if (day != null) earned.add(_streak(habit, goal, day));
      }
      if (walk.comebackOn != null) {
        earned.add(Achievement(
          id: 'comeback_${habit.id}',
          kind: AchievementKind.comeback,
          title: 'Comeback',
          badge: '$comebackLength',
          unit: 'AGAIN',
          message: 'A streak ended, and you built a new one to $comebackLength.',
          habitId: habit.id,
          habitName: habit.name,
          earnedOn: walk.comebackOn!,
        ));
      }
      if (walk.bestOn != null) {
        earned.add(Achievement(
          id: 'best_${habit.id}_${_key(walk.runStart!)}',
          kind: AchievementKind.personalBest,
          title: 'New best',
          badge: '${walk.bestLength}',
          unit: _unitWord(habit).toUpperCase(),
          message: 'Longer than any streak ${habit.name} has had.',
          habitId: habit.id,
          habitName: habit.name,
          earnedOn: walk.bestOn!,
        ));
      }

      final formedOn = _formedOn(habit, now);
      if (formedOn != null) {
        final days = _daysBetween(habit.trackedFrom, formedOn) + 1;
        earned.add(Achievement(
          id: 'formed_${habit.id}',
          kind: AchievementKind.formed,
          title: 'Habit formed',
          badge: '${Momentum.habitFormed}',
          unit: 'MOMENTUM',
          message: 'Momentum reached ${Momentum.habitFormed} in $days days: about the time it takes a habit to stick.',
          habitId: habit.id,
          habitName: habit.name,
          earnedOn: formedOn,
        ));
      }
    }

    tinyDays.sort();
    for (final goal in showedUpGoals) {
      if (tinyDays.length < goal) break;
      earned.add(Achievement(
        id: 'showedUp_$goal',
        kind: AchievementKind.showedUp,
        title: 'Showed up anyway',
        badge: '$goal',
        unit: 'HARD DAYS',
        message: goal == showedUpGoals.first
            ? 'Ten hard days you still showed up. That\'s how habits survive.'
            : '$goal hard days you did the small version instead of nothing.',
        earnedOn: tinyDays[goal - 1],
      ));
    }

    comebackDays.sort();
    for (final goal in neverTwiceGoals) {
      if (comebackDays.length < goal) break;
      earned.add(Achievement(
        id: 'neverTwice_$goal',
        kind: AchievementKind.neverTwice,
        title: 'Never missed twice',
        badge: '$goal',
        unit: 'COMEBACKS',
        message: '$goal times you came straight back after a miss.',
        earnedOn: comebackDays[goal - 1],
      ));
    }

    final weeks = _perfectWeeks(habits, now, weekStart);
    for (final goal in perfectWeekGoals) {
      if (weeks.length < goal) break;
      earned.add(Achievement(
        id: 'perfectWeek_$goal',
        kind: AchievementKind.perfectWeek,
        title: goal == 1 ? 'Perfect week' : '$goal perfect weeks',
        badge: '$goal',
        unit: goal == 1 ? 'WEEK' : 'WEEKS',
        message: goal == 1 ? 'Every habit kept, every day of a week.' : '$goal weeks with every habit kept, every day.',
        earnedOn: weeks[goal - 1],
      ));
    }

    earned.sort((a, b) {
      final byDay = a.earnedOn.compareTo(b.earnedOn);
      return byDay != 0 ? byDay : a.rank.compareTo(b.rank);
    });
    return earned;
  }

  /// The next milestone for each habit (and the shared ones), closest first.
  static List<AchievementProgress> next(List<Habit> habits, DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    final last = _lastNext;
    if (last != null && last.day == day && _same(last.habits, habits)) return last.next;
    final result = List<AchievementProgress>.unmodifiable(_next(habits, now));
    _lastNext = (habits: List.of(habits), day: day, next: result);
    return result;
  }

  static List<AchievementProgress> _next(List<Habit> habits, DateTime now) {
    final progress = <AchievementProgress>[];
    var tiny = 0;
    var comebacks = 0;
    for (final habit in habits) {
      if (!habit.schedule.isPeriodic) continue;
      final walk = _walk(habit, now);
      tiny += walk.tinyDays.length;
      comebacks += walk.comebacks.length;
      final goal = streakGoals(habit).where((g) => !walk.reached.containsKey(g)).firstOrNull;
      if (goal != null) {
        final title = _streakTitle(habit, goal);
        progress.add(AchievementProgress(
          title: title,
          habitName: habit.name,
          badge: '$goal',
          unit: _unit(habit, goal),
          current: walk.streak,
          goal: goal,
        ));
      }
    }
    final tinyGoal = showedUpGoals.where((g) => tiny < g).firstOrNull;
    if (tinyGoal != null && tiny > 0) {
      progress.add(AchievementProgress(
          title: 'Showed up anyway', badge: '$tinyGoal', unit: 'HARD DAYS', current: tiny, goal: tinyGoal));
    }
    final comebackGoal = neverTwiceGoals.where((g) => comebacks < g).firstOrNull;
    if (comebackGoal != null && comebacks > 0) {
      progress.add(AchievementProgress(
          title: 'Never missed twice', badge: '$comebackGoal', unit: 'COMEBACKS', current: comebacks, goal: comebackGoal));
    }
    progress.sort((a, b) => b.fraction.compareTo(a.fraction));
    return progress;
  }

  static Achievement _streak(Habit habit, int goal, DateTime day) {
    final title = _streakTitle(habit, goal);
    return Achievement(
      id: '${habit.isBreak ? 'clean' : 'streak'}_${goal}_${habit.id}',
      kind: habit.isBreak ? AchievementKind.clean : AchievementKind.streak,
      title: title,
      badge: '$goal',
      unit: _unit(habit, goal),
      message: _streakMessage(habit, goal, title),
      habitId: habit.id,
      habitName: habit.name,
      earnedOn: day,
    );
  }

  /// "21 days", "12 weeks", "21 in a row" (rest days or every few days),
  /// or for a habit being broken "30 days without smoking", "30 days within
  /// your limit".
  static String _streakTitle(Habit habit, int goal) {
    final word = _unitWord(habit);
    final units = '$goal ${goal == 1 ? word : '${word}s'}';
    if (habit.goal == HabitGoal.quit) return '$units without ${_lower(habit.name)}';
    if (habit.goal == HabitGoal.limit) return '$units within your limit';
    return _plain(habit) ? units : '$goal in a row';
  }

  static String _unit(Habit habit, int goal) {
    if (!habit.isBreak && !_plain(habit)) return 'IN A ROW';
    final word = _unitWord(habit).toUpperCase();
    return goal == 1 ? word : '${word}S';
  }

  static String _unitWord(Habit habit) => habit.resetFrequency.periodUnit;

  /// Every day, week or month, with no rest days.
  static bool _plain(Habit habit) => habit.resetInterval == 1 && !habit.schedule.hasRestDays;

  static String _streakMessage(Habit habit, int goal, String title) {
    if (habit.isBreak) {
      return switch ((habit.resetFrequency, goal)) {
        (ResetFrequency.daily, 1) => 'The first day is the hardest. Done.',
        (ResetFrequency.daily, 7) => 'A whole week without a slip.',
        (ResetFrequency.daily, 30) => "A whole month without a slip. That's a real change.",
        (ResetFrequency.daily, 90) => 'Three months. This is who you are now.',
        (ResetFrequency.daily, 365) => 'A whole year. Remarkable.',
        _ => '$title. Keep going.',
      };
    }
    if (habit.resetFrequency == ResetFrequency.daily && _plain(habit)) {
      return switch (goal) {
        7 => "A full week. It's starting to stick.",
        21 => 'Three weeks in a row.',
        66 => '66 days: about the average time it takes a habit to form (Lally et al., 2009).',
        100 => 'A hundred days in a row.',
        365 => 'A whole year, every day.',
        _ => '$title in a row.',
      };
    }
    return '$title in a row. Keep it rolling.';
  }

  static String _lower(String name) {
    final trimmed = name.trim();
    if (trimmed.length > 1 && trimmed[1] == trimmed[1].toUpperCase() && trimmed[1] != trimmed[1].toLowerCase()) {
      return trimmed; // "TV" stays
    }
    return trimmed.isEmpty ? trimmed : trimmed[0].toLowerCase() + trimmed.substring(1);
  }

  /// [_formedOn] per habit and day: it only changes with history (a new
  /// Habit) or the day, so a tap on one habit doesn't redo the others.
  static final _formed = Expando<Map<DateTime, DateTime?>>('formed on');

  /// The first day momentum reached 80, if it has.
  static DateTime? _formedOn(Habit habit, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final cached = _formed[habit] ??= {};
    if (cached.containsKey(today)) return cached[today];
    if (cached.length > 4) cached.clear();
    return cached[today] = _firstFormed(habit, now);
  }

  static DateTime? _firstFormed(Habit habit, DateTime now) {
    final start = habit.trackedFrom;
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (var d = start; !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1))
        d == today ? now : DateTime(d.year, d.month, d.day, 23, 59),
    ];
    final scores = habit.momentumSeries(days);
    for (var i = 0; i < scores.length; i++) {
      if (scores[i].round() >= Momentum.habitFormed) return DateTime(days[i].year, days[i].month, days[i].day);
    }
    return null;
  }

  /// The last day of each week where every habit counted was kept every day
  /// (and something was due on at least five of them), oldest first.
  static List<DateTime> _perfectWeeks(List<Habit> habits, DateTime now, int weekStart) {
    final tracked = habits.where((h) => h.schedule.isPeriodic).toList();
    if (tracked.isEmpty) return const [];
    final first = tracked.map((h) => h.trackedFrom).reduce((a, b) => a.isBefore(b) ? a : b);
    final today = DateTime(now.year, now.month, now.day);
    final days = Insights.days(tracked, from: first, to: today, now: now);
    final weeks = <DateTime>[];
    var week = <DayRecord>[];
    for (final record in days) {
      if ((record.day.weekday - weekStart + 7) % 7 == 0) week = [];
      week.add(record);
      final weekEnds = (record.day.weekday - weekStart + 7) % 7 == 6;
      if (!weekEnds || week.length < 7 || record.day == today) continue;
      final counted = week.where((d) => !d.isEmpty).toList();
      if (counted.length >= 5 && counted.every((d) => d.done + d.twoMinute == d.due)) weeks.add(record.day);
    }
    return weeks;
  }

  /// [_walk] per habit and day: a tap changes one habit, not the others.
  static final _walks = Expando<Map<DateTime, _Walk>>('achievement walks');

  static _Walk _walk(Habit habit, DateTime now) {
    final cached = _walks[habit] ??= {};
    if (cached.length > 4) cached.clear();
    return cached[DateTime(now.year, now.month, now.day)] ??= _walkFrom(habit, now);
  }

  static _Walk _walkFrom(Habit habit, DateTime now) {
    final walk = _Walk();
    final goals = streakGoals(habit);
    PeriodMark? previous;
    var streakBeforeMiss = 0;
    var longestBefore = 0; // the longest run before the current one
    var runEnded = false;
    var best = 0;
    // A habit being broken is clean "so far" all day: the day counts once it's over
    final current = habit.schedule.periodStart(now);

    for (final period in Insights.periods(habit, now)) {
      final mark = period.mark;
      if (mark == PeriodMark.untracked || mark == PeriodMark.rest || mark == PeriodMark.current) continue;
      if (habit.isBreak && period.start == current) continue;
      final missedBefore = previous == PeriodMark.missed || previous == PeriodMark.partial;
      if (mark == PeriodMark.done || mark == PeriodMark.twoMinute) {
        // Reached the day it was kept (a week kept on Saturday, on Saturday)
        final day = Insights.keptOn(habit, period);
        if (missedBefore && streakBeforeMiss > 0) walk.comebacks.add(day);
        final continues = !missedBefore || streakBeforeMiss > 0;
        final before = missedBefore ? streakBeforeMiss : walk.streak;
        if (walk.streak == 0 && !(missedBefore && streakBeforeMiss > 0)) {
          // A new run
          longestBefore = best;
          walk.runStart = period.start;
          walk.bestOn = null;
        }
        walk.streak = (continues ? before : 0) + 1;
        if (walk.streak > best) best = walk.streak;
        if (mark == PeriodMark.twoMinute) walk.tinyDays.add(day);
        for (final goal in goals) {
          if (walk.streak >= goal) walk.reached.putIfAbsent(goal, () => day);
        }
        if (runEnded && walk.streak >= comebackLength) walk.comebackOn ??= day;
        if (longestBefore >= minBest && walk.streak == longestBefore + 1) {
          walk.bestOn = day;
          walk.bestLength = walk.streak;
        } else if (walk.bestOn != null && walk.streak > walk.bestLength) {
          walk.bestLength = walk.streak;
        }
      } else {
        // One miss puts the streak at risk; two in a row end it
        if (missedBefore && streakBeforeMiss > 0) runEnded = true;
        streakBeforeMiss = missedBefore ? 0 : walk.streak;
        walk.streak = 0;
      }
      previous = mark;
    }
    // A miss that ends a streak only counts as ended after the second
    if (previous == PeriodMark.missed || previous == PeriodMark.partial) walk.streak = streakBeforeMiss;
    return walk;
  }

  static String _key(DateTime day) => '${day.year}-${day.month}-${day.day}';

  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

class _Walk {
  /// The streak as it stands (a single miss doesn't end it yet).
  int streak = 0;

  /// The day each streak goal was first reached.
  final reached = <int, DateTime>{};

  final tinyDays = <DateTime>[];

  /// Kept right after a single miss, carrying the streak on.
  final comebacks = <DateTime>[];

  DateTime? comebackOn;

  /// When the current run first passed the longest before it, and how long
  /// it is now.
  DateTime? bestOn;
  int bestLength = 0;
  DateTime? runStart;
}
