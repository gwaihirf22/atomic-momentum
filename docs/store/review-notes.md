# App Review notes and privacy answers

## Notes for the reviewer (App Store Connect → App Review Information → Notes)

Momentum is a free habit tracker. There's no account or login, and everything is stored on the device. There are no in-app purchases, ads or analytics.

How to try it:
- Tap the amber + (the Habits tab) to add a habit. A short tour runs on first launch with example habits, and Settings → Help → How to has guides.
- Log a habit with + on its card, or hold its ring to finish it. Tap the card to open the habit's page.
- A missed day shows "Don't miss twice". The habit's page offers a freeze (Settings → Freezes shows the bank and vacation mode).

Apple Health (optional, only for habits the person links):
- Reads steps, exercise minutes, workouts, sleep, mindful minutes and water, to fill in linked habits (Add habit → a habit like "Walk" → "Fill in from Apple Health").
- Writes water and mindful minutes only when the person logs them in a linked habit, and takes back its own writes if they undo.
- Health data stays on the device. It's never sent anywhere, used for advertising, or shared.

Notifications are local reminders and streak warnings, scheduled on the device. Time-sensitive alerts are optional (Settings → Notifications).

Widgets: home screen and lock screen widgets show habits, momentum and quotes. A habit widget's + logs a step through an App Intent.

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

Before the app can be offered in the EU, App Store Connect asks whether you're a trader. A trader's address, phone and email are shown on the EU App Store.
- A free app with no ads or purchases is usually non-trader.
- The US-only tip link is still worth a moment's thought.
- **This is Paul's call.** Choosing "not a trader" doesn't stop the app from being offered in the EU.
