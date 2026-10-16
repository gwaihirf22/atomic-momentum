# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Atomic Momentum is a habit tracking application:
- **Flutter app** (primary, long-term): Dart/Flutter for iOS, macOS, Android and web, on `main`. The goal is an App Store and Google Play release. Swift is written only where Apple requires it (widget, Live Activity and Watch extensions inside `ios/`).
- **SwiftUI app** (fallback): a native Xcode project on the `swift` branch, kept in case the project ever moves to Swift. Currently Xcode's starter template.
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

# Run on the iPhone simulator (iOS 15+ deployment target; Xcode 27 has no separate
# Simulator app - the booted device is shown in Xcode's DeviceHub)
xcrun simctl boot "iPhone 17 Pro"
./flutter/bin/flutter run -d "iPhone 17 Pro"
xcrun simctl io booted screenshot shot.png   # screenshot without the UI

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
- **Streak Tracking**: Streaks are derived from per-day history (`StreakCalculator`), counted in days/weeks/months, with the "never miss twice" rule: one missed due period is bridged (the streak is `atRisk` and the card says "Don't miss twice"), two in a row end it. Editing a past day on the Calendar repairs or breaks a streak. Stored streaks are recomputed on load (`UpdateHabitUseCase.resetHabitsIfNeeded`)
- **Momentum**: a 0–100 score per habit (`MomentumCalculator`, `Habit.momentum`): an exponential moving average over due periods with partial credit, calibrated to reach 80 in ~66 days of steady practice on any schedule; shown on the card with a 7-day trend arrow
- **Reset Days**: Weekly/monthly habits reset on a user-chosen weekday/day-of-month (`Habit.resetAnchor`); progress rolls over at local midnight
- **Streak Warnings**: `StreakWarningPlanner` plans a "Don't miss twice" notification before the miss that would end a streak (default 4 hours ahead, configurable in Settings), plus an optional nudge before a first miss (Settings switch); `StreakWarningService` schedules them
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

### Product Direction
**Read `docs/strategy/product-strategy.md` before planning features.** It holds the positioning ("Momentum, not perfection", built on *Atomic Habits*), monetization (free + one-time Pro + in-app-purchase tip jar), the Flutter-over-Swift decision and the roadmap. v1, in order:
1. ~~Momentum score + never miss twice~~ (done)
2. Two-minute version
3. Year heatmap + weekly review
4. Onboarding tutorial
5. Store readiness

### Testing Strategy
- **Every feature or fix ships with tests.** Run the whole suite with `./flutter/bin/flutter test`; it must pass.
- **Layout**: `test/unit/` (pure logic, mirrors `lib/`), `test/integration/` (real use cases + SharedPreferences mock), `test/widget/` and `test/widget_test.dart` (screens)
- **Imports**: always `package:atomic_momentum/...`, never relative `../lib/` paths (relative imports load libraries twice and make coverage report ~0%)
- **Time**: pure logic takes a `now`/`clock` parameter so tests can pin dates; integration tests that hit `DateTime.now()` must pick times that work whenever they run
- **Notifications**: tests swap the platform plugin for `FakeStreakWarningScheduler` (`test/helpers/`)
- **Status (2026-10-16)**: 407 tests passing (coverage last measured at 58.5% on 2026-10-15; use cases, data layer and `habit_provider.dart` were the weakest areas)

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