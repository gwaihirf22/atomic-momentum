# Getting Momentum onto the App Store

The checklist for the first release. The texts are in this folder:
- [listing.md](listing.md): name, subtitle, description, keywords, categories, screenshots;
- [privacy-policy.md](privacy-policy.md): published at https://paul-blake.com/momentum/privacy;
- [review-notes.md](review-notes.md): reviewer notes, privacy-label answers, export compliance, EU trader status.

## Where it stands (2026-10-24)

**Build 2 was rejected** on 2026-10-23, for two things. Paul replied with a screen recording, got no answer in 1.5 days, and is sending build 3:
- **3.1.1 (the tip link):** the reviewer took it for a payment that needs In-App Purchase, though Apple allows a link out on the US storefront. Build 3 keeps it in its own section, renamed: Settings → Say thanks → "Buy Paul a coffee" ("Opens buymeacoffee.com in your browser", "If you'd like to say thanks, you can tip me there"). On iPhone it now goes only by the App Store's country: when StoreKit doesn't say, it's hidden (before, the phone's region stood in).
- **2.5.1 (HealthKit not clearly identified):** build 3 adds Settings → Apple Health → "About Apple Health" (what it reads and writes, that it stays on the phone), and the explainer and editor name Apple Health. The reviewer notes give the path, with the screen recording attached.

**Version 1.0.0, build 3:** rated 13+, released by hand once approved.
- Build 1 (2026-10-20) went to TestFlight and Paul's phone.
- Build 2 adds the lock screen widgets and the "Log a habit" Control, vacation check-ins, the weekly review, "All done today" and the new greetings, "Buy me a coffee" (buymeacoffee.com/paulblake, US only; "Buy Paul a coffee" from build 3) and "Blake Built" in Settings → About.

**While Apple reviews:**
- Questions from App Review arrive by email and in App Store Connect's App Review messages. The answers to the usual ones (Health, the tip link, content rights) are in [review-notes.md](review-notes.md).
- **Once approved:**
  - press Release in App Store Connect;
  - set `AppLinks.store` (`lib/core/services/sharer.dart`) to the app's link (`https://apps.apple.com/app/id<Apple ID>`, from App Information) in the next build, so share cards say "on the App Store";
  - add the link to paul-blake.com/momentum and the Buy Me a Coffee page.
- **If it's rejected:** fix what the message names, then upload a new build of the same version.

## Momentum Plus (1.1, `plus` branch): Paul's steps before TestFlight

1. **Agreements, Tax, and Banking** in App Store Connect: accept the **Paid Applications** agreement, add the bank account and the tax forms. Nothing can be sold, even in TestFlight, until it's active.
   - **2026-10-27:**
     - the legal entity and the W-9 are filled in: Individual/Sole proprietor, Non-Exempt Payee;
     - the Schwab bank account is waiting for Apple's approval (up to 24 hours, with no other changes allowed meanwhile).
2. **EU trader status (DSA):** ~~declare it~~ Paul declared himself a **trader** on 2026-10-27, since Plus and tips are sold in the EU. A trader's address, phone and email show on the EU App Store pages. Apple accepts a P.O. box in place of a home address (App Store Connect → Business to change them).
3. **App Store Small Business Program** (developer.apple.com/app-store/small-business-program): enrol, so Apple takes 15% instead of 30%.
4. **The four in-app purchases** (App Store Connect → the app → Monetization → In-App Purchases), each with a display name, description and a review screenshot (the Plus page):
   - `com.paulblake.momentum.plus`: **Non-Consumable**, $1.99, "Momentum Plus", **Family Sharing on**;
   - `com.paulblake.momentum.tip.small` / `.medium` / `.large`: **Consumable**, $0.99 / $2.99 / $4.99, "Small tip" / "Medium tip" / "Large tip".
5. **iCloud for TestFlight:** CloudKit Console → the `iCloud.com.paulblake.momentum` container → **Deploy Schema Changes** to Production (TestFlight and the App Store sync in production).
6. **The build:** on `plus`, set `version: 1.1.0+1` in `pubspec.yaml`, `flutter build ipa`, upload, and add it to TestFlight. Testers buy with their own Apple Account, free (sandbox).

The products are submitted for review with the 1.1 version itself.

## Making the next build

1. Raise the build number in `pubspec.yaml` (`version: 1.0.0+3`). After release, an update also takes a new version (`1.0.1+4`). The widgets follow it by themselves (`ios/MomentumWidgets/Widgets.xcconfig`).
2. Run `./flutter/bin/flutter build ipa` without `DEV_TOOLS`. Xcode's "Check no dev tools" phase fails an archive that has them.
3. Upload from Xcode: `open build/ios/archive/Runner.xcarchive` → Distribute App → App Store Connect.
   - The export at the end of `flutter build ipa` fails with "No Accounts". That's expected: Xcode uploads with Paul's signed-in account.
   - Exporting from the command line would need an App Store Connect API key (Users and Access → Integrations) for `xcodebuild -authenticationKeyPath`.
   - Keep the archives in Xcode's Organizer: their symbols turn crash reports into readable code.
4. **Screenshots**, only if the app's look changes: `tool/store_screens.sh && tool/widget_screens.sh && python3 tool/store_frames.py` (see CLAUDE.md). The uploaded set is kept in `docs/store/screenshots/` (see listing.md).

## Decisions

- **Store name** (2026-10-20): "Atomic Momentum"; v1 iPhone-only (iPad soon after); the code stays public; policy pages on paul-blake.com.
- **Seller** (2026-10-21): the individual account.
  - Apple takes no trade names or DBAs, only a legal entity with a D-U-N-S number, and an LLC isn't worth it for a free app.
  - The brand "Blake Built" goes everywhere else: Settings → About, the listing's Copyright "2026 Blake Built", the website.
  - An individual account can move to an organization later, keeping the app and its reviews.
- **The NKJV licence** (2026-10-20): gratis use with the notice (`docs/design/inspire.md`).
- **Tips** (2026-10-21): one Buy Me a Coffee page for all of Paul's apps.

## Everything left before launch (audit of 2026-10-20)

Every earlier plan, design doc and note, checked against the code. One at a time; tick them off here. The open ones don't hold up the release.

**Claude can build:**
- [x] Vacation notifications: a return date with a welcome back, otherwise a check-in every 3 days (weekly after two weeks) with "I'm back", a Settings switch (2026-10-20)
- [x] Weekly review (the last open part of v1 roadmap item 4; 2026-10-20)
- [x] Privacy policy and support links in Settings → About (2026-10-20)
- [x] Screenshots at 6.9": `tool/store_screens.sh` (the example habits on the "Store iPhone 17 Pro Max" simulator) then `python3 tool/store_frames.py` (headline + phone frame). The set to upload is `build/store_frames/final/`: Sepia, Sepia, Charged, Light, Sepia, Charged, Light, Sepia (2026-10-20). Since 2026-10-20 10 pictures, with the lock screen and home screen widgets 4th and 5th (`tool/widget_screens.sh`)
- [x] Publish the policy pages on paul-blake.com: https://paul-blake.com/momentum/privacy and /momentum/support (website commit 5ae688c)
- [x] Widgets on Paul's real phone: real data through the App Group, logging and taps work (TestFlight build 1, 2026-10-20; not every kind added yet)
- [x] Lock screen widgets (a habit with a +, a streak flame) and the iOS 18 "Log a habit" Control (2026-10-20, build 2; still to try on the real phone)
- [x] "Buy me a coffee" opens buymeacoffee.com/paulblake (2026-10-21)
- [ ] `AppLinks.store`, once the app is approved
- [ ] Health on Paul's real phone (Watch data, other apps' runs, turning access off; `tool/device_health_check.sh` on iOS)
- [x] The tours work in the other session: a welcome page, steps that can't be knocked off course, "Replay tours" (2026-10-20)
- [x] Three moments Paul picked on 2026-10-17 (decided 2026-10-20):
  - All done today: a celebratory greeting, a glowing ring with a burst, a haptic; on Calendar a gold ring with a soft gold fill (built)
  - "Streak saved" shown on the card (not wanted: the card has enough on it)
  - Greetings that use the person's own data, and many more greetings taking turns (built)

**Paul:**
- [x] The support email: momentum@paul-blake.com through Cloudflare Email Routing (works, 2026-10-20)
- [x] Create the app in App Store Connect ("Atomic Momentum", 2026-10-20)
- [x] The first upload from Xcode: build 1.0.0 (1), on TestFlight and installed on Paul's phone (2026-10-20)
- [x] Build 1.0.0 (2) submitted for App Review (2026-10-21)
- [x] A Buy Me a Coffee page: buymeacoffee.com/paulblake (2026-10-21)
- [x] The seller name: individual, branded Blake Built (2026-10-21)
- [x] EU trader status: a trader (2026-10-27)
- [ ] Ask Apple Developer Support to show the seller as "Paul Blake"
- [ ] Review the tours
- [x] The NKJV licence: gratis use with the notice, under 500 verses and 25% of the library (2026-10-20)
- [ ] Check the built-in quotes against their sources (`docs/design/inspire.md`, "Review before release")
- [ ] Google Play, if v1 includes it: the closed test needs 12 testers for 14 days, so start early

**After launch:**
- habit stacking, and routines with timers (a Live Activity);
- "I am someone who…" statements;
- best times of day;
- iPad (built on `plus` for 1.1, with Momentum Plus: [../design/ipad.md](../design/ipad.md); needs the iPad screenshots, `docs/store/listing.md`);
- more Health metrics;
- more How-to guides;
- Android widgets.

**Parked:**
- one habit's own pause, and freezes in Insights;
- extra widget options;
- backup and CSV export;
- Apple Watch, Siri, StandBy.
