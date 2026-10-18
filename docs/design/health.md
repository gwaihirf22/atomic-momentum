# Health: habits that fill themselves in

## What it does
- **Reading.** A habit being built can be linked to one Health metric, and Health fills it in. The habit's units follow the metric, and steps allow a target up to 100,000.

  | Metric | Counts in | iPhone | Android |
  |---|---|---|---|
  | Steps | steps | ✓ | ✓ |
  | Exercise | minutes (Exercise time; on Android, workout durations) | ✓ | ✓ |
  | Workouts | workouts started that day | ✓ | ✓ |
  | Sleep | hours | ✓ | ✓ |
  | Mindful minutes | minutes | ✓ | not offered through the package |
  | Water | 250 ml glasses | ✓ | ✓ |

- **Writing.** Water and mindful minutes can also log back. Each + writes the amount added to Health. A − takes back what the app wrote that day, newest first. If what's being removed came from Health itself (another app, or the Watch), the app says "That came from Apple Health. Change it there." and Health's number comes back.

## Rules
- **The higher number wins.** For each day, the app keeps the higher of what was logged and what Health says. Health never lowers a day, and taps still count on days Health missed.
- **Window.** Each sync looks at the last 7 days, never before the day the habit was linked and never before it started counting. Values are clamped so no period goes past what it can hold (10 × the target).
- **Sleep** counts on the morning you wake. Asleep time from 6 PM the evening before to 6 PM that day is added up and rounded to the nearest hour. Overlapping records (iPhone and Watch) count once, and so do overlapping exercise and mindful sessions.
- **Water.** Liters ÷ 0.25, rounded, gives glasses.
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
- **Platform:** `HealthSource` / `PluginHealthSource` (`core/services/health_source.dart`, package `health`). Tests use `FakeHealthSource`.
- **Syncing and writing:** `HealthSyncService` (`core/services/health_sync_service.dart`). It handles syncs and the write log (`health_writes_v1`, kept 8 days).
- **UI:** `HealthSection`, `HealthSettingsSection`, the habit page line, and `InfoTopic.health`.

## Setup checklist (Paul)
1. **Apple Developer:** turn on HealthKit for App ID `com.paulblake.momentum`. In Xcode, check that Runner → Signing & Capabilities shows HealthKit; the entitlement file already has it.
2. **App Store Connect:** declare health data in App Privacy (used for app functionality, not linked to identity, not used for tracking).
3. **Privacy policy:** publish one and link it in both stores. Health Connect's "why" screen opens the app (the `ViewPermissionUsageActivity` alias); a policy page in the app can come later.
4. **Google Play Console:** fill in the Health Connect permissions declaration (steps, exercise, sleep, hydration read; hydration write) before release.
5. **Android:** minSdk is now 26 (Android 8), which Health Connect needs.

## Testing by hand
- **iPhone simulator:**
  1. In the Health app, add data under Browse → Steps (or Sleep, Water) → Add Data.
  2. In Momentum, link a habit and allow access.
  3. Check that it fills in today and the days since linking.
- **Android:** use an emulator with the Health Connect app installed.

## Later
- Accounts and sync between devices (Pro). History stays the source of truth, and the per-day "higher wins" rule merges cleanly. This phone's own state (last sync, write log, permissions) stays local. Change timestamps per day will be needed first.
- Quick picks that come linked (Walk 8,000 steps, Sleep 7 hours).
- Background delivery (filling in without opening the app), and a badge on habit cards.
- **From the other session's year simulation:** raising a target re-scores all past days. Health-linked targets can be raised too, so the same question applies.
