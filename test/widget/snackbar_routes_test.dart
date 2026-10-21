import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/screens/habit_detail_screen.dart';
import 'package:atomic_momentum/screens/habit_editor_screen.dart';
import 'package:atomic_momentum/screens/home_screen.dart';

import '../helpers/fake_notifications_plugin.dart';

/// A SnackBar showing while something opens over the whole app (found by
/// the monkey test): Flutter shows it on every page of a tab, and two alike
/// stopped the editor's page from opening ("multiple heroes share the same
/// tag").
void main() {
  late String id;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    NotificationService.debugOverride(plugin: FakeNotificationsPlugin());
    await initializeDependencies(seedDefaultHabit: false);
    final habits = get<HabitProvider>();
    await habits.createHabit(
        const CreateHabitParams(name: 'Gym', target: 1, color: HabitColor.red, categoryId: BuiltInCategoryIds.body));
    id = habits.habits.single.id;
  });

  tearDown(() async {
    NotificationService.debugReset();
    await resetDependencies();
  });

  testWidgets("a SnackBar on a tab's pages doesn't stop the editor opening over them", (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();

    // Calendar visited (tabs stay alive), then back on Habits
    await tester.tap(find.byKey(const Key('tab_calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab_habits')));
    await tester.pumpAndSettle();
    // A SnackBar shows (as freezing shows one): on every tab's page alike
    final home = tester.element(find.byType(HomeScreen));
    ScaffoldMessenger.of(home).showSnackBar(const SnackBar(content: Text('Gym is frozen for today')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SnackBar, skipOffstage: false), findsAtLeastNWidgets(2));

    // The editor opens over the whole app
    await tester.tap(find.byKey(const Key('addHabitButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(HabitEditorScreen), findsOneWidget);
  });
}
