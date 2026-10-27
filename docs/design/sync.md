# Sync between devices

*Decided October 21, 2026. Reworked October 25, 2026: sync is the first part of **Momentum Plus** (see [../strategy/product-strategy.md](../strategy/product-strategy.md), §2), built on the `plus` branch. It ships with the iPad app.*

**Status (2026-10-25, `plus`):** steps 1–5 below are built and tested (the merge, recording and applying, `SyncService`, Settings → Sync behind Developer tools, `CloudSync.swift`). **Tried on real iCloud 2026-10-26** (development environment): Paul's iPhone 15 Pro Max and iPad Pro, both installed with `FULL_ENTITLEMENTS=1 DEV_TOOLS=1 tool/install_on_iphone.sh <device id>`; turning sync on on the iPad brought all 8 habits over (the iPad then asked for its own Health permission, as each device reads its own Health). TestFlight and App Store builds use CloudKit's production environment, separate from development: deploy the schema there (CloudKit Console → Deploy Schema Changes) before a TestFlight build with sync. Left for later: offering to combine same-named habits when joining, and the Keychain copy of the device id (restores are caught by comparing records instead).

## The decision

Momentum syncs **within each platform's own cloud**, with no accounts and no server:
- **iPhone and iPad:** iCloud (CloudKit, the person's private database).
- **Android:** Google Drive's hidden app folder (`appDataFolder`), on the person's own Drive.
- **Off by default,** and part of Momentum Plus: Settings → Momentum Plus → "Sync with iCloud" turns it on once Plus is bought (sync already on stays on whatever happens to the purchase).
- **Not planned:** syncing between an iPhone and an Android phone. That would need accounts (Sign in with Apple and Google, email) and a hosted service such as Firebase or Supabase. Revisit only if people ask for it.

## Why

- **No server to run or pay for.** The data lives in the person's iCloud or Drive and counts against their storage.
- **The privacy promise holds.** The developer never sees anyone's habits, so the privacy label stays "Data Not Collected". Accounts would mean holding people's habit data, including quit and limit habits (smoking, drinking).
- **No sign-in screen on iPhone.** iCloud uses the Apple ID already on the phone; Android asks for a Google account once. Accounts would also bring Apple's rules: Sign in with Apple whenever Google sign-in is offered (guideline 4.8), and deleting an account from inside the app (5.1.1(v)).
- **It covers almost everyone.** People who sync tend to stay on one platform: an iPhone and an iPad, or an Android phone and tablet.

**Without sync**, a new phone already gets its habits back from a device backup: iCloud Backup restores the app's storage on iPhone, and Android's Auto Backup does the same. Sync is for using two devices side by side.

## What the person sees

- **Settings → Sync**, with one switch: "Sync with iCloud" (iPhone, iPad) or "Sync with Google Drive" (Android).
- **Turning it on** with habits on both devices merges them; nothing is lost and there's no "which copy to keep" question. Habits with the same name and goal on both are offered to be combined. Without an iCloud account, the row says so.
- **Status line:** "Synced 2 minutes ago", "Waiting for a connection", or what went wrong in plain words ("iCloud is full").
- **Turning it off** keeps everything on this device. A second choice, "Delete the copy in iCloud", removes the cloud data for every device.
- **An (i) explainer:** where the data goes, that the developer can't see it, and that Health numbers aren't synced (each device reads Health itself).

## What syncs

**Everything the person made or chose** (Paul, 2026-10-25: all settings follow you):
- habits: their settings, history, two-minute days, day notes, freezes, vacation pauses and quotes;
- categories, habit order and grouping;
- own quotes and saved quotes;
- the freeze bank and achievements already celebrated;
- every setting, appearance included.

**Stays on each device:**
- Health's numbers and the app's own Health writes (`health_*`). Apple doesn't allow personal health information in iCloud (guideline 5.1.3). Each device fills in its own numbers from Health, which syncs itself between iPhone and iPad.
- `greetingsSeen` (rewritten on every launch) and `allowTimeSensitive` (follows that phone's own notification permission).
- Today's quote, the tours, the app icon (the phone holds it), developer tools, migration flags, and sync's own `sync_*` keys.

## How it works: a layer beside today's storage

Storage doesn't change: habits stay one JSON list in prefs, read and written by the same repositories. That keeps sync out of the rest of the app, and it no longer waits for [history-compaction.md](history-compaction.md).

1. **Changes are recorded where they're made,** as this device's own records: `HabitProvider` hands each change (before, after, and where it came from) to `SyncJournal`. Settings, categories, quotes and order, which nothing else rewrites, are compared with the last synced copy.
2. **Records are exchanged** through a `CloudTransport` (CloudKit, Drive, or a fake in tests).
3. **All devices' records are merged** (`SyncMerge`, pure Dart).
4. **The merge is applied through the providers,** like any change (`HabitProvider.applySynced`), never by writing prefs underneath them. Reminders, warnings, widgets and achievements follow as they do now.

### Records

**Every device writes only its own records** (named after its device id). The cloud never sees two devices write the same record, so there are no conflicts to resolve there; merging happens when reading.

Each record is one of three kinds:
- **Register:** a value with a stamp from a hybrid logical clock (`Hlc`: wall time, a counter, the device id, so a device with a wrong clock can't win forever). The latest stamp across devices wins.
- **Grow-only element:** membership of a set that only grows: achievements celebrated, saved quotes, milestones credited to the freeze bank, health cards dismissed.
- **Contribution:** a number per device, summed across devices. Only for days of habits that aren't filled in from Health.

| What | Kind |
|---|---|
| A habit's settings, in groups that change together: **amount** (target, units, Health link, history generation), **schedule** (reset frequency, interval, weekdays, anchor), **reminders** (reminder, notify); and name, color, category, icon, two-minute version, why, quotes, start date, pauses one each | Registers |
| A day's count, habit not linked to Health | Contribution per device |
| A day's count, habit linked to Health | Register |
| Two-minute, frozen and note, per day | Registers |
| A habit deleted | Register (final) |
| Categories, own quotes, the order | Registers (a deleted one holds null) |
| Settings | Registers (hour and minute together; a removed key holds null) |

Worked-out values (progress, streaks, momentum) are never synced: they're recomputed from the merged days, as now.

### Counting: both devices' taps add up

Last-writer-wins is wrong for a day's count. Offline, the phone logs 3 glasses and the iPad logs 1. The day should hold 4.

So each device keeps its own contribution, and the day is their sum, with **set semantics**: a change sets this device's contribution to the new total minus the others'. A + adds; typing a number, holding the ring, Undo, clearing and Calendar edits set the total. Widgets log through the app, so they count like taps.

**Caps:** two devices' taps can sum past a period's cap (10× the target). Contributions are never trimmed; what's shown and checked is clamped, the same way on every device (each period's days in date order, trimming the day that crosses the cap).

### Health-linked habits

A day of a habit filled in from Health is a **register**, shown as the higher of it and this device's Health. Summing would count twice: water logged in the app is also written to Health, Health syncs it to the iPad, and the iPad would then count it again. With one value and Health's own number beside it, both devices land on the same day. Numbers written from Health itself are never records.

**Known limit:** each device only knows its own Health writes, so on the iPad − on a glass logged on the iPhone says "That came from Apple Health. Change it there."

### Start dates and unit changes

- **"Counts from" and "Start from"** set the habit's start date, a register. Days before it are left out when merging, unless a day was logged *after* the start was set; then the start moves back to it, as logging before the start does today. So "Counts from, clear earlier" on one device beats an older offline log on the other.
- **Changing units** rescales history (`historyScale`). It starts a new history generation, keyed by its stamp and holding its scale; counts from an older generation that arrive late are rescaled, not dropped.

### The freeze bank

The bank is **worked out on every device, never counted**: start with 3, then replay in date order, with the cap of 5, the credited milestones (dated by when they were earned) and the frozen days held now. So a freeze given back on two devices (an unneeded freeze, returned after a merge) comes back once, and a milestone earned while the bank was full adds nothing whichever device sees it first. A register set at the first join carries over the balance from before sync. The bank's lasting dates (first spent, the rainy-day fund) merge as the earliest.

### Deletions

Deleting a habit records a final marker. A habit that's merely missing (Developer → "Load a year of use", or a habit storage drops as invalid) is never read as deleted; sync pauses while a year of use is loaded.

### Joining, restoring, versions

- **Joining** (turning sync on): pull first; what's already in the cloud wins, habits only on this device are added, and this device's counts are added only where it has more than the cloud, so joining never lowers a day.
- **A device restored from a backup** would carry another device's id. On each start a device fetches its own records first; if the cloud has newer ones than it knows, it takes a new id and joins again. On iOS the id also lives in a this-device-only Keychain item.
- **The iCloud account changes,** or another device deletes the copy in iCloud: sync stops and asks to be turned on again. It never re-uploads by itself.
- **Versions:** each bucket carries a schema version. A device running an older version that finds newer records pauses sync and asks to update the app, rather than misreading them.

### Buckets

Records travel in **buckets**, plain JSON (a month is about 2 KB, so not compressed), each owned by one device:
- `<device>~h~<habit>`: a habit's settings and deletion;
- `<device>~d~<habit>~<yyyy-MM>`: that habit's days and marks for a month;
- `<device>~meta`: everything else.

A tap rewrites one small month bucket. A year is about 150 buckets per device, each far under CloudKit's 1 MB per record.

## How it's built

### Dart (shared)
- **`lib/domain/sync/`** (pure): `Hlc`, records and buckets, `SyncMerge`.
- **`lib/core/sync/`:** `SyncJournal` (records changes), `SyncStore` (local only: device id, clock, last synced copy, this device's buckets, a cache of the others'), `SyncService` (turn on and off, sync now, status; runs 3 s after a change, on launch and resume, and when the cloud says something changed), `CloudTransport`.

### iPhone and iPad: CloudKit
- **`CKSyncEngine`** (iOS 17, the app's minimum): Apple's engine for exactly this. It batches, retries, works offline, and wakes the app with silent pushes when another device changes something.
- **Database:** the person's private database, zone `Momentum`, container `iCloud.com.paulblake.momentum`, record type `Bucket` (`data`, `device`, `schema`).
- **Swift, like the widgets:** `ios/Runner/CloudSync.swift` (channel `momentum/sync`). It keeps the engine's state, an outbox of buckets waiting to go and an inbox of fetched ones in Application Support, so a background push with no Flutter running loses nothing.
- **Xcode:** the iCloud capability (CloudKit) and Push Notifications on the app's ID (the paid team has both), and the remote-notification background mode. The free-team entitlements stay without iCloud.
- **Before release:** CloudKit Console → Deploy Schema Changes to Production.

### Android: Google Drive's app folder
- **Access:** `google_sign_in` 7 with only the `drive.appdata` scope (a hidden folder only this app can see; nothing in the person's Drive), and `googleapis` Drive v3. Pure Dart, no Kotlin. Check whether Google's OAuth verification applies to that scope before building, and set up the Google Cloud project's Android clients (debug, upload and Play signing keys).
- **One file per device** holding its buckets; each device reads the others'. (`DriveTransport` implements `CloudTransport`, like `CloudKitTransport`.) Drive only stores files, so the same "each device writes only its own" rule makes it work.
- **No pushes:** check on launch, on resume, and a few seconds after a change.

## Testing

- **The merge is pure Dart,** tested like the calculators: each rule, then random edits on three devices delivered in random orders, twice, offline and late, which must always converge.
- **Two devices in the simulator** (`test/simulation/sync/`): two copies of the app on the simulated clock with a fake cloud between them, living 60 days of the persona split across them; both must end with the same habits, streaks and momentum as one device that did everything.
- **On real devices:** two iPhone simulators signed into one iCloud account (and later an iPad), and for Android the Motorola and an emulator on one Google account.

## Order of work

1. The records, clock and merge, with their tests.
2. Recording in `HabitProvider`, applying merges through it, the freeze bank's replay.
3. `SyncService`, the fake cloud and the two-device simulation.
4. Settings → Sync and its explainer (Developer tools only for now).
5. iCloud: `CKSyncEngine`, entitlements, and a try on two simulators.
6. **Later:** the Momentum Plus purchase, Google Drive (when the Android phone arrives), and the iPad app it ships with.
7. **Privacy, when it ships:** a paragraph in the privacy policy (paul-blake.com/momentum/privacy and `docs/store/privacy-policy.md`) on where synced data lives, the About footer ("Your habits stay on this phone"), and a recheck of the App Store privacy answers and Google Play's Data safety form, which should stay "not collected", since the developer can't read it.
