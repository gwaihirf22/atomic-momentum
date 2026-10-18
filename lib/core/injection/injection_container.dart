import '../services/achievement_store.dart';
import '../services/sharer.dart';
import '../services/app_icon_service.dart';
import '../services/support_link.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Data sources
import '../../data/datasources/local_habit_datasource.dart';
import '../../data/datasources/shared_preferences_datasource.dart';

// Repositories
import '../../domain/repositories/habit_repository.dart';
import '../../data/repositories/habit_repository_impl.dart';
import '../../domain/repositories/category_repository.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../../domain/repositories/quote_repository.dart';
import '../../data/repositories/quote_repository_impl.dart';

// Use cases
import '../../domain/usecases/get_habits_usecase.dart';
import '../../domain/usecases/create_habit_usecase.dart';
import '../../domain/usecases/update_habit_usecase.dart';
import '../../domain/usecases/delete_habit_usecase.dart';
import '../../domain/usecases/manage_categories_usecase.dart';
import '../../domain/usecases/manage_quotes_usecase.dart';

// Providers
import '../../presentation/providers/habit_provider.dart';
import '../../presentation/providers/category_provider.dart';
import '../../presentation/providers/theme_provider.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../presentation/providers/quote_provider.dart';

// Services
import '../services/health_source.dart';
import '../services/health_sync_service.dart';
import '../services/notification_service.dart';
import '../services/streak_warning_service.dart';
import '../services/reminder_service.dart';
import '../../domain/services/streak_warning_planner.dart';
import '../migration/smart_reminders_migration.dart';

final GetIt sl = GetIt.instance;

Future<void> initializeDependencies({bool seedDefaultHabit = true}) async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  
  // Initialize notification service
  await NotificationService.initialize();

  // Data sources
  sl.registerLazySingleton<LocalHabitDataSource>(
    () => SharedPreferencesDataSource(sl()),
  );

  // Repositories
  sl.registerLazySingleton<HabitRepository>(
    () => HabitRepositoryImpl(sl()),
  );

  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(sl()),
  );

  sl.registerLazySingleton<QuoteRepository>(() => QuoteRepositoryImpl(sl()));

  // Use cases
  sl.registerLazySingleton(() => GetHabitsUseCase(sl()));
  sl.registerLazySingleton(() => CreateHabitUseCase(sl()));
  sl.registerLazySingleton(() => UpdateHabitUseCase(sl()));
  sl.registerLazySingleton(() => DeleteHabitUseCase(sl()));
  sl.registerLazySingleton(() => ManageCategoriesUseCase(sl(), sl()));
  sl.registerLazySingleton(() => ManageQuotesUseCase(sl()));

  // Settings and streak warnings
  sl.registerLazySingleton(() => SettingsProvider(sl()));
  sl.registerLazySingleton(() => AchievementStore(sl()));
  sl.registerLazySingleton<Sharer>(() => const SystemSharer());
  sl.registerLazySingleton<AppIconService>(() => const PlatformAppIconService());
  sl.registerLazySingleton<SupportLink>(() => PlatformSupportLink());
  sl.registerLazySingleton<HealthSource>(() => PluginHealthSource());
  // Reads the source when it syncs, so tests can swap in a fake after setup
  sl.registerLazySingleton(() => HealthSyncService(source: () => sl<HealthSource>(), prefs: sl()));
  sl.registerLazySingleton(() => StreakWarningService(
    scheduler: LocalNotificationStreakWarningScheduler(defaults: () => sl<SettingsProvider>().notifyDefaults),
    readSettings: () => sl<SettingsProvider>().streakWarnings,
    quietHours: () => sl<SettingsProvider>().quietHours,
  ));
  sl.registerLazySingleton(() => ReminderService(
        scheduler: LocalNotificationReminderScheduler(defaults: () => sl<SettingsProvider>().notifyDefaults),
        // Streak warnings come first; reminders get the rest of iOS's 64
        reservedFor: (habits) => StreakWarningPlanner.maxPending(habits, sl<SettingsProvider>().streakWarnings),
        quietHours: () => sl<SettingsProvider>().quietHours,
      ));
  // Habits that never had a reminder get smart ones, once
  await enableSmartRemindersOnce(
    repository: sl(),
    prefs: sharedPreferences,
    time: sl<SettingsProvider>().defaultReminderTime,
  );

  // Providers
  sl.registerFactory(() => HabitProvider(
    getHabitsUseCase: sl(),
    createHabitUseCase: sl(),
    updateHabitUseCase: sl(),
    deleteHabitUseCase: sl(),
    seedDefaultHabit: seedDefaultHabit,
    streakWarningService: sl(),
    reminderService: sl(),
    categoryRepository: sl(),
    healthSync: sl(),
  ));
  // Shared: the Categories page and the Habits screen must see the same list
  sl.registerLazySingleton(() => CategoryProvider(sl(), sl()));
  await sl<CategoryProvider>().load();
  sl.registerLazySingleton(() => QuoteProvider(sl(), sl()));
  await sl<QuoteProvider>().load();
  
  // Theme provider with persistence
  sl.registerLazySingleton(() => ThemeProvider.fromPrefs(sharedPreferences));
}

/// Reset dependencies for testing
Future<void> resetDependencies() async {
  await sl.reset();
}

/// Get dependency
T get<T extends Object>() => sl.get<T>();
