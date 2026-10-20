import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/theme/app_palette.dart';
import 'package:atomic_momentum/data/datasources/local_habit_datasource.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/delete_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/get_habits_usecase.dart';
import 'package:atomic_momentum/domain/usecases/update_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/presentation/widgets/adaptive.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';

import '../helpers/failing_habit_repository.dart';

void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(() async {
    await resetDependencies();
  });

  Future<String> addWater() async {
    final habits = get<HabitProvider>();
    await habits.createHabit(const CreateHabitParams(
      name: 'Drink Water',
      target: 3,
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
    ));
    return habits.habits.single.id;
  }

  group('the real app', () {
    testWidgets('shows on-screen messages (CupertinoApp has no messenger of its own)', (tester) async {
      final id = await addWater();
      await tester.pumpWidget(const MomentumApp());
      await tester.pumpAndSettle();

      await tester.drag(find.byKey(Key('habitCard_$id')), const Offset(-250, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('deleteHabit_$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDeleteHabit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Drink Water deleted'), findsOneWidget);
    });

    testWidgets('follows the device appearance by default', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const MomentumApp());
      await tester.pumpAndSettle();

      final app = tester.widget<CupertinoApp>(find.byType(CupertinoApp));
      expect(app.theme!.brightness, Brightness.dark);

      // ...and changes with it
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(tester.widget<CupertinoApp>(find.byType(CupertinoApp)).theme!.brightness, Brightness.light);
    });

    testWidgets('System uses Sepia by day when chosen, and Dark at night', (tester) async {
      await get<ThemeProvider>().setDayTheme(AppTheme.sepia);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const MomentumApp());
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Habits').first);
      expect(AppPalette.of(context), AppPalette.sepia);
      // Sepia is a light theme for the status bar and system controls
      expect(tester.widget<CupertinoApp>(find.byType(CupertinoApp)).theme!.brightness, Brightness.light);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(AppPalette.of(tester.element(find.text('Habits').first)), AppPalette.dark);
    });

    testWidgets("uses the palette's amber as the accent for Material controls, not purple", (tester) async {
      await tester.pumpWidget(const MomentumApp());
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(find.text('Habits').first));
      // System by default, Sepia by day
      expect(theme.colorScheme.primary, AppPalette.sepia.accent);
      expect(theme.scaffoldBackgroundColor, AppPalette.sepia.background);
    });
  });

  group('Add Habit', () {
    testWidgets('a failed save keeps the form open with what was typed', (tester) async {
      final repository = FailingHabitRepository(get<LocalHabitDataSource>())..failSaves = true;
      final failing = HabitProvider(
        getHabitsUseCase: GetHabitsUseCase(repository),
        createHabitUseCase: CreateHabitUseCase(repository),
        updateHabitUseCase: UpdateHabitUseCase(repository),
        deleteHabitUseCase: DeleteHabitUseCase(repository),
      );
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
          ChangeNotifierProvider<HabitProvider>.value(value: failing),
          ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
          ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
        ],
        child: const MaterialApp(home: Scaffold(body: Text('Home'))),
      ));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(MaterialPageRoute<void>(builder: (_) => const AddHabitScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Budget review');
      await tester.enterText(find.byType(TextFormField).at(1), '1');
      await tester.tap(find.byKey(const Key('saveHabitButton')));
      await tester.pumpAndSettle();

      expect(find.byType(AddHabitScreen), findsOneWidget);
      expect(find.text('Budget review'), findsOneWidget);
      expect(find.text('Couldn\'t save "Budget review". Please try again.'), findsOneWidget);
    });
  });

  group('Settings: appearance', () {
    testWidgets('offers System, Light, Sepia and Dark, and saves the choice', (tester) async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
          ChangeNotifierProvider<HabitProvider>.value(value: get<HabitProvider>()),
          ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
          ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byKey(const Key('appearanceSetting')), matching: find.text('System')),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('appearanceSetting')));
      await tester.pumpAndSettle();
      for (final appearance in Appearance.values) {
        expect(find.byKey(Key('appearance_${appearance.name}')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('appearance_sepia')));
      await tester.pumpAndSettle();

      expect(get<ThemeProvider>().appearance, Appearance.sepia);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('themeMode'), 'sepia');
      // The day theme only applies to System
      expect(find.byKey(const Key('dayThemeSetting')), findsNothing);
    });

    testWidgets('Habit editor offers Story and Builder, each explained, and saves the choice', (tester) async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
          ChangeNotifierProvider<HabitProvider>.value(value: get<HabitProvider>()),
          ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
          ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('addHabitStyleSetting')), 200,
          scrollable: find.byType(Scrollable).first);

      expect(find.descendant(of: find.byKey(const Key('addHabitStyleSetting')), matching: find.text('Story')),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('addHabitStyleSetting')));
      await tester.pumpAndSettle();
      expect(find.text('Three quick steps'), findsOneWidget);
      expect(find.text('Write it as one sentence'), findsOneWidget);
      await tester.tap(find.byKey(const Key('addHabitStyle_builder')));
      await tester.pumpAndSettle();

      expect(get<SettingsProvider>().addHabitStyle, AddHabitStyle.builder);
      expect((await SharedPreferences.getInstance()).getString('addHabitStyle'), 'builder');
      expect(find.descendant(of: find.byKey(const Key('addHabitStyleSetting')), matching: find.text('Builder')),
          findsOneWidget);
    });

    testWidgets('under System, "In light mode" picks Light or Sepia', (tester) async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
          ChangeNotifierProvider<HabitProvider>.value(value: get<HabitProvider>()),
          ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
          ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byKey(const Key('dayThemeSetting')), matching: find.text('Sepia')),
          findsOneWidget, reason: 'Sepia by default');
      await tester.tap(find.byKey(const Key('dayThemeSetting')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dayTheme_dark')), findsNothing);
      await tester.tap(find.byKey(const Key('dayTheme_light')));
      await tester.pumpAndSettle();

      expect(get<ThemeProvider>().dayTheme, AppTheme.light);
      expect((await SharedPreferences.getInstance()).getString('dayTheme'), 'light');
      expect(find.descendant(of: find.byKey(const Key('dayThemeSetting')), matching: find.text('Light')),
          findsOneWidget);
    });
  });

  group('adaptive controls', () {
    Future<BuildContext> pumpOn(WidgetTester tester, TargetPlatform platform) async {
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: platform),
        home: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }),
      ));
      return context;
    }

    testWidgets('confirmations are iOS alerts on iPhone', (tester) async {
      final context = await pumpOn(tester, TargetPlatform.iOS);
      final result = confirmAdaptive(context,
          title: 'Delete?', confirmLabel: 'Delete', destructive: true, confirmKey: const Key('yes'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('yes')));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('confirmations are Material dialogs on Android', (tester) async {
      final context = await pumpOn(tester, TargetPlatform.android);
      final result = confirmAdaptive(context, title: 'Delete?', confirmLabel: 'Delete', confirmKey: const Key('yes'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      // AlertDialog.adaptive builds a private AlertDialog subclass
      expect(find.byWidgetPredicate((w) => w is AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('choices are an action sheet on iPhone', (tester) async {
      const options = [AdaptiveOption(1, 'One'), AdaptiveOption(2, 'Two', key: Key('two'))];

      final context = await pumpOn(tester, TargetPlatform.iOS);
      final choice = chooseAdaptive<int>(context, title: 'Pick', options: options, selected: 1);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.byKey(const Key('two')));
      await tester.pumpAndSettle();
      expect(await choice, 2);
    });

    testWidgets('choices are a dialog on Android', (tester) async {
      const options = [AdaptiveOption(1, 'One'), AdaptiveOption(2, 'Two', key: Key('two'))];
      final context = await pumpOn(tester, TargetPlatform.android);
      final choice = chooseAdaptive<int>(context, title: 'Pick', options: options);
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('two')));
      await tester.pumpAndSettle();
      expect(await choice, 2);
    });

    testWidgets('time is picked with the iOS wheel on iPhone', (tester) async {
      final context = await pumpOn(tester, TargetPlatform.iOS);
      final picked = pickTimeAdaptive(context, initial: const TimeOfDay(hour: 9, minute: 30));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await tester.tap(find.byKey(const Key('pickerDone')));
      await tester.pumpAndSettle();
      expect(await picked, const TimeOfDay(hour: 9, minute: 30));
    });
  });

  group('haptics', () {
    late List<String> haptics;

    setUp(() {
      haptics = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('adding one taps lightly; completing a habit taps harder, finishing the day hardest; filters click', (tester) async {
      final id = await addWater();
      await tester.pumpWidget(const MomentumApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('incrementHabit_$id')));
      await tester.pumpAndSettle();
      expect(haptics.last, 'HapticFeedbackType.lightImpact');

      await tester.tap(find.byKey(Key('incrementHabit_$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('incrementHabit_$id')));
      await tester.pumpAndSettle();
      // Completing it taps harder; as the day's only habit, the day is all
      // done too, the firmest of all
      expect(haptics.sublist(haptics.length - 2), ['HapticFeedbackType.mediumImpact', 'HapticFeedbackType.heavyImpact']);

      await tester.tap(find.byKey(const Key('categoryRing_body')));
      await tester.pumpAndSettle();
      expect(haptics.last, 'HapticFeedbackType.selectionClick');
    });
  });
}
