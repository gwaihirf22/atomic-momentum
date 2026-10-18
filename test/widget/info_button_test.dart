import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/help/explainers.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/builder_add_screen.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/story_habit_screen.dart';

/// The (i) explainers: two-minute days and momentum.
void main() {
  late HabitProvider habits;
  late String read;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    await habits.createHabit(const CreateHabitParams(
      name: 'Read',
      target: 10,
      units: 'pages',
      color: HabitColor.teal,
      categoryId: BuiltInCategoryIds.mind,
      twoMinute: TwoMinuteVersion(description: 'Read one page'),
    ));
    read = habits.habits.single.id;
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

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder sheet(InfoTopic topic) => find.byKey(Key('infoSheet_${topic.name}'));

  Future<void> close(WidgetTester tester, InfoTopic topic) async {
    await tester.ensureVisible(find.byKey(const Key('infoGotIt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('infoGotIt')));
    await tester.pumpAndSettle();
    expect(sheet(topic), findsNothing);
  }

  test('every explainer has a title, an intro and short points', () {
    for (final topic in InfoTopic.values) {
      final explainer = Explainer.of(topic);
      expect(explainer.title, isNotEmpty);
      expect(explainer.intro.length, lessThan(200), reason: '$topic intro');
      for (final point in explainer.points) {
        expect(point.text.length, lessThan(160), reason: point.text);
        expect(point.badge != null || point.icon != null, isTrue, reason: point.text);
      }
    }
  });

  testWidgets("the habit page's (i) by \"2 min\" explains it with the habit's own example", (tester) async {
    await pump(tester, HabitDetailScreen(habitId: read));
    await tap(tester, find.byKey(const Key('info_twoMinute')));
    expect(sheet(InfoTopic.twoMinute), findsOneWidget);
    expect(find.text('Read 10 pages'), findsOneWidget);
    expect(find.text('Read one page'), findsOneWidget);
    expect(find.textContaining('never lowers your momentum'), findsOneWidget);
    await close(tester, InfoTopic.twoMinute);
  });

  testWidgets("the habit page's momentum tile explains momentum and shows its level", (tester) async {
    await pump(tester, HabitDetailScreen(habitId: read));
    expect(find.textContaining('Momentum · Building'), findsOneWidget);
    await tap(tester, find.byKey(const Key('info_momentum_tile')));
    expect(sheet(InfoTopic.momentum), findsOneWidget);
    expect(find.textContaining('Unstoppable · 90+'), findsOneWidget);
    await close(tester, InfoTopic.momentum);
  });

  testWidgets("the editor's two-minute section has an (i), also in Builder's last step", (tester) async {
    await pump(tester, const AddHabitScreen());
    await tap(tester, find.byKey(const Key('info_twoMinute')));
    expect(sheet(InfoTopic.twoMinute), findsOneWidget);
    expect(find.text('Read 10 pages'), findsOneWidget, reason: 'the general example until a tiny version is written');
    await close(tester, InfoTopic.twoMinute);
  });

  testWidgets('Builder step 3 explains two-minute days', (tester) async {
    await pump(tester, const BuilderAddScreen());
    await tester.enterText(find.byKey(const Key('habitNameField')), 'Stretch');
    await tap(tester, find.byKey(const Key('builderNext')));
    await tester.enterText(find.byKey(const Key('habitTargetField')), '1');
    await tap(tester, find.byKey(const Key('builderNext')));
    expect(tester.widget<Text>(find.byKey(const Key('builderStepTitle'))).data, 'Make it easy');
    await tap(tester, find.byKey(const Key('info_twoMinute')));
    expect(sheet(InfoTopic.twoMinute), findsOneWidget);
  });

  testWidgets('Story\'s "On a hard day" sheet has the (i), with the example as written', (tester) async {
    await pump(tester, StoryHabitScreen(editHabit: habits.getHabitById(read)));
    await tap(tester, find.byKey(const Key('storyTiny')));
    await tap(tester, find.byKey(const Key('info_twoMinute')));
    expect(sheet(InfoTopic.twoMinute), findsOneWidget);
    expect(find.text('Read 10 pages'), findsOneWidget);
    expect(find.text('Read one page'), findsWidgets);
  });

  testWidgets('VoiceOver reads the (i) as a button that says what it explains', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, HabitDetailScreen(habitId: read));
    expect(
      tester.getSemantics(find.byKey(const Key('info_twoMinute'))),
      matchesSemantics(label: 'About two-minute days', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });
}
