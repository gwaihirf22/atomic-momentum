# Getting Momentum onto the App Store

The checklist for the first release. The texts are in this folder:
- [listing.md](listing.md): name, subtitle, description, keywords, categories, screenshots;
- [privacy-policy.md](privacy-policy.md): published at https://paul-blake.com/momentum/privacy;
- [review-notes.md](review-notes.md): reviewer notes, privacy-label answers, export compliance, EU trader status.

## Where it stands (2026-10-21)

**In App Review:** version 1.0.0, build 2, submitted 2026-10-21, rated 13+, released by hand once approved.
- Build 1 (2026-10-20) went to TestFlight and Paul's phone.
- Build 2 adds the lock screen widgets and the "Log a habit" Control, vacation check-ins, the weekly review, "All done today" and the new greetings, "Buy me a coffee" (buymeacoffee.com/paulblake, US only) and "Blake Built" in Settings → About.

**While Apple reviews:**
- Questions from App Review arrive by email and in App Store Connect's App Review messages. The answers to the usual ones (Health, the tip link, content rights) are in [review-notes.md](review-notes.md).
- **Once approved:**
  - press Release in App Store Connect;
  - set `AppLinks.store` (`lib/core/services/sharer.dart`) to the app's link (`https://apps.apple.com/app/id<Apple ID>`, from App Information) in the next build, so share cards say "on the App Store";
  - add the link to paul-blake.com/momentum and the Buy Me a Coffee page.
- **If it's rejected:** fix what the message names, then upload a new build of the same version.

## Making the next build

1. Raise the build number in `pubspec.yaml` (`version: 1.0.0+3`). After release, an update also takes a new version (`1.0.1+4`). The widgets follow it by themselves (`ios/MomentumWidgets/Widgets.xcconfig`).
2. Run `./flutter/bin/flutter build ipa` without `DEV_TOOLS`. Xcode's "Check no dev tools" phase fails an archive that has them.
3. Upload from Xcode: `open build/ios/archive/Runner.xcarchive` → Distribute App → App Store Connect.
   - The export at the end of `flutter build ipa` fails with "No Accounts". That's expected: Xcode uploads with Paul's signed-in account.
   - Exporting from the command line would need an App Store Connect API key (Users and Access → Integrations) for `xcodebuild -authenticationKeyPath`.
   - Keep the archives in Xcode's Organizer: their symbols turn crash reports into readable code.
4. **Screenshots**, only if the app's look changes: `tool/store_screens.sh && tool/widget_screens.sh && python3 tool/store_frames.py` (see CLAUDE.md). The uploaded set is in `build/store_frames/final/`.

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
- [ ] EU trader status (App Store Connect → Business; see review-notes.md). Choosing "not a trader" doesn't keep the app out of the EU
- [ ] Ask Apple Developer Support to show the seller as "Paul Blake"
- [ ] Review the tours
- [x] The NKJV licence: gratis use with the notice, under 500 verses and 25% of the library (2026-10-20)
- [ ] Check the built-in quotes against their sources (`docs/design/inspire.md`, "Review before release")
- [ ] Google Play, if v1 includes it: the closed test needs 12 testers for 14 days, so start early

**After launch:**
- habit stacking, and routines with timers (a Live Activity);
- "I am someone who…" statements;
- best times of day;
- iPad;
- more Health metrics;
- more How-to guides;
- Android widgets.

**Parked:**
- one habit's own pause, and freezes in Insights;
- extra widget options;
- backup and CSV export;
- Apple Watch, Siri, StandBy.
