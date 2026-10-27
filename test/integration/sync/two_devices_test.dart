import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atomic_momentum/core/demo/memory_prefs.dart';
import 'package:atomic_momentum/core/dev/year_of_use.dart';
import 'package:atomic_momentum/core/services/achievement_store.dart';
import 'package:atomic_momentum/core/services/freeze_bank.dart';
import 'package:atomic_momentum/core/services/habit_order.dart';
import 'package:atomic_momentum/core/sync/sync_service.dart';
import 'package:atomic_momentum/data/datasources/shared_preferences_datasource.dart';
import 'package:atomic_momentum/data/repositories/category_repository_impl.dart';
import 'package:atomic_momentum/data/repositories/habit_repository_impl.dart';
import 'package:atomic_momentum/data/repositories/quote_repository_impl.dart';
import 'package:atomic_momentum/domain/entities/category.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';
import 'package:atomic_momentum/domain/entities/reset_frequency.dart';
import 'package:atomic_momentum/domain/usecases/create_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/delete_habit_usecase.dart';
import 'package:atomic_momentum/domain/usecases/get_habits_usecase.dart';
import 'package:atomic_momentum/domain/usecases/manage_categories_usecase.dart';
import 'package:atomic_momentum/domain/usecases/manage_quotes_usecase.dart';
import 'package:atomic_momentum/domain/usecases/update_habit_usecase.dart';
import 'package:atomic_momentum/presentation/providers/category_provider.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';

import '../../helpers/fake_cloud.dart';

/// One of the person's devices: the app's real providers and storage, in
/// memory, with sync over a shared [FakeCloud].
class Device {
  final MemoryPrefs prefs;
  final FakeCloudLink link;
  late final HabitProvider habits;
  late final SettingsProvider settings;
  late final ThemeProvider theme;
  late final CategoryProvider categories;
  late final QuoteProvider quotes;
  late final FreezeBank bank;
  late final SyncService sync;

  /// What this device's Health shows, by habit name and day (a day missing:
  /// not known).
  final Map<String, Map<DateTime, int>> health = {};

  Device._(this.prefs, this.link);

  static Future<Device> create(FakeCloud cloud, {MemoryPrefs? prefs}) async {
    final device = Device._(prefs ?? MemoryPrefs(), cloud.link());
    await device._build();
    return device;
  }

  Future<void> _build() async {
    final repository = HabitRepositoryImpl(SharedPreferencesDataSource(prefs));
    final categoryRepository = CategoryRepositoryImpl(prefs);
    final quoteRepository = QuoteRepositoryImpl(prefs);
    bank = FreezeBank(prefs);
    categories = CategoryProvider(categoryRepository, ManageCategoriesUseCase(categoryRepository, repository));
    await categories.load();
    habits = HabitProvider(
      getHabitsUseCase: GetHabitsUseCase(repository),
      createHabitUseCase: CreateHabitUseCase(repository),
      updateHabitUseCase: UpdateHabitUseCase(repository),
      deleteHabitUseCase: DeleteHabitUseCase(repository),
      categoryRepository: categoryRepository,
      freezeBank: bank,
      habitOrder: HabitOrder(prefs),
      categories: categories,
    );
    quotes = QuoteProvider(quoteRepository, ManageQuotesUseCase(quoteRepository));
    settings = SettingsProvider(prefs);
    theme = ThemeProvider.fromPrefs(prefs);
    await habits.loadHabits();
    await quotes.load();
    sync = SyncService(
      prefs: prefs,
      transport: link,
      delay: const Duration(hours: 1),
      healthOn: (habit, day) => health[habit.name]?[DateTime(day.year, day.month, day.day)],
    )
      ..attach(habits: habits, settings: settings, theme: theme, categories: categories, quotes: quotes, bank: bank);
  }

  Habit named(String name) => habits.habits.firstWhere((h) => h.name == name);

  Future<void> add(
    String name, {
    int target = 8,
    ResetFrequency frequency = ResetFrequency.daily,
    HealthLink? health,
  }) async {
    expect(
      await habits.createHabit(CreateHabitParams(
        name: name,
        target: target,
        units: health == null ? 'times' : 'steps',
        color: HabitColor.blue,
        categoryId: BuiltInCategoryIds.body,
        resetFrequency: frequency,
        health: health,
      )),
      isTrue,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloud cloud;
  var now = DateTime(2026, 10, 25, 9);

  /// Runs [body] on a clock that only moves when told, a minute per step.
  Future<void> run(Future<void> Function() body) => withClock(Clock(() => now), body);
  void later() => now = now.add(const Duration(minutes: 1));

  /// Syncs every device, twice round, so each has seen all the others.
  Future<void> syncAll(List<Device> devices) async {
    for (var round = 0; round < 2; round++) {
      for (final device in devices) {
        later();
        await device.sync.syncNow();
        await pumpEventQueue();
      }
    }
  }

  setUp(() {
    cloud = FakeCloud();
    now = DateTime(2026, 10, 25, 9);
  });

  test('turning on with habits on both devices keeps everything from both', () => run(() async {
        final phone = await Device.create(cloud);
        final ipad = await Device.create(cloud);
        await phone.add('Walk');
        await phone.habits.updateHabitProgress(phone.named('Walk').id, 3);
        await ipad.add('Read', target: 2);
        await ipad.habits.updateHabitProgress(ipad.named('Read').id, 1);

        expect(await phone.sync.turnOn(), isTrue);
        later();
        expect(await ipad.sync.turnOn(), isTrue);
        await syncAll([phone, ipad]);

        for (final device in [phone, ipad]) {
          expect(device.habits.habits.map((h) => h.name).toSet(), {'Walk', 'Read'});
          expect(device.named('Walk').progress, 3);
          expect(device.named('Read').progress, 1);
        }
        expect(phone.sync.state, SyncState.synced);
        // And the log says what happened
        final lines = ipad.sync.log.entries.map((e) => e.text).join('\n');
        expect(lines, contains('Joined as device'));
        expect(lines, contains('Brought in: Walk (new)'));
      }));

  group('Health-linked habits', () {
    DateTime day(int ago) => DateTime(now.year, now.month, now.day - ago);
    HealthLink steps() => HealthLink(metric: HealthMetric.steps, linkedOn: day(30));

    test('Health\'s numbers never go to the cloud; each device shows its own', () => run(() async {
          final phone = await Device.create(cloud);
          final ipad = await Device.create(cloud);
          await phone.add('Walk', target: 8000, health: steps());
          final id = phone.named('Walk').id;
          // Filled in from the phone's Health, then 500 more typed in on Monday
          phone.health['Walk'] = {day(2): 6000, day(1): 7000, day(0): 4000};
          await phone.habits.setDays(id, {day(2): 6000, day(1): 7500, day(0): 4000});

          await phone.sync.turnOn();
          final sent = cloud.buckets.values.map((b) => b.contents).join();
          expect(sent, isNot(contains('"v":6000')));
          expect(sent, isNot(contains('"v":4000')));
          // What the person logged over Health does go
          expect(sent, contains('"v":7500'));

          await ipad.sync.turnOn();
          await syncAll([phone, ipad]);
          // The phone's Health numbers don't come (the iPad's own Health
          // fills those days in, as applySynced asks it to); what was logged does
          final walk = ipad.named('Walk');
          expect(walk.history[day(2)], isNull);
          expect(walk.history[day(1)], 7500);
          expect(walk.history[day(0)], isNull);
          // And the phone keeps its own
          expect(phone.named('Walk').history[day(0)], 4000);
          expect(phone.named('Walk').history[day(2)], 6000);
        }));

    test('a logged day never shows less than this device\'s Health', () => run(() async {
          final phone = await Device.create(cloud);
          final ipad = await Device.create(cloud);
          await phone.add('Walk', target: 8000, health: steps());
          await phone.sync.turnOn();
          await ipad.sync.turnOn();
          await syncAll([phone, ipad]);
          final id = phone.named('Walk').id;

          phone.health['Walk'] = {day(0): 3000};
          await phone.habits.setDays(id, {day(0): 5000});
          ipad.health['Walk'] = {day(0): 6000};
          await syncAll([phone, ipad]);
          expect(phone.named('Walk').history[day(0)], 5000);
          expect(ipad.named('Walk').history[day(0)], 6000);
        }));

    test('a number that turns out to be only Health\'s is cleared from the cloud', () => run(() async {
          final phone = await Device.create(cloud);
          final ipad = await Device.create(cloud);
          await phone.add('Walk', target: 8000, health: steps());
          await phone.sync.turnOn();
          await ipad.sync.turnOn();
          await syncAll([phone, ipad]);
          final id = phone.named('Walk').id;

          // 5000 logged over Health's 3000; then the phone's Health catches up
          phone.health['Walk'] = {day(0): 3000};
          await phone.habits.setDays(id, {day(0): 5000});
          ipad.health['Walk'] = {day(0): 2000};
          await syncAll([phone, ipad]);
          expect(ipad.named('Walk').history[day(0)], 5000);

          phone.health['Walk'] = {day(0): 9000};
          await syncAll([phone, ipad]);
          final sent = cloud.buckets.values.map((b) => b.contents).join();
          expect(sent, isNot(contains('"v":5000')));
          expect(ipad.named('Walk').history[day(0)], 2000);

          // A later log on the iPad still stands
          later();
          await ipad.habits.setDays(id, {day(0): 9500});
          await syncAll([phone, ipad]);
          expect(phone.named('Walk').history[day(0)], 9500);
        }));
  });

  test('taps on two devices while one is offline add up', () => run(() async {
        final phone = await Device.create(cloud);
        final ipad = await Device.create(cloud);
        await phone.add('Water');
        await phone.sync.turnOn();
        await ipad.sync.turnOn();
        await syncAll([phone, ipad]);
        final id = ipad.named('Water').id;

        ipad.link.offline = true;
        await phone.habits.updateHabitProgress(id, 2);
        later();
        await ipad.habits.updateHabitProgress(id, 1);
        await syncAll([phone, ipad]);
        expect(ipad.sync.state, SyncState.offline);
        expect(phone.named('Water').progress, 2);

        ipad.link.offline = false;
        await syncAll([phone, ipad]);
        expect(phone.named('Water').progress, 3);
        expect(ipad.named('Water').progress, 3);
      }));

  test('a tap made while a merge comes in keeps both', () => run(() async {
        final phone = await Device.create(cloud);
        final ipad = await Device.create(cloud);
        await phone.add('Water');
        await phone.sync.turnOn();
        await ipad.sync.turnOn();
        await syncAll([phone, ipad]);
        final id = phone.named('Water').id;

        await phone.habits.updateHabitProgress(id, 2);
        later();
        await phone.sync.syncNow();
        // The iPad taps, and before that's saved the phone's change arrives
        final saved = ipad.habits.updateHabitProgress(id, 1);
        await ipad.sync.syncNow();
        await saved;
        await pumpEventQueue();
        await syncAll([phone, ipad]);
        expect(ipad.named('Water').progress, 3);
        expect(phone.named('Water').progress, 3);

        // And what's stored agrees with what's shown
        final reloaded = await Device.create(FakeCloud(), prefs: ipad.prefs);
        expect(reloaded.named('Water').progress, 3);
      }));

  test('renames, deletions, settings, categories, appearance and the order follow', () => run(() async {
        final phone = await Device.create(cloud);
        final ipad = await Device.create(cloud);
        await phone.add('Walk');
        await phone.add('Read');
        await phone.sync.turnOn();
        await ipad.sync.turnOn();
        await syncAll([phone, ipad]);

        later();
        await phone.habits.updateHabitDetails(phone.named('Walk').id, const UpdateHabitParams(name: 'Long walk'));
        await phone.habits.deleteHabit(phone.named('Read').id);
        await phone.settings.setWeekStart(DateTime.sunday);
        await phone.theme.setAppearance(Appearance.sepia);
        final body = phone.categories.categories.firstWhere((c) => c.id == BuiltInCategoryIds.body);
        await phone.categories.update(body.copyWith(name: 'Health'));
        await syncAll([phone, ipad]);

        expect(ipad.habits.habits.map((h) => h.name), ['Long walk']);
        expect(ipad.settings.firstDayOfWeek, DateTime.sunday);
        expect(ipad.theme.appearance, Appearance.sepia);
        expect(ipad.categories.categories.firstWhere((c) => c.id == BuiltInCategoryIds.body).name, 'Health');
      }));

  test('a freeze spent on one device leaves the bank lower on both, once', () => run(() async {
        final phone = await Device.create(cloud);
        final ipad = await Device.create(cloud);
        await phone.add('Walk');
        await phone.sync.turnOn();
        await ipad.sync.turnOn();
        await syncAll([phone, ipad]);
        expect(ipad.bank.available, FreezeBank.start);

        final id = phone.named('Walk').id;
        expect(await phone.habits.freeze(id, now), isTrue);
        await syncAll([phone, ipad]);
        expect(phone.bank.available, FreezeBank.start - 1);
        expect(ipad.bank.available, FreezeBank.start - 1);
        expect(ipad.named('Walk').isFrozenOn(now), isTrue);

        // Taken back on the iPad: back on both
        expect(await ipad.habits.unfreeze(id, now), isTrue);
        await syncAll([phone, ipad]);
        expect(phone.bank.available, FreezeBank.start);
        expect(ipad.bank.available, FreezeBank.start);
      }));

  test('achievements celebrated on one device aren\'t celebrated again on the other', () => run(() async {
        final phone = await Device.create(cloud);
        final ipad = await Device.create(cloud);
        await phone.sync.turnOn();
        await ipad.sync.turnOn();
        await AchievementStore(phone.prefs).markSeen(['streak-walk-7']);
        await syncAll([phone, ipad]);
        expect(AchievementStore(ipad.prefs).seen, contains('streak-walk-7'));
      }));

  test('a device restored from a backup of another joins again under its own id', () => run(() async {
        final phone = await Device.create(cloud);
        final ipad = await Device.create(cloud);
        await phone.add('Water');
        await phone.sync.turnOn();
        await ipad.sync.turnOn();
        await syncAll([phone, ipad]);
        final id = phone.named('Water').id;

        // A backup of the phone, taken now…
        final backup = MemoryPrefs({for (final key in phone.prefs.getKeys()) key: phone.prefs.get(key)!});
        // …then the phone carries on
        await phone.habits.updateHabitProgress(id, 2);
        await syncAll([phone, ipad]);

        // A new phone restored from that backup logs one more
        final restored = await Device.create(cloud, prefs: backup);
        later();
        await restored.sync.syncNow();
        expect(restored.sync.device, isNot(phone.sync.device));
        await restored.habits.updateHabitProgress(id, restored.named('Water').progress + 1);
        await syncAll([phone, ipad, restored]);
        for (final device in [phone, ipad, restored]) {
          expect(device.named('Water').progress, 3);
        }
      }));

  test('three devices tapping, offline and syncing at random lose no tap and end the same', () => run(() async {
        final random = Random(11);
        final devices = [for (var i = 0; i < 3; i++) await Device.create(cloud)];
        await devices[0].add('Water', target: 50);
        await devices[0].add('Read', target: 50, frequency: ResetFrequency.weekly);
        for (final device in devices) {
          expect(await device.sync.turnOn(), isTrue);
        }
        await syncAll(devices);
        final ids = [for (final h in devices[0].habits.habits) h.id];
        final taps = {for (final id in ids) id: 0};

        for (var step = 0; step < 120; step++) {
          later();
          final device = devices[random.nextInt(3)];
          final id = ids[random.nextInt(ids.length)];
          switch (random.nextInt(6)) {
            case 0 || 1 || 2:
              final habit = device.habits.getHabitById(id)!;
              await device.habits.updateHabitProgress(id, habit.progress + 1);
              taps[id] = taps[id]! + 1;
            case 3:
              await device.habits.setDayNote(id, now, 'note $step');
            case 4:
              device.link.offline = random.nextBool();
            case 5:
              await device.sync.syncNow();
          }
          await pumpEventQueue();
        }
        for (final device in devices) {
          device.link.offline = false;
        }
        await syncAll(devices);

        final first = devices.first.habits.habits;
        for (final id in ids) {
          expect(devices.first.habits.getHabitById(id)!.progress, taps[id], reason: 'every tap counted');
        }
        for (final device in devices.skip(1)) {
          for (final habit in first) {
            expect(SyncService.sameHabit(device.habits.getHabitById(habit.id)!, habit), isTrue);
          }
        }
      }));

  test('sync waits while a developer year of use is loaded, and can be turned off', () => run(() async {
        final phone = await Device.create(cloud);
        final ipad = await Device.create(cloud);
        await phone.add('Walk');
        await phone.sync.turnOn();
        await ipad.sync.turnOn();
        await syncAll([phone, ipad]);

        await phone.prefs.setString(YearOfUse.backupKey, '{}');
        await phone.sync.syncNow();
        expect(phone.sync.state, SyncState.paused);
        await phone.prefs.remove(YearOfUse.backupKey);

        await phone.sync.turnOff(deleteCloud: true);
        expect(phone.sync.isOn, isFalse);
        expect(cloud.buckets, isEmpty);
        // The iPad finds the copy gone: it stops, keeping its habits
        await ipad.sync.syncNow();
        expect(ipad.sync.state, SyncState.stopped);
        expect(ipad.sync.isOn, isFalse);
        expect(ipad.habits.habits.map((h) => h.name), ['Walk']);
      }));
}
