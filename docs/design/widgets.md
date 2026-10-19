# Home screen widgets

*Started October 18, 2026. Phase 1 built (one habit, momentum, today); phases 2 and 3 to come.*

Paul wants all six kinds from the mockups (artifact `6FUeW7KVC4sjHMMyDadGac`, one board per kind). They're built in three phases, by how often people would look at them and what each needs underneath:

| Phase | Widgets | Status |
|---|---|---|
| 1 | The plumbing; **One habit** (small, medium; + logs from the home screen); **Momentum** (small, medium; lock screen round, rectangle, line); **Today** (lock screen round: "3/6") | Built |
| 2 | **A group of habits** (large "Today" list with a + per row; four rings; 2×2); **Quote** (the day's quote, a habit's quotes, lock screen) | To do |
| 3 | **Insights** (today, this week, heatmaps, the month); **I will** (a habit's Story sentence, your own words) | To do |

## How it works

```
 App (Flutter)                          App Group                     Widget extension (SwiftUI)
 HomeWidgetSync ──snapshot JSON──▶  widget_snapshot_v1  ──────────▶  Snapshot.load() → views
      ▲                                                                   │ + tapped
      │ takeLogs / applied                                                ▼
 AppDelegate WidgetChannel ◀──────  widget_logs_v1  ◀──── LogHabitIntent (runs in the app's process)
```

- **The app works everything out.** `WidgetSnapshot` (`lib/presentation/home_widgets/widget_snapshot.dart`) turns the habits into the numbers and words the widgets show: progress, "5 of 8 glasses", the next step for +, streak, momentum, the last 7 periods, today's count, the quote, and the app's palette for the phone's light and dark mode. The widgets only lay it out, so they always agree with the app. Swift reads it in `ios/MomentumWidgets/Snapshot.swift`: keep the two in step, and bump `WidgetSnapshot.version` for a change older widgets can't read.
- **When it's written.** `HomeWidgetSync` (started by `HomeWidgetHost` in `main.dart`) listens to the habits, settings, theme and quotes, and writes 400 ms after a change, only if something the widgets show changed. Never before habits load, or after a failed load.
- **The + on a widget.** `LogHabitIntent` (`ios/MomentumWidgets/Shared/`) queues the tap in the App Group, shows the step at once (`WidgetStore.showStep`, the same steps as `StepSize.up`), then has the app log it. It's an `AudioPlaybackIntent`, so iOS runs it in the app's process, starting the app in the background if needed. The app takes the queue (`HomeWidgetBridge.takeLogs`) and logs each tap the way the card's + does (`HabitProvider.updateHabitProgress`; for a tap made before midnight, `updateProgressForDate` on that day). So streaks, momentum, Health, reminders and streak warnings all follow. Then it rewrites the snapshot and lets the intent finish (`applied`; the intent gives up after 8 s, and the tap stays queued for the next launch or resume).
- **No + on habits being broken.** A stray tap would log a slip.
- **Tapping a widget** opens `momentum://habit/<id>`; the app shows that habit the way a reminder's tap does (`NotificationService.focusRequests`).
- **Looks.** Widgets follow the app's Appearance setting: under System, the day theme (Light or Sepia) in light mode and Charged in dark mode; a chosen theme in both. The lock screen draws in one tint (iOS), so its widgets use no theme colors.
- **A new period.** Each entry knows when its habit's period ends (`periodEnds`); from then the widget shows it starting over, until the app writes again.

## Pieces

| Where | What |
|---|---|
| `lib/core/services/home_widget_bridge.dart` | `HomeWidgetBridge` (channel `momentum/widgets`), `WidgetLog`; tests use `FakeHomeWidgetBridge` |
| `lib/presentation/home_widgets/` | `WidgetSnapshot`, `HomeWidgetSync`, `HomeWidgetHost` |
| `ios/Runner/AppDelegate.swift` | `WidgetChannel`: save, takeLogs, applied, takeOpenedHabit; momentum:// links |
| `ios/MomentumWidgets/Shared/` | In both targets: `WidgetStore` (App Group keys, the queue, `showStep`), `LogHabitIntent`, `AppHook` |
| `ios/MomentumWidgets/` | The extension: `MomentumWidgetsBundle`, `HabitWidget` (with `PickHabitIntent`/`HabitEntity` to pick the habit), `MomentumWidget` and `TodayWidget`, `Pieces` (ring, gauge, orb, streak, last 7), Sora fonts |

**Xcode:** target `MomentumWidgets`, bundle id `com.paulblake.momentum.widgets`, iOS 17+ (the app stays iOS 16; iOS 16 phones just don't offer the widgets). Its version comes from Flutter through `MomentumWidgets/Widgets.xcconfig`. The app embeds it in "Embed Foundation Extensions", placed before Flutter's "Thin Binary" phase (after it, the build has a cycle). **App Group** `group.com.paulblake.momentum` on both targets, which needs a team that can sign App Groups (the paid account).

## Testing

- `test/unit/presentation/home_widgets/widget_snapshot_test.dart`: the snapshot's numbers and words.
- `test/integration/home_widget_sync_test.dart`: writing, taps logged through the real provider and storage, taps before midnight, done and broken habits, launch-time taps, looks, opening a habit.
- **On a simulator:** the dedicated "Widgets iPhone 17 Pro" simulator (not the Year ones or the ones other sessions use). Build with `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -destination 'id=<sim>' build`. Then hold the home screen, choose Edit → Add Widget → Momentum, and check what the App Group holds: `xcrun simctl get_app_container <sim> com.paulblake.momentum group.com.paulblake.momentum`.

## Later

- **Phase 2 and 3 widgets** (above). The quote is already in the snapshot.
- **"2 min" on the medium habit widget** (a second intent through `setTwoMinute`).
- **Android app widgets**, from the same snapshot.
- **Fresh numbers without opening the app:** a background refresh (BGTaskScheduler) to roll the day over and recompute momentum. Until then a new day shows progress starting over, and momentum as of the app's last write.
- **App Review:** the + relies on `AudioPlaybackIntent` to run in the app's process (as `home_widget` and other apps do). If Review objects, the tap still queues and the app logs it at its next launch; only reminders for that habit would wait until then.
