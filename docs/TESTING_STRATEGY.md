# Testing Strategy for Atomic Momentum Flutter App

**Document Version**: 1.0  
**Last Updated**: June 26, 2025  
**Phase**: Professional iOS Development Preparation

## Overview

This document outlines a comprehensive testing strategy for maintaining and developing the Atomic Momentum Flutter application through its iOS professional development phase and beyond.

## 🎯 Testing Philosophy

### Core Principles
1. **Test-Driven Development**: Write tests before or alongside implementation
2. **Pyramid Strategy**: Many unit tests, fewer integration tests, minimal E2E tests
3. **Quality Gates**: No code ships without passing all tests
4. **Performance Focus**: Every test should also validate performance expectations
5. **iOS Excellence**: All tests must validate iOS-specific requirements

### Testing Pyramid
```
              E2E Tests (5%)
         ┌─────────────────────┐
         │   User Journeys     │
         │   App Store Testing │
         └─────────────────────┘
            Integration Tests (20%)
       ┌──────────────────────────────┐
       │     Widget Integration       │
       │     Provider Integration     │
       │     Data Flow Testing        │
       └──────────────────────────────┘
              Unit Tests (75%)
    ┌────────────────────────────────────────┐
    │        Domain Entities                 │
    │        Use Cases                       │
    │        Data Models                     │
    │        Repository Implementations      │
    └────────────────────────────────────────┘
```

## 🧪 Testing Levels & Implementation

### 1. Unit Tests (75% of test suite)

#### Domain Layer Testing
**Test Location**: `test/unit/domain/`

**Entities Testing** (`test/unit/domain/entities/`)
```dart
// Example: habit_test.dart
void main() {
  group('Habit Entity', () {
    test('should create habit with correct progress percentage', () {
      final habit = Habit.create(
        name: 'Test Habit',
        target: 10,
        color: HabitColor.blue,
        category: HabitCategory.body,
      );
      
      expect(habit.progressPercentage, equals(0.0));
      
      final updatedHabit = habit.updateProgress(5);
      expect(updatedHabit.progressPercentage, equals(0.5));
    });
    
    test('should calculate streaks correctly', () {
      // Test streak calculation logic
    });
    
    test('should handle date-based history correctly', () {
      // Test history tracking
    });
  });
}
```

**Use Cases Testing** (`test/unit/domain/usecases/`)
```dart
// Example: create_habit_usecase_test.dart
void main() {
  group('CreateHabitUseCase', () {
    late MockHabitRepository mockRepository;
    late CreateHabitUseCase useCase;
    
    setUp(() {
      mockRepository = MockHabitRepository();
      useCase = CreateHabitUseCase(mockRepository);
    });
    
    test('should create habit successfully', () async {
      // Arrange
      final habitParams = CreateHabitParams(/* ... */);
      when(mockRepository.createHabit(any)).thenAnswer((_) async => Right(mockHabit));
      
      // Act
      final result = await useCase(habitParams);
      
      // Assert
      expect(result, isA<Right<Failure, Habit>>());
      verify(mockRepository.createHabit(any)).called(1);
    });
  });
}
```

#### Data Layer Testing
**Test Location**: `test/unit/data/`

**Models Testing**
```dart
// Test JSON serialization/deserialization
void main() {
  group('HabitModel', () {
    test('should serialize to JSON correctly', () {
      final habitModel = HabitModel(/* ... */);
      final json = habitModel.toJson();
      
      expect(json['name'], equals(habitModel.name));
      expect(json['progress'], equals(habitModel.progress));
    });
    
    test('should deserialize from JSON correctly', () {
      final json = {'name': 'Test', 'progress': 5, /* ... */};
      final habitModel = HabitModel.fromJson(json);
      
      expect(habitModel.name, equals('Test'));
      expect(habitModel.progress, equals(5));
    });
  });
}
```

**Repository Implementation Testing**
```dart
void main() {
  group('HabitRepositoryImpl', () {
    late MockLocalHabitDataSource mockLocalDataSource;
    late HabitRepositoryImpl repository;
    
    setUp(() {
      mockLocalDataSource = MockLocalHabitDataSource();
      repository = HabitRepositoryImpl(mockLocalDataSource);
    });
    
    test('should return habits from local data source', () async {
      // Test repository pattern implementation
    });
  });
}
```

#### Presentation Layer Testing
**Test Location**: `test/unit/presentation/`

**Provider Testing**
```dart
void main() {
  group('HabitProvider', () {
    late MockGetHabitsUseCase mockGetHabitsUseCase;
    late HabitProvider provider;
    
    setUp(() {
      mockGetHabitsUseCase = MockGetHabitsUseCase();
      provider = HabitProvider(mockGetHabitsUseCase, /* ... */);
    });
    
    test('should load habits successfully', () async {
      // Arrange
      final habits = [createTestHabit()];
      when(mockGetHabitsUseCase(NoParams())).thenAnswer((_) async => Right(habits));
      
      // Act
      await provider.loadHabits();
      
      // Assert
      expect(provider.habits, equals(habits));
      expect(provider.isLoading, false);
      expect(provider.hasError, false);
    });
  });
}
```

### 2. Widget Tests (15% of test suite)

#### Screen Widget Testing
**Test Location**: `test/widget/screens/`

```dart
void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('should display habits when loaded', (WidgetTester tester) async {
      // Arrange
      final mockHabitProvider = MockHabitProvider();
      when(mockHabitProvider.habits).thenReturn([createTestHabit()]);
      when(mockHabitProvider.isLoading).thenReturn(false);
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<HabitProvider>.value(
            value: mockHabitProvider,
            child: HomeScreen(),
          ),
        ),
      );
      
      // Assert
      expect(find.text('Test Habit'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
    
    testWidgets('should show loading state', (WidgetTester tester) async {
      // Test loading state UI
    });
    
    testWidgets('should handle category filtering', (WidgetTester tester) async {
      // Test category filter chips
    });
  });
}
```

#### Component Widget Testing
```dart
void main() {
  group('HabitCard Widget', () {
    testWidgets('should display habit information correctly', (WidgetTester tester) async {
      final habit = createTestHabit();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(habit: habit),
          ),
        ),
      );
      
      expect(find.text(habit.name), findsOneWidget);
      expect(find.text('${habit.progress}/${habit.target}'), findsOneWidget);
    });
  });
}
```

### 3. Integration Tests (20% of test suite)

#### Data Flow Integration
**Test Location**: `test/integration/`

```dart
void main() {
  group('Habit Data Flow Integration', () {
    testWidgets('should create, save, and load habit end-to-end', (WidgetTester tester) async {
      // Arrange - Set up real providers with mock data sources
      final testHabit = createTestHabit();
      
      // Act & Assert - Test complete user flow
      await tester.pumpWidget(createTestApp());
      
      // Navigate to add habit screen
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      
      // Fill in habit details
      await tester.enterText(find.byType(TextField).first, testHabit.name);
      await tester.enterText(find.byType(TextField).last, testHabit.target.toString());
      
      // Save habit
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      
      // Verify habit appears in list
      expect(find.text(testHabit.name), findsOneWidget);
    });
    
    testWidgets('should persist habits across app restarts', (WidgetTester tester) async {
      // Test SharedPreferences persistence
    });
  });
}
```

#### Provider Integration Testing
```dart
void main() {
  group('Provider Integration', () {
    testWidgets('should update UI when habit progress changes', (WidgetTester tester) async {
      // Test provider state changes propagate to UI
    });
  });
}
```

### 4. End-to-End Tests (5% of test suite)

#### User Journey Testing
**Test Location**: `test/e2e/`

```dart
void main() {
  group('User Journey E2E Tests', () {
    testWidgets('complete habit management workflow', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      
      // 1. Create a new habit
      await createHabitFlow(tester, 'Morning Run', 7, HabitCategory.body);
      
      // 2. Update progress
      await updateHabitProgress(tester, 'Morning Run', 3);
      
      // 3. View in calendar
      await navigateToCalendar(tester);
      await verifyHabitInCalendar(tester, 'Morning Run');
      
      // 4. Filter by category
      await filterByCategory(tester, HabitCategory.body);
      
      // 5. Verify persistence
      await restartApp(tester);
      await verifyHabitExists(tester, 'Morning Run');
    });
  });
}
```

## 🏗️ Test Infrastructure Setup

### Test Configuration
**File**: `dart_test.yaml`
```yaml
name: atomic_momentum_tests

platforms:
  - chrome
  - ios
  - android

tags:
  unit: Tests that don't require a device or simulator
  widget: Tests that test individual widgets
  integration: Tests that test multiple components together
  e2e: End-to-end tests
  ios: Tests specific to iOS platform
  performance: Performance-related tests

presets:
  unit:
    paths: ["test/unit"]
    tags: unit

  widget:
    paths: ["test/widget"]
    tags: widget

  integration:
    paths: ["test/integration"]
    tags: integration

  e2e:
    paths: ["test/e2e"]
    tags: e2e

  ios:
    tags: ios
    platforms: [ios]
```

### Mock Generation
**File**: `build.yaml`
```yaml
targets:
  $default:
    builders:
      mockito|mockBuilder:
        generate_for:
          - test/**_test.dart
```

### Test Utilities
**File**: `test/helpers/test_helpers.dart`
```dart
// Test data builders
Habit createTestHabit({
  String name = 'Test Habit',
  int progress = 0,
  int target = 7,
  HabitCategory category = HabitCategory.body,
}) {
  return Habit.create(
    name: name,
    target: target,
    color: HabitColor.blue,
    category: category,
  ).updateProgress(progress);
}

// Widget test helpers
Widget createTestApp({Widget? home}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<HabitProvider>(create: (_) => MockHabitProvider()),
      ChangeNotifierProvider<CategoryProvider>(create: (_) => MockCategoryProvider()),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => MockThemeProvider()),
    ],
    child: MaterialApp(
      home: home ?? HomeScreen(),
    ),
  );
}

// Common test flows
Future<void> createHabitFlow(WidgetTester tester, String name, int target, HabitCategory category) async {
  // Implementation for creating habit in tests
}
```

## 📱 iOS-Specific Testing Strategy

### iOS UI Testing
```dart
group('iOS Cupertino Components', () {
  testWidgets('should use CupertinoNavigationBar on iOS', (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: HomeScreen(),
      ),
    );
    
    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
  });
  
  testWidgets('should display iOS-style progress indicators', (WidgetTester tester) async {
    // Test iOS-specific UI components
  });
});
```

### iOS Accessibility Testing
```dart
group('iOS Accessibility', () {
  testWidgets('should support VoiceOver navigation', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp());
    
    // Test semantic labels and accessibility tree
    expect(tester.getSemantics(find.byType(HabitCard)), isNotNull);
  });
  
  testWidgets('should support Dynamic Type', (WidgetTester tester) async {
    // Test font scaling support
  });
});
```

### iOS Performance Testing
```dart
group('iOS Performance', () {
  testWidgets('should maintain 60fps during animations', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp());
    
    // Trigger animations and measure frame times
    await tester.fling(find.byType(ListView), Offset(0, -500), 1000);
    await tester.pumpAndSettle();
    
    // Assert smooth scrolling performance
  });
});
```

## 🚀 Continuous Integration Setup

### GitHub Actions Workflow
**File**: `.github/workflows/flutter_tests.yml`
```yaml
name: Flutter Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.32.4'
        
    - name: Install dependencies
      run: flutter pub get
      
    - name: Run unit tests
      run: flutter test --preset=unit --coverage
      
    - name: Run widget tests
      run: flutter test --preset=widget
      
    - name: Run integration tests
      run: flutter test --preset=integration
      
    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        file: coverage/lcov.info
```

## 📊 Test Metrics & Quality Gates

### Coverage Requirements
- **Unit Tests**: 90% coverage minimum
- **Integration Tests**: 80% coverage minimum
- **Overall**: 85% coverage minimum

### Performance Benchmarks
- **App Startup**: < 2 seconds
- **Navigation**: < 300ms between screens
- **Data Loading**: < 1 second for local data
- **Animation Performance**: 60fps sustained

### Quality Gates
1. All tests must pass before merge
2. Coverage threshold must be met
3. No critical security vulnerabilities
4. iOS accessibility score > 95%
5. Performance benchmarks must be met

## 🔧 Development Workflow

### Test-First Development
1. **Write Test**: Define expected behavior
2. **Implement**: Make test pass
3. **Refactor**: Improve code quality
4. **Integrate**: Ensure all tests pass

### Testing During iOS Development
1. **Component Testing**: Test each Cupertino component
2. **Interaction Testing**: Test iOS-specific gestures
3. **Platform Testing**: Test on iOS simulator and devices
4. **Accessibility Testing**: VoiceOver and Dynamic Type support

### Maintenance Testing
1. **Regression Testing**: Ensure existing functionality
2. **Performance Testing**: Monitor for degradation
3. **Compatibility Testing**: Test across iOS versions
4. **User Testing**: Beta testing with real users

---

## 🎯 Next Steps for Implementation

### Immediate (Next Sprint)
1. Set up basic test infrastructure
2. Implement unit tests for domain entities
3. Create widget tests for main screens
4. Establish CI/CD pipeline

### Professional Development Phase
1. iOS-specific testing framework
2. Performance testing automation
3. Accessibility testing integration
4. App Store testing preparation

This testing strategy ensures maintainable, high-quality code throughout the iOS professional development phase and beyond.