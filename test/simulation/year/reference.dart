import 'dart:math' as math;

import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';

/// What the year simulation expects, worked out on its own: from what the
/// person did (the ledger kept here as each action happens) and each
/// habit's rules as the app describes them, never from the app's own
/// calculators. Written plainly, to be easy to check by eye: periods are
/// listed by stepping from the anchor, streaks and momentum are walked
/// period by period.
///
/// When the app and this disagree, one of them is wrong; the failure
/// message says which numbers differ, and the fix goes wherever the rule
/// was broken.
class RefHabit {
  final String name;
  final HabitGoal goal;
  final int? twoMinuteMinimum;
  final bool hasTwoMinute;
  ResetFrequency frequency;
  int interval;
  Set<int>? weekdays;
  DateTime anchor;
  int target;
  ReminderSettings? reminder;

  /// The first day it counts from: the day it was added, earlier once a
  /// day before that is logged (for good), or wherever Start from / Counts
  /// from put it.
  DateTime get trackedFrom => _trackedFrom;
  set trackedFrom(DateTime d) {
    _trackedFrom = d;
    changed();
  }

  DateTime _trackedFrom;
  bool deleted = false;

  /// What was logged each day (date-only keys).
  final Map<DateTime, int> amounts = {};

  /// Days the "2 min" button was used.
  final Set<DateTime> tapped = {};

  /// Days with a note.
  final Set<DateTime> notes = {};

  /// Writes (or with empty text, removes) the note on [date].
  void note(DateTime date, String text) => text.isEmpty ? notes.remove(day(date)) : notes.add(day(date));

  RefHabit(CreateHabitParams params, DateTime addedOn)
      : name = params.name,
        goal = params.goal,
        hasTwoMinute = params.twoMinute != null && !params.goal.isBreak,
        twoMinuteMinimum = params.goal.isBreak ? null : params.twoMinute?.minimum,
        frequency = params.resetFrequency ?? ResetFrequency.daily,
        interval = math.max(1, params.resetInterval),
        weekdays = _weekdays(params.scheduledWeekdays, params.resetFrequency ?? ResetFrequency.daily, params.resetInterval),
        anchor = day(params.resetAnchor ?? addedOn),
        target = params.target,
        reminder = params.reminder,
        _trackedFrom = day(addedOn);

  static Set<int>? _weekdays(List<int>? days, ResetFrequency frequency, int interval) {
    if (days == null || frequency != ResetFrequency.daily || interval > 1) return null;
    final set = days.toSet();
    return set.isEmpty || set.length == 7 ? null : set;
  }

  bool get isBreak => goal.isBreak;
  bool get periodic => frequency != ResetFrequency.never;

  // ------------------------------------------------------------ periods

  List<DateTime>? _starts;

  /// Every period start from well before the year to well after it,
  /// stepped out from the anchor.
  List<DateTime> get starts => _starts ??= () {
        DateTime step(DateTime from, int k) => switch (frequency) {
              ResetFrequency.daily => DateTime(from.year, from.month, from.day + k * interval),
              ResetFrequency.weekly => DateTime(from.year, from.month, from.day + 7 * k * interval),
              ResetFrequency.monthly => _clamped(anchor.year, anchor.month + k * interval, anchor.day),
              ResetFrequency.never => from,
            };
        final low = DateTime(anchor.year - 2, 1, 1);
        final high = DateTime(anchor.year + 3, 1, 1);
        final list = <DateTime>[];
        for (var k = 0;; k--) {
          final s = step(anchor, k);
          if (s.isBefore(low)) break;
          list.insert(0, s);
        }
        for (var k = 1;; k++) {
          final s = step(anchor, k);
          if (s.isAfter(high)) break;
          list.add(s);
        }
        return list;
      }();

  /// After an edit to the schedule, periods are worked out again.
  void scheduleChanged() {
    _starts = null;
    changed();
  }

  /// Something logged or set changed: forget what was worked out.
  void changed() => _periods.clear();

  final Map<DateTime, List<RefPeriod>> _periods = {};

  /// Sets what's logged on [date] (0 clears it), as Undo puts days back.
  void setDay(DateTime date, int amount) {
    amount == 0 ? amounts.remove(day(date)) : amounts[day(date)] = amount;
    changed();
  }

  static DateTime _clamped(int year, int month, int dayOfMonth) {
    final first = DateTime(year, month);
    final last = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, math.min(dayOfMonth, last));
  }

  /// The period containing [date]: its start and the next one's.
  (DateTime, DateTime) periodOf(DateTime date) {
    final d = day(date);
    final list = starts;
    var lo = 0, hi = list.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (list[mid].isAfter(d)) {
        hi = mid - 1;
      } else {
        lo = mid;
      }
    }
    return (list[lo], list[lo + 1]);
  }

  bool dueOn(DateTime date) => weekdays == null || weekdays!.contains(date.weekday);

  // ------------------------------------------------------------- ledger

  /// The card's − / +: today's total for the period becomes [total].
  void setTotal(DateTime now, int total) {
    final today = day(now);
    var earlier = 0;
    if (periodic) {
      final (start, _) = periodOf(today);
      for (var d = start; d.isBefore(today); d = next(d)) {
        earlier += amounts[d] ?? 0;
      }
    } else {
      for (final e in amounts.entries) {
        if (e.key != today) earlier += e.value;
      }
    }
    amounts[today] = math.max(0, total - earlier);
    // Below what the earlier days hold: the rest comes off them, latest first
    var excess = earlier - total;
    final days = [
      for (final d in amounts.keys)
        if (d.isBefore(today) && (!periodic || !d.isBefore(periodOf(today).$1)) && amounts[d]! > 0) d,
    ]..sort((a, b) => b.compareTo(a));
    for (final d in days) {
      if (excess <= 0) break;
      final take = math.min(amounts[d]!, excess);
      amounts[d] = amounts[d]! - take;
      if (amounts[d] == 0) amounts.remove(d);
      excess -= take;
    }
    changed();
  }

  /// Calendar: what was logged on [date]; a log before the start moves it.
  void logOn(DateTime date, int amount) {
    final d = day(date);
    if (amount == 0) {
      amounts.remove(d);
    } else {
      amounts[d] = amount;
      if (d.isBefore(trackedFrom)) trackedFrom = d;
    }
    changed();
  }

  void tap(DateTime now) {
    final d = day(now);
    tapped.add(d);
    if (d.isBefore(trackedFrom)) trackedFrom = d;
    changed();
  }

  /// Everything logged on the days of the period containing [now], up to today.
  Map<DateTime, int> periodDays(DateTime now) {
    final today = day(now);
    final (start, end) = periodOf(today);
    return {for (var d = start; d.isBefore(end) && !d.isAfter(today); d = next(d)) d: amounts[d] ?? 0};
  }

  void countFrom(DateTime date, {bool clearEarlier = false}) {
    final d = day(date);
    if (clearEarlier) {
      amounts.removeWhere((k, _) => k.isBefore(d));
      tapped.removeWhere((k) => k.isBefore(d));
    }
    trackedFrom = d;
  }

  // ----------------------------------------------------------- outcomes

  /// How the period starting at [start] went, as of [now].
  RefPeriod period(DateTime start, DateTime now) {
    final today = day(now);
    final (s, end) = periodOf(start);
    var total = 0;
    var tappedIn = false;
    for (var d = s; d.isBefore(end) && !d.isAfter(today); d = next(d)) {
      total += amounts[d] ?? 0;
      if (tapped.contains(d)) tappedIn = true;
    }
    final isCurrent = !today.isBefore(s) && today.isBefore(end);
    final untracked = !end.isAfter(trackedFrom);
    final due = dueOn(s);
    late final RefMark mark;
    if (untracked) {
      mark = RefMark.untracked;
    } else if (!due) {
      mark = RefMark.rest;
    } else if (isBreak) {
      mark = total <= target ? RefMark.done : (isCurrent ? RefMark.slipped : RefMark.missed);
    } else if (total >= target) {
      mark = RefMark.done;
    } else if (hasTwoMinute && (tappedIn || (twoMinuteMinimum != null && twoMinuteMinimum! > 0 && total >= twoMinuteMinimum!))) {
      mark = RefMark.twoMinute;
    } else if (isCurrent) {
      mark = RefMark.current;
    } else {
      mark = total > 0 ? RefMark.partial : RefMark.missed;
    }
    return RefPeriod(s, end, mark, total, isCurrent);
  }

  /// Every period from the first one tracked to the one under way, oldest first.
  List<RefPeriod> periods(DateTime now) {
    if (!periodic) return const [];
    if (_periods.length > 16) _periods.clear();
    return _periods[now] ??= _periodsAt(now);
  }

  List<RefPeriod> _periodsAt(DateTime now) {
    final (first, _) = periodOf(trackedFrom);
    final (current, _) = periodOf(now);
    return [
      for (final s in starts)
        if (!s.isBefore(first) && !s.isAfter(current)) period(s, now),
    ];
  }

  /// 0 to 1, as a ring shows it: a two-minute period at least half.
  double fraction(RefPeriod p) {
    if (isBreak) return p.mark == RefMark.done ? 1 : 0;
    final f = math.min(1.0, p.total / target);
    return p.mark == RefMark.twoMinute ? math.max(f, 0.5) : f;
  }

  /// The day a longer period was kept: when its running total reached the
  /// target (or the two-minute minimum), or "2 min" was tapped; a habit
  /// being broken keeps it on its last day.
  DateTime keptOn(RefPeriod p) {
    final lastDay = DateTime(p.end.year, p.end.month, p.end.day - 1);
    if (isBreak) return lastDay;
    final goal = p.mark == RefMark.done ? target : (twoMinuteMinimum ?? 0);
    var total = 0;
    for (var d = p.start; d.isBefore(p.end); d = next(d)) {
      total += amounts[d] ?? 0;
      if ((goal > 0 && total >= goal) || (p.mark == RefMark.twoMinute && tapped.contains(d))) return d;
    }
    return lastDay;
  }

  bool isOneDay(RefPeriod p) => p.end == next(p.start);

  // ------------------------------------------------------------ streaks

  /// The streak at [now]: (current, longest, at risk).
  ({int current, int longest, bool atRisk}) streak(DateTime now) {
    if (!periodic) return (current: 0, longest: 0, atRisk: false);
    // Due periods, the one under way only once it's kept (or, being
    // broken, once it slipped: that's a miss already)
    final due = [
      for (final p in periods(now))
        if (p.mark != RefMark.untracked && p.mark != RefMark.rest)
          if (!p.isCurrent || p.kept || p.mark == RefMark.slipped) p,
    ];
    // Runs of kept periods, a single miss bridged
    var longest = 0, run = 0, misses = 0;
    for (final p in due) {
      if (p.kept) {
        run = misses >= 2 ? 1 : run + 1;
        misses = 0;
        longest = math.max(longest, run);
      } else {
        misses++;
      }
    }
    // The current streak: back from the latest until two misses in a row
    var current = 0;
    misses = 0;
    for (var i = due.length - 1; i >= 0 && misses < 2; i--) {
      if (due[i].kept) {
        current++;
        misses = 0;
      } else {
        misses++;
      }
    }
    // At risk: the last ended due period was missed. For a habit being
    // broken, the period under way (kept so far) doesn't count either way.
    final ended = [for (final p in due) if (!(isBreak && p.isCurrent && p.kept)) p];
    final last = ended.isEmpty ? null : ended.last;
    final endedCurrent = _streakOf(ended);
    final atRisk = last != null && !last.kept && (isBreak ? endedCurrent > 0 : current > 0);
    return (current: current, longest: longest, atRisk: atRisk);
  }

  static int _streakOf(List<RefPeriod> due) {
    var count = 0, misses = 0;
    for (var i = due.length - 1; i >= 0 && misses < 2; i--) {
      if (due[i].kept) {
        count++;
        misses = 0;
      } else {
        misses++;
      }
    }
    return count;
  }

  // ----------------------------------------------------------- momentum

  /// The weight each period gets: steady practice reaches 80 in about 66
  /// days, or 8 periods for slow schedules.
  double get alpha {
    final gap = switch (frequency) {
      ResetFrequency.daily => weekdays != null ? 7 / weekdays!.length : interval.toDouble(),
      ResetFrequency.weekly => 7.0 * interval,
      ResetFrequency.monthly => 30.44 * interval,
      ResetFrequency.never => double.infinity,
    };
    final n = math.max(8.0, 66 / gap);
    return 1 - math.pow(0.2, 1 / n).toDouble();
  }

  /// Momentum 0–100 at [at], with only what was logged by then.
  double momentum(DateTime at) => _momentum(at).score;

  /// How formed the habit is at [at]: what steady practice would score
  /// after the periods that have ended (at least one). Its weight in the
  /// overall.
  double formed(DateTime at) => 1 - math.pow(1 - alpha, math.max(1, _momentum(at).ended)).toDouble();

  ({double score, int ended}) _momentum(DateTime at) {
    if (!periodic) return (score: 0, ended: 0);
    if (day(at).isBefore(trackedFrom)) return (score: 0, ended: 0);
    final walk = _RefScore(alpha);
    var result = 0.0;
    for (final p in periods(at)) {
      if (p.mark == RefMark.untracked || p.mark == RefMark.rest) continue;
      final credit = _credit(p, walk.s);
      if (!p.isCurrent) {
        walk.end(credit, p.kept);
        result = walk.s;
      } else {
        // The period under way counts once it's complete, or kept small
        // when that raises the score
        final next = walk.next(credit, p.kept);
        result = credit >= 1 || (p.mark == RefMark.twoMinute && next > walk.s) ? next : walk.s;
      }
    }
    return (score: 100 * result, ended: walk.ended);
  }

  /// Momentum at the end of each day from [trackedFrom] to today (today
  /// as it stands at [now]), walked once.
  Map<DateTime, double> dayEnds(DateTime now) {
    final out = <DateTime, double>{};
    if (!periodic) return out;
    final today = day(now);
    final walk = _RefScore(alpha);
    for (final p in periods(now)) {
      if (p.mark == RefMark.untracked) continue;
      var total = 0;
      var tappedIn = false;
      for (var d = p.start; d.isBefore(p.end) && !d.isAfter(today); d = next(d)) {
        if (d.isBefore(trackedFrom)) {
          total += amounts[d] ?? 0;
          if (tapped.contains(d)) tappedIn = true;
          continue;
        }
        if (p.mark == RefMark.rest) {
          out[d] = 100 * walk.s;
          continue;
        }
        total += amounts[d] ?? 0;
        if (tapped.contains(d)) tappedIn = true;
        // The period as it stood at the end of d
        final so = RefPeriod(p.start, p.end, _markFor(total, tappedIn, isCurrent: true), total, true);
        final credit = _credit(so, walk.s);
        final counted = walk.next(credit, so.kept);
        out[d] = 100 * (credit >= 1 || (so.mark == RefMark.twoMinute && counted > walk.s) ? counted : walk.s);
      }
      if (p.mark != RefMark.rest && !p.isCurrent) walk.end(_credit(p, walk.s), p.kept);
    }
    return out;
  }

  RefMark _markFor(int total, bool tappedIn, {required bool isCurrent}) {
    if (isBreak) return total <= target ? RefMark.done : RefMark.slipped;
    if (total >= target) return RefMark.done;
    if (hasTwoMinute && (tappedIn || (twoMinuteMinimum != null && twoMinuteMinimum! > 0 && total >= twoMinuteMinimum!))) {
      return RefMark.twoMinute;
    }
    return isCurrent ? RefMark.current : (total > 0 ? RefMark.partial : RefMark.missed);
  }

  /// The day each streak milestone in [goals] was first reached, plus the
  /// comebacks (kept right after a single miss), the day a new streak
  /// reached [comebackLength] after one ended, and the days kept small.
  ({
    Map<int, DateTime> reached,
    List<DateTime> comebacks,
    DateTime? comebackOn,
    List<DateTime> tiny,
    DateTime? speedrunOn,
    DateTime? respawnOn,
    DateTime? noIceOn,
  }) walk(DateTime now, List<int> goals, {int comebackLength = 7}) {
    final reached = <int, DateTime>{};
    final comebacks = <DateTime>[];
    final tiny = <DateTime>[];
    DateTime? comebackOn, speedrunOn, respawnOn, noIceOn;
    var streak = 0, before = 0;
    var runEnded = false;
    var tinyInARow = 0;
    RefPeriod? previous;
    for (final p in periods(now)) {
      if (p.mark == RefMark.untracked || p.mark == RefMark.rest) continue;
      // A day being broken counts once it's over; any other period under
      // way once it's kept
      if (p.isCurrent && (isBreak || !p.kept)) continue;
      final afterMiss = previous != null && previous.missed;
      final when = isOneDay(p) ? p.start : keptOn(p);
      if (p.kept) {
        if (afterMiss && before > 0) comebacks.add(when);
        final startsRun = afterMiss ? before == 0 : streak == 0;
        if (startsRun && runEnded) respawnOn ??= when;
        streak = afterMiss ? (before > 0 ? before + 1 : 1) : streak + 1;
        if (p.mark == RefMark.twoMinute) tiny.add(when);
        tinyInARow = p.mark == RefMark.twoMinute ? tinyInARow + 1 : 0;
        if (tinyInARow >= 5) speedrunOn ??= when;
        if (streak >= 30) noIceOn ??= when;
        for (final g in goals) {
          if (streak >= g) reached.putIfAbsent(g, () => when);
        }
        if (runEnded && streak >= comebackLength) comebackOn ??= when;
      } else {
        if (afterMiss && before > 0) runEnded = true;
        before = afterMiss ? 0 : streak;
        streak = 0;
        tinyInARow = 0;
      }
      previous = p;
    }
    return (
      reached: reached,
      comebacks: comebacks,
      comebackOn: comebackOn,
      tiny: tiny,
      speedrunOn: speedrunOn,
      respawnOn: respawnOn,
      noIceOn: noIceOn,
    );
  }

  double _credit(RefPeriod p, double s) {
    if (isBreak) return p.total <= target ? 1 : 0;
    var done = math.min(1.0, p.total / target);
    if (p.mark == RefMark.twoMinute) done = math.max(done, math.max(0.5, s));
    return done;
  }

  /// Score now minus the score a week ago, at the same time of day.
  double trend(DateTime now) =>
      momentum(now) - momentum(DateTime(now.year, now.month, now.day - 7, now.hour, now.minute));

  /// The day a period's total first reached three times the target.
  DateTime? overachievedOn(DateTime now) {
    if (isBreak || target <= 0) return null;
    final totals = <DateTime, int>{};
    for (final d in amounts.keys.toList()..sort()) {
      final amount = amounts[d]!;
      if (amount <= 0 || d.isAfter(day(now))) continue;
      final start = periodOf(d).$1;
      totals[start] = (totals[start] ?? 0) + amount;
      if (totals[start]! >= 3 * target) return d;
    }
    return null;
  }

  /// Whether it counts toward overall momentum at [at]: once something is
  /// logged; a habit being broken once a period has passed since it began.
  bool countsToward(DateTime at) {
    if (!periodic || deleted) return false;
    if (isBreak) return trackedFrom.isBefore(periodOf(at).$1);
    return amounts.entries.any((e) => e.value > 0 && !e.key.isAfter(at));
  }
}

/// The moving average over ended periods (0–1), with the comeback rule:
/// a kept period right after exactly one missed period gets half of that
/// miss's cost back.
class _RefScore {
  _RefScore(this.a);
  final double a;
  double s = 0;
  int ended = 0;
  double _owed = 0;
  int _missRun = 0;

  /// What the score would be after a period earning [credit].
  double next(double credit, bool kept) {
    final plain = s * (1 - a) + credit * a;
    return kept ? math.min(1.0, plain + _owed) : plain;
  }

  void end(double credit, bool kept) {
    final after = next(credit, kept);
    _missRun = kept ? 0 : _missRun + 1;
    _owed = _missRun == 1 ? math.max(0.0, s - after) / 2 : 0;
    s = after;
    ended++;
  }
}

enum RefMark { done, twoMinute, partial, missed, slipped, current, rest, untracked }

class RefPeriod {
  final DateTime start;
  final DateTime end;
  final RefMark mark;
  final int total;
  final bool isCurrent;

  const RefPeriod(this.start, this.end, this.mark, this.total, this.isCurrent);

  bool get kept => mark == RefMark.done || mark == RefMark.twoMinute;
  bool get missed => mark == RefMark.missed || mark == RefMark.partial || mark == RefMark.slipped;

  @override
  String toString() => 'RefPeriod(${start.month}/${start.day}, $mark, $total)';
}

/// One heatmap day, as worked out here.
class RefDay {
  int due = 0, done = 0, twoMinute = 0;
  double amount = 0;

  @override
  String toString() => '$done+$twoMinute of $due (${amount.toStringAsFixed(2)})';
}

/// Every habit, and what's worked out across them.
class Reference {
  final Map<String, RefHabit> habits = {};

  Iterable<RefHabit> get live => habits.values.where((h) => !h.deleted);

  /// The heatmap from [from] to [to] across the live habits.
  Map<DateTime, RefDay> days(DateTime from, DateTime to, DateTime now) {
    final out = {for (var d = day(from); !d.isAfter(day(to)); d = next(d)) d: RefDay()};
    void add(DateTime d, RefHabit h, RefPeriod p) {
      final record = out[d];
      if (record == null) return;
      record
        ..due += 1
        ..done += p.mark == RefMark.done ? 1 : 0
        ..twoMinute += p.mark == RefMark.twoMinute ? 1 : 0
        ..amount += h.fraction(p);
    }

    for (final h in live) {
      for (final p in h.periods(now)) {
        if (p.mark == RefMark.untracked || p.mark == RefMark.rest) continue;
        if (h.isOneDay(p)) {
          add(p.start, h, p);
        } else if (p.kept) {
          final d = h.keptOn(p);
          if (!d.isAfter(day(now))) add(d, h, p);
        }
      }
    }
    return out;
  }

  /// Periods ended between [from] and [now]: full, two-minute, missed,
  /// and two-minute ones that saved a streak.
  ({int full, int twoMinute, int missed, int saved}) kept(DateTime from, DateTime now) {
    var full = 0, twoMinute = 0, missed = 0, saved = 0;
    for (final h in live) {
      // The period under way counts once it's kept
      final ended = [
        for (final p in h.periods(now))
          if (p.mark != RefMark.untracked && p.mark != RefMark.rest && (!p.isCurrent || p.kept)) p,
      ];
      var streak = 0, before = 0;
      RefPeriod? previous;
      for (final p in ended) {
        final inRange = !p.start.isBefore(h.periodOf(from).$1);
        final afterMiss = previous != null && previous.missed;
        if (p.kept) {
          if (p.mark == RefMark.twoMinute && afterMiss && before > 0 && inRange) saved++;
          streak = (afterMiss ? before : streak) + 1;
          if (inRange) p.mark == RefMark.done ? full++ : twoMinute++;
        } else {
          before = afterMiss ? 0 : streak;
          streak = 0;
          if (inRange) missed++;
        }
        previous = p;
      }
    }
    return (full: full, twoMinute: twoMinute, missed: missed, saved: saved);
  }

  /// Kept share by weekday, for habits done day by day.
  Map<int, double> weekdays(DateTime from, DateTime now) {
    final kept = List<int>.filled(8, 0), due = List<int>.filled(8, 0);
    for (final h in live) {
      for (final p in h.periods(now)) {
        if (p.start.isBefore(day(from)) || !h.isOneDay(p)) continue;
        if (p.mark == RefMark.untracked || p.mark == RefMark.rest) continue;
        // The day under way counts once it's kept
        if (p.isCurrent && !p.kept) continue;
        due[p.start.weekday]++;
        if (p.kept) kept[p.start.weekday]++;
      }
    }
    return {
      for (var w = 1; w <= 7; w++)
        if (due[w] >= 4) w: kept[w] / due[w],
    };
  }

  /// Everything earned by [now], by the app's ids, with the day each was
  /// reached ([ids] maps habit names to the app's ids).
  Map<String, DateTime> achievements(DateTime now, Map<String, String> ids, {required int weekStart}) {
    final out = <String, DateTime>{};
    final tiny = <DateTime>[];
    final comebacks = <DateTime>[];
    for (final h in live) {
      if (!h.periodic) continue;
      final id = ids[h.name]!;
      final goals = streakGoals(h);
      final w = h.walk(now, goals);
      for (final entry in w.reached.entries) {
        out['${h.isBreak ? 'clean' : 'streak'}_${entry.key}_$id'] = entry.value;
      }
      if (w.comebackOn != null) out['comeback_$id'] = w.comebackOn!;
      // The fun ones
      if (w.speedrunOn != null) out['fun_tiny5_$id'] = w.speedrunOn!;
      if (w.respawnOn != null) out['fun_respawn_$id'] = w.respawnOn!;
      if (w.noIceOn != null && (out['fun_noIce'] == null || w.noIceOn!.isBefore(out['fun_noIce']!))) {
        out['fun_noIce'] = w.noIceOn!;
      }
      final over = h.overachievedOn(now);
      if (over != null) out['fun_over_$id'] = over;
      final lap = DateTime(h.trackedFrom.year, h.trackedFrom.month, h.trackedFrom.day + 365);
      if (!lap.isAfter(day(now))) out['fun_lap_$id'] = lap;
      tiny.addAll(w.tiny);
      comebacks.addAll(w.comebacks);
      for (final entry in h.dayEnds(now).entries) {
        if (entry.value.round() >= 80) {
          out['formed_$id'] = entry.key;
          break;
        }
      }
    }
    tiny.sort();
    for (final goal in const [10, 50, 100]) {
      if (tiny.length >= goal) out['showedUp_$goal'] = tiny[goal - 1];
    }
    comebacks.sort();
    for (final goal in const [5, 25]) {
      if (comebacks.length >= goal) out['neverTwice_$goal'] = comebacks[goal - 1];
    }
    final weeks = perfectWeeks(now, weekStart);
    for (final goal in const [1, 4, 12]) {
      if (weeks.length >= goal) out['perfectWeek_$goal'] = weeks[goal - 1];
    }
    out.addAll(_funAcross(now));
    return out;
  }

  /// Clean sweep, Weekend warrior, Dear diary and Juggler.
  Map<String, DateTime> _funAcross(DateTime now) {
    final out = <String, DateTime>{};
    final today = day(now);
    final tracked = [for (final h in live) if (h.periodic) h];
    if (tracked.isNotEmpty) {
      final first = tracked.map((h) => h.trackedFrom).reduce((a, b) => a.isBefore(b) ? a : b);
      final records = days(first, today, now);
      for (final entry in records.entries) {
        if (entry.value.due >= 5 && entry.value.done == entry.value.due) {
          out['fun_sweep'] = entry.key;
          break;
        }
      }
      bool kept(RefDay? d) => d != null && d.due > 0 && d.done + d.twoMinute == d.due;
      for (final entry in records.entries) {
        if (entry.key.weekday != DateTime.sunday) continue;
        final saturday = DateTime(entry.key.year, entry.key.month, entry.key.day - 1);
        if (kept(records[saturday]) && kept(entry.value)) {
          out['fun_weekend'] = entry.key;
          break;
        }
      }
      final started = [for (final h in tracked) if (!h.trackedFrom.isAfter(today)) h.trackedFrom]..sort();
      if (started.length >= 10) out['fun_juggler'] = started[9];
    }
    final noted = {
      for (final h in live)
        for (final d in h.notes)
          if (!d.isAfter(today)) d,
    }.toList()
      ..sort();
    if (noted.length >= 10) out['fun_diary'] = noted[9];
    return out;
  }

  static List<int> streakGoals(RefHabit h) => switch (h.frequency) {
        ResetFrequency.daily => h.isBreak ? const [1, 7, 30, 90, 365] : const [7, 21, 66, 100, 365],
        ResetFrequency.weekly => const [4, 12, 26, 52],
        ResetFrequency.monthly => const [3, 6, 12],
        ResetFrequency.never => const [],
      };

  /// The last day of each whole week (by [weekStart]) where every habit due
  /// was kept every day, with something due on at least five of them, not
  /// counting a week that ends today.
  List<DateTime> perfectWeeks(DateTime now, int weekStart) {
    final tracked = [for (final h in live) if (h.periodic) h];
    if (tracked.isEmpty) return const [];
    final first = tracked.map((h) => h.trackedFrom).reduce((a, b) => a.isBefore(b) ? a : b);
    final today = day(now);
    final records = days(first, today, now);
    final weeks = <DateTime>[];
    var week = <RefDay>[];
    for (final entry in records.entries) {
      final offset = (entry.key.weekday - weekStart + 7) % 7;
      if (offset == 0) week = [];
      week.add(entry.value);
      if (offset != 6 || week.length < 7 || entry.key == today) continue;
      final counted = [for (final d in week) if (d.due > 0) d];
      if (counted.length >= 5 && counted.every((d) => d.done + d.twoMinute == d.due)) weeks.add(entry.key);
    }
    return weeks;
  }

  /// Momentum of the habits that count toward it, each weighed by how
  /// formed it is, or null.
  double? overall(DateTime now) {
    final counted = [for (final h in live) if (h.countsToward(now)) h];
    if (counted.isEmpty) return null;
    var sum = 0.0, weight = 0.0;
    for (final h in counted) {
      final w = h.formed(now);
      sum += h.momentum(now) * w;
      weight += w;
    }
    return sum / weight;
  }
}

DateTime day(DateTime t) => DateTime(t.year, t.month, t.day);
DateTime next(DateTime d) => DateTime(d.year, d.month, d.day + 1);
