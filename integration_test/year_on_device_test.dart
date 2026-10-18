import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/dev/year_persona.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/reminder_service.dart';
import 'package:atomic_momentum/domain/services/reminder_planner.dart';
import 'package:atomic_momentum/domain/services/streak_warning_planner.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/widgets/break_wording.dart';
import 'package:atomic_momentum/screens/ios_main_navigation.dart';

import '../test/helpers/fake_sharer.dart';
import '../test/simulation/year/persona_driver.dart';
import '../test/simulation/year/reference.dart';

/// The persona's year on a real simulator or emulator: the real app on
/// screen, real fonts and rendering, and the real notification center
/// holding what the app schedules. The clock is simulated (set around the
/// whole test, so frames and timers read it too) and storage is in memory,
/// so the person's own habits on the device are never read or written.
///
/// Every day is lived through the app's providers; about one day a week the
/// persona's taps go through the Habits cards instead (+, 2 min, holding a
/// ring and Undo). After every visit the cards' streaks and the momentum
/// ring are checked against the [Reference]; at each month's end every
/// screen is visited, its numbers checked, and a screenshot saved
/// (build/year_screens/<device>/). At the end, the device's pending
/// notifications must be exactly what the app planned (on iOS, within 64).
///
/// Run with tool/device_year_check.sh "<simulator or emulator>", which puts
/// the real app back afterwards. `--dart-define=YEAR_DAYS=92` lives fewer
/// days (the Android emulator is slow).
void main() {
  // The year starts tomorrow, so nothing it schedules can fire during the run
  // (the clock guard only covers lib/)
  final real = DateTime.now();
  final persona = YearPersona(DateTime(real.year, real.month, real.day + 1));
  const days = int.fromEnvironment('YEAR_DAYS', defaultValue: YearPersona.length);
  var now = persona.date(0).add(const Duration(hours: 7));

  withClock(Clock(() => now), () {
    final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    testWidgets('a year of the app on this device', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await initializeDependencies(seedDefaultHabit: false);
      // A clean slate: nothing left over from an earlier run (the real app
      // reschedules its own when the script puts it back)
      await FlutterLocalNotificationsPlugin().cancelAll();
      final sharer = FakeSharer.install();
      await tester.pumpWidget(const MomentumApp());
      await _settle(tester);
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();

      final context = tester.element(find.byType(IOSMainNavigation));
      final habits = Provider.of<HabitProvider>(context, listen: false);
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final quotes = Provider.of<QuoteProvider>(context, listen: false);
      final ref = Reference();
      final ids = <String, String>{};
      final problems = <String>[];
      void problem(DateTime at, String message) => problems.add('${at.toIso8601String().substring(0, 16)}  $message');

      final driver = PersonaDriver(
        habits: () => habits,
        settings: settings,
        quotes: quotes,
        ref: ref,
        create: (params) async {
          await habits.createHabit(params);
          ids[params.name] = habits.habits.firstWhere((h) => h.name == params.name).id;
        },
        id: (name) => ids[name] ?? (throw ArgumentError('No habit named $name')),
        problem: problem,
      );

      var celebrations = 0, shared = 0;

      /// Closes any achievement sheet the app put up (sharing one a month).
      Future<void> closeSheets() async {
        for (var i = 0; i < 5 && find.byKey(const Key('achievementSheet')).evaluate().isNotEmpty; i++) {
          celebrations++;
          if (shared < celebrations ~/ 6 + 1 && find.byKey(const Key('achievementShare')).evaluate().isNotEmpty) {
            await tester.tap(find.byKey(const Key('achievementShare')));
            await _settle(tester);
            final share = find.text('Share…');
            if (share.evaluate().isNotEmpty) {
              await tester.tap(share);
              await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
              await _settle(tester);
              shared++;
            }
          }
          if (find.byKey(const Key('achievementDone')).evaluate().isNotEmpty) {
            await tester.tap(find.byKey(const Key('achievementDone')));
          } else {
            Navigator.of(tester.element(find.byKey(const Key('achievementSheet')))).pop();
          }
          await _settle(tester);
        }
      }

      Future<void> showTab(String tab) async {
        // (Habits, once shown, becomes the Add button: never tapped twice)
        final key = find.byKey(Key('tab_$tab'));
        final onHabits = find.byKey(const Key('addHabitButton')).evaluate().isNotEmpty;
        if (key.evaluate().isNotEmpty && !(tab == 'habits' && onHabits)) {
          await tester.tap(key);
          await _settle(tester);
        }
        // Back to the tab's first page
        for (var i = 0; i < 4; i++) {
          final back = find.byType(BackButton).hitTestable().evaluate().isNotEmpty
              ? find.byType(BackButton).hitTestable()
              : find.byType(CupertinoNavigationBarBackButton).hitTestable();
          if (back.evaluate().isEmpty) break;
          await tester.tap(back.first);
          await _settle(tester);
        }
      }

      /// One of the persona's actions done with a tap on its card, if it's
      /// one a card can do; false to leave it to the provider.
      Future<bool> byTap(PersonaAction action, DateTime at) async {
        final name = action.habit;
        if (name == null || !ids.containsKey(name)) return false;
        final h = habits.getHabitById(ids[name]!)!;
        final r = ref.habits[name]!;
        switch (action) {
          case SetTotal(:final total) when h.target == 1 && total == 1 && h.progress == 0 && !h.isBreak:
            final plus = find.byKey(Key('incrementHabit_${h.id}'));
            if (plus.evaluate().isEmpty) return false;
            await tester.ensureVisible(plus);
            await tester.tap(plus);
            r.setTotal(at, 1);
          case TwoMinuteTap():
            final button = find.byKey(Key('twoMinute_${h.id}'));
            if (button.evaluate().isEmpty) return false;
            await tester.ensureVisible(button);
            await tester.tap(button);
            r.tap(at);
          case HoldToFinish(:final undo):
            final ring = find.byKey(Key('habitIcon_${h.id}'));
            if (ring.evaluate().isEmpty) return false;
            final before = r.periodDays(at);
            await tester.ensureVisible(ring);
            await tester.longPress(ring);
            await _settle(tester);
            if (h.isCompleted) {
              for (final d in before.keys) {
                r.setDay(d, 0);
              }
            } else {
              r.setTotal(at, h.target);
            }
            if (undo) {
              await tester.tap(find.byKey(Key('undoHold_${h.id}')));
              for (final entry in before.entries) {
                r.setDay(entry.key, entry.value);
              }
            }
          default:
            return false;
        }
        await _settle(tester);
        return true;
      }

      /// What the Habits screen shows, against the reference.
      void checkCards(DateTime at) {
        for (final r in ref.live) {
          if (!r.periodic) continue;
          final h = habits.getHabitById(ids[r.name]!)!;
          final s = r.streak(at);
          final badge = find.byKey(Key('habitStreak_${h.id}'));
          if (s.current == 0) {
            if (badge.evaluate().isNotEmpty) problem(at, '${r.name}: a streak badge with no streak');
            continue;
          }
          // The badge shows the count; the words are VoiceOver's
          final label = h.isBreak ? BreakWording.streak(h, s.current) : h.schedule.streakLabel(s.current);
          if (find.descendant(of: badge, matching: find.text('${s.current}')).evaluate().isEmpty) {
            problem(at, '${r.name}: the card should show a streak of ${s.current} ($label)');
          }
          final spoken = tester.widgetList<Semantics>(find.descendant(of: badge, matching: find.byType(Semantics)))
              .map((w) => w.properties.label ?? '')
              .where((l) => l.isNotEmpty);
          if (!spoken.any((l) => l.startsWith(label))) problem(at, '${r.name}: VoiceOver reads $spoken, not "$label"');
        }
        final overall = ref.overall(at);
        final ring = find.byKey(const Key('overallMomentum'));
        if (overall != null && ring.evaluate().isEmpty) {
          problem(at, 'no momentum ring on Habits');
        } else if (overall != null && find.descendant(of: ring, matching: find.text('${overall.round()}')).evaluate().isEmpty) {
          problem(at, 'the momentum ring should show ${overall.round()}');
        }
      }

      /// Scrolls the tab on screen back to its top (the large title and ring).
      Future<void> toTop() async {
        final list = find.byType(CustomScrollView).hitTestable();
        if (list.evaluate().isEmpty) return;
        await tester.fling(list.first, const Offset(0, 3000), 3000);
        await _settle(tester);
      }

      Future<void> screenshot(String name) async {
        await _settle(tester);
        await binding.takeScreenshot(name);
      }

      /// Opens what [target] leads to (centred first, clear of the tab bar),
      /// takes its picture and comes back.
      Future<void> visit(Finder target, String shot, DateTime at) async {
        if (target.evaluate().isEmpty) return;
        await Scrollable.ensureVisible(tester.element(target.first), alignment: 0.4);
        await _settle(tester);
        await tester.tap(target.first, warnIfMissed: false);
        await _settle(tester);
        final back = find.byType(BackButton).hitTestable().evaluate().isNotEmpty
            ? find.byType(BackButton).hitTestable()
            : find.byType(CupertinoNavigationBarBackButton).hitTestable();
        if (back.evaluate().isEmpty) {
          problem(at, '$shot: tapping did not open its page');
          return;
        }
        await screenshot(shot);
        await tester.tap(back.first);
        await _settle(tester);
      }

      /// The month's end: every screen, its numbers, a picture of each.
      Future<void> checkpoint(int month, DateTime at) async {
        final m = 'm${month.toString().padLeft(2, '0')}';
        await showTab('habits');
        await toTop();
        checkCards(at);
        await screenshot('${m}_habits');

        final water = ids[YearPersona.water];
        if (water != null) await visit(find.byKey(Key('habitCard_$water')), '${m}_habit_page', at);
        await toTop();

        await showTab('calendar');
        await screenshot('${m}_calendar');

        await showTab('insights');
        final longest = ref.live.map((r) {
          final s = r.streak(at);
          return s.longest > s.current ? s.longest : s.current;
        }).fold(0, (a, b) => a > b ? a : b);
        final stat = find.byKey(const Key('insightsLongestStreak'));
        if (stat.evaluate().isNotEmpty && find.descendant(of: stat, matching: find.text('$longest')).evaluate().isEmpty) {
          problem(at, 'Insights should show a longest streak of $longest');
        }
        await screenshot('${m}_insights');
        await visit(find.byKey(const Key('heatmapExpand')), '${m}_heatmap', at);
        await visit(find.byKey(const Key('insightsSeeAllAchievements')), '${m}_achievements', at);
        await toTop();

        if (settings.showInspireTab) {
          await showTab('inspire');
          await screenshot('${m}_inspire');
        }
        await showTab('settings');
        await screenshot('${m}_settings');
        await showTab('habits');
        await toTop();
      }

      var month = 0;
      for (final day in persona.days.take(days)) {
        for (var v = 0; v < day.visits.length; v++) {
          final visit = day.visits[v];
          now = visit.on(day.date);
          // Opening the app: back from the background
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await habits.resetHabitsIfNeeded();
          await _settle(tester);
          await closeSheets();
          final byCards = day.index % 7 == 3;
          if (byCards) await showTab('habits');
          for (final action in visit.actions) {
            if (byCards && await byTap(action, now)) continue;
            await driver.apply(action, now);
          }
          await _settle(tester);
          await closeSheets();
          checkCards(now);
        }
        final next = DateTime(day.date.year, day.date.month, day.date.day + 1);
        if (next.month != day.date.month && day.visits.isNotEmpty) await checkpoint(++month, now);
      }

      // What the device holds is what the app planned, once its syncs (not
      // awaited after taps) have finished: the app's own resync, awaited
      await habits.resyncStreakWarnings();
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      final pending = await FlutterLocalNotificationsPlugin().pendingNotificationRequests();
      final reminders = [
        for (final h in habits.habits) ...ReminderPlanner.plan(h, now: now, quiet: settings.quietHours),
      ]..sort((a, b) => a.at.compareTo(b.at));
      final plannedReminders = reminders.take(get<ReminderService>().roomFor(habits.habits)).toList();
      final plannedWarnings = [
        for (final h in habits.habits)
          ...StreakWarningPlanner.plan(h.refresh(now), settings.streakWarnings, now, quiet: settings.quietHours),
      ];
      final pendingReminders = pending.where((p) => (p.payload ?? '').startsWith('reminder|')).length;
      if (Platform.isIOS && pending.length > 64) problem(now, '${pending.length} pending: iOS keeps 64');
      if (pendingReminders != plannedReminders.length || pending.length - pendingReminders != plannedWarnings.length) {
        problem(now, 'pending: $pendingReminders reminders and ${pending.length - pendingReminders} warnings; '
            'the app planned ${plannedReminders.length} and ${plannedWarnings.length}. '
            'Pending: ${pending.map((p) => '${p.id}:${p.payload}').join(' ')}');
      }
      await FlutterLocalNotificationsPlugin().cancelAll();

      expect(problems, isEmpty, reason: '\n${problems.length} problems:\n${problems.take(60).join('\n')}');
      expect(sharer.shared, isNotEmpty, reason: 'an achievement was shared');
      for (final png in sharer.shared) {
        expect(pngSize(png.png), (1080, 1350));
      }
    }, timeout: const Timeout(Duration(minutes: 90)));
  });
}

/// Lets the app finish what it's doing (some screens animate for a while).
Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
  } on FlutterError {
    // Something keeps animating; what's on screen is good enough
  }
}
