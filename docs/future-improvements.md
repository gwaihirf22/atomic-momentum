# Future improvements

Things to do that aren't on the product roadmap, or that are smaller than a roadmap item: performance, polish, loose ends and decisions still to make. The roadmap itself (statistics, onboarding, store readiness, routines, Pro, widgets) is in [strategy/product-strategy.md](strategy/product-strategy.md#4-roadmap).

*Last updated October 18, 2026.* Move an item to "Done" with its commit when it's built.

## Performance with a long history

- **Compact settled history** (checkpoint plus recent days, the rest archived and unpacked only when needed). Design: [design/history-compaction.md](design/history-compaction.md). Decide after the profile-mode measurements below.
- **Measure profile mode, what ships.** Use `tool/perf_check.sh <android device> [years]` on a quiet machine, plus an iPhone profile build.
  - Debug simulator runs are much slower than release and swing with machine load. One run at a load average of about 150 took about 13 s to show a year of habits.
  - Use the profile numbers to decide on compaction and on the intro's hold.
- **The first achievements check after loading** runs on the main isolate, after the frame. With a cold year it can hitch in debug. Move it off-thread if it shows up just after the intro.
- **The intro's hold** (`IntroScreen.maxHold`, 4 s) covers loading on a cold launch. Revisit it once profile numbers are in: if a year loads well under 4 s in release, leave it.

## App icon, launch and intro

- **More app icons.** The catalogue is built to grow: a source picture, a line in `tool/make_app_icons.py`, an `AppIcons` entry, a manifest alias and the Xcode setting (CLAUDE.md, "App icon"). **Decision needed:** the strategy lists "themes and alternate app icons" under Pro, but themes and the icon choice are free today.
- **iOS 18 tinted icons.** iOS makes a tinted version from the default icon. A tinted variant of our own (a grayscale logo in each icon set) would look cleaner.
- **The launch screen follows the phone's light or dark mode, not the app's Appearance setting.** With Appearance set to Dark on a phone in light mode, a cream frame shows before the dark intro. Native launch screens can't read the app's setting, so the only fix would be a neutral launch colour.
- **macOS and web icons** still come from the older `assets/branding/app_icon.png` crop. Regenerate them from the new full-bleed masters (`app_icon_charged.png`, `app_icon_light.png`).
- **`MomentumMark`** (the logo drawn in code, in the theme's colours) can be reused for the onboarding tutorial and an About screen.

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
- **The intro waits out a stalled start** (`9e858f5`) and **holds until habits load** (`d469056`).
