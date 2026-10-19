import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/demo/demo_persona.dart';
import 'package:atomic_momentum/core/demo/demo_world.dart';
import 'package:atomic_momentum/core/demo/memory_prefs.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';

import '../../../helpers/fake_notifications_plugin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 19, 10, 30);
  late DemoSeed seed;

  setUpAll(() => seed = withClock(Clock.fixed(now), () => DemoSeed.build(now)));

  group('MemoryPrefs', () {
    test('keeps values like SharedPreferences, in memory only', () async {
      final prefs = MemoryPrefs({'a': 1});
      expect(prefs.getInt('a'), 1);
      await prefs.setString('s', 'x');
      await prefs.setBool('b', true);
      await prefs.setDouble('d', 1.5);
      await prefs.setStringList('l', ['p', 'q']);
      expect([prefs.getString('s'), prefs.getBool('b'), prefs.getDouble('d'), prefs.getStringList('l')],
          ['x', true, 1.5, ['p', 'q']]);
      expect(prefs.getKeys(), {'a', 's', 'b', 'd', 'l'});
      // Lists come back as copies
      prefs.getStringList('l')!.add('r');
      expect(prefs.getStringList('l'), ['p', 'q']);
      await prefs.remove('a');
      expect(prefs.containsKey('a'), isFalse);
      await prefs.clear();
      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('the example world', () {
    late FakeNotificationsPlugin plugin;
    late Map<String, Object?> realBefore;

    setUp(() async {
      await resetDependencies();
      // Someone's own app: a habit, a dark theme, weeks on Sunday, a quote
      SharedPreferences.setMockInitialValues({
        'themeMode': 'dark',
        'weekStartDay': DateTime.sunday,
        'quotes_saved_v1': ['epictetus-make-it-a-habit'],
      });
      plugin = FakeNotificationsPlugin();
      NotificationService.debugOverride(plugin: plugin);
      await withClock(Clock.fixed(now), () async {
        await initializeDependencies(seedDefaultHabit: false);
        final real = get<HabitProvider>();
        await real.loadHabits();
        await real.createHabit(CreateHabitParams(
            name: 'My habit', target: 1, color: HabitColor.green, categoryId: BuiltInCategoryIds.body));
      });
      final prefs = get<SharedPreferences>();
      realBefore = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      plugin.scheduled.clear();
      plugin.shown.clear();
    });

    tearDown(() async {
      NotificationService.debugReset();
      await resetDependencies();
    });

    Map<String, Object?> realNow() {
      final prefs = get<SharedPreferences>();
      return {for (final key in prefs.getKeys()) key: prefs.get(key)};
    }

    test('has the example habits and the person\'s settings, not their habits', () async {
      final world = await withClock(Clock.fixed(now), () => DemoWorld.create(seed, settingsFrom: get<SharedPreferences>()));
      expect(world.habits.habits.map((h) => h.name), DemoPersona.names);
      expect(world.settings.weekStartOverride, DateTime.sunday);
      expect(world.categories.categories, isNotEmpty);
      for (final h in world.habits.habits) {
        expect(world.settings.healthCardDismissed, contains(h.id), reason: 'no Health offer on ${h.name}');
      }
      expect(world.idOf(DemoPersona.read), world.habits.habits.firstWhere((h) => h.name == 'Read').id);
      world.dispose();
    });

    test('anything done there never reaches the person\'s storage or notifications', () async {
      await withClock(Clock.fixed(now), () async {
        final world = await DemoWorld.create(seed, settingsFrom: get<SharedPreferences>());
        final habits = world.habits;
        final water = world.idOf(DemoPersona.water);
        final read = world.idOf(DemoPersona.read);
        // The card's +, a hold, two minutes, a freeze, an edit, a delete, a new habit
        await habits.updateHabitProgress(water, 6);
        await habits.updateHabitProgress(read, 20);
        await habits.setTwoMinute(world.idOf(DemoPersona.meditate), true);
        await habits.freeze(world.idOf(DemoPersona.gym), DateTime(now.year, now.month, now.day));
        await habits.deleteHabit(world.idOf(DemoPersona.budget));
        await habits.createHabit(CreateHabitParams(
            name: 'Stretch', target: 1, color: HabitColor.teal, categoryId: BuiltInCategoryIds.body));
        await habits.startVacation();
        await habits.endVacation();
        await world.settings.setWeekStart(DateTime.monday);
        await world.quotes.setSaved('seneca-while-we-wait-for-life', true);
        world.categories.toggleCategory(BuiltInCategoryIds.body);
        await habits.syncHealth(force: true);
        // Its own storage changed…
        expect(jsonDecode(world.prefs.getString('atomic_momentum_habits_v2')!), isNotEmpty);
        world.dispose();
      });
      // …the person's didn't, byte for byte, and nothing was scheduled
      expect(jsonEncode(realNow()), jsonEncode(realBefore));
      expect(plugin.scheduled, isEmpty);
      expect(plugin.shown, isEmpty);
    });

    test('every stored setting is copied (a new setting key must be listed)', () {
      final source = File('lib/presentation/providers/settings_provider.dart').readAsStringSync();
      final keys = RegExp(r"static const (_\w+Key) = '").allMatches(source).map((m) => m.group(1)!).toList();
      expect(keys, isNotEmpty);
      final listed = RegExp(r'storedKeys = \[([^\]]*)\]').firstMatch(source)!.group(1)!;
      for (final key in keys) {
        expect(listed, contains(key), reason: '$key is missing from SettingsProvider.storedKeys');
      }
      expect(SettingsProvider.storedKeys, hasLength(keys.length));
    });
  });
}
