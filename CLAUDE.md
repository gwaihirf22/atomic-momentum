# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Atomic Momentum is a habit tracking application:
- **Flutter app** (primary, active): Dart/Flutter for iOS, macOS, Android and web, on `main`. The goal is an App Store release.
- **SwiftUI app** (exploratory): a native Xcode project on the `swift` branch, kept as an option in case the project moves to Swift. Currently Xcode's starter template.
- **Web application** (legacy, complete): HTML/CSS/JavaScript with a Python server; kept for reference.

The project focuses on helping users build and maintain positive daily habits with visual progress tracking, streak monitoring, and category-based organization.

## Branches and Worktrees

| Branch | What it holds | Where it's checked out |
|---|---|---|
| `main` | The Flutter app. **Commit everyday work here.** | `/Users/paulblake/code/atomic-momentum` (this folder) |
| `swift` | The SwiftUI app (`AtomicMomentum/` Xcode project), branched from `main` | `/Users/paulblake/code/atomic-momentum-swift` (a git worktree) |

`Claude-code-refactor-experimental` is fully merged into `main` and can be deleted.

The two folders share one repository (one `.git`), so a commit or fetch in either is visible to both. Each folder has its own branch checked out, so you can have the Flutter app and the Xcode project open side by side without switching branches.

- **Swift work:** work in `../atomic-momentum-swift` and commit to `swift` there. To open it in Xcode: `open ../atomic-momentum-swift/AtomicMomentum/AtomicMomentum.xcodeproj`.
- **Keeping `swift` current with `main`:** in the Swift folder, run `git merge main`.
- **If the project moves to Swift:** in this folder, run `git merge swift` to bring the Xcode project into `main`.
- **A branch can only be checked out in one folder.** `git switch swift` here fails while the worktree exists; use the other folder instead.
- **The Flutter SDK** (`./flutter`, git-ignored) exists only in this folder; the Swift worktree doesn't need it.
- **Managing the worktree:**
  - see both folders: `git worktree list`
  - recreate the Swift folder: `git worktree add ../atomic-momentum-swift swift`
  - remove it (the branch is kept): `git worktree remove ../atomic-momentum-swift`

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

# Run ALL tests (unit, integration and widget) - do this before calling any change done
./flutter/bin/flutter test

# Generate test coverage
./flutter/bin/flutter test --coverage   # writes coverage/lcov.info

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
  - ✅ **Create**: Full habit creation with name, target, units, color, category, frequency
  - ✅ **Read**: Professional habit display with progress tracking and completion states
  - ✅ **Update**: Edit functionality with form pre-population and comprehensive validation
  - ✅ **Delete**: Safe deletion with confirmation dialogs and user feedback
- **Calendar View**: Monthly calendar with habit completion visualization and category filtering
- **Category System**: User-editable categories (`Category` entity + `CategoryRepository`, rules in `ManageCategoriesUseCase`); six built-ins seeded on first launch with ids `body`, `spirit`, … that habits store as `categoryId`; Settings → Categories (or long-press the rings) to add/edit/reorder/delete/restore; deleted or unknown ids show as Uncategorized. Design: `docs/design/custom-categories.md`
- **Streak Tracking**: Streaks are derived from per-day history (`StreakCalculator`), counted in days/weeks/months; editing a past day on the Calendar repairs or breaks a streak
- **Reset Days**: Weekly/monthly habits reset on a user-chosen weekday/day-of-month (`Habit.resetAnchor`); progress rolls over at local midnight
- **Streak Warnings**: One notification per habit before its streak deadline (default 4 hours, configurable in Settings) via `StreakWarningService`
- **Theme Support**: iOS-native light/dark mode with proper styling
- **Testing Framework**: Unit, integration and widget tests; see Testing Strategy
- **Development Tools**: Default habit system, comprehensive debug logging, bypass solutions

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

### Testing Strategy
- **Every feature or fix ships with tests.** Run the whole suite with `./flutter/bin/flutter test`; it must pass.
- **Layout**: `test/unit/` (pure logic, mirrors `lib/`), `test/integration/` (real use cases + SharedPreferences mock), `test/widget/` and `test/widget_test.dart` (screens)
- **Imports**: always `package:atomic_momentum/...`, never relative `../lib/` paths (relative imports load libraries twice and make coverage report ~0%)
- **Time**: pure logic takes a `now`/`clock` parameter so tests can pin dates; integration tests that hit `DateTime.now()` must pick times that work whenever they run
- **Notifications**: tests swap the platform plugin for `FakeStreakWarningScheduler` (`test/helpers/`)
- **Status (2026-10-15)**: 193 tests passing; 58.5% line coverage (use cases, data layer and `habit_provider.dart` are the weakest areas)

### Current Development Status (July 14, 2025)
- **Critical Bugs Fixed**: Navigation, units input, habit incrementation issues resolved
- **Core Features Complete**: Full CRUD functionality (Create, Read, Update, Delete) implemented
- **New Features Added**: 
  - Frequency selection dropdown (Daily/Weekly/Monthly/Never)
  - Complete edit habit functionality with form pre-population
  - Delete habit functionality with confirmation dialogs
  - Default habit system for testing convenience
- **UI Enhancements**: Professional habit cards with frequency display and edit/delete buttons
- **Debug System**: Comprehensive logging for development stability (temporary)
- **Architecture Validated**: Clean architecture patterns working correctly with bypass solutions
- **Ready for Phase 3**: Notifications, enhanced customization, data migration, advanced analytics
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