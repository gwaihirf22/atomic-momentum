import 'dart:isolate';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/shared_preferences_datasource.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../../data/repositories/habit_repository_impl.dart';
import '../../data/repositories/quote_repository_impl.dart';
import '../../domain/usecases/create_habit_usecase.dart';
import '../../domain/usecases/delete_habit_usecase.dart';
import '../../domain/usecases/get_habits_usecase.dart';
import '../../domain/usecases/manage_categories_usecase.dart';
import '../../domain/usecases/manage_quotes_usecase.dart';
import '../../domain/usecases/update_habit_usecase.dart';
import '../../presentation/providers/category_provider.dart';
import '../../presentation/providers/habit_provider.dart';
import '../../presentation/providers/quote_provider.dart';
import '../../presentation/providers/settings_provider.dart';
import '../dev/year_of_use.dart';
import '../services/achievement_store.dart';
import '../services/freeze_bank.dart';
import 'demo_persona.dart';
import 'memory_prefs.dart';

/// The example habits' history up to a moment, as stored: built once a day
/// (off the main thread in the app) and kept, so each tour and each visit
/// to How-to starts a fresh [DemoWorld] from it without building again.
class DemoSeed {
  /// The day it ends on.
  final DateTime day;

  /// The habits' JSON, as the data source stores them.
  final String habits;

  /// The achievements they've earned, filed as seen.
  final List<String> seen;

  const DemoSeed._(this.day, this.habits, this.seen);

  /// The example habits up to [now], built here and now (tests, and where
  /// there are no isolates).
  factory DemoSeed.build(DateTime now) {
    final stored = YearOfUse.stored(DemoPersona(now), now);
    return DemoSeed._(_day(now), stored.habits, stored.seen);
  }

  static (DateTime, Future<DemoSeed>)? _cached;

  /// Today's seed, built off the main thread the first time it's asked for
  /// on a day (so a launch can start it while the intro plays), and shared
  /// by everyone who asks that day, even while it's still being built.
  static Future<DemoSeed> forDay(DateTime now) {
    final day = _day(now);
    final cached = _cached;
    if (cached != null && cached.$1 == day) return cached.$2;
    final building = Isolate.run(() => YearOfUse.stored(DemoPersona(now), now))
        .then((stored) => DemoSeed._(day, stored.habits, stored.seen));
    _cached = (day, building);
    // A failed build is tried again next time
    building.catchError((Object _) {
      if (_cached?.$2 == building) _cached = null;
      return DemoSeed._(day, '[]', const []);
    });
    return building;
  }

  /// Forgets the cached seed (tests).
  static void clearCache() => _cached = null;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}

/// The world the tours show: the example habits in providers of their own,
/// stored only in memory, with no reminders, streak warnings or Health, and
/// a freeze bank of its own. Whatever is tapped here never reaches the
/// person's data, notifications or home screen widgets. The person's
/// settings are copied in, so it looks the way they have the app set up.
class DemoWorld {
  final MemoryPrefs prefs;
  final HabitProvider habits;
  final CategoryProvider categories;
  final QuoteProvider quotes;
  final SettingsProvider settings;
  final FreezeBank freezes;

  DemoWorld._(this.prefs, this.habits, this.categories, this.quotes, this.settings, this.freezes);

  /// A fresh world from [seed], with the settings in [settingsFrom] (the
  /// person's own storage, only ever read).
  static Future<DemoWorld> create(DemoSeed seed, {SharedPreferences? settingsFrom}) async {
    final prefs = MemoryPrefs({
      SharedPreferencesDataSource.habitsKey: seed.habits,
      AchievementStore.key: seed.seen,
      if (settingsFrom != null)
        for (final key in SettingsProvider.storedKeys)
          if (settingsFrom.get(key) case final value?) key: value is List ? value.cast<String>().toList() : value,
    });
    final repository = HabitRepositoryImpl(SharedPreferencesDataSource(prefs));
    final categoryRepository = CategoryRepositoryImpl(prefs);
    final quoteRepository = QuoteRepositoryImpl(prefs);
    final freezes = FreezeBank(prefs);
    final habits = HabitProvider(
      getHabitsUseCase: GetHabitsUseCase(repository),
      createHabitUseCase: CreateHabitUseCase(repository),
      updateHabitUseCase: UpdateHabitUseCase(repository),
      deleteHabitUseCase: DeleteHabitUseCase(repository),
      categoryRepository: categoryRepository,
      freezeBank: freezes,
    );
    final categories = CategoryProvider(categoryRepository, ManageCategoriesUseCase(categoryRepository, repository));
    final quotes = QuoteProvider(quoteRepository, ManageQuotesUseCase(quoteRepository));
    final settings = SettingsProvider(prefs);
    await habits.loadHabits();
    await categories.load();
    categories.updateAvailableCategories(habits.habits);
    await quotes.load();
    // Example habits never offer to link Health
    final ids = [for (final h in habits.habits) h.id];
    for (final id in ids) {
      await settings.dismissHealthCard(id, habitIds: ids);
    }
    return DemoWorld._(prefs, habits, categories, quotes, settings, freezes);
  }

  /// An example habit's id, by its name ([DemoPersona.water] …).
  String idOf(String name) => habits.habits.firstWhere((h) => h.name == name).id;

  void dispose() {
    habits.dispose();
    categories.dispose();
    quotes.dispose();
    settings.dispose();
  }
}
