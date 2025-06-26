# Flutter Clean Architecture Implementation

## Overview
Implement clean architecture principles in the Flutter app to support iOS excellence and maintainable code growth.

## Current Flutter Architecture Issues

### 1. Service Layer Limitations
- **HabitService**: Basic CRUD operations only
- **No Repository Pattern**: Direct storage access from service
- **Limited Error Handling**: Basic error propagation
- **No Caching Strategy**: Inefficient data loading

### 2. State Management Gaps
- **Provider Usage**: Limited to theme management only
- **No Global State**: Habit state managed locally in widgets
- **Manual State Updates**: Inefficient widget rebuilds
- **No State Persistence**: App state lost on restart

### 3. Data Layer Issues
- **SharedPreferences Direct Access**: No abstraction layer
- **No Data Validation**: Risk of corrupted data
- **Limited Storage Strategy**: No consideration for data growth
- **No Offline Support**: No offline-first architecture

## Proposed Clean Architecture

### Architecture Layers

```
┌─────────────────────────┐
│     Presentation        │
│   (Screens, Widgets)    │
├─────────────────────────┤
│     Application         │
│ (Providers, Use Cases)  │
├─────────────────────────┤
│      Domain             │
│ (Models, Repositories)  │
├─────────────────────────┤
│       Data              │
│ (Data Sources, DTOs)    │
└─────────────────────────┘
```

### Implementation Plan

#### Phase 1: Domain Layer Foundation

**1. Enhanced Models**
```dart
// lib/domain/entities/habit.dart
class Habit {
  final String id;
  final String name;
  final int progress;
  final int target;
  final Color color;
  final HabitCategory category;
  final ResetFrequency resetFrequency;
  final Map<DateTime, int> history;
  final int streak;
  final DateTime? lastStreakDate;
  final TimeOfDay? reminderTime;
  final bool reminderEnabled;
}

// lib/domain/entities/habit_category.dart
enum HabitCategory {
  body, spirit, mind, social, career, creative
}

// lib/domain/entities/reset_frequency.dart
enum ResetFrequency {
  daily, weekly, monthly
}
```

**2. Repository Interfaces**
```dart
// lib/domain/repositories/habit_repository.dart
abstract class HabitRepository {
  Future<List<Habit>> getHabits();
  Future<void> saveHabit(Habit habit);
  Future<void> deleteHabit(String id);
  Future<void> updateHabitProgress(String id, int progress);
  Future<Map<DateTime, int>> getHabitHistory(String id);
  Future<void> saveHabitHistory(String id, DateTime date, int progress);
}
```

**3. Use Cases**
```dart
// lib/domain/usecases/get_habits_usecase.dart
class GetHabitsUseCase {
  final HabitRepository repository;
  
  GetHabitsUseCase(this.repository);
  
  Future<List<Habit>> call() => repository.getHabits();
}

// lib/domain/usecases/update_habit_progress_usecase.dart
class UpdateHabitProgressUseCase {
  final HabitRepository repository;
  
  UpdateHabitProgressUseCase(this.repository);
  
  Future<void> call(String id, int progress) async {
    await repository.updateHabitProgress(id, progress);
    await _updateStreak(id, progress);
    await _saveToHistory(id, progress);
  }
}
```

#### Phase 2: Data Layer Implementation

**1. Data Sources**
```dart
// lib/data/datasources/local_habit_datasource.dart
abstract class LocalHabitDataSource {
  Future<List<HabitModel>> getHabits();
  Future<void> saveHabit(HabitModel habit);
  Future<void> deleteHabit(String id);
  Future<Map<String, dynamic>> getHabitHistory(String id);
}

// lib/data/datasources/shared_preferences_datasource.dart
class SharedPreferencesDataSource implements LocalHabitDataSource {
  final SharedPreferences prefs;
  
  SharedPreferencesDataSource(this.prefs);
  
  @override
  Future<List<HabitModel>> getHabits() async {
    // Implementation with proper error handling
  }
}
```

**2. Data Models**
```dart
// lib/data/models/habit_model.dart
class HabitModel extends Habit {
  const HabitModel({
    required super.id,
    required super.name,
    // ... other fields
  });
  
  factory HabitModel.fromJson(Map<String, dynamic> json) {
    // JSON deserialization with validation
  }
  
  Map<String, dynamic> toJson() {
    // JSON serialization
  }
  
  Habit toDomain() {
    // Convert to domain entity
  }
}
```

**3. Repository Implementation**
```dart
// lib/data/repositories/habit_repository_impl.dart
class HabitRepositoryImpl implements HabitRepository {
  final LocalHabitDataSource localDataSource;
  
  HabitRepositoryImpl(this.localDataSource);
  
  @override
  Future<List<Habit>> getHabits() async {
    try {
      final habitModels = await localDataSource.getHabits();
      return habitModels.map((model) => model.toDomain()).toList();
    } catch (e) {
      throw HabitRepositoryException('Failed to load habits: $e');
    }
  }
}
```

#### Phase 3: Application Layer

**1. State Management with Provider**
```dart
// lib/application/providers/habit_provider.dart
class HabitProvider extends ChangeNotifier {
  final GetHabitsUseCase getHabitsUseCase;
  final UpdateHabitProgressUseCase updateHabitProgressUseCase;
  
  List<Habit> _habits = [];
  bool _isLoading = false;
  String? _error;
  
  List<Habit> get habits => _habits;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<void> loadHabits() async {
    _setLoading(true);
    try {
      _habits = await getHabitsUseCase();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }
}
```

**2. Category Management**
```dart
// lib/application/providers/category_provider.dart
class CategoryProvider extends ChangeNotifier {
  HabitCategory? _selectedCategory;
  
  HabitCategory? get selectedCategory => _selectedCategory;
  
  void setCategory(HabitCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }
  
  List<Habit> filterHabits(List<Habit> habits) {
    if (_selectedCategory == null) return habits;
    return habits.where((habit) => habit.category == _selectedCategory).toList();
  }
}
```

#### Phase 4: Presentation Layer Improvements

**1. Screen Refactoring**
```dart
// lib/presentation/screens/home_screen.dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<HabitProvider, CategoryProvider>(
      builder: (context, habitProvider, categoryProvider, child) {
        if (habitProvider.isLoading) {
          return const LoadingWidget();
        }
        
        if (habitProvider.error != null) {
          return ErrorWidget(error: habitProvider.error!);
        }
        
        final filteredHabits = categoryProvider.filterHabits(habitProvider.habits);
        
        return HabitListView(habits: filteredHabits);
      },
    );
  }
}
```

**2. Widget Composition**
```dart
// lib/presentation/widgets/habit_card.dart
class HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onTap;
  
  const HabitCard({
    required this.habit,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(habit.name),
        subtitle: ProgressIndicator(
          progress: habit.progress,
          target: habit.target,
        ),
        trailing: StreakBadge(streak: habit.streak),
        onTap: onTap,
      ),
    );
  }
}
```

### Dependency Injection Setup

```dart
// lib/injection_container.dart
import 'package:get_it/get_it.dart';

final GetIt sl = GetIt.instance;

Future<void> initializeDependencies() async {
  // Data sources
  sl.registerLazySingleton<SharedPreferences>(
    () => SharedPreferences.getInstance(),
  );
  
  sl.registerLazySingleton<LocalHabitDataSource>(
    () => SharedPreferencesDataSource(sl()),
  );
  
  // Repositories
  sl.registerLazySingleton<HabitRepository>(
    () => HabitRepositoryImpl(sl()),
  );
  
  // Use cases
  sl.registerLazySingleton(() => GetHabitsUseCase(sl()));
  sl.registerLazySingleton(() => UpdateHabitProgressUseCase(sl()));
  
  // Providers
  sl.registerFactory(() => HabitProvider(sl(), sl()));
  sl.registerFactory(() => CategoryProvider());
}
```

## Error Handling Strategy

### Custom Exceptions
```dart
// lib/core/exceptions/habit_exceptions.dart
abstract class HabitException implements Exception {
  final String message;
  const HabitException(this.message);
}

class HabitRepositoryException extends HabitException {
  const HabitRepositoryException(super.message);
}

class HabitValidationException extends HabitException {
  const HabitValidationException(super.message);
}
```

### Error Handling Mixin
```dart
// lib/core/mixins/error_handler_mixin.dart
mixin ErrorHandlerMixin {
  void handleError(dynamic error, {VoidCallback? onRetry}) {
    String userMessage;
    
    if (error is HabitRepositoryException) {
      userMessage = 'Failed to save habit data';
    } else if (error is HabitValidationException) {
      userMessage = error.message;
    } else {
      userMessage = 'An unexpected error occurred';
    }
    
    _showErrorDialog(userMessage, onRetry);
  }
}
```

## Testing Strategy

### Unit Tests
```dart
// test/domain/usecases/get_habits_usecase_test.dart
void main() {
  late MockHabitRepository mockRepository;
  late GetHabitsUseCase useCase;
  
  setUp(() {
    mockRepository = MockHabitRepository();
    useCase = GetHabitsUseCase(mockRepository);
  });
  
  group('GetHabitsUseCase', () {
    test('should return list of habits when repository call is successful', () async {
      // Arrange
      final habits = [testHabit1, testHabit2];
      when(mockRepository.getHabits()).thenAnswer((_) async => habits);
      
      // Act
      final result = await useCase();
      
      // Assert
      expect(result, equals(habits));
      verify(mockRepository.getHabits()).called(1);
    });
  });
}
```

## Performance Considerations

### Lazy Loading
- Implement lazy loading for habit history
- Use pagination for large habit lists
- Cache frequently accessed data

### Memory Management
- Dispose providers properly
- Use weak references where appropriate
- Implement proper lifecycle management

### iOS Optimization
- Minimize widget rebuilds
- Use const constructors
- Implement proper image caching
- Optimize list rendering

## Migration Timeline

### Phase 1: Foundation (1-2 weeks)
- Set up clean architecture structure
- Implement domain layer
- Create repository interfaces

### Phase 2: Data Layer (1 week)
- Implement data sources
- Create data models
- Set up repository implementation

### Phase 3: Application Layer (1 week)
- Implement providers
- Set up dependency injection
- Add error handling

### Phase 4: Presentation Layer (1 week)
- Refactor existing screens
- Create reusable widgets
- Implement proper state management

### Phase 5: Testing & Polish (1 week)
- Add unit tests
- Performance optimization
- iOS-specific improvements

**Total Estimated Time: 5-6 weeks**