import 'dart:convert';
import 'dart:ui' show Color;

import '../../core/copy/quotes.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/momentum.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/services/recent_periods.dart';
import '../../domain/services/step_size.dart';
import '../widgets/break_wording.dart';
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

  /// The snapshot for [habits] at [now]. [light] and [dark] are the app's
  /// looks for the phone's light and dark mode (both the same when the
  /// person picked one), so widgets match the app.
  static Map<String, Object?> build({
    required List<Habit> habits,
    required Momentum? momentum,
    required DateTime now,
    required AppTheme light,
    required AppTheme dark,
    Quote? quote,
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
      'habits': [for (final habit in habits) _habit(habit, now, light: light, dark: dark)],
      'quote': quote == null ? null : _quote(quote),
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

  static Map<String, Object?> _habit(Habit habit, DateTime now, {required AppTheme light, required AppTheme dark}) {
    final periodic = habit.schedule.isPeriodic;
    final canAdd = !habit.isBreak && habit.progress < habit.target;
    final units = habit.units.isEmpty ? '' : ' ${habit.units}';
    final streak = habit.streak.current;
    Map<String, String> colors(Color Function(AppPalette p) of) => {
          'light': _hex(of(AppPalette.forTheme(light))),
          'dark': _hex(of(AppPalette.forTheme(dark))),
        };
    return {
      'id': habit.id,
      'name': habit.name,
      'color': colors((p) => p.habitColor(habit.color.color)),
      // A mark drawn on a full ring of that color (the done check)
      'onColor': colors((p) => p.onColor(p.habitColor(habit.color.color))),
      'isBreak': habit.isBreak,
      'progress': habit.progress,
      'target': habit.target,
      'units': habit.units,
      'text': habit.isBreak ? BreakWording.status(habit, now) : '${habit.progress} of ${habit.target}$units',
      'done': !habit.isBreak && habit.isCompleted,
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
    };
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

  static Map<String, String> _quote(Quote quote) => {
        'id': quote.id,
        'text': quote.text,
        // Verses carry their translation, as its copyright notice asks
        'author': quote.source == Quotes.nkjv ? '${quote.author} (NKJV)' : quote.author,
      };

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
      };

  /// "#RRGGBB" (palette colors are opaque).
  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _day(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  /// Local time without a zone ("2026-10-19T00:00:00"): the widgets read it
  /// in the phone's own time zone, as the app does.
  static String _local(DateTime t) => '${_day(t)}T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}
