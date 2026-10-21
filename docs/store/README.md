# Getting Momentum onto the App Store

The checklist for the first release. The texts are in this folder:
- [listing.md](listing.md): name, subtitle, description, keywords, categories, screenshots;
- [privacy-policy.md](privacy-policy.md): to publish at a public address;
- [review-notes.md](review-notes.md): reviewer notes, privacy-label answers, export compliance, EU trader status.

## Done

- Paid Apple Developer Program (team `9EWP23T2HE`, joined 2026-10-19). Development builds sign with every entitlement: App Group, time-sensitive notifications, HealthKit.
- Privacy manifests for the app and the widgets, and the export-compliance key.
- A release archive (`flutter build ipa`) builds and passes the no-dev-tools check.

## To do

**Paul:**
1. ~~**Create the app in App Store Connect**~~ (done 2026-10-20: "Atomic Momentum", SKU `momentum-ios`).
2. **The first upload, from Xcode:** open `build/ios/archive/Runner.xcarchive` → Distribute App → App Store Connect.
   - Xcode creates the Apple Distribution certificate the first time.
   - Command-line exports fail with "No Accounts" until that certificate exists, or until there's an App Store Connect API key (Users and Access → Integrations) for `xcodebuild -authenticationKeyPath`.
3. **Decide:**
   - the seller name (individual vs an LLC);
   - EU trader status;
   - the support email (suggested: an address on paul-blake.com, forwarded to Gmail by Cloudflare Email Routing).
   - Decided 2026-10-20: the store name "Atomic Momentum"; v1 iPhone-only (iPad soon after); the code stays public; policy pages on paul-blake.com.
4. ~~**The NKJV licence**~~: gratis use with the notice (decided 2026-10-20; `docs/design/inspire.md`).

**Claude:**
1. **Publish** the privacy policy and support page on paul-blake.com (`/momentum/privacy`, `/momentum/support`), and link the policy from Settings in the app (App Review guideline 5.1.1(i) asks for it in the app as well).
2. ~~**Screenshots**~~ (done 2026-10-20; see the checklist below).
3. **Fill in the URLs**, and `AppLinks.store` once the App Store link exists.

**Then:**
- TestFlight for a week or two on Paul's phone: internal testing needs no review.
- Submit.

## Everything left before launch (audit of 2026-10-20)

Every earlier plan, design doc and note, checked against the code. One at a time; tick them off here.

**Claude can build:**
- [x] Vacation notifications: a return date with a welcome back, otherwise a check-in every 3 days (weekly after two weeks) with "I'm back", a Settings switch (2026-10-20)
- [x] Weekly review (the last open part of v1 roadmap item 4; 2026-10-20)
- [x] Privacy policy and support links in Settings → About (2026-10-20)
- [x] Screenshots at 6.9": `tool/store_screens.sh` (the example habits on the "Store iPhone 17 Pro Max" simulator) then `python3 tool/store_frames.py` (headline + phone frame). The set to upload is `build/store_frames/final/`: Sepia, Sepia, Charged, Light, Sepia, Charged, Light, Sepia (2026-10-20). Since 2026-10-20 10 pictures, with the lock screen and home screen widgets 4th and 5th (`tool/widget_screens.sh`)
- [x] Publish the policy pages on paul-blake.com: https://paul-blake.com/momentum/privacy and /momentum/support (website commit 5ae688c)
- [x] Widgets on Paul's real phone: real data through the App Group, logging and taps work (TestFlight build 1, 2026-10-20; not every kind added yet)
- [ ] Health on Paul's real phone (Watch data, other apps' runs, turning access off; `tool/device_health_check.sh` on iOS)
- [x] The tours work in the other session: a welcome page, steps that can't be knocked off course, "Replay tours" (2026-10-20)
- [x] Three moments Paul picked on 2026-10-17 (decided 2026-10-20):
  - All done today: a celebratory greeting, a glowing ring with a burst, a haptic; on Calendar a gold ring with a soft gold fill (built)
  - "Streak saved" shown on the card (not wanted: the card has enough on it)
  - Greetings that use the person's own data, and many more greetings taking turns (built)

**Paul:**
- [x] The support email: momentum@paul-blake.com through Cloudflare Email Routing (works, 2026-10-20)
- [x] Create the app in App Store Connect ("Atomic Momentum", 2026-10-20)
- [x] The first upload from Xcode: build 1.0.0 (1), on TestFlight and installed on Paul's phone (2026-10-20). Later builds take the next build number (`version:` in pubspec.yaml)
- [ ] The seller name (individual or an LLC), and EU trader status
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
