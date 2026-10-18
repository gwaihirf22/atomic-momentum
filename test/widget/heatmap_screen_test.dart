import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/repositories/habit_repository.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/widgets/heatmap.dart';
import 'package:atomic_momentum/screens/heatmap_screen.dart';
import 'package:atomic_momentum/screens/insights_screen.dart';

/// The full-screen heatmap: the whole history, scrolled and zoomed.
void main() {
  late HabitProvider habits;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  /// Read, tracked for 400 days (over a year), done most days; Walk, new.
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    await withClock(
      Clock.fixed(daysAgo(400)),
      () => habits.createHabit(const CreateHabitParams(
        name: 'Read',
        target: 1,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.mind,
      )),
    );
    await habits.createHabit(const CreateHabitParams(
      name: 'Walk',
      target: 1,
      color: HabitColor.green,
      categoryId: BuiltInCategoryIds.body,
    ));
    final read = habits.habits.firstWhere((h) => h.name == 'Read');
    await get<HabitRepository>().saveHabit(read.copyWith(history: {
      for (var i = 400; i >= 1; i--)
        if (i % 4 != 0) daysAgo(i): 1,
    }));
    await habits.loadHabits();
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, Widget home, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
  }

  ZoomableHeatmapState zoom(WidgetTester tester) => tester.state<ZoomableHeatmapState>(find.byType(ZoomableHeatmap));
  ScrollPosition scroll(WidgetTester tester) =>
      tester.state<ScrollableState>(find.descendant(of: find.byKey(const Key('heatmapScroll')), matching: find.byType(Scrollable))).position;

  testWidgets("Insights' expand button opens every day, scrolled to today", (tester) async {
    await pump(tester, const InsightsScreen());
    await tester.ensureVisible(find.byKey(const Key('heatmapExpand')));
    await tester.tap(find.byKey(const Key('heatmapExpand')));
    await tester.pumpAndSettle();
    expect(find.byType(HeatmapScreen), findsOneWidget);
    final days = tester.widget<ZoomableHeatmap>(find.byType(ZoomableHeatmap)).days;
    expect(days.first.day, daysAgo(400), reason: 'the whole history');
    expect(days.last.day, today);
    expect(scroll(tester).pixels, scroll(tester).maxScrollExtent);
  });

  testWidgets('one finger scrolls back in time', (tester) async {
    await pump(tester, const HeatmapScreen());
    final end = scroll(tester).pixels;
    await tester.drag(find.byKey(const Key('heatmapScroll')), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(scroll(tester).pixels, lessThan(end));
  });

  testWidgets('pinching zooms, within limits', (tester) async {
    await pump(tester, const HeatmapScreen());
    final start = zoom(tester).cell;
    final center = tester.getCenter(find.byKey(const Key('heatmapScroll')));

    Future<void> pinch(double from, double to) async {
      final a = await tester.startGesture(center - Offset(from, 0));
      final b = await tester.startGesture(center + Offset(from, 0), pointer: 7);
      for (var i = 1; i <= 5; i++) {
        final spread = from + (to - from) * i / 5;
        await a.moveTo(center - Offset(spread, 0));
        await b.moveTo(center + Offset(spread, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
    }

    await pinch(20, 60);
    expect(zoom(tester).cell, greaterThan(start));
    await pinch(20, 400);
    expect(zoom(tester).cell, ZoomableHeatmap.maxCell);
    await pinch(150, 2);
    expect(zoom(tester).cell, ZoomableHeatmap.minCell);
  });

  testWidgets('− and + zoom too', (tester) async {
    await pump(tester, const HeatmapScreen());
    final start = zoom(tester).cell;
    await tester.tap(find.byKey(const Key('heatmapZoomIn')));
    await tester.pumpAndSettle();
    expect(zoom(tester).cell, greaterThan(start));
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(const Key('heatmapZoomOut')));
      await tester.pumpAndSettle();
    }
    expect(zoom(tester).cell, ZoomableHeatmap.minCell);
  });

  testWidgets('tapping a day says how it went', (tester) async {
    await pump(tester, const HeatmapScreen());
    final grid = find.byKey(const Key('heatmapGrid'));
    await tester.tapAt(tester.getTopRight(grid) + const Offset(-4, 4));
    await tester.pumpAndSettle();
    final summary = tester.widget<Text>(find.byKey(const Key('heatmapDaySummary'))).data!;
    expect(summary, contains('of'));
  });

  testWidgets('the picker shows one habit: Walk is new, so only recent days count', (tester) async {
    await pump(tester, const HeatmapScreen());
    final walk = habits.habits.firstWhere((h) => h.name == 'Walk');
    await tester.tap(find.byKey(const Key('heatmapHabitPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('heatmapPick_${walk.id}')));
    await tester.pumpAndSettle();
    final days = tester.widget<ZoomableHeatmap>(find.byType(ZoomableHeatmap)).days;
    expect(days.length, inInclusiveRange(25 * 7 + 1, 26 * 7), reason: 'at least 26 weeks');
    expect(days.where((d) => !d.isEmpty).length, 1, reason: 'only today');
  });

  testWidgets('month and year labels, and VoiceOver reads month by month', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, const HeatmapScreen());
    expect(find.byKey(Key('heatmapMonth_January ${today.year}')).evaluate().isNotEmpty || today.month == 1, isTrue);
    expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(_monthYear(today))}: something kept on')), findsOneWidget);
    semantics.dispose();
  });

  for (final cell in [ZoomableHeatmap.minCell, ZoomableHeatmap.maxCell]) {
    testWidgets('weekday letters stay within the rows at cell $cell', (tester) async {
      await pump(tester, const HeatmapScreen());
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byKey(Key(cell == ZoomableHeatmap.minCell ? 'heatmapZoomOut' : 'heatmapZoomIn')));
        await tester.pumpAndSettle();
      }
      expect(zoom(tester).cell, cell);
      final grid = tester.getRect(find.byKey(const Key('heatmapGrid')));
      for (final label in find.byWidgetPredicate((w) => w.key is ValueKey<String> && '${(w.key as ValueKey<String>).value}'.startsWith('heatmapWeekday_')).evaluate()) {
        final rect = tester.getRect(find.byWidget(label.widget));
        expect(rect.top, greaterThanOrEqualTo(grid.top - 0.5), reason: '${label.widget.key}');
        expect(rect.bottom, lessThanOrEqualTo(grid.bottom + 0.5), reason: '${label.widget.key}');
      }
      expect(tester.allRenderObjects.whereType<RenderParagraph>().any((p) => p.didExceedMaxLines), isFalse);
    });
  }
}

String _monthYear(DateTime day) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[day.month - 1]} ${day.year}';
}
