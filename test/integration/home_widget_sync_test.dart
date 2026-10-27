import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/home_widget_bridge.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/core/theme/app_palette.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/habit_goal.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/entities/two_minute_version.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/home_widgets/home_widget_sync.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/ios_main_navigation.dart';
import '../helpers/fake_home_widget_bridge.dart';

/// The home screen widgets end to end on the app's side: the snapshot they
/// draw, and taps on their + logged through the real provider and storage.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Sunday afternoon, Oct 18 2026
  final now = DateTime(2026, 10, 18, 15);
  final today = DateTime(2026, 10, 18);
  final yesterday = DateTime(2026, 10, 17);

  late FakeHomeWidgetBridge bridge;
  late HabitProvider habits;
  late HomeWidgetSync sync;

  HomeWidgetSync newSync() => HomeWidgetSync(
        bridge: bridge,
        habits: habits,
        settings: get<SettingsProvider>(),
        theme: get<ThemeProvider>(),
        quotes: get<QuoteProvider>(),
        categories: get<CategoryProvider>(),
      );

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies();
    bridge = FakeHomeWidgetBridge();
    habits = get<HabitProvider>();
    sync = newSync();
  });

  tearDown(() async {
    sync.dispose();
    await resetDependencies();
  });

  /// [body] at [now], with habits loaded and the sync running.
  Future<void> at(Future<void> Function() body) => withClock(Clock.fixed(now), () async {
        await habits.loadHabits();
        sync.start();
        await body();
      });

  Future<String> add(String name, {int target = 8, String units = '', HabitGoal goal = HabitGoal.build}) async {
    await habits.createHabit(CreateHabitParams(
      name: name,
      target: target,
      units: units,
      color: HabitColor.blue,
      categoryId: BuiltInCategoryIds.body,
      goal: goal,
    ));
    return habits.habits.firstWhere((h) => h.name == name).id;
  }

  test('nothing happens where there are no widgets', () async {
    bridge.isSupported = false;
    await at(() async {
      await add('Water');
      await sync.write();
    });
    expect(bridge.saved, isEmpty);
  });

  test('the snapshot is written after a change, and only when something changed', () async {
    await at(() async {
      await add('Water', units: 'glasses');
      await sync.write();
      expect(bridge.habit('Water')['text'], '0 of 8 glasses');
      final count = bridge.saved.length;

      await sync.write();
      expect(bridge.saved, hasLength(count), reason: 'nothing changed');

      await habits.updateHabitProgress(habits.habits.single.id, 3);
      await sync.write();
      expect(bridge.habit('Water')['progress'], 3);
    });
  });

  test('a change is written by itself, shortly after', () async {
    await at(() async {
      await add('Water');
      await Future<void>.delayed(HomeWidgetSync.delay * 2);
      expect(bridge.habit('Water')['target'], 8);
    });
  });

  test("a widget's + logs the next step today, as the card's + does", () async {
    await at(() async {
      final id = await add('Walk', target: 8000, units: 'steps');
      await habits.updateHabitProgress(id, 7450);

      final appliedBefore = bridge.appliedCount;
      bridge.tap(id, today, notify: false);
      await sync.applyLogs();

      expect(habits.getHabitById(id)!.progress, 8000);
      expect(habits.getHabitById(id)!.getProgressForDate(today), 8000);
      expect(bridge.habit('Walk')['done'], isTrue);
      expect(bridge.appliedCount, appliedBefore + 1, reason: 'the waiting widget is let go');
    });
  });

  test('a tap from before midnight counts for that day', () async {
    await at(() async {
      final id = await add('Read', target: 2);
      bridge.tap(id, yesterday, notify: false);
      await sync.applyLogs();

      final read = habits.getHabitById(id)!;
      expect(read.getProgressForDate(yesterday), 1);
      expect(read.getProgressForDate(today), 0);
    });
  });

  test('taps on a done habit, a habit being broken, or a deleted habit change nothing', () async {
    await at(() async {
      final done = await add('Water', target: 1);
      await habits.updateHabitProgress(done, 1);
      final smoking = await add('Smoking', target: 0, goal: HabitGoal.quit);

      bridge.tap(done, today, notify: false);
      bridge.tap(smoking, today, notify: false);
      bridge.tap('habit_gone', today, notify: false);
      await sync.applyLogs();

      expect(habits.getHabitById(done)!.progress, 1);
      expect(habits.getHabitById(smoking)!.progress, 0);
      expect(bridge.queue, isEmpty);
      expect(bridge.appliedCount, greaterThan(0));
    });
  });

  test("the watch's Crown sets today's amount, up to the target", () async {
    await at(() async {
      final id = await add('Water', units: 'glasses');
      bridge.tap(id, today, notify: false, kind: WidgetLogKind.set, amount: 5);
      await sync.applyLogs();
      expect(habits.getHabitById(id)!.progress, 5);

      bridge.tap(id, today, notify: false, kind: WidgetLogKind.set, amount: 3);
      await sync.applyLogs();
      expect(habits.getHabitById(id)!.progress, 3, reason: 'the Crown turns down too');

      bridge.tap(id, today, notify: false, kind: WidgetLogKind.set, amount: 40);
      await sync.applyLogs();
      expect(habits.getHabitById(id)!.progress, 8, reason: 'never past the target, as +');
      expect(bridge.habit('Water')['done'], isTrue);
    });
  });

  test("the Crown on a weekly habit before midnight changes that day's own amount", () async {
    await at(() async {
      await habits.createHabit(const CreateHabitParams(
        name: 'Run',
        target: 3,
        units: '',
        color: HabitColor.blue,
        categoryId: BuiltInCategoryIds.body,
        resetFrequency: ResetFrequency.weekly,
      ));
      final id = habits.habits.firstWhere((h) => h.name == 'Run').id;
      await habits.updateProgressForDate(id, DateTime(2026, 10, 16), 1);
      final total = habits.getHabitById(id)!.progressForPeriodContaining(yesterday);

      // The watch showed the week's total and set it one higher, yesterday
      bridge.tap(id, yesterday, notify: false, kind: WidgetLogKind.set, amount: total + 1);
      await sync.applyLogs();
      final run = habits.getHabitById(id)!;
      expect(run.getProgressForDate(yesterday), 1);
      expect(run.getProgressForDate(DateTime(2026, 10, 16)), 1, reason: 'other days are left as they were');
    });
  });

  test("the watch's 2 min keeps the day with the two-minute version", () async {
    await at(() async {
      await habits.createHabit(const CreateHabitParams(
        name: 'Read',
        target: 20,
        units: 'pages',
        color: HabitColor.blue,
        categoryId: BuiltInCategoryIds.body,
        twoMinute: TwoMinuteVersion(description: 'Read one page'),
      ));
      final id = habits.habits.firstWhere((h) => h.name == 'Read').id;
      final water = await add('Water');

      bridge.tap(id, today, notify: false, kind: WidgetLogKind.twoMinute);
      bridge.tap(water, today, notify: false, kind: WidgetLogKind.twoMinute);
      await sync.applyLogs();

      expect(habits.getHabitById(id)!.usedTwoMinuteButtonOn(today), isTrue);
      expect(bridge.habit('Read')['twoMinute'], {'can': true, 'done': true});
      expect(habits.getHabitById(water)!.twoMinuteDays, isEmpty, reason: 'Water has no two-minute version');
    });
  });

  test('the Crown and 2 min change nothing on a habit being broken', () async {
    await at(() async {
      final id = await add('Soda', target: 2, goal: HabitGoal.limit);
      bridge.tap(id, today, notify: false, kind: WidgetLogKind.set, amount: 1);
      bridge.tap(id, today, notify: false, kind: WidgetLogKind.twoMinute);
      await sync.applyLogs();
      expect(habits.getHabitById(id)!.progress, 0);
    });
  });

  test('a tap while the app is running is logged by itself', () async {
    await at(() async {
      final id = await add('Water');
      bridge.tap(id, today);
      bridge.tap(id, today);
      await pumpEventQueue();
      expect(habits.getHabitById(id)!.progress, 2, reason: 'the second tap, made while the first was applied, too');
      expect(bridge.habit('Water')['progress'], 2);
      expect(bridge.appliedCount, greaterThan(0));
    });
  });

  test('several taps are each logged, in order', () async {
    await at(() async {
      final id = await add('Water');
      bridge.tap(id, today, notify: false);
      bridge.tap(id, today, notify: false);
      bridge.tap(id, today, notify: false);
      await sync.applyLogs();
      expect(habits.getHabitById(id)!.progress, 3);
    });
  });

  test('taps made while the app was closed are logged once habits load', () async {
    await withClock(Clock.fixed(now), () async {
      await habits.loadHabits();
      final id = await add('Water');

      // A new launch: the tap is already queued
      habits = get<HabitProvider>();
      sync.dispose();
      sync = newSync();
      bridge.tap(id, today, notify: false);
      sync.start();
      expect(bridge.queue, hasLength(1), reason: 'not before habits have loaded');

      await habits.loadHabits();
      await pumpEventQueue();
      expect(habits.getHabitById(id)!.progress, 1);
      expect(bridge.queue, isEmpty);
    });
  });

  test("the widgets' looks follow Appearance", () async {
    await at(() async {
      final theme = get<ThemeProvider>();
      await theme.setAppearance(Appearance.system);
      await theme.setDayTheme(AppTheme.light);
      await sync.write();
      expect(bridge.last!['looks']['light']['theme'], 'light');
      expect(bridge.last!['looks']['dark']['theme'], 'dark');

      await theme.setAppearance(Appearance.sepia);
      await sync.write();
      expect(bridge.last!['looks']['light']['theme'], 'sepia');
      expect(bridge.last!['looks']['dark']['theme'], 'sepia', reason: 'a chosen look holds in dark mode too');
    });
  });

  test("tapping a habit's widget shows that habit, at launch or while running", () async {
    NotificationService.focusRequests.value = null;
    bridge.opened = 'habit/habit_a';
    await at(() async {
      await pumpEventQueue();
      expect(NotificationService.focusRequests.value?.habitId, 'habit_a');

      bridge.open('habit/habit_b');
      expect(NotificationService.focusRequests.value?.habitId, 'habit_b');
    });
    NotificationService.focusRequests.value = null;
  });

  test('tapping the quote or insights widgets opens their tab', () async {
    await at(() async {
      bridge.open('inspire');
      expect(IOSMainNavigation.tabRequests.value, AppTab.inspire);
      bridge.open('insights');
      expect(IOSMainNavigation.tabRequests.value, AppTab.insights);
      bridge.open('momentum');
      expect(IOSMainNavigation.tabRequests.value, AppTab.habits);
    });
    IOSMainNavigation.tabRequests.value = null;
  });

  test("the snapshot carries categories, each habit's quotes, and tomorrow's quote", () async {
    await at(() async {
      final id = await add('Run');
      await habits.addQuote(id, 'epictetus-walking-by-walking');
      await sync.write();
      expect(bridge.habit('Run')['category'], BuiltInCategoryIds.body);
      expect((bridge.habit('Run')['quotes'] as List).single['author'], 'Epictetus');
      expect((bridge.last!['categories'] as List).map((c) => c['id']), contains(BuiltInCategoryIds.body));
      expect(bridge.last!['quote'], isNotNull);
      expect(bridge.last!['quoteNext'], isNotNull);
      expect((bridge.last!['shortQuote']['text'] as String).length, lessThanOrEqualTo(90));
    });
  });
}
