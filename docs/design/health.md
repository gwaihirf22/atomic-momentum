# Health: habits that fill themselves in

## What it does
- **Reading.** A habit being built can be linked to one Health metric, and Health fills it in. The habit's units follow the metric, and steps allow a target up to 100,000.

  | Metric | Counts in | iPhone | Android |
  |---|---|---|---|
  | Steps | steps | ✓ | ✓ |
  | Exercise | minutes: the higher of Apple's Exercise minutes (Watch only) and the time in workouts any app logged (on Android, workout time) | ✓ | ✓ |
  | Workouts | workouts started that day | ✓ | ✓ |
  | Sleep | hours or minutes | ✓ | ✓ |
  | Mindful minutes | minutes or hours | ✓ | not offered through the package |
  | Water | glasses (250 ml), ml, fl oz or cups (8 oz) | ✓ | ✓ |

- **Writing.** Water and mindful minutes can also log back. Each + writes the amount added to Health. A − takes back what the app wrote that day, newest first. If what's being removed came from Health itself (another app, or the Watch), the app says "That came from Apple Health. Change it there." and Health's number comes back.

## Choosing the right link
- **Suggestions.** The editor suggests a metric from the habit's name: "Run", "Gym" or "Yoga" suggest Exercise, "Walk" suggests Steps, and so on. Nothing is linked without a tap.
- **Live preview.** Once a metric is chosen, the editor shows what Health holds today ("Apple Health shows 4,512 steps today"), or that it has nothing yet. A wrong link is visible before saving.
- **Quick picks come linked:** Walk (8,000 steps), Run (30 min exercise), Meditate (10 mindful minutes, iPhone), Sleep (7 hours) and Drink water (8 glasses). Where the phone can't fill them in, they're plain habits.
- **Targets** go to 100,000 for every habit; + and − step by the target's size.

## Rules
- **The higher number wins.** For each day, the app keeps the higher of what was logged and what Health says. Health never lowers a day, and taps still count on days Health missed.
- **Health's number is the floor** (Paul's choice, "Health wins, but say so"). − , typing and Calendar stop at what Health last said for that day (`HealthSyncService.floorOn`, from `health_values_v1`), less the app's own writes for water and mindful minutes, and say so: "Apple Health shows 8,412 steps today. Change it in Apple Health." A lower number is never put back silently by the next sync. For weekly and monthly habits, − takes from today first, then from the latest earlier day of the period, each day stopping at its own floor.
- **Window.** Each sync looks at the last 7 days, never before the day the habit was linked and never before it started counting. Values are clamped so no period goes past what it can hold (10 × the target).
- **Sleep** counts on the morning you wake: asleep time from 6 PM the evening before to 6 PM that day, in minutes, then in the habit's unit (hours round to the nearest). Overlapping records (iPhone and Watch) count once, and so do overlapping exercise and mindful sessions.
- **Units.** Health gives exact amounts in a base unit per metric: steps, workouts, minutes (exercise, sleep, mindful) or ml (water). A linked habit counts in a `HealthUnit` chosen from a short list. Each unit is an exact number of base units (a glass is 250 ml, a fl oz 29.5735 ml, a cup 236.588 ml, an hour 60 minutes) and converts both ways, rounding to whole units only at the end. The units field is never free text while linked.
- **Linking a habit that has units.**
  - If its units are ones the metric knows ("ml", "oz", "minutes"), they're kept with its target, so nothing needs converting.
  - If they aren't ("bottles", or none), it takes the metric's usual unit and default target. The editor then says so ("'bottles' isn't a unit Apple Health counts in…"), and past days stay as they were.
  - Choosing another unit converts the target, and past days convert too on save (8 glasses becomes 2000 ml; `UpdateHabitParams.historyScale`).
- **Writing back.** + logs the exact base amount (10 fl oz is 296 ml). The app's write log keeps base amounts, so − takes back exactly what was written.
- **When it syncs:**
  - when the app opens
  - on resume, at most once a minute
  - at midnight
  - right after a habit is linked (from its first sync)
  - from Settings → Sync now
- Numbers that came from Health are never written back to it.

## Code
- **Entities:** `HealthLink` / `HealthMetric` (`domain/entities/health_link.dart`); `Habit.health` (JSON `health`).
- **Pure logic:** `HealthDays` and `HealthMerge` (`domain/services/health_days.dart`).
- **Platform:** `HealthSource` / `PluginHealthSource` (`core/services/health_source.dart`, package `health`). Tests use `FakeHealthSource`. On Android the plugin reads each workout's distance, calories and steps with it, and fails the whole read without access to them, so `PluginHealthSource.accessTypes` asks for those too.
- **Syncing and writing:** `HealthSyncService` (`core/services/health_sync_service.dart`). It handles syncs and the write log (`health_writes_v1`, kept 8 days).
- **UI:** `HealthSection`, `HealthSettingsSection`, the habit page line, and `InfoTopic.health`.

## Setup checklist (Paul)
1. **Apple Developer:** turn on HealthKit for App ID `com.paulblake.momentum`. In Xcode, check that Runner → Signing & Capabilities shows HealthKit; the entitlement file already has it.
2. **App Store Connect:** declare health data in App Privacy (used for app functionality, not linked to identity, not used for tracking).
3. **Privacy policy:** publish one and link it in both stores. Health Connect's "why" screen opens the app (the `ViewPermissionUsageActivity` alias); a policy page in the app can come later.
4. **Google Play Console:** fill in the Health Connect permissions declaration (steps, exercise, sleep, hydration, distance and total calories read; hydration write) before release. Distance and calories are read only because the `health` package reads them with every workout.
5. **Android:** minSdk is now 26 (Android 8), which Health Connect needs.

## Testing on a device
`tool/device_health_check.sh "<simulator or emulator>"` runs `integration_test/health_on_device_test.dart` against the real store: Apple Health on an iPhone simulator (tap Allow the first time), Health Connect on an Android emulator (the script grants the permissions; debug builds may write steps, workouts and sleep, `src/debug/AndroidManifest.xml`). It writes steps, a nap, a run and a copy of it from "another app" into 02:00–03:00 yesterday and checks every metric reads back by the app's rules, writes and takes back water and mindful minutes, runs `HealthSyncService.logChange` both ways on today, then deletes its samples and checks Health is back where it started. Storage is in memory, and the real app is reinstalled afterwards.
- Passed on iPhone 17 Pro (iOS) and Year_Pixel (Android 16) on 2026-10-19.
- **Android:** Health Connect's daily steps total counts only apps on its data-source priority list. A shell grant doesn't add the test app to it, so there the test checks the record is stored and that the app reads exactly Health Connect's total. Real step apps (Fit, a watch) are on that list.
- **Android:** a Health Connect permission screen left open in the app's task takes every launch (Android delivers the launch to that screen and never starts the app), so the script closes Health Connect's screens first.

## Testing by hand
- **iPhone simulator:** a simulator can't record a run, and its Fitness app tends to crash. In a debug build, Settings → Apple Health → **Add sample Health data** writes a 30-minute run, steps, last night's sleep, mindful minutes and water. Allow writing when asked.
  1. Or add data by hand in the Health app, under Browse → Steps (or Sleep, Water) → Add Data.
  2. In Momentum, link a habit and allow access.
  3. Check that it fills in today and the days since linking.
- **Android:** use an emulator with the Health Connect app installed.

## Later
- Accounts and sync between devices (possibly a paid extra; the app is otherwise free). History stays the source of truth, and the per-day "higher wins" rule merges cleanly. This phone's own state (last sync, write log, permissions) stays local. Change timestamps per day will be needed first.
- Background delivery (filling in without opening the app), and a badge on habit cards.
- **From the other session's year simulation:** raising a target re-scores all past days. Health-linked targets can be raised too, so the same question applies.
