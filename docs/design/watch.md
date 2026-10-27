# Apple Watch

*Proposed October 26, 2026, for 1.1. Not built: waiting for Paul's review of the mockups (artifact `9abHpkxgwsjBy32pavyc7J`: the app's three screens, faces and complications, a reminder's Log button, the screen without Plus).*

The watch is where a habit gets logged in two seconds: raise the wrist after a run, after a glass of water, after ten minutes of reading. It doesn't replace the phone. It shows today, takes a tap, and tells you where your momentum stands.

## What it does

| Screen | What's on it |
|---|---|
| **Today** (the app's first screen) | Today's habits as a list, each with its ring, "5 of 8", and a **+** that logs one step (`StepSize.up`, as the card's + does). Habits done today sink to the bottom with a check. A habit being broken shows "Clean today" / "1 slip today" and no + (a stray tap would log a slip; slips are logged on the phone). At the top, "3 of 6 done" and, when every habit is kept, the gold "All done" ring. |
| **A habit** (tap a row) | The big ring with its number; the Digital Crown sets the amount (stopping at the target, as + does, and at Health's floor for a linked habit); **2 min** when it has a two-minute version; streak and "Don't miss twice" when at risk; the last 7 periods as bars. |
| **Momentum** (swipe from Today) | The overall ring with its level (Building … Atomic), the 7-day trend arrow, and "12 to Unstoppable". |
| **Complications** | Circular: today's count ("3/6") or one habit's ring; rectangular: one habit's name, ring and streak; corner: momentum's gauge; inline: "Momentum 74 · Strong". The Smart Stack gets a relevant widget: the habit due soonest, or "Don't miss twice" on a day that would end a streak. |
| **Notifications** | Reminders and "Don't miss twice" already reach the watch (iOS mirrors them). 1.1 adds a **Log** action to a reminder, so "Time to drink water" can be answered from the wrist. |

Not on the watch: adding or editing habits, Insights, Inspire, Settings, freezes, vacation mode. A long press on Today offers "Open on iPhone".

## How it works

```
 iPhone app (Flutter)                                  Watch app (SwiftUI, watchOS 10+)
 HomeWidgetSync ─ snapshot JSON ─▶ WatchConnectivity ─▶ applicationContext → Snapshot → views
      ▲                                                       │ + / Crown / 2 min
      │ applyLogs (as a widget's +)                           ▼
 AppDelegate WatchChannel ◀── transferUserInfo(log) ◀── queued logs (shown at once)
```

- **The snapshot is the source.** The watch draws the same `WidgetSnapshot` the widgets draw (habits, steps, rings, streaks, momentum, today's count, the palette), so it always agrees with the phone and the widgets. `Snapshot.swift` and its pieces already live in `ios/MomentumWidgets/Shared/`; the watch target compiles them too.
- **Getting it there.** The phone sends the snapshot with `WCSession.updateApplicationContext` each time `HomeWidgetSync` writes it (the latest replaces the last, delivered when the watch wakes). A watch with no phone nearby shows the last one, with the period ends the snapshot already carries so a new day starts over on time.
- **Logging back.** A tap on the watch is shown at once (the same `WidgetStore.showStep` arithmetic), queued, and sent with `transferUserInfo` (guaranteed, in order, even if the phone is away). The phone's `WatchChannel` takes them into the same queue as the widgets' + (`widget_logs_v1`) and calls `HomeWidgetSync.applyLogs`, so streaks, momentum, Health, reminders and warnings all follow, exactly as for a widget. Taps from before midnight go on that day (each log carries its time).
- **The Crown and 2 min** need two more log kinds besides "one step": "set to N" and "two-minute". The queue's JSON gains a `kind`; `applyLogs` handles them through `HabitProvider.updateProgressForDate` and `setTwoMinute`. Widgets keep sending plain steps.
- **The phone asleep or the app not running.** `WCSession` wakes the iPhone app in the background for `transferUserInfo`; with the scene lifecycle, `AppDelegate` activates the session in `didFinishLaunching` (not the engine callback), keeps the logs, and Flutter takes them at the next launch or resume, as widget taps are taken now.
- **Plus or free: undecided** (Paul, October 27). Two ways, and the build is nearly the same for both, because the snapshot's `plus` field already tells the watch which it is (notifications reach the watch for everyone either way):
  - **All Plus, as part of sync:** the watch is one more of your devices kept in step, like the iPad. Without Plus it shows one screen, "The Apple Watch app comes with Momentum Plus", with "Open on iPhone".
  - **Basic watch free, Plus adds more:** for everyone: Today with its rings and +, the complications, and a reminder's Log action. With Plus: a habit's own screen (the Crown, 2 min), the Momentum screen and the Smart Stack's "Don't miss twice". The split is a proposal for Paul to change.
- **Looks.** The watch is always dark: Charged's colors on true black, the habit colors drawn with the Dark palette's lift (`palette.habitColor`), already in the snapshot.

## Building it

1. **Xcode:** a watchOS App target `MomentumWatch` (`com.paulblake.momentum.watchkitapp`), watchOS 10, embedded in Runner ("Embed Watch Content"), with the Shared folder in its sources, and a widget extension target for its complications (`com.paulblake.momentum.watchkitapp.widgets`). Version from an xcconfig like `Widgets.xcconfig`.
2. **Phone side:** `WatchChannel` in `AppDelegate.swift` (`WCSessionDelegate`): send the snapshot on save, take logs; Dart: `HomeWidgetBridge` gains nothing (the snapshot it saves is sent as is), `applyLogs` learns the new kinds.
3. **Watch side:** SwiftUI views (`TodayView`, `HabitView`, `MomentumView`), the log queue, the complications (WidgetKit on watchOS, sharing the lock screen widgets' views where they fit).
4. **Tests:** Dart for the new log kinds and their dates; the Swift builds for the watch simulator; a hand check on a paired watch simulator (Xcode makes one with the iPhone 17 Pro) and on Paul's watch.
5. **Store:** watch screenshots (Series 11 46 mm and Ultra 3), a line in the listing, and the review notes.

## What Paul needs to do

- **Apple Developer:** the watch app's App ID (`com.paulblake.momentum.watchkitapp`) and its widgets' (`…watchkitapp.widgets`), each with App Groups (`group.com.paulblake.momentum`); Xcode's automatic signing can make them once the target exists, signed in with the paid team.
- **A watch to test on**, paired with the iPhone 12 Pro (Developer Mode on the watch too).
- **Decide:** the watch all Plus (part of sync), or a free basic watch with Plus adding more (see "Plus or free" above). Free basics would make the app's best quick-logging story available to everyone; all Plus keeps it with the iPad as "more devices".

## Open questions

- Should the Crown be able to go past the target as typing on the phone can (`Habit.maxOverTarget`)? Proposed: no, stop at the target like +.
- Watch-only logging with no iPhone near for days: the queue keeps everything; is a "Not synced yet" mark worth showing? Proposed: a small dot on Today after an hour unsent.
- Health: a linked habit fills in from Health on the phone; the watch shows what the phone last sent. Reading Health on the watch directly would be fresher but doubles the Health code. Proposed: not in 1.1.
