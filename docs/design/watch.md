# Apple Watch

*Proposed October 26, 2026; **built October 27** on `plus`, for 1.1 (mockups: artifact `9abHpkxgwsjBy32pavyc7J`). Paul's decisions: the basics are free and Plus adds more; everything in the design ships in the first build. Not yet tried on a real watch (see "Testing").*

The watch is where a habit gets logged in two seconds: raise the wrist after a run, after a glass of water, after ten minutes of reading. It doesn't replace the phone. It shows today, takes a tap, and tells you where your momentum stands.

## What it does

| Screen | What's on it |
|---|---|
| **Today** (the app's first screen) | Today's habits as a list, each with its ring, "5 of 8", and a **+** that logs one step (`StepSize.up`, as the card's + does). Habits done today sink to the bottom with a check. A habit being broken shows "Clean today" / "1 slip today" and no + (a stray tap would log a slip; slips are logged on the phone). At the top, "3 of 6 done" and, when every habit is kept, the gold "All done" ring. |
| **A habit** (tap a row) | The big ring with its number; the Digital Crown sets the amount (stopping at the target, as + does, and at Health's floor for a linked habit); **2 min** when it has a two-minute version; streak and "Don't miss twice" when at risk; the last 7 periods as bars. |
| **Momentum** (swipe from Today) | The overall ring with its level (Building … Atomic), the 7-day trend arrow, and "12 to Unstoppable". |
| **Complications** | Circular: today's count ("3/6") or one habit's ring; rectangular: one habit's name, ring and streak; corner: momentum's gauge; inline: "Momentum 74 · Strong". The Smart Stack gets a relevant widget: the habit due soonest, or "Don't miss twice" on a day that would end a streak. |
| **Notifications** | Reminders and "Don't miss twice" already reach the watch (iOS mirrors them). 1.1 adds a **Log** action to a reminder, so "Time to drink water" can be answered from the wrist. |

Not on the watch: adding or editing habits, Insights, Inspire, Settings, freezes, vacation mode. (No "Open on iPhone": watchOS has no way to open the iPhone app.)

## How it works

```
 iPhone app (Flutter)                                  Watch app (SwiftUI, watchOS 10+)
 HomeWidgetSync ─ snapshot JSON ─▶ WatchConnectivity ─▶ applicationContext → Snapshot → views
      ▲                                                       │ + / Crown / 2 min
      │ applyLogs (as a widget's +)                           ▼
 AppDelegate WatchChannel ◀── transferUserInfo(log) ◀── queued logs (shown at once)
```

- **The snapshot is the source.** The watch draws the same `WidgetSnapshot` the widgets draw (habits, steps, rings, streaks, momentum, today's count, the palette), so it always agrees with the phone and the widgets. `ios/MomentumWidgets/Snapshot.swift`, `Shared/WidgetStore.swift` and `Pieces.swift` are compiled into the watch app and its complications too (`HabitEntity.swift` into the complications).
- **Getting it there.** The phone sends the snapshot with `WCSession.updateApplicationContext` each time `HomeWidgetSync` writes it (the latest replaces the last, delivered when the watch wakes). A watch with no phone nearby shows the last one, with the period ends the snapshot already carries so a new day starts over on time.
- **Logging back.** A tap on the watch is shown at once (`WidgetStore.showStep`, `showSet`, `showTwoMinute`), then sent: as a message when the phone is reachable (at once, waking the iPhone app), else with `transferUserInfo` (guaranteed, in order, delivered when it is). The phone's `WatchLink` (`ios/Runner/WatchLink.swift`) takes each log once by its id (`watch_logs_seen_v1`) into the widgets' queue (`widget_logs_v1`): the running app applies it (`AppHook.logsWaiting` → `HomeWidgetSync.applyLogs`), a closed one through a background engine (`BackgroundRun.run("watch")`, no Health read), and one opening on screen as it loads. Streaks, momentum, Health, reminders and warnings follow, exactly as for a widget. Taps from before midnight go on that day (each log carries its day).
- **The Crown and 2 min** are two more log kinds (`WidgetLogKind`): `set` (with `amount`, the period's total) and `twoMinute`. `HomeWidgetSync._apply` sets today's total as the card does, or an earlier day's own amount by the difference, never past the target (or what's already over it) and never below Apple Health's number (the snapshot's `floor`); 2 min goes through `setTwoMinute`. Habits being broken take none of them. Widgets keep sending plain steps.
- **The phone asleep or the app not running.** `WatchLink.start()` runs in `didFinishLaunching` (not the engine callback), so a log that launched the app in the background is taken; a background engine applies it and writes the snapshot, which goes back to the watch.
- **A reminder's Log button.** Reminders and "Don't miss twice" of habits being built carry category `habit_reminder_log` with a background "Log" action (`PlannedReminder.canLog`, never for a habit being broken); iOS shows it on the watch too. `AppDelegate.userNotificationCenter(_:didReceive:)` takes it natively and hands one step to `WatchLink.deliver`, the same path as the watch's taps (no second Dart isolate).
- **Plus (decided October 27): the basics are free, Plus adds more.** For everyone: Today with its rings and +, every complication, and a reminder's Log button. With Plus: a habit's own screen (the Crown, 2 min) and the Momentum page; the Smart Stack brings up "Don't miss twice" only with Plus. Without Plus, tapping a habit or swiping to Momentum shows what comes with Plus (`PlusLockedView`). The watch reads the snapshot's `plus`, which background runs now keep too (they used to write `false`).
- **Looks.** The watch is always dark: Charged's colors on true black, the habit colors drawn with the Dark palette's lift (`palette.habitColor`), already in the snapshot.

## What was built

- **Targets** (added by `tool/add_watch_targets.rb`, the xcodeproj gem that ships with CocoaPods; run once): `MomentumWatch` (`com.paulblake.momentum.watchkitapp`, a single-target watchOS 10 app, `WKCompanionAppBundleIdentifier` in its own Info.plist so `flutter build` treats it as a companion) and `MomentumWatchWidgets` (`…watchkitapp.widgets`, the complications), both `SUPPORTED_PLATFORMS = watchos watchsimulator` so the iPhone build makes them for watchOS, versions from `MomentumWatch/Watch.xcconfig`, entitlements through `WATCH_ENTITLEMENTS` / `WATCH_WIDGETS_ENTITLEMENTS` (`tool/install_on_iphone.sh` sets them with `FULL_ENTITLEMENTS=1`). Runner embeds the watch app in "Embed Watch Content", before Flutter's Thin Binary. The icon is Charged (`tool/make_app_icons.py`, `WATCH`).
- **Watch app** (`ios/MomentumWatch/`): `WatchModel` (the session, the snapshot in the watch's App Group, sending logs, "Not on your iPhone yet" after an hour), `TodayView` (header, rows, + ; done ones last; "Not today" for the rest), `HabitView` (Plus: the ring, the Crown between `floor` and the target, settling 0.7 s before it logs, 2 min, streak, the last 7 bars), `MomentumPage` (Plus), `PlusLockedView`. Debug builds take `-momentumTest step/<habit name>` (or `set/6/<name>`, `twoMinute/<name>`, `open/<name>`) at launch, since a simulator can't be tapped from the command line.
- **Complications** (`ios/MomentumWatchWidgets/WatchComplications.swift`): Today (circular "3/6", corner, inline), Momentum (circular gauge, corner with the gauge along the screen's curve, inline "Momentum 74 · Strong", rectangular), Habit (picked through `HabitEntity`, with a recommendation per habit, as watch faces need; circular, corner, inline, rectangular) and Next up (the Smart Stack: the habit to do next, "Don't miss twice" first, relevant only with Plus). A tap opens the app (on the habit, `momentum://habit/<id>`). No + on complications: a watch widget can't reach the phone itself.
- **Tests:** Dart for the log kinds (`widget_log_test`, `home_widget_sync_test`), the snapshot's fields (`widget_snapshot_test`), a background run woken by the watch keeping Plus (`background_main_test`), and the Log button (`notification_service_test`, `reminder_planner_test`).

## Testing

- **Simulators:** "Momentum Watch" (Apple Watch Series 11 46 mm, watchOS 27.0, `3EA42732-…`) is paired with the "iPhone 17 Pro" simulator. `flutter build ios --simulator -d <iPhone>` (a device id is needed with a watch companion), `simctl install` the iPhone app, then the watch app from `Runner.app/Watch/`, and launch the iPhone app once more so it sees the watch app. Checked there: the phone's habits on the watch; a + from the watch logged on the phone ("1/10 minutes"); the Plus screens locked without Plus.
- **The simulators' relay is unreliable** (Xcode 27.1): watch-to-phone messages sometimes stop at the phone's daemon ("XPC has informed us that a fatal error has occured") until the pair is unpaired and paired again (`xcrun simctl unpair`, `pair`, boot the watch).
- **Still to try on Paul's watch:** the Crown, 2 min, complications on a face, the Smart Stack, a reminder's Log from the wrist, and a tap with the iPhone app closed.

## What Paul needs to do

- **Signing, once, in Xcode** (the command line can't use his account): open `ios/Runner.xcworkspace`, select the `MomentumWatch` target → Signing & Capabilities (team 9EWP23T2HE, automatic) and let Xcode register `com.paulblake.momentum.watchkitapp` with App Groups (`group.com.paulblake.momentum`); the same for `MomentumWatchWidgets` (`…watchkitapp.widgets`). Then `FULL_ENTITLEMENTS=1 DEV_TOOLS=1 tool/install_on_iphone.sh` builds with the watch.
- **His Apple Watch** (paired with the 15 Pro Max): Developer Mode on (Settings → Privacy & Security on the watch, after the first install attempt), then the Watch app on the iPhone installs Momentum (or it installs by itself with automatic installs on).
- **Store (1.1):** watch screenshots (Series 11 46 mm and Ultra), a line in the listing.

## Open questions

- The Crown stops at the target, like + (or at what's already logged over it).
- With no iPhone near, taps wait in the queue; Today says "Not on your iPhone yet" after an hour.
- Health: a linked habit fills in from Health on the phone; the watch shows what the phone last sent. Reading Health on the watch directly would be fresher but doubles the Health code. Proposed: not in 1.1.
