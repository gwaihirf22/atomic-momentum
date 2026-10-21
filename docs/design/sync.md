# Sync between devices

*Decided October 21, 2026. Not built yet: planned for the release that brings iPad.*

## The decision

Momentum syncs **within each platform's own cloud**, with no accounts and no server:
- **iPhone and iPad:** iCloud (CloudKit, the person's private database).
- **Android:** Google Drive's hidden app folder (`appDataFolder`), on the person's own Drive.
- **Off by default.** Settings → Sync turns it on. People who never turn it on are unaffected.
- **Not planned:** syncing between an iPhone and an Android phone. That would need accounts (Sign in with Apple and Google, email) and a hosted service such as Firebase or Supabase. Revisit only if people ask for it.

## Why

- **No server to run or pay for.** The data lives in the person's iCloud or Drive and counts against their storage. The app stays entirely free (no "sync as a paid extra", which the strategy once expected).
- **The privacy promise holds.** The developer never sees anyone's habits, so the privacy label stays "Data Not Collected". Accounts would mean holding people's habit data, including quit and limit habits (smoking, drinking).
- **No sign-in screen on iPhone.** iCloud uses the Apple ID already on the phone. Accounts would also bring Apple's rules: Sign in with Apple whenever Google sign-in is offered (guideline 4.8), and deleting an account from inside the app (5.1.1(v)).
- **It covers almost everyone.** People who sync tend to stay on one platform: an iPhone and an iPad, or an Android phone and tablet.

**Without sync**, a new phone already gets its habits back from a device backup: iCloud Backup restores the app's storage on iPhone, and Android's Auto Backup does the same. Sync is for using two devices side by side.

## What the person sees

- **Settings → Sync**, with one switch: "Sync with iCloud" (iPhone, iPad) or "Sync with Google Drive" (Android, which asks for a Google account the first time).
- **Turning it on** with habits on both devices merges them; nothing is lost and there's no "which copy to keep" question. Without an iCloud account, the row says so and links to the phone's iCloud settings.
- **Status line:** "Synced 2 minutes ago", "Waiting for a connection", or what went wrong in plain words ("iCloud is full").
- **Turning it off** keeps everything on this device. A second choice, "Delete the copy in iCloud", removes the cloud data for every device.
- **An (i) explainer:** where the data goes, that the developer can't see it, and that Health numbers aren't synced (each device reads Health itself).

## What syncs

| Syncs | Stays on the device |
|---|---|
| Habits: definitions, history, two-minute days, day notes, freezes, vacation pauses, a habit's quotes (`atomic_momentum_habits_v2`) | Health's numbers and the app's own Health writes (`health_values_v1`, `health_writes_v1`, `health_last_sync_v1`) |
| Categories (`categories_v1`), habit order and grouping (`habit_order_v1`, `habit_group_by_category_v1`) | Today's quote (`quote_today_v1`) |
| Own quotes and saved quotes (`quotes_mine_v1`, `quotes_saved_v1`) | Tours seen, Replay tours (`tours_seen_v1`, `tours_replay_v1`) |
| The freeze bank (`freeze_bank_v1`, see below) and achievements already celebrated (`achievements_seen_v1`) | Appearance, app icon, launch intro, greetings seen |
| Settings about the habits: week start, day start, default reminder time, streak warnings, quiet hours, sound, weekly review, vacation check-ins, quote sources, Inspire tab | Developer tools (`dev_backup_v1`) |

**Open question:** which settings people expect to follow them. Notifications and quiet hours could reasonably differ between a phone and an iPad. Decide before building; the table is a starting point.

**Apple Health isn't synced.** Apple doesn't allow personal health information in iCloud (guideline 5.1.3). Only what was logged in the app syncs; each device fills in its own numbers from Health, which already syncs itself between iPhone and iPad (Health is on iPad since iPadOS 17). The "higher of Health and what's logged" rule (`HealthMerge`) then gives both devices the same day.

## How changes merge (the hard part)

The cloud only carries records. Each device merges what arrives, so the rules have to give every device the same answer, in any order, after any time offline.

### Records, not one big list

Today every habit is one JSON object inside one key, rewritten whole on each save. Sync needs smaller records, each with when and where it last changed:
- **A habit's settings:** name, target, schedule, color, reminder and the rest. One record per habit; last change wins, field by field (renaming on the iPad doesn't undo a target changed on the phone).
- **A day's log:** one record per habit per day (see "Counting" below).
- **Day notes, two-minute days, freezes, pauses:** one record each, keyed by habit and day.
- **Categories, quotes, order:** one record each; last change wins.
- **Deletions** leave a marker (a tombstone) so a device that was offline doesn't bring the habit back. Markers are kept for 90 days.

This is the same split [history-compaction.md](history-compaction.md) wants for speed (per-day records, settled days archived apart). **Build the two together:** one storage change, not two.

### Counting: both devices' taps add up

Last-writer-wins is wrong for a day's count. Offline, the phone logs 3 glasses and the iPad logs 1. The day should hold 4, not 3 or 1.

So a day's log keeps **each device's contribution**, and the day's total is their sum:
- **+** on a device raises its own contribution; **−** lowers it (a contribution may go negative; the total never shows below 0).
- **Typing a number,** holding the ring, Undo and Calendar edits set the total: the device sets its contribution to the new total minus the others'.
- **Widgets and the lock screen** log through the app (`HomeWidgetSync.applyLogs`), so they're the device's contribution like any tap.

Everything worked out from history (streaks, momentum, Insights, achievements) is recomputed from the merged days, as now. Nothing derived is synced.

### The freeze bank

`FreezeBank` keeps a running count (`available`), and two devices spending offline would each take from the same count. Instead, work it out from what syncs:
- **Earned:** the milestones that added a freeze (`_credited`, merged as a set).
- **Spent:** the habits' frozen days (already synced with the habits); a freeze that came back (`unneededFreezes`) isn't spent.
- **Left:** 3 + earned − spent, at most 5.

**To settle:** the cap makes this depend on order. A milestone earned while the bank was full adds nothing, and that should still hold after merging. The bank's lasting dates (first spent, the rainy-day fund) merge as "earliest wins".

### Versions

A record carries the app's data version. A device running an older version that finds newer records pauses sync and asks to update the app, rather than misreading them.

## How it's built

### iPhone and iPad: CloudKit

- **`CKSyncEngine`** (iOS 17, the app's minimum): Apple's engine for exactly this. It batches, retries, works offline, and wakes the app with silent pushes when another device changes something.
- **Database:** the person's private database, in a custom zone, container `iCloud.com.paulblake.momentum`.
- **Swift, like the widgets:** a small `SyncChannel` in `AppDelegate.swift` (channel `momentum/sync`) hands records between `CKSyncEngine` and Dart. The merge itself is Dart, shared with Android.
- **Xcode:** the iCloud capability (CloudKit) and push notifications on the app's ID (the paid team has both), and the remote-notification background mode.
- **Record types** follow the records above: `Habit`, `DayLog`, `DayMark` (notes, two-minute, frozen), `Pause`, `Category`, `Quote`, `Setting`, `FreezeCredit`.

### Android: Google Drive's app folder

- **Access:** `google_sign_in` with only the `drive.appdata` scope (a hidden folder only this app can see; nothing in the person's Drive). Check whether Google's OAuth verification applies to that scope before building.
- **No server-side merge:** Drive only stores files. Each device writes **its own change log file** and reads the others', so two devices never write the same file.
- **No pushes:** check on launch, on resume, and a few seconds after a change.

### Around the merge

- **After a merge:** the existing paths take over. `HabitProvider` reloads, reminders and warnings are rescheduled (`ReminderService.syncAll`, `StreakWarningService.syncAll`), and the widgets refresh (`HomeWidgetSync`).
- **Achievements:** one earned on another device is celebrated once, not on every device. That's why `achievements_seen_v1` syncs.

## Testing

- **The merge is pure Dart,** so it's tested like the calculators: each rule, then random edits on two or three devices delivered in random orders, offline and late, which must always converge to the same habits.
- **Two devices in the simulator:** two copies of the app on the simulated clock (`test/simulation/`) with a fake cloud between them; the year persona lives its year across a phone and an iPad, and the `Reference` must match on both.
- **On real devices:** an iPhone and an iPad simulator signed into one iCloud account (or Paul's phone and an iPad), and two Android emulators on one Google account.

## Order of work

1. **Storage as records** (with [history-compaction.md](history-compaction.md)), migrated from today's one-key list. Nothing visible changes.
2. **The merge engine** in Dart, with its tests and the two-device simulation.
3. **iCloud:** `CKSyncEngine`, Settings → Sync, and the explainer. Ships with iPad.
4. **Google Drive** for Android.
5. **Privacy:** add a paragraph to the privacy policy (paul-blake.com/momentum/privacy and `docs/store/privacy-policy.md`) on where synced data lives. Recheck the App Store privacy answers and Google Play's Data safety form, which should stay "not collected", since the developer can't read it.

Steps 1 and 2 are most of the work. The cloud parts are small by comparison.
