# Onboarding tours and How-to

v1 roadmap item 5. The strategy wants the tutorial to teach the method ("Momentum, not perfection", *Atomic Habits*), not just the controls.

## Paul's choices (2026-10-19)
- **Short tours**, one per screen:
  - First launch runs only the **Habits** tour, which says more tours come as you visit other tabs.
  - The first visit to Calendar, Insights, Inspire, Settings, a habit page or the Add-habit editor runs that screen's tour.
- **Style:** a dimmed screen with a spotlight cut-out, a speech bubble and an arrow.
- **Every step works both ways** (Paul, 2026-10-19, after trying the preview): the person can do the thing in the spotlight or tap **Next**, on every step.
  - Steps with an action ("Tap + to log one more glass, or tap Next") move on by themselves when it's done.
  - The spotlight always lets touches through (on example habits, so nothing real changes), and **Next** and **Skip** are always there.
  - No step makes you act, and none makes you tap Next, so a step that says "try it" is never followed by one where the target can't be touched.
- **Example habits:**
  - Tours where history matters (Habits, the habit page, Calendar, Insights) run on **example habits** with 6+ months of use.
  - Inspire, Settings and the editor run on the person's real screen, with Next steps only.
- **Ending:** the first tour ends on the person's own empty Habits screen, with a bubble at the Add habit orb. Notification permission is asked when the first tour closes, not after the intro.
- **Skip and replay:** skip any time; replay from **Settings → Help** (the first section): **How to** and **Tours**.
- **How-to pictures** are **live miniatures**: real screens rendered small from the example data, in the reader's theme, annotated, never stale, no PNGs. The one exception is iOS home-screen widgets (SwiftUI), shown as a few PNGs.
- **People who already have habits** are offered the tours once: "New: short tours. Take the Habits tour?" (Start / Not now).

## Built

### P0: the look (18c6363), waiting for Paul's approval
- **`TourSpotlight`** (`lib/presentation/tour/spotlight.dart`):
  - the screen dimmed in `AppPalette.scrim`;
  - a rounded hole around the target (6 pt padding, radius 14) with an accent ring that pulses on try-its (not with Reduce Motion);
  - touches absorbed except inside the hole on a try-it.
- **`RenderCallout`** places the bubble on the side with room (preferring the asked-for side), its arrow at the target's middle, clear of the tab bar. With no room or no target, it sits in the middle without an arrow.
- **`TourBubble`** (`tour_bubble.dart`): an eyebrow, or a "Try it" chip; one or two sentences; step dots; Skip; an orb Next (`TourNextButton`), on every step.
- **`ExampleHabitsPill`**: "Example habits · Done".
- **Settings → Developer → "Tour style preview"** steps through five examples over the real Habits screen.
- **`tool/tour_screens.sh "<device>"`** screenshots each step in Light, Sepia and Charged at 100% and 135% text, into `build/tour_screens/<device>/`.

### P1: the example world (bcadae1)
- **`DemoPersona`** (`lib/core/demo/demo_persona.dart`): 8 habits over 200 days ending today. The last days are scripted:

  | Habit | Today |
  |---|---|
  | Drink water | 5 of 8 (the + try-it) |
  | Read | not started (the hold try-it) |
  | Meditate | missed yesterday: "Don't miss twice" (the swipe) |
  | Social media | being broken, clean |

  Also Gym on today's weekday, Call Mum (weekly, not yet this week), Budget review (monthly), and Journal (added on day 160). A vacation week, three freezes on Meditate, notes and a quote.
- **`YearOfUse.build(Persona, until)` / `YearOfUse.stored`**: `YearPersona` is unchanged.
- **`DemoSeed`** (built once a day, in an isolate) and **`DemoWorld`**: its own providers on `MemoryPrefs`, with no reminders, warnings or Health and a freeze bank of its own. The person's settings are copied in through `SettingsProvider.storedKeys`.
- **`WorldController` / `WorldScope` / `WorldHome`** (`lib/presentation/tour/world_scope.dart`):
  - The root navigator belongs to the world (`CupertinoApp.navigatorKey`), so switching remounts everything below on the world's providers, the editor and sheets included.
  - The theme, the intro and the home-screen widgets stay real.
  - Leaving returns to the tab the person was on.
- **In an example world:**
  - no celebrations;
  - notification and widget taps left for the real app;
  - Health never asked (`NoHealthSource`);
  - Settings hides Developer, App icon and Support.
- **`IOSMainNavigation({demo, initialTab, controller})`**, with `MainNavigationController`: `show`, `navigatorOf`, `popAllToRoot`, `current`.
- **Settings → Developer → "Open example world".**
- **Tests:**
  - the persona on five different todays;
  - isolation: everything done in an example world leaves the person's storage byte-for-byte the same, schedules nothing, and widgets never see an example;
  - a guard against screens reaching past their world (`test/unit/core/world_isolation_guard_test.dart`).

### P2–P4: the engine, the seven tours, How-to (2026-10-19, overnight)
- **Engine** (1b93520): `TourAnchor`/`TourAnchors` (wrapped anchors, or found by the key a widget already has, `TourAnchorId.keyFor`), `TourEvents` (+, hold, Undo, 2 min, swipe, habit page, heatmap and Calendar days, Add habit), `Tour`/`TourStep`/`TourWait`/`TourMove` (`tour.dart`), `TourController` (worlds, step moves, revealing targets, Next or the gesture, Skip, `TourStore` `tours_seen_v1`), `TourLayer` in `MomentumApp`. Every step lets touches through the spotlight and keeps Next and Skip.
- **Tours** (`tours.dart`): Habits (first launch; ends at Add habit in the person's own app), Calendar, Insights, a habit's page (on the example habits), Inspire, Settings, and the first new habit's Story editor (on the person's own screen). Each runs on its first visit once the Habits tour is behind them (`TourController.firstVisit`).
- **First launch** (`TourStart`): a new install takes the Habits tour as the intro ends, then notification permission is asked; people with habits from before are offered it once ("Take the Habits tour?").
- **Giving way**: Android's back steps back (skips on the first step); a notification or widget tap ends a tour; so does coming back after 10 minutes or on a new day.
- **Settings → Help**: How to, and Tours (play any again; "Show tours again").
- **Arrange** (2026-10-20): a tour on the person's own Arrange page, on its first visit with habits to arrange: the Group by category switch, dragging a category, dragging a habit, and the ways in (hold a ring or a card). `Tour.tab` is null for it, so it stays in the tab Arrange opened in; `OpenArrange` opens the page when it's taken again from Settings → Tours. How to has "Arrange your habits" (`HowToScene.arrange` opens the page in a picture).
- **Paul's review, round one** (2026-10-20):
  - **Nothing in a spotlight derails a tour.** A step with nothing to do lets no touches through (`TourStep.passesTouches`: `touchable ?? wait != null`). On a try-it step, `TourGate` (`tour_gate.dart`, set by `TourController`) lets only that step's gesture work: the habit card's open, +, −, ring tap and hold, 2 min, swipes, Freeze, Edit and Delete each check it, and so do Insights' Every day buttons. `tours_test`'s "nothing in a spotlight takes a tour off course" pokes every step of every tour (nine taps, a hold, two drags) and fails if a page or sheet opens or the target is lost.
  - **The app's voice.** Tours speak as the app: first person, a quip now and then, like the fun achievements. Only try-it steps say to do something now; other steps describe ("Once we're done, tap any underlined part").
  - **A welcome** opens the Habits tour: the app's mark, "Hi! I'm Momentum.", thanks, what it's for, and that it does the talking (`TourStep.headline`; Next reads "Show me around").
  - **Freezes** are explained as limited: 3 to start, one earned at milestones, 5 at most.
  - **Settings → Help → Replay tours** (`tours_replay_v1`): the next launch starts over from the welcome, every tour coming back (`TourStart.forLaunch`); it turns itself off once it has run.
- **How to** (`lib/presentation/howto/`, `lib/screens/how_to_screen.dart`): eleven guides, each a page of `PhonePicture`s (the real app on a tab or a habit's page, on the example habits, at 390 × 844 scaled to fit, inert, in the reader's theme, cropped around and ringed on its target) with a sentence or two.
- **Tests**: every step of every tour finds its target at 375 pt / 135% and 390 pt; the Habits tour in all three themes at both sizes with real fonts; doing each thing for real moves on; the offer; replay; first visits once; give-way cases; every guide picture rings its target in all three themes at 375 pt / 135%.

## Left
- **Paul's review** of the screenshots (`tool/tour_screens.sh`), and any wording or style changes.
- **More guides**: the Story/Builder editor pictures (a picture of the editor needs a scene that opens it), Health, sharing, home-screen widgets (iOS PNGs).
- **VoiceOver/TalkBack pass on devices**; Reduce Motion is handled in the spotlight.
- **A habit page's tour** starts on the example habits and returns to the tab, not to the person's own page.

### Original plan, for reference

### P2: the engine
- **Anchors:** `TourAnchor(id, tag, child)` registers a GlobalKey in the nearest `TourAnchorScope` (the root one, or a miniature's own). It resolves only visible copies (TickerMode on, current route, on screen). About 25 thin wrappers:
  - the tab bar and `addHabitButton`;
  - Habits: the overall ring, cards, +, the ring, 2 min, Undo;
  - Calendar: a day, a day's habit;
  - Insights: momentum, heatmap, the day summary;
  - the habit page: ring, freeze, heatmap, momentum, Edit;
  - the editor: the Story sentence, "On a hard day", the style switch;
  - Inspire: the quote, Another, options;
  - Settings' Help rows.

  Example habits are found by name (`DemoWorld.idOf`).
- **`TourLayer`** sits in the `MomentumApp` builder Stack, above the root navigator. A per-frame rect follower tracks scrolling and swipes.
- **Reveal:** `Scrollable.ensureVisible`. For lazy slivers (Settings, Insights, the habit page), a step's `reveal` hint scrolls the `PrimaryScrollController` and waits up to 10 frames. An anchor that never appears is skipped and logged, and tests catch it.
- **Try-it events (`tour_events.dart`):**
  - `PlusTapped`, `HoldFinished`, `HoldUndone`, `HoldExpired`, `CardSwiped` (via `Slidable.of(ctx).actionPaneType`), `HeatmapDaySelected`, `CalendarDaySelected`, `AddHabitTapped`;
  - each is one line in the existing handler, and costs nothing without a listener.
- **Hold Undo:** `HoldUndoTiming` (an InheritedWidget, default `HoldUndo.duration`) gives Undo 12 s during tours.
- **Steps that navigate:** `before` actions `ShowTab`, `PushHabitPage(name)`, `PopToRoot`, `CloseSwipes`, through `MainNavigationController`.
- **`TourController`** and **`TourStore`** (`tours_seen_v1`, the one real key tours write).
- **Accessibility:**
  - **Reduce Motion:** nothing moves (no pulse, scale or fades); scrolling is instant.
  - **VoiceOver and TalkBack:** try-its become Next steps naming the custom action; each bubble is keyed per step so focus moves to it.
- **Android back:** `PopScope` in `WorldHome`; back goes one step back, and on the first step asks before skipping.
- **Lifecycle:** on resume the tour ends (marked seen, swapped back) after a notification or widget tap, a new day, or 10 minutes away.

### P3: the seven tours
- **Tours as data:** `tours.dart` (`TourId {habits, habitPage, calendar, insights, inspire, settings, editor}`, `Tour`, `TourStep`), in the explainers' voice.
- **Habits, the first run, on example habits from launch:**
  1. the momentum ring;
  2. the Water card;
  3. try it: + on Water;
  4. try it: hold Read's ring;
  5. try it: Undo;
  6. try it: swipe Meditate;
  7. "2 min" for hard days;
  8. the tab bar ("More short tours appear as you visit other tabs");
  9. swap to the real world: "Your turn: add your first habit" at the Add habit orb.
- **The other tours, 4–6 steps each:**
  - **Habit page:** ring and typing, the week, freeze, momentum, heatmap, Edit.
  - **Calendar:** tap a day, fix a past day, Start from.
  - **Insights:** the chart's 80 line, try it: tap a heatmap day, full history, achievements.
  - **Inspire (real):** the quote, Save/Add to habit, Another, search.
  - **Settings (real):** Help, freezes and vacation, reminders.
  - **Editor (real, on the person's first new habit):** the Story sentence, "On a hard day", the Builder switch.
- **Triggers:** `tabShown` from `_switchTo`, `habitPageOpened`, and `editorOpened(isNew)`. Postponed while a tour runs, while a sheet or celebration is open, or until the Habits tour is seen.
- **Permission:** the notification permission request moves from `main()` to the end of the first tour.
- **Existing users:** the one-time offer.
- **Settings → Help:** `HowToScreen` and `ToursScreen` (Play for each tour; "Show tours again").
- **Copy fix:** the empty state says "Tap Add habit below…".
- **Starting on example habits:** the first-run Habits tour starts on them from launch. `main()` starts `DemoSeed.forDay` during the intro, and IntroGate's `isReady` reads the world's habits.

### P4: How-to with live miniatures (`lib/presentation/howto/`)
- **`PhoneFrame`:** a 390×844 frame, built as follows.
  - **Settings:** fixed safe-area padding; no text scaling; animations and accessible navigation off.
  - **Theme:** the reader's palette.
  - **Data:** `WorldScope(howToWorld)`, a scoped `TourAnchorScope`, a one-page Navigator, and `TabBarInset` with a static `FloatingTabBar`.
  - **Inert:** `TickerMode(false)`, `IgnorePointer` and `ExcludeFocus`, with one `Semantics(image, label)`.
- **`HowToScene(scene, crop, annotations)`:** annotations are drawn outside the scaled picture at the reader's text size, positioned from the miniature's anchors.
- **States:**
  - **An open swipe:** `Slidable.openEndActionPane(duration: zero)`.
  - **The Undo strip:** `HabitCard(holdUndo: …)`.
  - **Sheets:** `SceneSheet` draws `InfoSheet` or `AchievementSheet`.
  - **Share cards:** a live `ShareCardFrame`.
- **Performance:** lazy `ListView.builder`, a `RepaintBoundary` each. Only if the SE janks, rasterize scenes at runtime.
- **The 15 guides:**
  1. Add a habit
  2. Log your day
  3. Hard days: two minutes
  4. Streaks and never miss twice
  5. Momentum and levels
  6. Freezes and vacation
  7. Breaking a habit
  8. Calendar
  9. The habit page
  10. Insights
  11. Inspire and your own quotes
  12. Reminders and quiet hours
  13. Apple Health / Health Connect
  14. Sharing
  15. Home-screen widgets (iOS PNGs)

### P5: devices and docs
- **Devices:** VoiceOver and TalkBack passes, Reduce Motion, Android profile timing.
- **Docs:** CLAUDE.md and the roadmap.

## Tests still to write
- **Isolation v2:** a `TourDriver` performs every tour's steps and try-its. Only `tours_seen_v1` may change.
- **Fit:** every step of every tour at 375×667 and 390×844, at 100% and 135% text, in 3 palettes:
  - the anchor resolves;
  - the cut-out stays in the safe area and clear of the tab bar;
  - the bubble is inside the safe area and doesn't cover the cut-out;
  - nothing overflows.

  The How-to guides are tested the same way.
- **Flow:**
  - first launch, through to permission and the Add bubble;
  - a skip at each step;
  - Android back;
  - a resume after a notification tap;
  - a midnight during a tour;
  - the existing-user offer, once;
  - "Show tours again";
  - each tab's tour, once only.
- **Devices:** an integration test screenshots every tour step on both iPhones and Android for Paul's review.

## Risks
1. **Leaks through globals.** Covered by the guard and isolation tests. `Achievements.freezeSource` reads the real bank's dates; at worst a fun achievement shows.
2. **Lazy slivers and hidden tabs.** Handled by the `reveal` hints, and caught by the fit test.
3. **Gestures through the cut-out:** Slidable versus the tab swipe, and holds. Check on devices early in P2.
4. **135% text next to large cut-outs:** short text, and the pinned-bubble fallback.
5. **The example build on a slow phone** outlasting the intro. Measure it.
6. **VoiceOver focus** differs between iOS and Android.
