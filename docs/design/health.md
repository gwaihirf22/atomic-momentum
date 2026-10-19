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

## Status (parked 2026-10-19, for the onboarding tutorial)
Paul asked (2026-10-18) to verify Health pedantically and expand it. He chose: when lowering, "Health wins, but say so"; and all four expansions below.

### Done
- **The floor:** −, typing and Calendar stop at Health's number with a notice; weekly and monthly − take from earlier days of the period (75ff1e3).
- **Loose ends found verifying** (b56fde2):
  - Calendar edits mirror to Health;
  - deletes are checked, and water uses a 1-second span;
  - access is re-checked, with "Allow access" on Settings and the habit page;
  - writes are serialized, and a tap during a sync isn't lost;
  - a workout two apps recorded counts once;
  - Android sample data stays within the manifest;
  - "Add sample Health data" sits behind `DevTools.enabled`.
- **Health simulation:** 60 days of invariants, in all four zones through `tool/notification_sim.sh` (189d30a).
- **Device check against the real stores**, passing on iOS and Android; it found Android workouts reading nothing without distance and calories access, now fixed (fc784d7).
- **d9's habit page:** "Sync now" on a linked habit, and an offer to link an unlinked habit whose name suggests a metric, dismissable per habit (24a00be).

### Left, in order
1. **More metrics** (`HealthMetric`, `health_link.dart`):

   | Metric | Unit | Health type |
   |---|---|---|
   | Walking + running distance | km or mi | `DISTANCE_WALKING_RUNNING` |
   | Cycling distance | km or mi | `DISTANCE_CYCLING` |
   | Swimming distance | m or yd | `DISTANCE_SWIMMING` |
   | Flights climbed | flights | `FLIGHTS_CLIMBED` |
   | Active energy | kcal | `ACTIVE_ENERGY_BURNED` |
   | Stand hours | hours (iPhone + Watch only) | `APPLE_STAND_HOUR` |
   | Weight | kg or lb | `WEIGHT` |

   Each needs exact `HealthUnit` conversions, `suggestFor` words, a quick pick where natural, Info.plist and manifest permissions, and availability per platform. Weight is different: it takes the day's latest value, not a sum. It works as "weigh in" (any value counts) or "stay at or under" (with item 3's break rule). Android: check what each plugin read also touches, as workouts do (see `PluginHealthSource.accessTypes`).
2. **Workout types:** an optional `HealthLink.workoutTypes` set (running, strength, yoga, cycling, swimming, HIIT, walking) from `HealthWorkoutActivityType`. Exercise minutes and workouts count only those types. The editor shows type chips, and suggestions come from the name ("Yoga" → yoga).
3. **Break habits from Health:**
   - `HealthMerge` takes Health's amount as the day's slips, the higher number still winning.
   - **Caffeine** (`DIETARY_CAFFEINE`), in mg or cups (95 mg).
   - **Alcoholic drinks:** the `health` package lacks them, so this needs a native channel (`ios/Runner/HealthExtras.swift`, iPhone only).
   - **Lift the `!habit.isBreak` check** on the habit page's Health offer (`_HealthOffer` in `habit_detail_screen.dart`) and in `HealthSection`.
   - **Check-ins** add "Apple Health shows 2 drinks today", keeping d9's vacation skip in `ReminderPlanner` (paused days, and everything while `isOnVacation`).
4. **Background updates** (riskiest; prototype first):
   - **iOS:** `HKObserverQuery` with `enableBackgroundDelivery` for each linked type, plus the entitlement `com.apple.developer.healthkit.background-delivery`. It wakes a headless Flutter entry point (`@pragma('vm:entry-point')`) that runs the sync and save, then the reminder and warning resync, so a finished goal silences today's reminder.
   - **Android:** a `workmanager` task about every 15 minutes, since Health Connect has no push.
   - **Settings:** "Update in the background".
   - **Fallback:** if Dart can't run reliably in the background, use `BGAppRefreshTask` and say it's opportunistic.
   - Rebase onto the widgets work's pbxproj before adding Swift files.
5. **Docs:** CLAUDE.md's Health paragraph, for each of the above.

### Also open
- **iOS device check:** not rerun after `accessTypes` deduplicated the access list (iPhone behaviour is otherwise the same). Run `tool/device_health_check.sh "iPhone 17 Pro"` next time Health changes.
- **Paul's real-iPhone checklist:** [future-improvements.md](../future-improvements.md) §1. It covers what a simulator can't: an Apple Watch, another app's runs, and turning access off.
- **Google Play's Health Connect declaration** must now include distance and total calories (setup checklist above).

## Later
- Accounts and sync between devices (possibly a paid extra; the app is otherwise free). History stays the source of truth, and the per-day "higher wins" rule merges cleanly. This phone's own state (last sync, write log, permissions) stays local. Change timestamps per day will be needed first.
- A badge on habit cards filled in from Health (background delivery is item 4 above).
- **From the other session's year simulation:** raising a target re-scores all past days. Health-linked targets can be raised too, so the same question applies.
