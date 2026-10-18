import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/repositories/habit_repository.dart';
import 'package:atomic_momentum/domain/services/achievements.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/share/share_cards.dart';
import 'package:atomic_momentum/presentation/share/share_sheet.dart';
import 'package:atomic_momentum/presentation/widgets/achievement_widgets.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/insights_screen.dart';

import '../helpers/fake_sharer.dart';

/// Sharing a card: the preview, its options, and the picture handed over.
void main() {
  late HabitProvider habits;
  late FakeSharer sharer;
  late String id;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime ago(int n) => DateTime(today.year, today.month, today.day - n);

  final smoking = Achievement(
    id: 'clean_30_s',
    kind: AchievementKind.clean,
    title: '30 days without smoking',
    badge: '30',
    unit: 'DAYS',
    message: "A whole month without a slip. That's a real change.",
    habitId: 's',
    habitName: 'Smoking',
    earnedOn: today,
  );

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    sharer = FakeSharer.install();
    habits = get<HabitProvider>();
    await withClock(
      Clock.fixed(ago(40)),
      () => habits.createHabit(const CreateHabitParams(
        name: 'Read',
        target: 1,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.mind,
      )),
    );
    final habit = habits.habits.single;
    id = habit.id;
    await get<HabitRepository>().saveHabit(habit.copyWith(history: {for (var i = 40; i >= 1; i--) ago(i): 1}));
    await habits.loadHabits();
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 2400);
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

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  /// Taps Share… and lets the card render to a picture.
  Future<void> send(WidgetTester tester) async {
    final button = find.descendant(of: find.byType(ShareSheet), matching: find.text('Share…'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(button);
      for (var i = 0; i < 20 && sharer.shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  Widget achievementSheet(Achievement a) => Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () => showShareSheet(
                context,
                card: (look, hideName) => AchievementShareCard(achievement: a, look: look, hideName: hideName),
                fileName: 'momentum-achievement.png',
                canHideName: a.habitName != null,
                hideNameByDefault: a.kind == AchievementKind.clean,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

  String cardTitle(WidgetTester tester) => tester
      .widgetList<Text>(find.descendant(of: find.byKey(const Key('shareCard_achievement')), matching: find.byType(Text)))
      .map((t) => t.data)
      .join(' | ');

  testWidgets('a habit being broken shares with its name hidden at first; the switch shows it', (tester) async {
    await pump(tester, achievementSheet(smoking));
    await tap(tester, 'open');
    expect(cardTitle(tester), contains('30 days clean'));
    expect(cardTitle(tester), isNot(contains('smoking')));
    await tap(tester, 'shareHideName');
    expect(cardTitle(tester), contains('30 days without smoking'));
  });

  testWidgets('styles change the card; Share… hands over a 1080 × 1350 picture with the name', (tester) async {
    await pump(tester, achievementSheet(smoking));
    await tap(tester, 'open');
    await tap(tester, 'shareStyle_ember');
    final look = tester.widget<ShareCardFrame>(find.byKey(const Key('shareCard_achievement'))).look;
    expect(look.style, ShareStyle.ember);

    await send(tester);
    expect(sharer.shared, hasLength(1));
    expect(pngSize(sharer.shared.single.png), (1080, 1350));
    expect(sharer.shared.single.name, 'momentum-achievement.png');
    expect(sharer.shared.single.text, isNull, reason: 'no store link before launch');
    expect(find.byType(ShareSheet), findsNothing, reason: 'closes after sharing');
  });

  testWidgets("the achievement sheet's Share opens the preview", (tester) async {
    await pump(tester, Scaffold(body: AchievementSheet(achievement: smoking, isNew: true)));
    await tap(tester, 'achievementShare');
    expect(find.byType(ShareSheet), findsOneWidget);
    expect(find.byKey(const Key('shareCard_achievement')), findsOneWidget);
  });

  testWidgets("the habit page shares its streak", (tester) async {
    await pump(tester, HabitDetailScreen(habitId: id));
    await tap(tester, 'detailShare');
    expect(find.byKey(const Key('shareCard_streak')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('shareCard_streak')), matching: find.text('Read')), findsOneWidget);
    await send(tester);
    expect(pngSize(sharer.shared.single.png), (1080, 1350));
  });

  testWidgets('Insights shares momentum and the last 6 months', (tester) async {
    await pump(tester, const InsightsScreen());
    await tap(tester, 'share_Momentum');
    expect(find.byKey(const Key('shareCard_momentum')), findsOneWidget);
    expect(find.byKey(const Key('shareStyle_ember')), findsNothing, reason: 'the chart needs a theme');
    Navigator.of(tester.element(find.byType(ShareSheet))).pop();
    await tester.pumpAndSettle();

    await tap(tester, 'share_Every day');
    expect(find.byKey(const Key('shareCard_heatmap')), findsOneWidget);
    expect(find.byKey(const Key('shareHideName')), findsNothing, reason: 'all habits: no name to hide');
  });
}
