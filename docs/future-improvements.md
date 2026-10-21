# Future improvements

Things to do that aren't on the product roadmap, or that are smaller than a roadmap item: performance, polish, loose ends and decisions still to make. The roadmap itself (statistics, onboarding, store readiness, routines, widgets) is in [strategy/product-strategy.md](strategy/product-strategy.md#4-roadmap).

*Last updated October 18, 2026.* Move an item to "Done" with its commit when it's built.

## Next up: Paul's to-dos (October 18, 2026)

In this order. The rest of v1 (the weekly review, rewards and the onboarding tutorial) still stands alongside these; see the roadmap.

### 1. Verify Apple Health more thoroughly

**Automated (2026-10-19):** `tool/device_health_check.sh` checks every metric, the app's writes and their removal, and cleanup against the real Apple Health (iPhone 17 Pro simulator) and Health Connect (Year_Pixel); it found Android workouts reading nothing without distance and calories access (fixed). Lowering below Health's number now stops there and says so. What a simulator can't do is left for the real iPhone.

**Where Health stands** (what's done, and the expansions left: more metrics, workout types, break habits from Health, background updates): [design/health.md](design/health.md), "Status". Parked on 2026-10-19 for the onboarding tutorial.

It seems to work well; now check it properly on the real iPhone (`DEV_TOOLS=1 tool/install_on_iphone.sh`), with real data from the Health app and an Apple Watch if there is one.

- **Each metric fills in the right number for today and the past week:**
  - steps;
  - exercise minutes (Watch minutes, and a run logged in another app);
  - workouts;
  - sleep (counted on the morning you wake);
  - mindful minutes;
  - water.
- **Units:** glasses, ml, fl oz and cups for water; hours and minutes for sleep and exercise. Changing a unit converts the target and the past days.
- **Logging back:** water and mindful minutes logged in the app appear in Health; − takes back only the app's own entries; changing a Health-filled number shows "That came from Apple Health."
- **Permissions:** first ask, a refusal, and turning access off later in the Health app.
- **Edges:** never before the day a habit was linked or started counting, and never past a period's cap.
- Anything wrong gets a test and a fix. Design: [design/health.md](design/health.md).

### 2. Home screen widgets (moved up from v2)

**Built** (October 19): all six kinds from the mockups (one habit with a working +, a group of habits, momentum and the lock screen, Insights, Quote, "I will"), plus "today" on the lock screen. They reach Paul's iPhone once the paid account can sign the App Group. What's left (Android, background refresh, saving a quote) is in [design/widgets.md](design/widgets.md), "Later". Design and status: [design/widgets.md](design/widgets.md).

**What "widgets" means here:** in the code, "widget" means any piece of the Flutter UI. These are home screen and lock screen widgets: a WidgetKit extension written in SwiftUI inside `ios/`, which is Swift Apple requires (see the strategy's platform section). Android's equivalent (app widgets) comes after.

Paul's ideas:
- **One habit:** its ring and today's progress, with a + to log from the home screen (interactive: the app needs iOS 17, like the widgets).
- **A group of habits:** a category, or habits you pick, as rows of rings.
- **Momentum:** the overall momentum ring and its level, for encouragement. Small, plus the round lock screen widget.
- **Insights:** a small view such as the week's heatmap or "X of Y done today".
- **A quote:** a bigger widget with the quote of the day, or one of a habit's quotes.
- **"I will" statements:** a habit's Story sentence ("I will drink water, 8 glasses every day").
- **A general one:** "I will complete my habits", "I will become a better person", or the person's own words.

How it fits together:
- **Package:** `home_widget`.
- **Shared data:** the app writes a small snapshot (today's habits, rings, momentum, the day's quote) into an App Group that the widget reads. A log made in a widget has to merge into history and cancel that habit's pending reminders.
- **Free account:** a free team may not be able to sign App Groups. If so, widgets wait for the paid account.
- **Existing designs:** the Inspire design already sketches the quote, momentum and one-habit widgets ([design/inspire.md](design/inspire.md), "Later"), and the drawing code to borrow from is in the ring, `MomentumRing` and the share cards.

### 3. Become an Apple developer and get through App Review

First time through, so here's the path:
1. **Enroll** in the Apple Developer Program ($99 a year). Identity checks can take a day or more. Then switch `tool/install_on_iphone.sh` to `FULL_ENTITLEMENTS=1` and turn on the time-sensitive and HealthKit capabilities for the app's ID.
2. **App Store Connect:** create the app (name "Momentum", id `com.paulblake.momentum`), age rating, category, and export compliance (no special encryption).
3. **Privacy:**
   - A privacy policy at a public web address; Health apps must have one.
   - The privacy "nutrition label": no data leaves the phone, no tracking.
   - The Health usage text is already written (`Info.plist`).
4. **Screenshots** for the required iPhone sizes, plus the description, keywords and support page.
5. **Before submitting:**
   - ~~Confirm the NKJV Scripture licence~~: gratis use with the notice, kept under 500 verses and 25% of the library (2026-10-20).
   - Make the tip page if wanted (`AppLinks.coffee`).
   - Build with plain `flutter build ipa`; the archive refuses dev tools.
6. **TestFlight first:** run the real build for a week or two, then submit. Review notes should explain Health (what's read and written, and why). Expect a question or two from Apple; most first rejections are about metadata or privacy wording, not the app.

### 4. Google Play, while Apple reviews

- **Account:** create a Play Console developer account ($25, once), with identity verification.
- **Testing:** new personal accounts must run a **closed test with at least 12 testers for 14 days** before going to production, so start this early.
- **Forms:**
  - the Data safety form;
  - Health Connect's permissions declaration (Google reviews why each health permission is needed).
- **Android checks still to do on a phone:**
  - switching the app icon (the launcher aliases);
  - Health Connect on a real phone (the emulator check passes);
  - notifications with exact alarms;
  - the adaptive icon on other launchers.
- **Build:** use plain `flutter build appbundle`.

## Performance with a long history

- **Compact settled history** (checkpoint plus recent days, the rest archived and unpacked only when needed). Design: [design/history-compaction.md](design/history-compaction.md).
  - **Not urgent:** in profile mode a year loads in about 0.5 s and two years in about 0.8 s (see Done).
  - Worth doing before long-time users reach several years, since the load grows with every day.
- **Try an iPhone SE (or older phone)** with a year loaded. The iPhone 15 Pro Max is instant (see Done); the SE is the slowest phone supported.
- **The first launch frame** takes 57–134 ms in profile mode (it varies between runs): the first content frame, with the first achievements check right after it, on the main isolate. Move the check off-thread if it shows as a hitch just after the intro.

## App icon, launch and intro

- **More app icons.** The catalogue is built to grow: a source picture, a line in `tool/make_app_icons.py`, an `AppIcons` entry, a manifest alias and the Xcode setting (CLAUDE.md, "App icon"). All of them are free; the app has no Pro.
- **iOS 18 tinted icons.** iOS makes a tinted version from the default icon. A tinted variant of our own (a grayscale logo in each icon set) would look cleaner.
- **The launch screen follows the phone's light or dark mode, not the app's Appearance setting.** With Appearance set to Dark on a phone in light mode, a cream frame shows before the dark intro. Native launch screens can't read the app's setting, so the only fix would be a neutral launch colour.
- **macOS and web icons** still come from the older `assets/branding/app_icon.png` crop. Regenerate them from the new full-bleed masters (`app_icon_charged.png`, `app_icon_light.png`).
- **`MomentumMark`** (the logo drawn in code, in the theme's colours) can be reused for the onboarding tutorial and an About screen.

## Buy me a coffee

- **Turn it on:** make a tip page (Buy Me a Coffee, Ko-fi or similar) and put its address in `AppLinks.coffee` (`lib/core/services/sharer.dart`). Until then the Settings row stays hidden.
- **Tips outside the US** would have to be in-app purchases (Apple guideline 3.1.1; Google Play's payments policy). Add them only if wanted: three consumable products, through `in_app_purchase` or RevenueCat, plus each store's paid-apps agreement.
- **Watch the rules:**
  - Google's US allowance follows a court order, reported to run until November 2027. Recheck it before then, and before each store submission (Apple guideline 3.1.1(a), Google Play's payments policy).
  - On Android the US check uses the phone's region, because Play's own country needs its billing library. If Google objects, switch to Play Billing's `BillingConfig.countryCode`.

## Health and Inspire

- **Health:** accounts and sync, background delivery, and what raising a target does to past days. See [design/health.md](design/health.md) ("Later").
- **Inspire:** widgets, a habit's quote as its reminder text, and quotes on moments (a comeback, a two-minute day, a habit formed). See [design/inspire.md](design/inspire.md) ("Later").

## Quality

- **Test coverage** was 58.5% when last measured (October 15). Use cases, the data layer and `habit_provider.dart` were the weakest. Measure it again with `./flutter/bin/flutter test --coverage`.

## Housekeeping

- **Merged branches:** `health`, `health-2` to `health-5`, `inspire`, `inspire-fade` and `inspire-shuffle` are all merged into `main` and can be deleted. `quotes-2` is checked out in `../atomic-momentum-health`.
- **Measurement worktrees:** `../atomic-momentum-perf`, `-perf-after`, `-year` and `-year-se` are detached checkouts used for speed and year-of-use runs. Remove them with `git worktree remove` once those runs are finished.
- **Simulator installs:** two `flutter run`s in this folder share one build directory, so the second waits for the first. Install on one simulator at a time and check the installed copy has the change.

## Done

- **Freezes, vacation mode and fun achievements** (October 19): the rewards idea, as Paul reshaped it. See [design/freezes.md](design/freezes.md).

- **Loading a year off the main isolate** (`2cafdc0`), with decode-once storage and cached statistics (`76f7dc2`, `3ee1b35`, `e60195e`).
- **The intro waits out a stalled start** (`9e858f5`) and **holds until habits load** (`d469056`). The 4 s hold (`IntroScreen.maxHold`) is never reached in release, since habits load well inside the 2.4 s intro.
- **A year on a real iPhone** (15 Pro Max, release build with `DEV_TOOLS=1`, "Load a year of use"): Paul saw no lag on launch, a fresh relaunch, or opening Insights. The intro took longer than the loading, and it stays.
- **Profile-mode launch, measured** (Android emulator, quiet machine, `tool/perf_check.sh`): from start to habits on screen took 536 ms with a year of history and 838 ms with two.
