# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Atomic Momentum is a habit tracking application with dual implementations:
- **Web application** (primary/active): HTML/CSS/JavaScript with Python server
- **Flutter mobile app** (planned): Dart/Flutter implementation in development

The project focuses on helping users build and maintain positive daily habits with visual progress tracking, streak monitoring, and category-based organization.

## Development Commands

### Flutter Application (Primary - Active Development)
```bash
# IMPORTANT: Flutter is installed locally in ./flutter/bin/flutter
# Use the full path for all Flutter commands

# Install Flutter dependencies
./flutter/bin/flutter pub get

# Run Flutter app (development) - requires specifying device
./flutter/bin/flutter run -d chrome --web-port=8080 --web-hostname=localhost

# Build for web (faster for testing)
./flutter/bin/flutter build web

# Run tests (recommended for Phase 3)
./flutter/bin/flutter test test/unit/ test/integration/

# Generate test coverage
./flutter/bin/flutter test --coverage test/unit/ test/integration/

# Build for production
./flutter/bin/flutter build apk          # Android
./flutter/bin/flutter build ios          # iOS
./flutter/bin/flutter build web          # Web

# Run Flutter linting
./flutter/bin/flutter analyze

# Common debugging: Check available devices
./flutter/bin/flutter devices
```

### Web Application (Legacy - Complete)
```bash
# Start the development server
python server.py
# Server runs on http://localhost:8000
```

## Architecture Overview

### Flutter Application Structure (Primary - Clean Architecture)
- **Entry Point**: `lib/main.dart` with dependency injection initialization
- **Domain Layer**: `lib/domain/` - Business logic and entities
  - `entities/` - Core data models (Habit, StreakData, HabitColor, etc.)
  - `usecases/` - Business logic operations (CreateHabit, UpdateHabit, etc.)
  - `repositories/` - Abstract data access interfaces
- **Data Layer**: `lib/data/` - Data sources and implementations  
  - `repositories/` - Concrete repository implementations
  - `datasources/` - SharedPreferences and local storage
  - `models/` - Data transfer objects
- **Presentation Layer**: `lib/presentation/` - UI and state management
  - `providers/` - State management (HabitProvider, CategoryProvider, ThemeProvider)
- **Core Layer**: `lib/core/` - Cross-cutting concerns
  - `injection/` - Dependency injection with GetIt
  - `validation/` - Business rule validation
  - `migration/` - Data migration utilities
  - `theme/` - iOS-specific styling

### Key Components
- **Habit Management**: Complete CRUD with validation and error handling
- **Calendar View**: Monthly calendar with habit completion visualization and category filtering
- **Category System**: 6 professional categories with visual filtering
- **Streak Tracking**: Comprehensive streak calculation with history
- **Theme Support**: iOS-native light/dark mode with proper styling
- **Testing Framework**: 96.5% test coverage with unit and integration tests

### Data Flow (Clean Architecture)
1. UI triggers use cases through providers
2. Use cases execute business logic using repository interfaces
3. Repositories handle data persistence via SharedPreferences
4. State updates flow back through providers to UI
5. All data models support JSON serialization for cross-platform compatibility

### Web Application Structure (Legacy - Complete)
- **Entry Point**: `templates/index.html` served via `server.py`
- **Core Logic**: Modular JavaScript in `scripts/` directory
- **Data Storage**: Browser localStorage (fully implemented)
- **Status**: Feature complete, used as reference for Flutter implementation

## Development Practices

### Current Phase: Phase 3 - Feature Completion
Based on completed Phase 2 testing and validation:
1. **High Priority**: Notification system implementation using existing ReminderSettings
2. **Medium Priority**: Enhanced color/icon customization and data migration tools
3. **Future**: Advanced analytics and iOS-specific optimizations

### File Modifications for Phase 3
- **Primary Development**: Focus on `lib/` directory for Flutter development
- **Notification System**: Implement flutter_local_notifications integration
- **UI Enhancements**: Improve `lib/screens/` for better iOS experience
- **Data Migration**: Create utilities in `lib/core/migration/`

### Testing Strategy (Validated in Phase 2)
- **Flutter**: Use `./flutter/bin/flutter test test/unit/ test/integration/` 
- **Coverage**: 96.5% test success rate achieved (112/116 tests passing)
- **Integration**: All 9 integration tests passing - end-to-end validation complete
- **Unit Tests**: 103/105 passing - domain logic verified

### Current Development Status (July 14, 2025)
- **Critical Bugs Fixed**: Navigation, units input, habit incrementation issues resolved
- **New Features Added**: Frequency selection dropdown (Daily/Weekly/Monthly/Never)
- **Debug System**: Temporary comprehensive logging for development stability
- **Architecture Validated**: Clean architecture patterns working correctly with bypass solutions
- **Ready for Core Features**: Edit/Delete habit functionality, then Phase 3 features
- **Testing Framework**: Robust and reliable for continued development

## Key Implementation Details

### Habit Data Structure
```javascript
{
  id: "unique_habit_id",
  name: "Habit Name",
  progress: 5,
  target: 8,
  color: "#2196F3",
  category: "Body",
  resetFrequency: "weekly",
  history: {}, // Date-based completion tracking
  streak: 0,
  lastStreakDate: null,
  reminderTime: null,
  reminderEnabled: false
}
```

### Storage Service Pattern
- Use `getHabits()` and `saveHabits()` from `storageService.js`
- Habit history stored separately via `loadHabitHistory()` and `saveHabitHistory()`
- All data persistence goes through storage service abstraction

### Theme System
- Theme state managed in `theme.js`
- Apply theme changes via `applyTheme()` function
- Dark/light mode preference stored in localStorage

### Common Development Tasks

#### Adding New Habit Features
1. Update habit data structure in `main.js` defaultHabits
2. Modify habit creation/editing logic in form handlers
3. Update display logic in habit rendering functions
4. Test with calendar view integration

#### Modifying Calendar Functionality
1. Calendar logic in `scripts/calendar.js`
2. Habit completion data retrieved from habit history
3. Category filtering integrated with main view filters
4. Day detail popups show habit-specific information

#### Styling Changes
1. Main styles in `styles/main.css`
2. Calendar-specific styles in `styles/calendar.css`
3. Theme variables defined for dark/light mode support
4. Responsive design considerations for mobile devices