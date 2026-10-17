# Momentum (Atomic Momentum)

A habit tracker built on the ideas in *Atomic Habits*: **momentum, not perfection**. It rewards showing up instead of punishing a missed day.

Built with Flutter for iPhone first, with Android, macOS and web from the same code.

## What it does

- **Habits with flexible schedules:** daily, chosen weekdays, every N days or weeks, monthly (on the day you choose), or a lifetime total. Log progress with the ring or the −/+ stepper.
- **Never miss twice:** a streak survives one missed day (the card warns "Don't miss twice"); two misses in a row end it.
- **Momentum score:** a 0–100 score per habit and overall. It rises with steady practice, gives partial credit, and dips gently on misses.
- **Smart reminders:** on by default. They follow each habit's schedule, counting down to when it's due, and go quiet once it's done. You can also pick custom days.
- **Two-minute version:** a tiny version of each habit for hard days ("put on running shoes"). Tap "2 min" on the card to keep the day: the streak continues and momentum gets half credit.
- **Streak warnings:** a "Don't miss twice" notification before a miss would end a streak.
- **Calendar:** each day's completion as a ring. You can edit past days to fix a missed log.
- **Categories:** six built in, fully editable, with filter rings that show today's progress.
- **Native feel:** iOS controls, large titles, light/dark/system appearance and haptics. Designed for screens down to the iPhone SE and for large text sizes.

## Run it

Flutter is bundled in `./flutter` (git-ignored; see below).

```bash
./flutter/bin/flutter pub get

# iPhone simulator (Xcode 27: start the device from Xcode's DeviceHub first)
./flutter/bin/flutter run -d "iPhone 17 Pro"

# Other targets
./flutter/bin/flutter run -d macos
./flutter/bin/flutter run -d chrome --web-port=8080 --web-hostname=localhost

# Tests and analysis
./flutter/bin/flutter test
./flutter/bin/flutter analyze

# Notifications: six simulated weeks in four time zones, and a real check on a simulator
tool/notification_sim.sh
tool/device_notification_check.sh "iPhone 17 Pro"
```

Requirements: Xcode with CocoaPods for iOS and macOS. The minimum iOS is 16.

## Project layout

| Path | What's there |
|---|---|
| `lib/domain/` | Entities (Habit, HabitSchedule, StreakData, Momentum, ReminderSettings), use cases, and pure logic: streaks, momentum, reminder and warning planning |
| `lib/data/` | SharedPreferences storage and repositories |
| `lib/presentation/` | Providers (state) and shared widgets |
| `lib/screens/` | Habits, Calendar, Settings, Add/Edit Habit, Categories |
| `lib/core/` | Notifications, dependency injection, theme and style, migrations |
| `test/` | Unit, integration and widget tests, including a small-screen guard |
| `test/simulation/` | Notification simulator: six weeks of the app on a simulated clock, with saved timelines |
| `tool/` | `notification_sim.sh` (simulator in four time zones), `device_notification_check.sh` (real notifications on a simulator) |
| `assets/` | App icon source and the Sora title font |
| `docs/strategy/product-strategy.md` | Positioning, monetization, platform decision and roadmap |

The `swift` branch (checked out at `../atomic-momentum-swift`) holds a SwiftUI fallback. The original HTML/JS prototype lives on the git tag `legacy-web-prototype`.

## Roadmap

See [docs/strategy/product-strategy.md](docs/strategy/product-strategy.md). Next up:
1. Statistics: year heatmap, weekly review, rewards and achievements
2. Onboarding tutorial
3. App Store readiness
