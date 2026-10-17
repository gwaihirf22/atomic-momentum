# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Atomic Momentum is a habit tracking application:
- **Flutter app** (primary, long-term): Dart/Flutter for iOS, macOS, Android and web, on `main`. The goal is an App Store and Google Play release. Swift is written only where Apple requires it (widget, Live Activity and Watch extensions inside `ios/`).
- **SwiftUI app** (fallback): a native Xcode project on the `swift` branch, kept in case the project ever moves to Swift. Currently Xcode's starter template.
- **Web prototype** (retired): the original HTML/JS app with a Python server was removed from `main` on 2026-10-17. It's kept on the tag `legacy-web-prototype` (`git checkout legacy-web-prototype` to look at it).

The project focuses on helping users build and maintain positive daily habits with visual progress tracking, streak monitoring, and category-based organization.

## Branches and Worktrees

| Branch | What it holds | Where it's checked out |
|---|---|---|
| `main` | The Flutter app. **Commit everyday work here.** | `/Users/paulblake/code/atomic-momentum` (this folder) |
| `swift` | The SwiftUI app (`AtomicMomentum/` Xcode project), branched from `main` | `/Users/paulblake/code/atomic-momentum-swift` (a git worktree) |


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

# Run on the iPhone simulator (iOS 16+ deployment target). Xcode 27 replaced the
# Simulator app with DeviceHub (Xcode.app/Contents/Applications/DeviceHub.app).
# Start the iPhone from DeviceHub: one booted with `xcrun simctl boot` shows there
# but doesn't take clicks. Then:
./flutter/bin/flutter run -d "iPhone 17 Pro"
xcrun simctl io booted screenshot shot.png   # screenshot from the command line
# After changes, reload BOTH simulators: iPhone 17 Pro and iPhone SE (3rd gen, iOS 18.5)

# Build for web (faster for testing)
./flutter/bin/flutter build web

# Run ALL tests (unit, integration and widget) - do this before calling any change done
./flutter/bin/flutter test

# Notification simulator in four time zones (after changing reminders, warnings or dates)
tool/notification_sim.sh

# Real notifications on a simulator (by hand, on both iPhones); leaves the app installed with its data.
# Never use `flutter test integration_test`: it uninstalls the app afterwards, deleting its habits.
tool/device_notification_check.sh "iPhone 17 Pro"

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
- **Smart Reminders**: `ReminderSettings` (smart or custom days, time, message); `ReminderPlanner` works out times from the schedule (each due day for daily habits; a countdown to the due day for longer periods: 1 day before for every 2–6 days, 3 and 1 day before for weekly to every 3 weeks, 7/3/1 for monthly) and drops reminders once the period is done; `ReminderService` schedules the soonest 48 across habits as one-off notifications (iOS allows 64) and replaces them on load, changes, progress and midnight. New habits remind by default at Settings → Default time; `smart_reminders_migration.dart` switched them on once for older habits
- **Two-minute version**: a habit's tiny version for hard days (`TwoMinuteVersion`: description, optional minimum amount, "Show on card"). The card's "2 min" button (`TwoMinuteButton`) or reaching the minimum keeps the day: streaks count it as kept, momentum gives it half credit (`TwoMinuteLog`, used by both calculators), reminders and warnings stop for that period. Tapped days are stored apart from history in `Habit.twoMinuteDays`, for later statistics and rewards
- **Notification taps**: `NotificationService.handleTap` turns a payload into `focusRequests` (also on launch from a tap); `IOSMainNavigation` switches to Habits and pops to the list, `HomeScreen` clears a hiding filter, scrolls to the card and highlights it. The Habits list builds every card (a `Column`, not a lazy sliver) so any card can be scrolled to
- **Progress saving**: `HabitProvider.updateHabitProgress` (and `setTwoMinute`) show a tap instantly and save in the background through one queue, one save at a time, collapsing quick taps; reminder and warning syncs never block taps
- **Habits header**: `LargeTitleScaffold` gives the main tabs large titles in Sora that hand over to a small bar title on scroll; the Habits greeting (`Greetings`) is random for the time of day (shifted by Settings → "My day starts at", `SettingsProvider.dayStart`, for night shifts), new each time the app opens, and steps down 32→28→24pt to fit two lines; overall momentum shows as a ring (`MomentumRing`)
- **Look and feel**: adaptive controls (`presentation/widgets/adaptive.dart`: iOS alerts, action sheets and wheel pickers on Apple platforms, Material on Android); Settings is an inset grouped list (`settings_list.dart`); style tokens in `core/theme/app_style.dart`; haptics in `core/feedback/haptics.dart`; appearance is System/Light/Dark (`ThemeProvider`)
- **Branding**: app name "Momentum", id `com.paulblake.momentum`; icon source `assets/branding/app_icon_source.png`, regenerate with `./flutter/bin/dart run flutter_launcher_icons`

### Data Flow (Clean Architecture)
1. UI triggers use cases through providers
2. Use cases execute business logic using repository interfaces
3. Repositories handle data persistence via SharedPreferences
4. State updates flow back through providers to UI
5. All data models support JSON serialization for cross-platform compatibility

## Development Practices

### Product Direction
**Read `docs/strategy/product-strategy.md` before planning features.** It holds the positioning ("Momentum, not perfection", built on *Atomic Habits*), monetization (free + one-time Pro + in-app-purchase tip jar), the Flutter-over-Swift decision and the roadmap. v1, in order:
1. ~~Momentum score + never miss twice~~ (done)
2. ~~Smart reminders: on by default, following each habit's due days, per-habit control~~ (done)
3. ~~Two-minute version~~ (done)
4. Statistics: year heatmap, weekly review, two-minute days, rewards (earned freeze/break days, can be turned off) and achievements
5. Onboarding tutorial
6. Store readiness (name "Momentum", icon and app id `com.paulblake.momentum` are done)

### Small Screens and Text
The smallest supported phone is the **iPhone SE (2nd/3rd gen), 375pt wide**; the minimum iOS is 16. Every screen must work there at the default text size and at iOS's largest standard size (~135%), and must not break at Accessibility sizes.
- **Our labels are never cut off with "…".** Keep titles short (~20 characters or fewer); explanations go in subtitles and footers, which wrap.
- **Rows grow taller instead of truncating.** No fixed heights around text; use minimum heights. `CupertinoListTile` truncates titles by default: give text an explicit `maxLines` (see `settings_list.dart`).
- **User content** (habit and category names) may wrap to 2 lines; only beyond that may it end in "…".
- **Layouts adapt:** habit cards and Calendar rows switch to two rows below 390pt or above 115% text (`HabitCard.useTwoRows`); category rings show 4 per page with large text.
- **Guard:** `test/widget/small_screens_test.dart` renders every screen with real fonts (`test/helpers/real_fonts.dart`) at 375/390pt and 100%/135% text, and fails on any overflow or text that hits its line limit. Add new screens and sheets to it.

### Testing Strategy
- **Every feature or fix ships with tests.** Run the whole suite with `./flutter/bin/flutter test`; it must pass.
- **Layout**: `test/unit/` (pure logic, mirrors `lib/`), `test/integration/` (real use cases + SharedPreferences mock), `test/widget/` and `test/widget_test.dart` (screens)
- **Imports**: always `package:atomic_momentum/...`, never relative `../lib/` paths (relative imports load libraries twice and make coverage report ~0%)
- **Time**: app code reads the time with `clock.now()` from package:clock, never `DateTime.now()` (a guard test enforces it), so tests can run the app under `withClock`. Pure logic also takes a `now` parameter
- **Notification simulator** (`test/simulation/`): six weeks of the real app on a simulated clock, against a simulated iOS notification center (delivers as time passes, applies iOS's 64 limit). Every delivery is checked (nothing missing or extra versus the app's plan, nothing for a finished period, right times, warnings only with a streak at stake, no duplicates). Each scenario's timeline is saved in `test/simulation/goldens/`: review diffs, update with `./flutter/bin/flutter test test/simulation --update-goldens`. After changing reminders, warnings or dates, run `tool/notification_sim.sh` (UTC, New York, London, Lord Howe: clock changes). Add a scenario for each new kind of notification
- **On-device check**: `tool/device_notification_check.sh "<simulator>"` schedules real notifications seconds ahead and confirms iOS delivers them, then reinstalls the real app; run by hand on both simulators when notification code changes. Not `flutter test integration_test`, which uninstalls the app and its data
- **Notifications**: tests use fakes from `test/helpers/` (`FakeStreakWarningScheduler`, `FakeReminderScheduler`, `FakeNotificationsPlugin`)
- **Fonts and randomness**: widget tests draw text in a square placeholder font; tests about fit load real fonts (`real_fonts.dart`). `test/flutter_test_config.dart` seeds the greeting so layouts are the same every run
- **Async in widget tests**: don't keep a `Future` alive across calls in app code (chained futures break under the test clock); use a flag and a pending value instead (see `ReminderService.syncAll`)
- **Status (2026-10-17)**: 598 tests passing, including the notification simulator (coverage last measured at 58.5% on 2026-10-15; use cases, data layer and `habit_provider.dart` were the weakest areas)

## Key Implementation Details
- **Storage**: habits are JSON in SharedPreferences via `SharedPreferencesDataSource`; a habit keeps its full per-day `history`, and streak, progress and momentum are derived from it (`Habit.refresh`, `StreakCalculator`, `MomentumCalculator`). Categories live under `categories_v1`
- **Dates**: day-only dates are built from calendar fields (`DateTime(y, m, d)`), never with `toLocal()`; table_calendar hands over UTC midnights
- **Notifications**: `NotificationService` wraps flutter_local_notifications. Reminders use payload `reminder|<habitId>` and are found and replaced as a set; streak warnings use ids hashed from `<habitId>-streak-…`. iOS keeps at most 64 pending: reminders get what streak warnings leave (`ReminderService.roomFor`). Warning lead times count on the clock (24h before midnight is midnight the day before, even when clocks change). Permission is asked once at first launch, after the first frame
- **Adding a screen or sheet**: use `LargeTitleScaffold` for main tabs, the adaptive helpers for dialogs and pickers, and add it to `test/widget/small_screens_test.dart`
- **Platforms**: iOS and Android are the targets; `macos/` and `web/` are kept for development runs. Linux and Windows runners were removed (recreate with `flutter create --platforms=linux,windows .`)
