import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/background/background_refresh.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/plus_store.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';

/// The engine iOS starts with the app closed (`backgroundMain`), woken by
/// the Apple Watch: it logs what the watch sent and writes the snapshot the
/// widgets and the watch draw, keeping Momentum Plus.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 18, 15);
  const widgets = MethodChannel('momentum/widgets');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<Object?> queued;
  late List<String> saved;
  bool? done;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await resetDependencies();
    SharedPreferences.setMockInitialValues({PlatformPlusStore.unlockedKey: '2026-10-17T10:00:00Z'});
    queued = [];
    saved = [];
    done = null;
    messenger.setMockMethodCallHandler(BackgroundRefresh.channel, (call) async {
      switch (call.method) {
        case 'reason':
          return BackgroundRefresh.watch;
        case 'done':
          done = call.arguments as bool;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(widgets, (call) async {
      switch (call.method) {
        case 'save':
          saved.add(call.arguments as String);
        case 'takeLogs':
          final taken = List.of(queued);
          queued.clear();
          return taken;
      }
      return null;
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(BackgroundRefresh.channel, null);
    messenger.setMockMethodCallHandler(widgets, null);
    await resetDependencies();
    debugDefaultTargetPlatformOverride = null;
  });

  test("a log from the watch is applied with the app closed, and the snapshot keeps Plus", () async {
    await withClock(Clock.fixed(now), () async {
      // The app, earlier: a habit
      await initializeDependencies();
      final habits = get<HabitProvider>();
      await habits.loadHabits();
      await habits.createHabit(const CreateHabitParams(
        name: 'Water',
        target: 8,
        units: 'glasses',
        color: HabitColor.blue,
        categoryId: BuiltInCategoryIds.body,
      ));
      final id = habits.habits.single.id;
      await habits.whenSettled();
      await resetDependencies();

      // Closed; the watch's Crown set 5 and iOS woke the background engine
      queued.add({'id': 'w1', 'habit': id, 'day': '2026-10-18', 'kind': 'set', 'amount': '5'});
      await backgroundMain();

      expect(done, isTrue);
      expect(queued, isEmpty);
      final snapshot = jsonDecode(saved.last) as Map<String, dynamic>;
      expect(snapshot['plus'], isTrue, reason: 'the watch and Siri keep Plus after a background run');
      final water = (snapshot['habits'] as List).single as Map;
      expect(water['id'], id);
      expect(water['progress'], 5, reason: 'the Crown set 5');
    });
  });
}
