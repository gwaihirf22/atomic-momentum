import 'package:atomic_momentum/core/dev/year_persona.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/achievement_celebrations.dart';
import 'package:atomic_momentum/core/services/achievement_store.dart';
import 'package:atomic_momentum/domain/entities/momentum.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/services/achievements.dart';
import 'package:atomic_momentum/domain/services/habit_stats.dart';
import 'package:atomic_momentum/domain/services/insights.dart';
import 'package:atomic_momentum/domain/services/quote_of_the_day.dart';
import 'package:atomic_momentum/domain/services/recent_periods.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';

import '../simulated_phone.dart';
import 'persona_driver.dart';
import 'reference.dart';

/// The persona's year lived on a [SimulatedPhone], with every visit checked
/// against the [Reference]. Problems are collected, not thrown, so one run
/// reports everything that's wrong.
class YearRun {
  final SimulatedPhone phone;
  final YearPersona persona;
  final ref = Reference();

  /// One block per month: what a year looks like, for the golden.
  final List<String> digest = [];

  /// Seconds spent in each kind of check, to keep the year quick.
  final Map<String, Duration> timings = {};

  YearRun(this.phone, this.persona);

  late final driver = PersonaDriver(
    habits: () => phone.habits,
    settings: phone.settings,
    quotes: quotes,
    ref: ref,
    create: phone.create,
    id: phone.id,
    problem: problem,
  );

  QuoteProvider get quotes => get<QuoteProvider>();

  /// Last time the app was opened (a sync of everything it schedules).
  DateTime? _lastOpen;

  /// Achievements celebrated, with when.
  final Map<String, DateTime> celebrated = {};
  final Set<String> _earnedBefore = {};

  /// Reminders expected but not delivered, found as days go by.
  final Set<String> _remindersChecked = {};

  // Month digest counters
  int _month = -1;
  final Map<String, int> _deliveredThisMonth = {};
  final List<String> _earnedThisMonth = [];
  final Set<DateTime> _quoteDaysThisMonth = {};

  Future<void> live() async {
    for (final day in persona.days) {
      if (day.date.month != _month) {
        if (_month != -1) _monthDigest(DateTime(day.date.year, day.date.month, 0));
        _month = day.date.month;
      }
      // A cold start on the 1st: everything must come back the same from storage
      if (day.date.day == 1 && day.visits.isNotEmpty && day.index > 0) await _coldStart(day.visits.first.on(day.date));
      for (var v = 0; v < day.visits.length; v++) {
        final visit = day.visits[v];
        final at = visit.on(day.date);
        await _timed('advancing', () => phone.advanceTo(at));
        _countDeliveries(at);
        _checkRemindersUpTo(at);
        final label = visit.actions.isEmpty ? 'look' : visit.actions.join(', ');
        await _timed('app', () => phone.at(at, label, () async {
              for (final action in visit.actions) {
                await driver.apply(action, at);
              }
            }));
        _lastOpen = at;
        await _timed('visit checks', () => _checkVisit(at, lastVisit: v == day.visits.length - 1));
        if (v == day.visits.length - 1) await _timed('day checks', () => _checkDay(at, monthEnd: _isMonthEnd(day.date)));
      }
    }
    final end = persona.date(YearPersona.length);
    await phone.advanceTo(end);
    _countDeliveries(end);
    _checkRemindersUpTo(end);
    _monthDigest(DateTime(end.year, end.month, end.day - 1));
  }

  bool _isMonthEnd(DateTime d) => DateTime(d.year, d.month, d.day + 1).month != d.month;

  T _t<T>(String what, T Function() f) {
    final watch = Stopwatch()..start();
    final result = f();
    timings[what] = (timings[what] ?? Duration.zero) + watch.elapsed;
    return result;
  }

  Future<void> _timed(String what, Future<void> Function() check) async {
    final watch = Stopwatch()..start();
    await check();
    timings[what] = (timings[what] ?? Duration.zero) + watch.elapsed;
  }

  /// The same message on many days is reported once, with how often.
  final Map<String, ({String first, int count})> _problems = {};

  List<String> get problems => [
        for (final e in _problems.entries) '${e.value.first}  ${e.key}${e.value.count > 1 ? '  (x${e.value.count})' : ''}',
      ];

  void problem(DateTime at, String message) {
    final seen = _problems[message];
    _problems[message] = (first: seen?.first ?? _stamp(at), count: (seen?.count ?? 0) + 1);
  }

  // ------------------------------------------------------------ actions

  // ------------------------------------------------------------- checks

  Future<void> _coldStart(DateTime at) async {
    await phone.advanceTo(at);
    final before = {for (final h in phone.habits.habits) h.id: h.refresh(at)};
    await phone.open(cold: true);
    phone.close();
    final after = {for (final h in phone.habits.habits) h.id: h.refresh(at)};
    if (before.keys.toSet().difference(after.keys.toSet()).isNotEmpty || before.length != after.length) {
      problem(at, 'a cold start lost habits: ${before.length} before, ${after.length} after');
    }
    for (final entry in before.entries) {
      final reloaded = after[entry.key];
      if (reloaded != null && reloaded != entry.value) {
        problem(at, '${entry.value.name} came back from storage different:\n'
            '    before ${entry.value.toJson()}\n    after  ${reloaded.toJson()}');
      }
    }
  }

  static String _num(double v) => v.toStringAsFixed(4);

  bool _close(double a, double b) => (a - b).abs() < 1e-6;

  Future<void> _checkVisit(DateTime now, {required bool lastVisit}) async {
    final today = day(now);
    for (final r in ref.live) {
      final h = phone.habits.getHabitById(phone.id(r.name));
      if (h == null) {
        problem(now, '${r.name} is missing from the app');
        continue;
      }
      if (h.trackedFrom != r.trackedFrom) {
        problem(now, '${r.name}: counts from ${_d(h.trackedFrom)}, expected ${_d(r.trackedFrom)}');
      }
      // History as logged
      final logged = {for (final e in h.history.entries) if (e.value > 0) e.key: e.value};
      final expected = {for (final e in r.amounts.entries) if (e.value > 0) e.key: e.value};
      if (logged.length != expected.length || logged.entries.any((e) => expected[e.key] != e.value)) {
        final days = {...logged.keys, ...expected.keys}.where((d) => logged[d] != expected[d]).toList()..sort();
        problem(now, '${r.name}: history differs on ${days.map((d) => '${_d(d)} ${logged[d]} vs ${expected[d]}').join(', ')}');
      }
      if (!r.periodic) {
        if (h.progress != r.amounts.values.fold(0, (a, b) => a + b)) problem(now, '${r.name}: total ${h.progress}');
        continue;
      }

      final s = _t('ref streak', () => r.streak(now));
      if (h.streak.current != s.current || h.streak.longest != s.longest || h.streak.atRisk != s.atRisk) {
        problem(now, '${r.name}: streak ${h.streak.current} (best ${h.streak.longest}${h.streak.atRisk ? ', at risk' : ''}), '
            'expected ${s.current} (best ${s.longest}${s.atRisk ? ', at risk' : ''})');
      }
      final m = _t('ref momentum', () => r.momentum(now));
      if (!_close(h.momentum.score, m)) {
        problem(now, '${r.name}: momentum ${_num(h.momentum.score)} on the card, expected ${_num(m)}');
      }
      if (!lastVisit) continue;
      // Once a day, the rest: the trend, the card's bars, the week on Calendar
      final fresh = _t('app refresh', () => h.refresh(now));
      final refTrend = _t('ref trend', () => r.trend(now));
      if (!_close(_t('app trend', () => fresh.momentum.trend), refTrend)) {
        problem(now, '${r.name}: 7-day trend ${_num(fresh.momentum.trend)}, expected ${_num(refTrend)}');
      }
      if (!_close(h.momentumAt(now).score, m) || !_close(h.momentumSeries([now]).single, m)) {
        problem(now, '${r.name}: momentumAt ${_num(h.momentumAt(now).score)} and the series '
            '${_num(h.momentumSeries([now]).single)} should both be ${_num(m)}');
      }
      if (MomentumLevel.of(h.momentum.score) != _level(m)) problem(now, '${r.name}: level ${MomentumLevel.of(h.momentum.score)}');

      // The card's last seven periods
      final bars = _t('app bars', () => recentPeriods(h, now));
      final refPeriods = r.periods(now);
      for (var i = 0; i < bars.length; i++) {
        final back = bars.length - 1 - i;
        final want = back < refPeriods.length ? _mark(refPeriods[refPeriods.length - 1 - back]) : PeriodMark.untracked;
        if (bars[i].mark != want) {
          problem(now, '${r.name}: the bar for ${_d(bars[i].start)} is ${bars[i].mark.name}, expected ${want.name}');
        }
      }
      // Calendar, this week: who's listed and whether they're kept
      for (var back = 0; back < 7; back++) {
        final d = DateTime(today.year, today.month, today.day - back);
        if (h.startedOn(d) != !d.isBefore(r.trackedFrom)) problem(now, '${r.name}: startedOn(${_d(d)}) is ${h.startedOn(d)}');
        if (h.isDueOn(d) != r.dueOn(d)) problem(now, '${r.name}: isDueOn(${_d(d)}) is ${h.isDueOn(d)}');
        if (d.isBefore(r.trackedFrom) || !r.dueOn(d)) continue;
        final p = r.period(r.periodOf(d).$1, now);
        if (h.wasKeptOnDate(d) != p.kept) problem(now, '${r.name}: kept on ${_d(d)} is ${h.wasKeptOnDate(d)}, expected ${p.kept}');
      }
    }

    final overall = phone.habits.overallMomentum?.score;
    final refOverall = ref.overall(now);
    if ((overall == null) != (refOverall == null) || (overall != null && !_close(overall, refOverall!))) {
      problem(now, 'overall momentum ${overall == null ? 'none' : _num(overall)}, '
          'expected ${refOverall == null ? 'none' : _num(refOverall)}');
    }

    _checkQuotes(now);
    await _timed('reference achievements', () async {
      _reachedOn = ref.achievements(now, {for (final r in ref.live) r.name: phone.id(r.name)},
          weekStart: phone.settings.firstDayOfWeek);
    });
    await _timed('achievements', () => _celebrate(now));
  }

  static MomentumLevel _level(double score) {
    final s = score.round();
    if (s >= 90) return MomentumLevel.atomic;
    if (s >= 80) return MomentumLevel.unstoppable;
    if (s >= 70) return MomentumLevel.strong;
    if (s >= 40) return MomentumLevel.rolling;
    return MomentumLevel.building;
  }

  static PeriodMark _mark(RefPeriod p) => switch (p.mark) {
        RefMark.done => PeriodMark.done,
        RefMark.twoMinute => PeriodMark.twoMinute,
        RefMark.partial => PeriodMark.partial,
        RefMark.missed => PeriodMark.missed,
        RefMark.slipped || RefMark.current => PeriodMark.current,
        RefMark.rest => PeriodMark.rest,
        RefMark.untracked => PeriodMark.untracked,
      };

  void _checkQuotes(DateTime now) {
    final families = phone.settings.quoteFamilies;
    final shown = quotes.today(families, now: now);
    final pool = quotes.from(families);
    final turn = QuoteOfTheDay.pick(now, pool);
    final shuffled = driver.shuffled;
    final want = shuffled != null && shuffled.day == day(now) && pool.any((q) => q.id == shuffled.id) ? shuffled.id : turn?.id;
    if (shown?.id != want) problem(now, 'quote of the day is ${shown?.id}, expected $want');
    if (shown != null) _quoteDaysThisMonth.add(day(now));
    // Quotes kept with habits: every one shown resolves
    for (final h in phone.habits.habits) {
      final resolved = quotes.resolve(h.quoteIds).map((q) => q.id).toList();
      final live = [for (final id in h.quoteIds) if (quotes.find(id) != null) id];
      if (resolved.join(',') != live.join(',')) problem(now, '${h.name}: kept quotes resolve to $resolved');
    }
  }

  /// Runs the app's celebration rules, as the main screen does when it looks.
  Future<void> _celebrate(DateTime now) async {
    final store = get<AchievementStore>();
    final earned = Achievements.earned(phone.habits.habits, now, weekStart: phone.settings.firstDayOfWeek);
    final started = store.started;
    final decision = AchievementCelebrations.decide(
        earned: earned, started: started, seen: store.seen, now: now, busy: false);
    if (decision.markSeen.isNotEmpty || !started) await store.markSeen(decision.markSeen);

    final ids = {for (final a in earned) a.id};
    // New ever: one earned, lost (history edited) and earned again isn't news
    final fresh = [for (final a in earned) if (!_earnedBefore.contains(a.id)) a];
    _earnedBefore.addAll(ids);
    final celebrate = decision.celebrate;
    if (celebrate != null) {
      if (celebrated.containsKey(celebrate.id)) problem(now, '"${celebrate.title}" celebrated twice');
      celebrated[celebrate.id] = now;
      _earnedThisMonth.add('${celebrate.title}${celebrate.habitName == null ? '' : ' (${celebrate.habitName})'} *');
    }
    // Something reached just now (or yesterday, while the app was closed) is
    // celebrated, unless another one is at the same moment
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    for (final a in fresh) {
      if (a.id == celebrate?.id) continue;
      if (!started) continue;
      if (a.onShelf) _earnedThisMonth.add('${a.title}${a.habitName == null ? '' : ' (${a.habitName})'}');
      final reached = _reachedOn[a.id];
      if (reached != null && !reached.isBefore(yesterday) && celebrate == null && a.onShelf) {
        problem(now, '"${a.title}"${a.habitName == null ? '' : ' (${a.habitName})'} was reached ${_d(reached)} '
            'but filed without a celebration (the app dates it ${_d(a.earnedOn)})');
      }
    }
  }

  /// The day each achievement was reached, by the reference (updated daily).
  Map<String, DateTime> _reachedOn = {};

  Future<void> _checkDay(DateTime now, {required bool monthEnd}) async {
    final today = day(now);
    final habits = phone.habits.habits;
    final weekStart = phone.settings.firstDayOfWeek;
    // Achievements, against the reference's own walk (worked out at the visit)
    final earned = {
      for (final a in Achievements.earned(habits, now, weekStart: weekStart))
        if (a.onShelf) a.id: a.earnedOn,
    };
    for (final id in {...earned.keys, ..._reachedOn.keys}) {
      final app = earned[id], want = _reachedOn[id];
      if (app == null || want == null || app != want) {
        problem(now, 'achievement $id: the app has ${app == null ? 'nothing' : _d(app)}, expected ${want == null ? 'nothing' : _d(want)}');
      }
    }

    // The heatmap: this week every day, the whole year at month end
    final from = monthEnd ? persona.start : DateTime(today.year, today.month, today.day - 6);
    final days = Insights.days(habits, from: from, to: today, now: now);
    final refDays = ref.days(from, today, now);
    for (final record in days) {
      final r = refDays[record.day]!;
      if (record.due != r.due || record.done != r.done || record.twoMinute != r.twoMinute || !_close(record.amount, r.amount)) {
        problem(now, 'heatmap ${_d(record.day)}: ${record.done}+${record.twoMinute} of ${record.due} '
            '(${record.amount.toStringAsFixed(2)}), expected $r');
      }
    }

    // Insights over the last 26 weeks, as its cards show
    final since = DateTime(today.year, today.month, today.day - 26 * 7 + 1);
    final kept = Insights.kept(habits, from: since, now: now);
    final refKept = ref.kept(since, now);
    if (kept.full != refKept.full || kept.twoMinute != refKept.twoMinute || kept.missed != refKept.missed ||
        kept.streaksSaved != refKept.saved) {
      problem(now, 'kept ${kept.full} + ${kept.twoMinute} small, ${kept.missed} missed, ${kept.streaksSaved} saved; '
          'expected ${refKept.full} + ${refKept.twoMinute}, ${refKept.missed}, ${refKept.saved}');
    }
    final weekdays = Insights.weekdays(habits, from: since, now: now).rates;
    final refWeekdays = ref.weekdays(since, now);
    if (weekdays.length != refWeekdays.length || weekdays.entries.any((e) => !_close(e.value, refWeekdays[e.key] ?? -1))) {
      problem(now, 'weekday rates $weekdays, expected $refWeekdays');
    }
    final longest = Insights.longestStreak(habits);
    final refLongest = ref.live.map((r) {
      final s = r.streak(now);
      return s.longest > s.current ? s.longest : s.current;
    }).fold(0, (a, b) => a > b ? a : b);
    if (longest != refLongest) problem(now, 'longest streak $longest, expected $refLongest');
    final formed = Insights.formed(habits);
    final refFormed = ref.live.where((r) => r.periodic && r.momentum(now).round() >= 80).length;
    if (formed != refFormed) problem(now, 'habits formed $formed, expected $refFormed');
    final byMonth = Insights.momentumByMonth(habits, now);
    final last = byMonth.last.score, refOverall = ref.overall(now);
    if ((last == null) != (refOverall == null) || (last != null && !_close(last, refOverall!))) {
      problem(now, 'this month\'s momentum $last, expected $refOverall');
    }

    // The habit page
    for (final r in ref.live) {
      if (!r.periodic) continue;
      final h = phone.habits.getHabitById(phone.id(r.name))!;
      final stats = HabitStats.of(h, now, weekStart: weekStart);
      final s = r.streak(now);
      final best = s.longest > s.current ? s.longest : s.current;
      final count = switch (r.frequency) {
        ResetFrequency.daily => r.interval == 1 ? 30 : 15,
        ResetFrequency.weekly => 8,
        _ => 6,
      };
      final all = r.periods(now);
      final recent = [
        for (final p in all.sublist(all.length > count ? all.length - count : 0))
          if (p.mark != RefMark.untracked && p.mark != RefMark.rest && (!p.isCurrent || p.kept)) p,
      ];
      final refKeptCount = recent.where((p) => p.kept).length;
      if (stats.best != best || stats.kept != refKeptCount || stats.due != recent.length) {
        problem(now, '${r.name} page: best ${stats.best}, kept ${stats.kept} of ${stats.due}; '
            'expected best $best, kept $refKeptCount of ${recent.length}');
      }
      if (!_close(stats.momentumTrend.last, r.momentum(DateTime(today.year, today.month, today.day, 23, 59)))) {
        problem(now, '${r.name} page: momentum line ends at ${_num(stats.momentumTrend.last)}');
      }
    }

    // Kept quotes of a deleted quote: hidden, and better gone
    if (driver.myQuote != null && quotes.find(driver.myQuote!) == null) {
      for (final h in habits) {
        if (h.quoteIds.contains(driver.myQuote)) problem(now, '${h.name} still keeps the deleted quote $driver.myQuote');
      }
    }
  }

  // --------------------------------------------------------- reminders

  /// Reminders that should have come by [until], as the app promises them:
  /// on each due day for a habit done day by day; counting down to the last
  /// day of a longer period (1 day before for 2–6 day periods, 3 and 1 for
  /// a week or more, 7, 3 and 1 for a month); every day for a check-in on a
  /// habit being broken; on the chosen days for custom reminders. Each is
  /// expected when the app had been opened in the day before and the period
  /// wasn't kept by then. Worked out from the ledger, which doesn't change
  /// between visits, so it's as it stood then.
  void _checkRemindersUpTo(DateTime until) {
    final lastOpen = _lastOpen;
    if (lastOpen == null) return;
    final quiet = phone.settings.quietHours;
    for (final r in ref.live) {
      final reminder = r.reminder;
      if (reminder == null || !reminder.enabled || !r.periodic) continue;
      for (var d = day(lastOpen); !d.isAfter(day(until)); d = next(d)) {
        final wanted = DateTime(d.year, d.month, d.day, reminder.time.hour, reminder.time.minute);
        if (wanted.hour != reminder.time.hour) continue; // a time that doesn't exist that day
        final at = quiet.shift(wanted);
        if (!at.isAfter(lastOpen) || at.isAfter(until)) continue;
        if (at.difference(lastOpen) > const Duration(hours: 24)) continue;
        final key = '${r.name}|${_d(d)}';
        if (!_remindersChecked.add(key)) continue;
        if (d.isBefore(r.trackedFrom) || !r.dueOn(d)) continue;
        if (reminder.mode == ReminderMode.custom) {
          if (!reminder.daysOfWeek.contains(d.weekday)) continue;
        } else if (!r.isBreak && !_countdownDay(r, d)) {
          continue;
        }
        if (!r.isBreak && r.period(d, at).kept) continue;
        final id = phone.id(r.name);
        final came = phone.delivered.any((n) => n.habitId == id && n.isReminder && n.at == at);
        if (!came) problem(at, 'no reminder for ${r.name} on ${_d(d)} at ${_hm(at)}, though it was still to do');
      }
    }
  }

  /// Whether a smart reminder falls on [d]: a day before the period's last
  /// day by one of the countdown offsets (0 for a period of one day).
  static bool _countdownDay(RefHabit r, DateTime d) {
    final (start, end) = r.periodOf(d);
    final length = DateTime.utc(end.year, end.month, end.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    final offsets = length <= 1
        ? const [0]
        : length < 7
            ? const [1]
            : length < 28
                ? const [3, 1]
                : const [7, 3, 1];
    return offsets.any((o) => d == DateTime(end.year, end.month, end.day - 1 - o));
  }

  int _deliveredCounted = 0;

  void _countDeliveries(DateTime until) {
    final list = phone.delivered;
    for (; _deliveredCounted < list.length; _deliveredCounted++) {
      final n = list[_deliveredCounted];
      final kind = n.isReminder ? 'reminders' : ((n.title ?? '').startsWith("Don't miss twice") ? 'warnings' : 'nudges');
      _deliveredThisMonth[kind] = (_deliveredThisMonth[kind] ?? 0) + 1;
    }
  }

  // ------------------------------------------------------------- digest

  void _monthDigest(DateTime lastDay) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final at = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59);
    digest.add('== ${months[lastDay.month - 1]} ${lastDay.year}');
    for (final r in ref.live) {
      if (!r.periodic) {
        digest.add('  ${r.name.padRight(16)} ${r.amounts.values.fold(0, (a, b) => a + b)} of ${r.target}');
        continue;
      }
      final s = r.streak(at);
      final m = r.momentum(at);
      final monthStart = DateTime(lastDay.year, lastDay.month, 1);
      var kept = 0, small = 0, missed = 0;
      for (final p in r.periods(at)) {
        if (p.start.isBefore(monthStart) || p.mark == RefMark.untracked || p.mark == RefMark.rest) continue;
        if (p.mark == RefMark.done) kept++;
        if (p.mark == RefMark.twoMinute) small++;
        if (p.missed) missed++;
      }
      digest.add('  ${r.name.padRight(16)} streak ${s.current} (best ${s.longest})${s.atRisk ? ' at risk' : ''}, '
          'momentum ${m.round()} ${_level(m).name}; this month $kept kept, $small small, $missed missed');
    }
    final overall = ref.overall(at);
    digest.add('  overall momentum ${overall == null ? '-' : overall.round()}');
    digest.add('  notifications: ${['reminders', 'warnings', 'nudges'].map((k) => '${_deliveredThisMonth[k] ?? 0} $k').join(', ')}');
    // (Not which quotes: one's own quote's id comes from the clock, so the
    // turns differ by time zone; each day's quote is checked as it shows)
    digest.add('  quote of the day on ${_quoteDaysThisMonth.length} days, another quote: ${driver.shuffles}');
    for (final line in _earnedThisMonth) {
      digest.add('  earned: $line');
    }
    _deliveredThisMonth.clear();
    _earnedThisMonth.clear();
    _quoteDaysThisMonth.clear();
    driver.shuffles = 0;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _d(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _hm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
  static String _stamp(DateTime t) => '${_d(t)} ${_hm(t)}';
}
