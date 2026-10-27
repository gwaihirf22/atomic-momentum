import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/copy/quotes.dart';
import 'package:atomic_momentum/core/theme/app_palette.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/momentum.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/presentation/home_widgets/widget_snapshot.dart';

void main() {
  // Sunday evening, Oct 18 2026
  final now = DateTime(2026, 10, 18, 21, 30);
  final today = DateTime(2026, 10, 18);

  Habit make(String name, {int target = 8, String units = '', ResetFrequency every = ResetFrequency.daily, HabitGoal goal = HabitGoal.build}) =>
      withClock(Clock.fixed(DateTime(2026, 10, 1, 9)), () => Habit.create(
            name: name,
            target: target,
            units: units,
            color: HabitColor.blue,
            categoryId: BuiltInCategoryIds.body,
            resetFrequency: every,
            goal: goal,
          ));

  Habit logged(Habit habit, int amount) => withClock(Clock.fixed(now), () => habit.updateProgress(amount));

  Map<String, Object?> snapshot(List<Habit> habits, {Momentum? momentum, AppTheme light = AppTheme.sepia, AppTheme dark = AppTheme.dark}) =>
      withClock(Clock.fixed(now), () => WidgetSnapshot.build(
            habits: habits,
            momentum: momentum,
            now: now,
            light: light,
            dark: dark,
          ));

  Map<String, Object?> habitIn(Map<String, Object?> snap, int index) =>
      (snap['habits'] as List)[index] as Map<String, Object?>;

  test('a habit under way: its progress, the next step and when the period ends', () {
    final water = logged(make('Drink water', units: 'glasses'), 5);
    final h = habitIn(snapshot([water]), 0);

    expect(h['name'], 'Drink water');
    expect(h['progress'], 5);
    expect(h['target'], 8);
    expect(h['text'], '5 of 8 glasses');
    expect(h['done'], isFalse);
    expect(h['next'], 6, reason: 'one step toward the target, as the card\'s +');
    expect(h['addLabel'], 'Add one');
    expect(h['period'], 'today');
    expect(h['periodEnds'], '2026-10-19T00:00:00');
    expect((h['recent'] as List).last, {'mark': 'current', 'fraction': 0.63});
  });

  test('a frozen habit is held as it is: frozen, and no +', () {
    final read = withClock(Clock.fixed(now), () => make('Read').freeze(today));
    final h = habitIn(snapshot([read]), 0);
    expect(h['frozen'], isTrue);
    expect(h['next'], isNull);
    expect(habitIn(snapshot([make('Read')]), 0)['frozen'], isFalse);
  });

  test('a done habit has no next step', () {
    final h = habitIn(snapshot([logged(make('Read', target: 20, units: 'pages'), 20)]), 0);
    expect(h['done'], isTrue);
    expect(h['next'], isNull);
    expect(h['addLabel'], isNull);
  });

  test('+ steps by the target, as in the app', () {
    final walk = logged(make('Walk', target: 8000, units: 'steps'), 7450);
    final h = habitIn(snapshot([walk]), 0);
    expect(h['next'], 8000);
    expect(h['step'], 1000);
    expect(h['addLabel'], 'Add 1,000 steps');
  });

  test('a habit being broken: its status, and no + to log a slip by accident', () {
    final smoking = make('Smoking', target: 0, goal: HabitGoal.quit);
    final h = habitIn(snapshot([smoking]), 0);
    expect(h['isBreak'], isTrue);
    expect(h['text'], 'Clean today');
    expect(h['next'], isNull);
    expect(h['done'], isFalse);
  });

  test('a weekly habit counts over its week', () {
    final run = logged(make('Run', target: 3, every: ResetFrequency.weekly), 2);
    final h = habitIn(snapshot([run]), 0);
    expect(h['period'], 'this week');
    expect(h['text'], '2 of 3');
  });

  test('today counts habits due today, and how many are done', () {
    final snap = snapshot([
      logged(make('Water'), 8),
      logged(make('Read'), 3),
      make('Stretch'),
    ]);
    expect(snap['today'], {'done': 1, 'due': 3});
    expect(snap['day'], '2026-10-18');
  });

  test('momentum with its level, or null with nothing to average', () {
    expect(snapshot([])['momentum'], isNull);
    expect(snapshot([], momentum: const Momentum(score: 74.4, trend: 3.2))['momentum'],
        {'score': 74, 'trend': 3, 'level': 'Strong', 'formed': 80, 'habits': 0, 'rising': 0});
  });

  test('looks follow the app: its day and night themes, with habit colors drawn for each', () {
    final snap = snapshot([make('Water')], light: AppTheme.sepia, dark: AppTheme.dark);
    final looks = snap['looks'] as Map;
    expect(looks['light']['theme'], 'sepia');
    expect(looks['light']['surface'], '#FBF6EC');
    expect(looks['dark']['theme'], 'dark');
    expect(looks['dark']['accent'], '#FFB020');

    final colors = habitIn(snap, 0)['color'] as Map;
    final drawn = AppPalette.sepia.habitColor(HabitColor.blue.color).toARGB32() & 0xFFFFFF;
    expect(colors['light'], '#${drawn.toRadixString(16).padLeft(6, '0').toUpperCase()}');
    expect(colors['light'], isNot(colors['dark']));
  });

  test('Scripture keeps its translation; other quotes their author', () {
    Map<String, Object?> withQuote(String id) => withClock(Clock.fixed(now), () => WidgetSnapshot.build(
          habits: const [],
          momentum: null,
          now: now,
          light: AppTheme.light,
          dark: AppTheme.dark,
          quote: Quotes.library.firstWhere((q) => q.id == id),
        ));
    expect((withQuote('kjv-proverbs-24-16')['quote'] as Map)['author'], endsWith('(NKJV)'));
    expect((withQuote('epictetus-say-what-you-would-be')['quote'] as Map)['author'], 'Epictetus');
  });

  test('says whether Momentum Plus is this person\'s (Siri and Shortcuts read it), without a new version', () {
    Map<String, Object?> withPlus(bool plus) => withClock(Clock.fixed(now), () => WidgetSnapshot.build(
          habits: [make('Water')],
          momentum: null,
          now: now,
          light: AppTheme.light,
          dark: AppTheme.light,
          plus: plus,
        ));
    expect(withPlus(true)['plus'], isTrue);
    expect(withPlus(false)['plus'], isFalse);
    expect(withPlus(true)['v'], 1, reason: 'an added field: widgets reading version 1 still read it');
  });

  test('encodes to JSON with its version', () {
    final json = withClock(Clock.fixed(now), () => WidgetSnapshot.encode(
          habits: [make('Water')],
          momentum: null,
          now: now,
          light: AppTheme.light,
          dark: AppTheme.light,
        ));
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['v'], WidgetSnapshot.version);
    expect(decoded['written'], '2026-10-18T21:30:00');
    expect(today, DateTime(2026, 10, 18));
  });

  String sentenceOf(Map<String, Object?> h) => (h['sentence'] as List).map((p) => (p as Map)['t']).join();
  List<String> keysOf(Map<String, Object?> h) =>
      [for (final p in h['sentence'] as List) if ((p as Map)['k'] == true) p['t'] as String];

  test("a habit's Story sentence, its own words marked, and its hard-day version", () {
    final water = make('Drink water', units: 'glasses').copyWith(twoMinute: const TwoMinuteVersion(description: 'Fill one glass'));
    final h = habitIn(snapshot([water]), 0);
    expect(sentenceOf(h), 'I will drink water 8 glasses every day.');
    expect(keysOf(h), ['drink water', '8 glasses', 'every day']);
    expect(h['hardDay'], 'fill one glass');
  });

  test('habits being broken read as Story writes them', () {
    final smoking = habitIn(snapshot([make('Smoking', target: 0, goal: HabitGoal.quit)]), 0);
    expect(sentenceOf(smoking), 'I will quit smoking.');
    expect(smoking['hardDay'], isNull);
    final alcohol = habitIn(snapshot([make('Alcohol', target: 2, units: 'drinks', goal: HabitGoal.limit)]), 0);
    expect(sentenceOf(alcohol), 'I will keep alcohol to 2 drinks a day.');
  });

  test('insights: a character a day for the heatmap, this week, and the month', () {
    var water = make('Water', target: 1);
    for (var d = 1; d <= 18; d++) {
      if (d % 5 != 0) water = withClock(Clock.fixed(DateTime(2026, 10, d, 20)), () => water.setProgressForDate(DateTime(2026, 10, d), 1));
    }
    final insights = snapshot([water])['insights'] as Map;
    final from = DateTime.parse(insights['from'] as String);
    final days = insights['days'] as String;
    expect(from.weekday, DateTime.monday);
    expect(days.length, today.difference(from).inDays + 1, reason: 'from the first day shown to today');
    expect(days.substring(days.length - 18), 'PPPP0PPPP0PPPP0PPP', reason: 'Oct 1 to 18: kept, missed every fifth');
    expect(days.substring(0, days.length - 18), matches(RegExp(r'^-*$')), reason: 'nothing due before the habit');
    expect(insights['weekToday'], 6, reason: 'Sunday, in a week starting Monday');
    expect((insights['week'] as List).length, 7);
    expect(insights['twoMinute'], 0);
    expect(insights['longestStreak'], greaterThan(0));
  });

  test('no habits, no insights', () {
    expect(snapshot([])['insights'], isNull);
  });
}
