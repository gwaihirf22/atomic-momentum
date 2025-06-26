import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Data sources
import '../../data/datasources/local_habit_datasource.dart';
import '../../data/datasources/shared_preferences_datasource.dart';

// Repositories
import '../../domain/repositories/habit_repository.dart';
import '../../data/repositories/habit_repository_impl.dart';

// Use cases
import '../../domain/usecases/get_habits_usecase.dart';
import '../../domain/usecases/create_habit_usecase.dart';
import '../../domain/usecases/update_habit_usecase.dart';
import '../../domain/usecases/delete_habit_usecase.dart';

// Providers
import '../../presentation/providers/habit_provider.dart';
import '../../presentation/providers/category_provider.dart';
import '../../presentation/providers/theme_provider.dart';

final GetIt sl = GetIt.instance;

Future<void> initializeDependencies() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  // Data sources
  sl.registerLazySingleton<LocalHabitDataSource>(
    () => SharedPreferencesDataSource(sl()),
  );

  // Repositories
  sl.registerLazySingleton<HabitRepository>(
    () => HabitRepositoryImpl(sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetHabitsUseCase(sl()));
  sl.registerLazySingleton(() => CreateHabitUseCase(sl()));
  sl.registerLazySingleton(() => UpdateHabitUseCase(sl()));
  sl.registerLazySingleton(() => DeleteHabitUseCase(sl()));

  // Providers
  sl.registerFactory(() => HabitProvider(
    getHabitsUseCase: sl(),
    createHabitUseCase: sl(),
    updateHabitUseCase: sl(),
    deleteHabitUseCase: sl(),
  ));
  sl.registerFactory(() => CategoryProvider());
  
  // Theme provider with persistence
  final isDarkMode = sharedPreferences.getBool('isDarkMode') ?? false;
  sl.registerLazySingleton(() => ThemeProvider(isDarkMode));
}

/// Reset dependencies for testing
Future<void> resetDependencies() async {
  await sl.reset();
}

/// Initialize dependencies for testing with mocks
Future<void> initializeTestDependencies({
  SharedPreferences? mockSharedPreferences,
  LocalHabitDataSource? mockDataSource,
  HabitRepository? mockRepository,
}) async {
  // External dependencies
  if (mockSharedPreferences != null) {
    sl.registerLazySingleton<SharedPreferences>(() => mockSharedPreferences);
  }

  // Data sources
  if (mockDataSource != null) {
    sl.registerLazySingleton<LocalHabitDataSource>(() => mockDataSource);
  } else {
    sl.registerLazySingleton<LocalHabitDataSource>(
      () => SharedPreferencesDataSource(sl()),
    );
  }

  // Repositories
  if (mockRepository != null) {
    sl.registerLazySingleton<HabitRepository>(() => mockRepository);
  } else {
    sl.registerLazySingleton<HabitRepository>(
      () => HabitRepositoryImpl(sl()),
    );
  }

  // Use cases
  sl.registerLazySingleton(() => GetHabitsUseCase(sl()));
  sl.registerLazySingleton(() => CreateHabitUseCase(sl()));
  sl.registerLazySingleton(() => UpdateHabitUseCase(sl()));
  sl.registerLazySingleton(() => DeleteHabitUseCase(sl()));

  // Providers
  sl.registerFactory(() => HabitProvider(
    getHabitsUseCase: sl(),
    createHabitUseCase: sl(),
    updateHabitUseCase: sl(),
    deleteHabitUseCase: sl(),
  ));
  sl.registerFactory(() => CategoryProvider());
  sl.registerLazySingleton(() => ThemeProvider(false)); // Default for tests
}

/// Get dependency
T get<T extends Object>() => sl.get<T>();

/// Check if dependency is registered
bool isRegistered<T extends Object>() => sl.isRegistered<T>();

/// Register singleton for testing
void registerSingleton<T extends Object>(T instance) {
  if (sl.isRegistered<T>()) {
    sl.unregister<T>();
  }
  sl.registerSingleton<T>(instance);
}

/// Register factory for testing
void registerFactory<T extends Object>(T Function() factory) {
  if (sl.isRegistered<T>()) {
    sl.unregister<T>();
  }
  sl.registerFactory<T>(factory);
}