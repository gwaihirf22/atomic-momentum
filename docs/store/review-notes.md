# App Review notes and privacy answers

## Notes for the reviewer (App Store Connect → App Review Information → Notes)

Momentum is a free habit tracker. There's no account or login, and everything is stored on the device. There are no in-app purchases, ads or analytics.

How to try it:
- Tap the amber + (the Habits tab) to add a habit. A short tour runs on first launch with example habits, and Settings → Help → How to has guides.
- Log a habit with + on its card, or hold its ring to finish it. Tap the card to open the habit's page.
- A missed day shows "Don't miss twice". The habit's page offers a freeze (Settings → Freezes shows the bank and vacation mode).

Apple Health (HealthKit; optional, only for habits the person links). Where the app identifies it:
- Settings → "Apple Health": "About Apple Health" explains what Momentum reads and writes and that the data stays on the phone; Sync now; how to change access.
- Add habit → type "Walk" → the "Apple Health" row → "Fill in from Apple Health" → Steps. iOS's Health permission sheet follows, then a live preview ("Apple Health shows 5,210 steps today").
- A linked habit's page shows "From Apple Health · Steps · synced just now".
- Reads steps, exercise minutes, workouts, sleep, mindful minutes and water, to fill in linked habits. Writes water and mindful minutes only when the person logs them in a linked habit, and takes back its own writes if they undo.
- Health data stays on the device. It's never sent anywhere, used for advertising, or shared.
- The attached screen recording, made on an iPhone, shows each of these.

Notifications are local reminders and streak warnings, scheduled on the device. Time-sensitive alerts are optional (Settings → Notifications).

Widgets: home screen and lock screen widgets show habits, momentum and quotes. A habit widget's + logs a step through an App Intent.

Tips (guideline 3.1.1, US storefront): Settings → Say thanks → "Buy Paul a coffee" opens my personal tip page (buymeacoffee.com) in Safari, the default browser. It appears only when StoreKit's Storefront.current.countryCode is "USA"; on every other storefront, or if the storefront is unknown, the row is hidden. It unlocks nothing: every feature is free, and there are no in-app purchases.

## App Privacy (the "nutrition label")

App Store Connect → App Privacy → Get Started:
- **"Do you or your third-party partners collect data from this app?"** → **No, we do not collect data from this app.**
  - "Collect" means sent off the device. Momentum keeps everything on the phone and has no servers, analytics or third-party SDKs that send data.
  - Health data read and stored on the device isn't "collected" in Apple's sense.
- Result: **Data Not Collected**.

## Content rights
- **"Does your app contain, show, or access third-party content?"** → **Yes, and I have the necessary rights** (answered 2026-10-21).
  - The built-in quotes are third-party content: Scripture in the NKJV, quoted under HarperCollins' gratis use (at most 500 verses, under 25% of the library, with its notice), and public-domain writers and translations.
  - Apple Health data is the person's own, read with their permission.

The privacy manifests (`ios/Runner/PrivacyInfo.xcprivacy`, `ios/MomentumWidgets/PrivacyInfo.xcprivacy`) say the same: no tracking, nothing collected, and UserDefaults read for the app's own settings and the App Group shared with the widgets.

## Export compliance

`ITSAppUsesNonExemptEncryption` is `false` in `Info.plist`: the app uses no encryption beyond what iOS provides, so App Store Connect doesn't ask on each build.

## EU Digital Services Act (trader status)

App Store Connect asks whether you're a trader. A trader's address, phone and email are shown on the EU App Store.
- **Paul is a trader** (declared 2026-10-27), since Momentum Plus and tips are sold in the EU.
- An individual can give a P.O. box in place of a home address; change it in App Store Connect → Business.

---

## 1.1 draft notes for the reviewer (Momentum Plus, iPad; not live)

- **Momentum Plus** (`com.paulblake.momentum.plus`, non-consumable, $1.99, Family Sharing) unlocks **sync between the person's devices through their own iCloud** (CloudKit private database). Settings → Momentum Plus → the Plus page; Restore Purchases is on that page. Sync turns on in Settings → Momentum Plus → "Sync with iCloud". The other items on the Plus page are listed as "Coming in 1.1" and unlock nothing yet.
- **Tips** (`com.paulblake.momentum.tip.small/medium/large`, consumable) are a thank-you and **unlock nothing**. They show in Settings → Say thanks outside the United States; in the United States, Say thanks keeps the "Buy Paul a coffee" link (3.1.1(a)), and there are no in-app tips there.
- **To test:** sandbox purchases work on the Plus page; for sync, two devices signed in to the same Apple Account.
- **iPad:** the app now runs natively on iPad (sidebar, split view). The habit editor opens as a form sheet.
- **App Privacy:** unchanged, Data Not Collected. Sync data lives in the user's own iCloud, which the developer can't access; purchases are handled by Apple.
