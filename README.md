# Momentum (Atomic Momentum)

A habit tracker built on the ideas in *Atomic Habits*: **momentum, not perfection**. It rewards showing up instead of punishing a missed day.

Built with Flutter for iPhone first, with Android, macOS and web from the same code.

## What it does

- **Habits with flexible schedules:** daily, chosen weekdays, every N days or weeks, monthly (on the day you choose), or a lifetime total. Log progress with the ring, the −/+ stepper, or by typing the number on the habit's page.
- **Build or break:** build a habit up, or break one: quit, or keep it under a limit.
- **Never miss twice:** a streak survives one missed period (the card warns "Don't miss twice"); two misses in a row end it.
- **Momentum score:** 0–100 per habit and overall, in five levels from Building to Atomic. It rises with steady practice, gives partial credit, dips gently on misses, and reaches 80 ("habit formed") in about 66 days.
- **Two-minute version:** a tiny version of each habit for hard days ("put on running shoes"). Tap "2 min" to keep the day: the streak continues and momentum never drops for it.
- **Smart reminders and streak warnings:** on by default. They follow each habit's schedule and go quiet once it's done. A "Don't miss twice" warning comes before a miss would end a streak. There are quiet hours, sounds and time-sensitive alerts.
- **Calendar:** each day's rings; edit past days, or move when a habit started.
- **Insights:** momentum over 6 months, a heatmap of every day (the whole history, pinch to zoom), two-minute days, your week and habits by momentum, plus achievements, celebrated as they're earned. All of it can be shared as designed cards.
- **Habit page:** the day's ring, the week and month, streak, best and momentum, an 8-week trend, the habit's "why" and day notes.
- **Inspire:** the quote of the day from a public-domain library, your own quotes, and quotes kept with a habit.
- **Apple Health and Health Connect:** habits fill in from steps, exercise, sleep and water, and water is logged back.
- **Looks:** Charged (dark), Light and Sepia themes; a choice of app icon (Match system, Charged or Light); a short intro on launch. Designed for screens down to the iPhone SE and for large text sizes.

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

# App icons for iPhone and Android, from assets/branding
python3 tool/make_app_icons.py

# Speed with a long history: profile mode on an Android device
tool/perf_check.sh emulator-5554 [years]
```

Requirements: Xcode with CocoaPods for iOS and macOS, and the Android SDK with Java 17 for Android (see CLAUDE.md, "Platforms"). The minimum iOS is 16.

## Project layout

| Path | What's there |
|---|---|
| `lib/domain/` | Entities (Habit, Momentum, Quote, Category…), use cases, and pure logic: streaks, momentum, insights, achievements, reminder and warning planning |
| `lib/data/` | SharedPreferences storage and repositories |
| `lib/presentation/` | Providers (state), the habit form, Inspire, sharing, the intro and shared widgets |
| `lib/screens/` | Habits, Calendar, Insights, Inspire, Settings, the habit page and editors |
| `lib/core/` | Notifications, Health, app icons, dependency injection, theme and style, migrations |
| `test/` | Unit, integration and widget tests, including a small-screen guard and a performance test |
| `test/simulation/` | The notification simulator (six weeks on a simulated clock) and the year simulator (a scripted year checked every day), with saved timelines |
| `integration_test/` | The year on a real device, and speed in profile mode |
| `tool/` | Notification and year checks, `perf_check.sh`, `make_app_icons.py`, `make_sounds.py` |
| `assets/` | App icon sources and previews, the intro mockup, and the Sora title font |
| `docs/` | [Product strategy](docs/strategy/product-strategy.md), [future improvements](docs/future-improvements.md), and designs for [categories](docs/design/custom-categories.md), [Health](docs/design/health.md), [Inspire](docs/design/inspire.md) and [long history](docs/design/history-compaction.md) |

The `swift` branch (checked out at `../atomic-momentum-swift`) holds a SwiftUI fallback. The original HTML/JS prototype lives on the git tag `legacy-web-prototype`.

## Roadmap

See [docs/strategy/product-strategy.md](docs/strategy/product-strategy.md). Next up:
1. Statistics: the weekly review and rewards (earned freeze and break days)
2. Onboarding tutorial
3. App Store and Google Play readiness

Smaller follow-ups are in [docs/future-improvements.md](docs/future-improvements.md).
