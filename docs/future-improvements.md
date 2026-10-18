# Future improvements

Things to do that aren't on the product roadmap, or that are smaller than a roadmap item: performance, polish, loose ends and decisions still to make. The roadmap itself (statistics, onboarding, store readiness, routines, Pro, widgets) is in [strategy/product-strategy.md](strategy/product-strategy.md#4-roadmap).

*Last updated October 18, 2026.* Move an item to "Done" with its commit when it's built.

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

- **Loading a year off the main isolate** (`2cafdc0`), with decode-once storage and cached statistics (`76f7dc2`, `3ee1b35`, `e60195e`).
- **The intro waits out a stalled start** (`9e858f5`) and **holds until habits load** (`d469056`). The 4 s hold (`IntroScreen.maxHold`) is never reached in release, since habits load well inside the 2.4 s intro.
- **A year on a real iPhone** (15 Pro Max, release build with `DEV_TOOLS=1`, "Load a year of use"): Paul saw no lag on launch, a fresh relaunch, or opening Insights. The intro took longer than the loading, and it stays.
- **Profile-mode launch, measured** (Android emulator, quiet machine, `tool/perf_check.sh`): from start to habits on screen took 536 ms with a year of history and 838 ms with two.
