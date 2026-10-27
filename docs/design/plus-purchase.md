# Momentum Plus: the purchase, and in-app tips

*Planned with Paul on October 26, 2026; built after the iPad version. Both ship together as 1.1 (`plus` branch).*

**Built (October 26, 2026):** `PlusStore`, the Plus page, Settings → Momentum Plus with sync behind it, Apple tips in Say thanks outside the US, the Developer switch and `ios/Runner/Momentum.storekit`; 2069 tests pass. **This round:** Plus and tips working end to end, tested on the simulator (`ios/Runner/Momentum.storekit`, running from Xcode) and on TestFlight (sandbox). The name stays Momentum Plus. **Left for 1.1's finish:** the weekly-review mention, the listing's "No in-app purchases" line, the privacy policy's paragraphs on sync and purchases, and the App Review notes. The rest of 1.1 (the Apple Watch, icons and themes, the year in review, Health insights, Shortcuts) is in the strategy's roadmap.

## Context
Sync works between Paul's iPhone and iPad (2026-10-26), but only in builds with Developer tools. To ship it, and to test through TestFlight on his second iPhone, the app needs the Plus purchase.

**Paul's decisions (2026-10-26):**
- **Momentum Plus is $1.99,** a one-time purchase.
- **Tips** of $0.99 / $2.99 / $4.99 are offered **outside the US**, as plain thank-yous. They **don't unlock Plus** (revised by Paul).
  - **Why:** a consumable that unlocks something for good is a known App Review rejection under 3.1.1, and it couldn't be restored on iOS 17.
  - **The order explains it:** "Get Plus, a thank-you that gives you sync" comes first, then "Want to give more? Leave a tip".
  - **The US** keeps the "Buy Paul a coffee" link.
- **Where Plus appears:**
  - in Settings;
  - **one gentle mention**, once, dismissible: "Using an iPad too?" at the end of a weekly review.
- **Android:** Plus is **hidden** until Google Drive sync exists.

Everything goes on the `plus` branch.

## How it's built

## Products (App Store Connect, Paul sets them up; the ids live in code)
- **Plus:** `com.paulblake.momentum.plus`, non-consumable, $1.99, Family Sharing on.
- **Tips:** `com.paulblake.momentum.tip.small` / `.medium` / `.large`, consumables, $0.99 / $2.99 / $4.99.
- **Restoring Plus:** it's a non-consumable, so Restore Purchases and Family Sharing bring it back on any device with the same Apple ID. Nothing extra needs to sync.

## `PlusStore` (`lib/core/services/plus_store.dart`; `FakePlusStore` in `test/helpers/`, with `install()`, like `FakeSupportLink`)
- **Its API:**
  - `isSupported`: iOS only (and Developer builds anywhere);
  - `unlocked`, a `ChangeNotifier`;
  - `offers()`: Plus and the tips, with their prices from the App Store;
  - `buy(offer)` → bought | cancelled | pending (Ask to Buy) | failed(message);
  - `restore()`.
- **`PlatformPlusStore`:**
  - built on the official **`in_app_purchase`**, with StoreKit 2 on iOS;
  - no RevenueCat, so "Data Not Collected" holds;
  - listens to the purchase stream from launch, so purchases waiting from last time are finished;
  - completes every purchase;
  - only the Plus product unlocks Plus; tips are completed and thanked, nothing more.
- **Stored in** `plus_v1`: since when (a quick start; Restore Purchases is the truth).
- **Developer builds:** Developer → "Pretend Plus is bought" (`plus_dev_v1`), so either state can be tested. Never in a store build.
- **Registered** in `injection_container.dart`. Initialised in `main()` beside the other services, so its listener is there before the first frame.

## Settings
- **The section** (`SyncSettingsSection`, renamed `PlusSettingsSection`), header **"Momentum Plus"**. It shows wherever Plus is supported:
  - a **"Momentum Plus"** row: "Sync with your iPad, and what comes next" before buying, "Thank you! Plus is yours" after. It opens the Plus page;
  - **"Sync with iCloud"**:
    - **Without Plus**, its subtitle reads "With Momentum Plus" and turning it on opens the Plus page.
    - **With Plus**, it works as now.
    - **Sync already on** stays on, whatever happens to the purchase.
  - "Sync now" and "About sync", as now.
- **No longer Developer-only:** the section comes out from behind `DevTools`.
- **"Say thanks":**
  - **US:** unchanged, the coffee link.
  - **Elsewhere on iPhone:**
    - without Plus, "Get Momentum Plus · $1.99" first, as "a thank-you that gives you sync";
    - then three tip rows, "Leave a $0.99 tip" and so on;
    - the footer: "Want to give more? Tips are a thank-you, nothing more."

  - **How it decides:** the same check as `SupportLink.isAvailable`. Where the link isn't shown, the tips are.

## The Plus page (`lib/screens/plus_screen.dart`, opened from Settings, the Sync switch and the mention)
- **What's in it:**
  - "Momentum Plus" and one line: "One purchase, yours for good, shared with your family."
  - **Now:** Sync with iCloud (iPhone and iPad).
  - **Coming:** new icons and themes, a year in review, Health insights, Shortcuts, Apple Watch.
  - **The promise:** "Nothing that's free today will ever cost money. Buy once, get everything that comes."
  - The **"Get Plus · $1.99"** button, with the price from the App Store.
  - **Outside the US, once Plus is yours:** "Want to give more?", with the three tips.
  - **Restore Purchases**, and the small print.
- **What each outcome shows:**
  - **Bought:** a thank-you and the page in its "yours" state, with a "Turn on sync" button.
  - **Pending:** "Waiting for approval".
  - **Cancelled:** nothing.
  - **Failed or the store can't be reached:** an alert, in plain words.
  - **Price while loading:** "Get Plus", never "…".

## The one gentle mention
- **Where:** the weekly review page (`lib/screens/weekly_review_screen.dart`), after Share. A small dismissible card: "Using an iPad too? Momentum Plus keeps them in sync." Tapping it opens the Plus page.
- **When it shows:**
  - only on iPhone, without Plus, from the second weekly review on;
  - **once ever:** `plus_mention_v1` is set when it's shown.

## Words and docs
- **About footer** ("Your habits stay on this phone"): "…on your devices: on this phone, and in your own iCloud if you turn on sync".
- **`docs/store/listing.md`:**
  - the price line: free, with in-app purchases;
  - the description: "Free. No ads, no subscriptions. Momentum Plus adds sync."
- **`docs/store/privacy-policy.md`:** paragraphs on iCloud sync and on purchases (handled by Apple; Paul sees no one's purchases). The website's copy is Paul's, in his own repo.
- **`docs/store/review-notes.md`:** what Plus is, that tips unlock nothing, and how to test it with sandbox purchases.
- **`docs/store/README.md` checklist (Paul):**
  - the Paid Apps agreement, banking and tax;
  - the Small Business Program (15%);
  - the four products, each with a review screenshot;
  - CloudKit Console → Deploy Schema Changes to Production;
  - submitting the products with the version.
- **Strategy:** Plus at $1.99, tips outside the US as plain thank-yous, the US coffee link unchanged. Also update CLAUDE.md and memory.

## Testing on devices
- **StoreKit configuration file:** `ios/Runner/Momentum.storekit` with the four products, set in the Runner scheme. Run from Xcode on a simulator, purchases go through without Apple.
- **TestFlight on the second iPhone:** a TestFlight build (store build, no Developer tools) buys with the sandbox, free, and syncs in CloudKit's production environment with other TestFlight installs.
  - This build's number is `1.0.0+4` only if build 3 is approved by then; otherwise the next number.

## Tests
- **Unit, `PlusStore` with a fake purchase stream:**
  - Plus unlocks it, and it's remembered; a tip never does;
  - restore unlocks;
  - pending and cancelled don't unlock;
  - failures report a message;
  - waiting purchases at launch are completed.
- **Widget:**
  - the Plus page's states (locked with prices, pending, bought, store unavailable; tips only outside the US);
  - turning on sync without Plus opens the Plus page;
  - Say thanks: outside the US, Get Plus first (until bought) and then the tips; the coffee link in the US;
  - the weekly review mention shows once, on the second review, never with Plus;
  - the Developer switch;
  - hidden on Android.
- **`small_screens_test`:** the Plus page (locked, bought, with tips), the tip rows and the mention card, at 375/390 pt and 100%/135%.
- **Everything else:** the whole suite, also in UTC; `flutter analyze` clean.

## Verification
1. **Simulators:** reload the three (iPhone 17 Pro, SE, Duo). Settings shows Momentum Plus.
2. **Simulator from Xcode, with the StoreKit file:**
   - buy Plus, and sync turns on;
   - tip, and get a thank-you (Plus stays as it was);
   - Restore;
   - Ask to Buy pending.
3. **Paul's phone and iPad** (Developer builds): the pretend switch, then sync as before.
4. **TestFlight**, after Paul's App Store Connect steps: on the second iPhone, buy with sandbox, turn on sync, and check the habits arrive from another TestFlight install.

## Commits on `plus`
1. `PlusStore`, the products and the Developer switch.
2. The Plus page, and the Settings section with sync gated.
3. Tips in Say thanks outside the US.
4. The weekly review mention.
5. The StoreKit file, then docs, listing, privacy and review notes.

## Testing it

- **On a simulator, from Xcode** (`open ios/Runner.xcworkspace`, choose a simulator, Run): purchases go through `ios/Runner/Momentum.storekit`, without Apple. Debug → StoreKit → Manage Transactions refunds, approves Ask to Buy or fails a purchase. The test storefront is the US (the coffee link shows, not the tips): change it in the .storekit file's Editor → Default Storefront to see the tips. If the scheme doesn't pick the file up, set it in Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration.
- **Developer builds** (`flutter run`, `DEV_TOOLS=1` installs): Settings → Developer → "Pretend Plus is bought".
- **TestFlight** (sandbox purchases, free): needs Paul's App Store Connect steps (docs/store/README.md, "Momentum Plus"), then a store build from `plus` as 1.1.0 (1).
