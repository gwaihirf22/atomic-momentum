import 'dart:convert';
import 'dart:ui' show Color;

import '../../core/copy/quotes.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_goal.dart';
import '../../domain/entities/momentum.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/services/achievements.dart';
import '../../domain/services/insights.dart';
import '../../domain/services/quote_of_the_day.dart';
import '../../domain/services/recent_periods.dart';
import '../../domain/services/step_size.dart';
import '../habit_form/sentence.dart';
import '../widgets/break_wording.dart';
import '../widgets/heatmap.dart';
import '../widgets/habit_stepper.dart';

/// What the home screen widgets draw, worked out by the app: the widgets
/// only lay it out, so their numbers always match the app's.
///
/// Written as JSON to the App Group (see `ios/MomentumWidgets/Snapshot.swift`,
/// which reads it). Keep the two in step; bump [version] for a change the
/// widgets can't read.
class WidgetSnapshot {
  const WidgetSnapshot._();

  static const version = 1;

  /// Quotes short enough for a small or lock screen widget, whole.
  static const shortQuoteLength = 90;

  /// The snapshot for [habits] at [now]. [light] and [dark] are the app's
  /// looks for the phone's light and dark mode (both the same when the
  /// person picked one), so widgets match the app. [quote] is today's quote
  /// and [quoteNext] tomorrow's (shown from midnight if the app hasn't
  /// written by then); [shortQuote] and [shortQuoteNext] the same for small
  /// widgets. [findQuote] looks up the quotes kept with each habit.
  static Map<String, Object?> build({
    required List<Habit> habits,
    required Momentum? momentum,
    required DateTime now,
    required AppTheme light,
    required AppTheme dark,
    Quote? quote,
    Quote? quoteNext,
    Quote? shortQuote,
    Quote? shortQuoteNext,
    List<Category> categories = const [],
    Quote? Function(String id)? findQuote,
    int weekStart = DateTime.monday,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final due = habits.where((h) => h.schedule.isPeriodic && h.isDueOn(today) && h.startedOn(today)).toList();
    final tracked = habits.where((h) => h.countsTowardMomentumAt(now)).toList();
    return {
      'v': version,
      'written': _local(now),
      'day': _day(today),
      'looks': {'light': _look(AppPalette.forTheme(light)), 'dark': _look(AppPalette.forTheme(dark))},
      'momentum': momentum == null
          ? null
          : {
              'score': momentum.rounded,
              'trend': momentum.trend.round(),
              'level': momentum.level.label,
              'formed': Momentum.habitFormed,
              'habits': tracked.length,
              'rising': tracked.where((h) => h.momentum.isRising).length,
            },
      'today': {'done': due.where((h) => h.wasCompletedOnDate(today)).length, 'due': due.length},
      'habits': [for (final habit in habits) _habit(habit, now, light: light, dark: dark, findQuote: findQuote)],
      'categories': [
        for (final category in categories) {'id': category.id, 'name': category.name},
      ],
      'insights': habits.isEmpty ? null : _insights(habits, now, weekStart),
      'quote': quote == null ? null : _quote(quote),
      'quoteNext': quoteNext == null ? null : _quote(quoteNext),
      'shortQuote': shortQuote == null ? null : _quote(shortQuote),
      'shortQuoteNext': shortQuoteNext == null ? null : _quote(shortQuoteNext),
    };
  }

  /// [build] as the JSON string the widgets read.
  static String encode({
    required List<Habit> habits,
    required Momentum? momentum,
    required DateTime now,
    required AppTheme light,
    required AppTheme dark,
    Quote? quote,
  }) =>
      jsonEncode(build(habits: habits, momentum: momentum, now: now, light: light, dark: dark, quote: quote));


  static Map<String, Object?> _habit(
    Habit habit,
    DateTime now, {
    required AppTheme light,
    required AppTheme dark,
    Quote? Function(String id)? findQuote,
  }) {
    final periodic = habit.schedule.isPeriodic;
    // Frozen or on vacation (and not kept): held as it is, no +
    final paused = periodic && habit.skipsPeriod(habit.schedule.periodStart(now));
    final canAdd = !paused && !habit.isBreak && habit.progress < habit.target;
    final units = habit.units.isEmpty ? '' : ' ${habit.units}';
    final streak = habit.streak.current;
    Map<String, String> colors(Color Function(AppPalette p) of) => {
          'light': _hex(of(AppPalette.forTheme(light))),
          'dark': _hex(of(AppPalette.forTheme(dark))),
        };
    return {
      'id': habit.id,
      'name': habit.name,
      'category': habit.categoryId,
      'color': colors((p) => p.habitColor(habit.color.color)),
      // A mark drawn on a full ring of that color (the done check)
      'onColor': colors((p) => p.onColor(p.habitColor(habit.color.color))),
      'isBreak': habit.isBreak,
      'progress': habit.progress,
      'target': habit.target,
      'units': habit.units,
      'text': habit.isBreak ? BreakWording.status(habit, now) : '${habit.progress} of ${habit.target}$units',
      'done': !habit.isBreak && habit.isCompleted,
      'frozen': paused,
      'due': periodic && habit.isDueOn(now),
      'period': _periodWord(habit),
      // When this period's progress no longer counts (the widget shows the
      // new period as empty from then until the app writes again)
      'periodEnds': periodic ? _local(habit.schedule.nextPeriodStart(now)) : null,
      'next': canAdd ? StepSize.up(habit.progress, habit.target) : null,
      // What + steps by, so a widget can show its tap before the app logs it
      'step': StepSize.forTarget(habit.target),
      'addLabel': canAdd ? stepTooltip(habit, adding: true, one: 'Add one') : null,
      'streak': streak,
      'streakLabel': streak == 0
          ? null
          : habit.isBreak
              ? BreakWording.streak(habit, streak)
              : habit.schedule.streakLabel(streak),
      'atRisk': streak > 0 && habit.streak.atRisk,
      'momentum': periodic ? habit.momentum.rounded : null,
      'recent': [
        for (final period in recentPeriods(habit, now))
          {'mark': period.mark.name, 'fraction': double.parse(period.fraction.toStringAsFixed(2))},
      ],
      // The habit as Story writes it, without its reminder: "I will drink
      // water 8 glasses every day."
      'sentence': _sentence(habit),
      'hardDay': _hardDay(habit),
      // "Words for this habit", in order; the widget takes a turn a day
      'quotes': [
        if (findQuote != null)
          for (final id in habit.quoteIds)
            if (findQuote(id) case final quote?) _quote(quote),
      ],
    };
  }

  /// Weeks of days on the Insights widgets' heatmaps (the large one shows
  /// them all, the medium one the last 15).
  static const heatmapWeeks = 25;

  /// Insights at a glance: the heatmap's days, this week, this month against
  /// last, and a few lines from history (as the Insights tab works them out).
  static Map<String, Object?> _insights(List<Habit> habits, DateTime now, int weekStart) {
    final today = DateTime(now.year, now.month, now.day);
    final thisWeek = DateTime(today.year, today.month, today.day - (today.weekday - weekStart + 7) % 7);
    final from = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * (heatmapWeeks - 1));
    final days = Insights.days(habits, from: from, to: today, now: now);
    final month = DateTime(today.year, today.month);
    final keptThisMonth = Insights.kept(habits, from: month, now: now);
    final months = Insights.momentumByMonth(habits, now, count: 2);
    final periodic = habits.where((h) => h.schedule.isPeriodic).toList();
    int bestOf(Habit h) => h.streak.longest > h.streak.current ? h.streak.longest : h.streak.current;
    final longest = periodic.isEmpty ? null : periodic.reduce((a, b) => bestOf(b) > bestOf(a) ? b : a);
    final best = Insights.weekdays(habits, from: from, now: now).best;
    final next = Achievements.next(habits, now).firstOrNull;
    return {
      'weekStart': weekStart,
      'from': _day(from),
      // A character a day from [from] to today: '-' nothing due, '0'–'4' how
      // full (the heatmap's shades), 'P' a perfect day
      'days': days.map((d) => d.isEmpty ? '-' : (d.perfect ? 'P' : '${Heatmap.shadeOf(d)}')).join(),
      'week': [
        for (var i = 0; i < 7; i++)
          () {
            final day = DateTime(thisWeek.year, thisWeek.month, thisWeek.day + i);
            if (day.isAfter(today)) return null;
            final record = days.where((d) => d.day == day).firstOrNull;
            return record == null || record.isEmpty ? null : double.parse(record.level.toStringAsFixed(2));
          }(),
      ],
      'weekToday': (today.weekday - weekStart + 7) % 7,
      'momentum': months.last.score?.round(),
      'momentumLast': months.length > 1 ? months.first.score?.round() : null,
      'kept': keptThisMonth.total == 0 ? null : (100 * keptThisMonth.kept / keptThisMonth.total).round(),
      'twoMinute': keptThisMonth.twoMinute,
      'streaksSaved': Insights.kept(habits, from: from, now: now).streaksSaved,
      'longestStreak': Insights.longestStreak(habits),
      'longest': longest == null || bestOf(longest) == 0
          ? null
          : {
              'name': longest.name,
              'label': longest.isBreak
                  ? BreakWording.streak(longest, bestOf(longest))
                  : longest.schedule.streakLabel(bestOf(longest)),
            },
      'bestDay': best == null ? null : _weekdays[best - 1],
      'next': next == null
          ? null
          : {
              'title': next.title,
              'habit': next.habitName,
              'current': next.current,
              'goal': next.goal,
            },
    };
  }

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// Story's sentence in parts, the habit's own words marked (`k`), so the
  /// widget can color them: "I will [drink water] [8 glasses] [every day]."
  static List<Map<String, Object>> _sentence(Habit habit) {
    Map<String, Object> plain(String t) => {'t': t};
    Map<String, Object> key(String t) => {'t': t, 'k': true};
    final name = HabitSentence.name(habit.name);
    if (habit.isBreak) {
      return [
        plain('I will '),
        key(HabitSentence.breakVerb(habit.goal)),
        plain(' '),
        key(name),
        if (habit.goal == HabitGoal.limit) ...[
          plain(' to '),
          key(HabitSentence.amount(habit.target, habit.units)),
          plain(' '),
          key(HabitSentence.perPeriod(habit.resetFrequency)),
        ],
        plain('.'),
      ];
    }
    final amount = HabitSentence.amount(habit.target, habit.units);
    return [
      plain('I will '),
      key(name),
      if (amount.isNotEmpty) ...[plain(' '), key(amount)],
      plain(' '),
      key(HabitSentence.schedule(habit.schedule)),
      plain('.'),
    ];
  }

  /// "fill one glass", for "On a hard day, I'll just fill one glass."
  static String? _hardDay(Habit habit) {
    final tiny = habit.twoMinute?.description.trim() ?? '';
    if (tiny.isEmpty || !habit.schedule.isPeriodic) return null;
    return tiny[0].toLowerCase() + tiny.substring(1);
  }

  /// "today", "this week": what the progress is counted over.
  static String _periodWord(Habit habit) {
    final schedule = habit.schedule;
    if (!schedule.isPeriodic) return 'in total';
    if (schedule.interval != 1) return 'this period';
    return switch (habit.resetFrequency) {
      ResetFrequency.weekly => 'this week',
      ResetFrequency.monthly => 'this month',
      _ => 'today',
    };
  }

  static Map<String, String> _quote(Quote quote) {
    final verse = quote.source == Quotes.nkjv;
    return {
      'id': quote.id,
      'text': quote.text,
      // Verses carry their translation, as its copyright notice asks
      'author': verse ? '${quote.author} (NKJV)' : quote.author,
      'source': verse ? '' : quote.source,
    };
  }

  /// The palette colors the widgets draw with.
  static Map<String, String> _look(AppPalette p) => {
        'theme': p.theme.name,
        'background': _hex(p.background),
        'surface': _hex(p.surface),
        'raised': _hex(p.raised),
        'track': _hex(p.track),
        'text': _hex(p.text),
        'textSecondary': _hex(p.textSecondary),
        'accent': _hex(p.accent),
        'gauge': _hex(p.gauge),
        'orbStart': _hex(p.orbStart),
        'orbEnd': _hex(p.orbEnd),
        'onOrb': _hex(AppPalette.onOrb),
        'good': _hex(p.good),
        'goodTint': _hex(p.goodTint),
        'gold': _hex(p.gold),
        'flame': _hex(p.flame),
        'warning': _hex(p.warning),
        'ice': _hex(p.ice),
      };

  /// "#RRGGBB" (palette colors are opaque).
  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// What a short quote widget shows: [quote] itself if it's short, else
  /// the day's turn among the short ones in [pool].
  static Quote? shortFor(Quote? quote, List<Quote> pool, DateTime day) {
    if (quote == null || quote.text.length <= shortQuoteLength) return quote;
    return QuoteOfTheDay.pick(day, [for (final q in pool) if (q.text.length <= shortQuoteLength) q]);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _day(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  /// Local time without a zone ("2026-10-19T00:00:00"): the widgets read it
  /// in the phone's own time zone, as the app does.
  static String _local(DateTime t) => '${_day(t)}T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}
