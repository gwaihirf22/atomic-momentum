import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/screens/notification_tester_screen.dart';

import '../helpers/fake_notifications_plugin.dart';

void main() {
  late HabitProvider habitProvider;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habitProvider = get<HabitProvider>();
  });

  tearDown(() async {
    NotificationService.debugReset();
    await resetDependencies();
  });

  Future<void> pumpTester(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider<HabitProvider>.value(
      value: habitProvider,
      child: const MaterialApp(home: NotificationTesterScreen()),
    ));
    await tester.pumpAndSettle();
  }

  String status(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('testerStatus'))).data!;

  testWidgets('explains that notifications are unavailable when the plugin is not ready', (tester) async {
    await pumpTester(tester);

    expect(find.byKey(const Key('notificationsUnsupported')), findsOneWidget);
    expect(find.text('Not available here'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(const Key('sendNow'))).enabled, isFalse);
  });

  group('with a working plugin', () {
    late FakeNotificationsPlugin plugin;

    setUp(() {
      plugin = FakeNotificationsPlugin();
      NotificationService.debugOverride(plugin: plugin);
    });

    testWidgets('Send now shows a notification immediately', (tester) async {
      await pumpTester(tester);
      expect(find.byKey(const Key('notificationsUnsupported')), findsNothing);

      await tester.tap(find.byKey(const Key('sendNow')));
      await tester.pumpAndSettle();

      expect(plugin.shown.single.title, 'Test notification');
      expect(status(tester), contains('Sent'));
    });

    testWidgets('Send in 10 seconds schedules it and lists it as pending', (tester) async {
      await pumpTester(tester);
      final before = DateTime.now();

      await tester.tap(find.byKey(const Key('sendLater')));
      await tester.pumpAndSettle();

      final scheduled = plugin.scheduled[NotificationService.scheduledTestNotificationId]!;
      final delay = scheduled.at.difference(before);
      expect(delay.inSeconds, inInclusiveRange(9, 11));
      expect(status(tester), contains('Scheduled for'));
      expect(find.text('Scheduled (1)'), findsOneWidget);
      expect(find.text('Scheduled test'), findsOneWidget);
    });

    testWidgets('previews the streak warning for a habit with a streak', (tester) async {
      await tester.runAsync(habitProvider.addSampleHabits);
      await pumpTester(tester);

      await tester.tap(find.byKey(const Key('previewStreakWarning')));
      await tester.pumpAndSettle();

      final warning = plugin.shown.single;
      expect(warning.title, startsWith("Don't miss twice: "));
      expect(warning.body, contains('day streak'));
      expect(status(tester), contains('Sent a streak warning'));
    });

    testWidgets('sends an example warning when no habit has a streak yet', (tester) async {
      await pumpTester(tester);

      await tester.tap(find.byKey(const Key('previewStreakWarning')));
      await tester.pumpAndSettle();

      final warning = plugin.shown.single;
      expect(warning.title, "Don't miss twice: Example habit");
      expect(warning.body, 'Complete "Example habit" before midnight tonight to keep your 2 day streak.');
      expect(status(tester), contains('example streak warning'));
    });

    testWidgets('the tap test schedules a notification that opens the habit picked', (tester) async {
      await tester.runAsync(habitProvider.addSampleHabits);
      await pumpTester(tester);
      final habit = habitProvider.habits.first;

      await tester.tap(find.byKey(const Key('sendHabitTapTest')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('tapTestHabit_${habit.id}')));
      await tester.pumpAndSettle();

      final scheduled = plugin.scheduled[NotificationService.habitTapTestNotificationId]!;
      expect(scheduled.title, 'Tap to open ${habit.name}');
      // Tapping it is handled like a streak warning: opens this habit
      expect(NotificationService.habitIdFromPayload(scheduled.payload), habit.id);
      expect(status(tester), contains('Habits should open at "${habit.name}"'));
    });

    testWidgets('the tap test asks for a habit first when there are none', (tester) async {
      await pumpTester(tester);
      await tester.tap(find.byKey(const Key('sendHabitTapTest')));
      await tester.pumpAndSettle();
      expect(plugin.scheduled, isEmpty);
      expect(status(tester), contains('Add a habit first'));
    });

    testWidgets("a real habit's streak preview opens that habit when tapped", (tester) async {
      await tester.runAsync(habitProvider.addSampleHabits);
      await pumpTester(tester);
      await tester.tap(find.byKey(const Key('previewStreakWarning')));
      await tester.pumpAndSettle();

      final payload = plugin.shown.single.payload;
      expect(habitProvider.habits.map((h) => h.id), contains(NotificationService.habitIdFromPayload(payload)));
    });

    testWidgets('the streak preview does not reuse the Send now id', (tester) async {
      await pumpTester(tester);

      await tester.tap(find.byKey(const Key('sendNow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('previewStreakWarning')));
      await tester.pumpAndSettle();

      expect(plugin.shown.map((n) => n.id).toSet(), hasLength(2));
      expect(plugin.shown.last.id, NotificationService.streakPreviewNotificationId);
    });
  });
}
