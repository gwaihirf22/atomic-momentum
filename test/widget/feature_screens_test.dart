import 'package:clock/clock.dart';
import 'dart:ui' show SemanticsFlag;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/manage_categories_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/add_habit_screen.dart';
import 'package:atomic_momentum/screens/calendar_screen.dart';
import 'package:atomic_momentum/screens/settings_screen.dart';
import 'package:atomic_momentum/presentation/widgets/category_icons.dart';
import 'package:atomic_momentum/presentation/widgets/color_picker.dart';
import 'package:atomic_momentum/presentation/widgets/selectable_swatch.dart';
import 'package:atomic_momentum/domain/entities/reminder_settings.dart';

void main() {
  late HabitProvider habitProvider;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habitProvider = get<HabitProvider>();
  });

  tearDown(() async {
    await resetDependencies();
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    // Tall surface so whole forms render without scrolling
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
        ChangeNotifierProvider<HabitProvider>.value(value: habitProvider),
        ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
        ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
      ],
      child: MaterialApp(home: screen),
    ));
    await tester.pumpAndSettle();
  }

  const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  group('Add habit: reset day', () {
    Future<void> chooseFrequency(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(Key('frequency_${label.toLowerCase()}')));
      await tester.pumpAndSettle();
    }

    testWidgets('is hidden for daily habits and defaults to today for weekly', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());

      expect(find.byKey(const Key('changeStartDate')), findsNothing);
      expect(find.text('Resets every day'), findsOneWidget);

      await chooseFrequency(tester, 'Weekly');

      final todayName = weekdays[DateTime.now().weekday - 1];
      expect(find.text('Resets every $todayName'), findsOneWidget);
    });

    testWidgets('can be changed with the pop-out calendar and is saved', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());
      await chooseFrequency(tester, 'Monthly');

      await tester.tap(find.byKey(const Key('changeStartDate')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Pick a day in the month the picker opens on, then confirm
      final pickDay = DateTime.now().day == 10 ? 11 : 10;
      await tester.tap(find.text('$pickDay'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Resets on the ${pickDay}th of each month'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Budget review');
      await tester.enterText(find.byType(TextFormField).at(1), '1');
      await tester.tap(find.text('Add Habit'));
      await tester.pumpAndSettle();

      final saved = habitProvider.habits.single;
      expect(saved.resetFrequency, ResetFrequency.monthly);
      expect(saved.resetAnchor.day, pickDay);
    });

    Future<void> fillNameAndTarget(WidgetTester tester, String name, String target) async {
      await tester.enterText(find.byType(TextFormField).at(0), name);
      await tester.enterText(find.byType(TextFormField).at(1), target);
    }

    testWidgets('every 2 days: stepper, start date and summary are saved', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());
      expect(find.text('per day'), findsOneWidget);

      await tester.tap(find.byKey(const Key('intervalPlus')));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsWidgets);
      expect(find.textContaining('Resets every 2 days, starting'), findsOneWidget);
      expect(find.text('per 2 days'), findsOneWidget);
      expect(find.byKey(const Key('changeStartDate')), findsOneWidget);
      // Weekday chips only apply to every-day habits
      expect(find.byKey(const Key('scheduleDay_1')), findsNothing);

      await fillNameAndTarget(tester, 'Run', '1');
      await tester.tap(find.text('Add Habit'));
      await tester.pumpAndSettle();

      final saved = habitProvider.habits.single;
      expect(saved.resetFrequency, ResetFrequency.daily);
      expect(saved.resetInterval, 2);
      expect(saved.scheduledWeekdays, isNull);
    });

    testWidgets('specific weekdays are saved, and smart reminders follow them', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());

      // Keep Mon, Wed, Fri: turn off Tue, Thu, Sat, Sun
      for (final day in [2, 4, 6, 7]) {
        await tester.tap(find.byKey(Key('scheduleDay_$day')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Due Mon, Wed, Fri; other days are rest days'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('reminderSummary'))).data,
          startsWith('On each due day (Mon, Wed, Fri)'));

      await fillNameAndTarget(tester, 'Gym', '1');
      await tester.tap(find.text('Add Habit'));
      await tester.pumpAndSettle();

      final saved = habitProvider.habits.single;
      expect(saved.scheduledWeekdays, [1, 3, 5]);
      expect(saved.reminder!.enabled, isTrue);
      expect(saved.reminder!.mode, ReminderMode.smart);
    });

    testWidgets('new habits remind by default, at the time set in Settings, in Smart mode', (tester) async {
      await tester.runAsync(() => get<SettingsProvider>().setDefaultReminderTime(const TimeOfDay(hour: 19, minute: 15)));
      await pumpScreen(tester, const AddHabitScreen());

      expect(tester.widget<SwitchListTile>(find.byKey(const Key('reminderSwitch'))).value, isTrue);
      expect(find.textContaining('7:15 PM'), findsOneWidget);
      expect(find.byKey(const Key('reminderSummary')), findsOneWidget);

      await fillNameAndTarget(tester, 'Walk', '1');
      await tester.tap(find.text('Add Habit'));
      await tester.pumpAndSettle();

      final reminder = habitProvider.habits.single.reminder!;
      expect(reminder.time, const TimeOfDay(hour: 19, minute: 15));
      expect(reminder.mode, ReminderMode.smart);
    });

    testWidgets('the smart summary follows the schedule', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());
      await chooseFrequency(tester, 'Weekly');
      expect(tester.widget<Text>(find.byKey(const Key('reminderSummary'))).data,
          startsWith("3 days and 1 day before it's due ("));
    });

    testWidgets('Custom days shows weekday chips and saves the chosen days', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());
      await tester.tap(find.text('Custom days'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reminderSummary')), findsNothing);

      for (final day in [2, 3, 4, 5, 6, 7]) {
        await tester.tap(find.byKey(Key('reminderDay_$day')));
        await tester.pumpAndSettle();
      }
      await fillNameAndTarget(tester, 'Swim', '1');
      await tester.tap(find.text('Add Habit'));
      await tester.pumpAndSettle();

      final reminder = habitProvider.habits.single.reminder!;
      expect(reminder.mode, ReminderMode.custom);
      expect(reminder.daysOfWeek, [1]);
    });

    testWidgets('a habit with custom reminder days opens in Custom mode', (tester) async {
      await habitProvider.createHabit(const CreateHabitParams(
        name: 'Yoga',
        target: 1,
        color: HabitColor.purple,
        categoryId: BuiltInCategoryIds.body,
        reminder: ReminderSettings(time: TimeOfDay(hour: 6, minute: 0), enabled: true, daysOfWeek: [2, 4]),
      ));
      await pumpScreen(tester, AddHabitScreen(editHabit: habitProvider.habits.single));

      expect(find.byKey(const Key('reminderSummary')), findsNothing);
      expect(find.byKey(const Key('reminderDay_2')), findsOneWidget);
    });

    testWidgets('the last weekday cannot be turned off', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());
      for (final day in [1, 2, 3, 4, 5, 6, 7]) {
        await tester.tap(find.byKey(Key('scheduleDay_$day')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Due Sun; other days are rest days'), findsOneWidget);
    });

    testWidgets('a weekly target reads as "per week"', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());
      await chooseFrequency(tester, 'Weekly');
      expect(find.text('per week'), findsOneWidget);
    });
  });

  testWidgets('Add habit category chips use the flat category icons, not emoji', (tester) async {
    await pumpScreen(tester, const AddHabitScreen());
    for (final c in get<CategoryProvider>().categories) {
      expect(find.descendant(of: find.byKey(Key('categoryChip_${c.id}')), matching: find.byIcon(c.icon)),
          findsOneWidget);
    }
    for (final emoji in ['💪', '🙏', '🧠', '👥', '💼', '🎨']) {
      expect(find.text(emoji), findsNothing);
    }
  });

  group('Add habit: pinned save button', () {
    Future<void> pumpPhone(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
          ChangeNotifierProvider<HabitProvider>.value(value: habitProvider),
          ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
          ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
        ],
        child: MaterialApp(home: screen),
      ));
      await tester.pumpAndSettle();
    }

    final button = find.byKey(const Key('saveHabitButton'));

    testWidgets('stays at the bottom of the screen while the form scrolls', (tester) async {
      await pumpPhone(tester, const AddHabitScreen());

      expect(button.hitTestable(), findsOneWidget, reason: 'reachable without scrolling');
      final atTop = tester.getRect(button);
      expect(atTop.bottom, greaterThan(844 - 40));
      expect(atTop.height, greaterThanOrEqualTo(44));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.getRect(button), atTop);
      expect(find.text('Add Habit'), findsOneWidget);
    });

    testWidgets('rides above the keyboard', (tester) async {
      await pumpPhone(tester, const AddHabitScreen());
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.getRect(button).bottom, lessThanOrEqualTo(844 - 300));
      expect(button.hitTestable(), findsOneWidget);
    });

    testWidgets('reads Save Changes when editing', (tester) async {
      await habitProvider.createHabit(const CreateHabitParams(
        name: 'Read',
        target: 1,
        color: HabitColor.teal,
        categoryId: BuiltInCategoryIds.mind,
      ));
      await pumpPhone(tester, AddHabitScreen(editHabit: habitProvider.habits.single));

      expect(find.descendant(of: button, matching: find.text('Save Changes')), findsOneWidget);
    });
  });

  group('Add habit: categories', () {
    bool chipSelected(WidgetTester tester, String key) =>
        tester.widget<FilterChip>(find.byKey(Key('categoryChip_$key'))).selected;

    testWidgets('a new habit starts in the first category; Uncategorized is not offered', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());

      expect(chipSelected(tester, BuiltInCategoryIds.body), isTrue);
      expect(find.byKey(const Key('categoryChip_uncategorized')), findsNothing);
    });

    testWidgets('Manage opens Categories; the form is kept and a new category is selected', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());
      await tester.enterText(find.byType(TextFormField).at(0), 'Pottery class');
      expect(find.text('Manage Categories'), findsOneWidget);

      await tester.tap(find.byKey(const Key('manageCategories')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addCategory')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('categoryNameField')), 'Crafts');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveCategory')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      final crafts = get<CategoryProvider>().categories.last;
      expect(crafts.name, 'Crafts');
      expect(find.text('Pottery class'), findsOneWidget);
      expect(chipSelected(tester, crafts.id), isTrue);
    });

    testWidgets('if the selected category is deleted there, the first category is selected', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());
      expect(chipSelected(tester, BuiltInCategoryIds.body), isTrue);

      await tester.tap(find.byKey(const Key('manageCategories')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byKey(const Key('categoryRow_body')),
        matching: find.byType(ListTile),
      ).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deleteCategory')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDeleteCategory')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('categoryChip_body')), findsNothing);
      expect(chipSelected(tester, BuiltInCategoryIds.spirit), isTrue);
    });

    testWidgets('editing an uncategorized habit keeps its category unless another is picked', (tester) async {
      await habitProvider.createHabit(const CreateHabitParams(
        name: 'Pottery',
        target: 1,
        color: HabitColor.pink,
        categoryId: 'hobbies',
      ));
      final habit = habitProvider.habits.single;

      await pumpScreen(tester, AddHabitScreen(editHabit: habit));
      expect(chipSelected(tester, 'uncategorized'), isTrue);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(habitProvider.habits.single.categoryId, 'hobbies');

      // Saving popped the only route; start a fresh app for the second edit
      await tester.pumpWidget(const SizedBox());
      await pumpScreen(tester, AddHabitScreen(editHabit: habitProvider.habits.single));
      await tester.tap(find.byKey(const Key('categoryChip_mind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(habitProvider.habits.single.categoryId, BuiltInCategoryIds.mind);
    });
  });

  testWidgets('Calendar shows renamed categories in its rings and filter header', (tester) async {
    await tester.runAsync(() async {
      final body = get<CategoryProvider>().categories.first;
      await get<ManageCategoriesUseCase>().update(body.copyWith(name: 'Fitness'));
      await get<CategoryProvider>().load();
    });
    await habitProvider.createHabit(const CreateHabitParams(
      name: 'Run',
      target: 1,
      color: HabitColor.orange,
      categoryId: BuiltInCategoryIds.body,
    ));

    await pumpScreen(tester, const CalendarScreen());

    expect(find.descendant(of: find.byKey(const Key('categoryRing_body')), matching: find.text('Fitness')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('categoryRing_body')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('filterHeaderLabel'))).data, startsWith('Fitness'));
  });

  group('Add habit: Apple HIG layout', () {
    testWidgets('color and icon swatches are at least 44pt tap targets', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());

      for (final key in [const Key('colorSwatch_Blue'), const Key('iconSwatch_water')]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
        expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
      }
    });

    testWidgets('the color picker is one row of 44pt swatches ending in More, at phone width', (tester) async {
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: get<ThemeProvider>()),
          ChangeNotifierProvider<HabitProvider>.value(value: habitProvider),
          ChangeNotifierProvider<CategoryProvider>.value(value: get<CategoryProvider>()),
          ChangeNotifierProvider<SettingsProvider>.value(value: get<SettingsProvider>()),
        ],
        child: const MaterialApp(home: AddHabitScreen()),
      ));
      await tester.pumpAndSettle();

      final picker = find.byType(CompactColorPicker);
      final swatches = find.descendant(of: picker, matching: find.byType(SelectableSwatch));
      final rects = [for (final e in swatches.evaluate()) tester.getRect(find.byWidget(e.widget))];

      expect(rects.length, greaterThanOrEqualTo(4));
      expect(rects.map((r) => r.top).toSet(), hasLength(1), reason: 'a single row');
      expect(rects.last.right, lessThanOrEqualTo(390 - 16));
      for (final r in rects) {
        expect(r.width, greaterThanOrEqualTo(44));
      }
      expect(find.byKey(const Key('colorSwatch_More')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swatches are labelled for VoiceOver and selectable', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());

      expect(find.bySemanticsLabel('Green color'), findsOneWidget);
      expect(find.bySemanticsLabel('No icon'), findsOneWidget);

      await tester.tap(find.byKey(const Key('colorSwatch_Green')));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.byKey(const Key('colorSwatch_Green'))).hasFlag(SemanticsFlag.isSelected),
          isTrue);
    });
  });

  group('Calendar: editing a day', () {
    testWidgets('adding to the selected day updates history and streak', (tester) async {
      await habitProvider.createHabit(const CreateHabitParams(
        name: 'Journal',
        target: 1,
        color: HabitColor.indigo,
        categoryId: BuiltInCategoryIds.mind,
      ));
      final id = habitProvider.habits.single.id;

      await pumpScreen(tester, const CalendarScreen());

      expect(find.text('0/1'), findsOneWidget);
      await tester.tap(find.byKey(Key('incrementDay_$id')));
      await tester.pumpAndSettle();

      final habit = habitProvider.getHabitById(id)!;
      expect(habit.progress, 1);
      expect(habit.streak.current, 1);
      expect(find.text('1/1'), findsOneWidget);

      await tester.tap(find.byKey(Key('decrementDay_$id')));
      await tester.pumpAndSettle();
      expect(habitProvider.getHabitById(id)!.streak.current, 0);
    });
  });

  testWidgets('Calendar hides a habit on its rest days', (tester) async {
    final tomorrowWeekday = DateTime.now().weekday % 7 + 1;
    await habitProvider.createHabit(CreateHabitParams(
      name: 'Pottery',
      target: 1,
      color: HabitColor.pink,
      categoryId: BuiltInCategoryIds.creative,
      scheduledWeekdays: [tomorrowWeekday],
    ));
    final id = habitProvider.habits.single.id;

    // Today (selected by default) is a rest day for it
    await pumpScreen(tester, const CalendarScreen());
    expect(find.byKey(Key('dayHabit_$id')), findsNothing);
  });

  testWidgets('Calendar rows show the habit icon, with a check badge once completed', (tester) async {
    await habitProvider.createHabit(const CreateHabitParams(
      name: 'Water',
      target: 1,
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      icon: 'water',
    ));
    final id = habitProvider.habits.single.id;
    await pumpScreen(tester, const CalendarScreen());

    Finder inIcon(Finder f) => find.descendant(of: find.byKey(Key('dayHabitIcon_$id')), matching: f);
    expect(inIcon(find.byIcon(Icons.local_drink)), findsOneWidget);
    expect(inIcon(find.byKey(const Key('completedBadge'))), findsNothing);

    await tester.tap(find.byKey(Key('incrementDay_$id')));
    await tester.pumpAndSettle();
    // Done: the ring fills and shows a check, as on the habit cards
    expect(inIcon(find.byKey(const Key('completedBadge'))), findsOneWidget);
    expect(inIcon(find.byIcon(Icons.local_drink)), findsNothing);
  });

  testWidgets('editing a habit and choosing No icon removes its icon', (tester) async {
    await habitProvider.createHabit(const CreateHabitParams(
      name: 'Water',
      target: 1,
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      icon: 'water',
    ));
    await pumpScreen(tester, AddHabitScreen(editHabit: habitProvider.habits.single));

    await tester.tap(find.byKey(const Key('iconSwatch_none')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(habitProvider.habits.single.metadata.icon, isNull);
  });

  group('week start', () {
    double left(WidgetTester tester, Finder f) => tester.getTopLeft(f.first).dx;

    testWidgets('the Calendar starts on Sunday in the US, or on the chosen day', (tester) async {
      await pumpScreen(tester, const CalendarScreen());
      expect(left(tester, find.text('Sun')), lessThan(left(tester, find.text('Mon'))));

      await tester.runAsync(() => get<SettingsProvider>().setWeekStart(DateTime.monday));
      await tester.pumpAndSettle();
      expect(left(tester, find.text('Mon')), lessThan(left(tester, find.text('Sun'))));
    });

    testWidgets('Add Habit weekday chips follow the week start', (tester) async {
      await pumpScreen(tester, const AddHabitScreen());

      final sunday = tester.getRect(find.byKey(const Key('scheduleDay_7')));
      final monday = tester.getRect(find.byKey(const Key('scheduleDay_1')));
      expect(sunday.top, monday.top);
      expect(sunday.left, lessThan(monday.left));
    });

    testWidgets('Settings offers Start week on, defaulting to the region', (tester) async {
      await pumpScreen(tester, const SettingsScreen());
      expect(find.text('Automatic (Sunday)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('weekStartSetting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('weekStart_${DateTime.monday}')));
      await tester.pumpAndSettle();

      expect(get<SettingsProvider>().weekStartOverride, DateTime.monday);
      expect(get<SettingsProvider>().firstDayOfWeek, DateTime.monday);
    });
  });

  group('Calendar: editing a past day', () {
    testWidgets('+ counts up each tap, completes the day, and − undoes it', (tester) async {
      // Added last month, so the past day is one it was tracked on
      final added = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
      await withClock(
        Clock.fixed(added),
        () => habitProvider.createHabit(const CreateHabitParams(
          name: 'Stretch',
          target: 3,
          color: HabitColor.teal,
          categoryId: BuiltInCategoryIds.body,
        )),
      );
      final id = habitProvider.habits.single.id;

      await pumpScreen(tester, const CalendarScreen());

      // A past day that's visible: the 2nd of this month, or the 15th of last
      // month early in the month
      final now = DateTime.now();
      final DateTime pastDay;
      if (now.day >= 3) {
        pastDay = DateTime(now.year, now.month, 2);
      } else {
        await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
        await tester.pumpAndSettle();
        pastDay = DateTime(now.year, now.month - 1, 15);
      }
      await tester.tap(find.text('${pastDay.day}'));
      await tester.pumpAndSettle();

      Finder checkInCard() => find.descendant(
            of: find.byKey(Key('dayHabit_$id')),
            matching: find.byIcon(Icons.check),
          );

      for (var expected = 1; expected <= 3; expected++) {
        await tester.tap(find.byKey(Key('incrementDay_$id')));
        await tester.pumpAndSettle();
        expect(find.text('$expected/3'), findsOneWidget);
      }
      expect(habitProvider.getHabitById(id)!.history[pastDay], 3);
      expect(checkInCard(), findsOneWidget);

      await tester.tap(find.byKey(Key('decrementDay_$id')));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      expect(checkInCard(), findsNothing);
      expect(habitProvider.getHabitById(id)!.wasCompletedOnDate(pastDay), isFalse);
    });
  });

  group('Sample habits', () {
    testWidgets('Settings adds one habit per category, once', (tester) async {
      await pumpScreen(tester, const SettingsScreen());

      await tester.scrollUntilVisible(find.byKey(const Key('addSampleHabits')), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('addSampleHabits')));
      await tester.pumpAndSettle();
      expect(find.text('Added 6 sample habits'), findsOneWidget);

      final categories = habitProvider.habits.map((h) => h.categoryId).toSet();
      expect(categories, BuiltInCategoryIds.all.toSet());

      await tester.tap(find.byKey(const Key('addSampleHabits')));
      await tester.pumpAndSettle();
      expect(find.text('Sample habits are already added'), findsOneWidget);
      expect(habitProvider.habits, hasLength(6));
    });
  });

  group('Settings: streak warnings', () {
    testWidgets('shows the default and persists changes', (tester) async {
      await pumpScreen(tester, const SettingsScreen());

      expect(find.text('Streak warnings'), findsOneWidget);
      expect(find.text('4 hours before'), findsOneWidget);

      await tester.tap(find.byKey(const Key('streakWarningLeadTime')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 day before').last);
      await tester.pumpAndSettle();

      expect(get<SettingsProvider>().streakWarnings.leadTime, const Duration(hours: 24));

      await tester.tap(find.byKey(const Key('streakWarningsSwitch')));
      await tester.pumpAndSettle();
      expect(get<SettingsProvider>().streakWarnings.enabled, isFalse);
    });

    testWidgets('"remind before a first miss" is off by default, and only works with warnings on',
        (tester) async {
      await pumpScreen(tester, const SettingsScreen());
      final firstMiss = find.byKey(const Key('streakWarningFirstMissSwitch'));
      await tester.scrollUntilVisible(firstMiss, 200, scrollable: find.byType(Scrollable).first);

      expect(tester.widget<SwitchListTile>(firstMiss).value, isFalse);
      await tester.tap(firstMiss);
      await tester.pumpAndSettle();
      expect(get<SettingsProvider>().streakWarnings.remindBeforeFirstMiss, isTrue);

      await get<SettingsProvider>().setStreakWarningsEnabled(false);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(firstMiss).onChanged, isNull);
    });
  });
}
