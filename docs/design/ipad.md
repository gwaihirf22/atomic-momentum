# Momentum on iPad

*Built October 26, 2026 on the `plus` branch, to ship with Momentum Plus as 1.1 (sync with your iPad is Plus's first feature, so the iPad had to be a real iPad app first). Paul chose the full iPad design.*

## What changes

Momentum used to be iPhone-only: on an iPad it ran as a phone-sized window, locked upright. Now it's a universal app (`TARGETED_DEVICE_FAMILY = "1,2"`, app and widgets):
- **It turns any way on iPad** (Info.plist's `~ipad` orientations). iPhones stay upright: `main()` locks portrait unless the device is a tablet (`isTabletScreen`).
- **What's an iPad** comes from iOS itself (`DeviceKind`, channel `momentum/device`: `userInterfaceIdiom == .pad`), not from the size: the **iPhone Duo** unfolds to 669 × 951 points, bigger than many tablets' short side, and is still an iPhone ("this phone", upright, the phone layout with roomier cards). Where the platform can't say (Android, tests) a short side of 700 points or more counts (`AppLayout.tabletFrom`; the iPad mini is 744).
- **It works at any window size:** Split View, Slide Over and Stage Manager. The layout follows the window, never the device.
- **One window at a time.** Flutter on iOS runs one engine bound to one window, and the app's request notifiers are global (`NotificationService.focusRequests`, `IOSMainNavigation.tabRequests`, `TourGate.step`, `HabitCard._all`): with two windows a notification tap would be handled twice. `UIApplicationSupportsMultipleScenes` stays false.

## Three tiers, from the window's width

`AppLayout.of(context)` (`lib/presentation/layout/app_layout.dart`):

| Tier | Width | Looks like |
|---|---|---|
| **compact** | under 700 | The phone app, unchanged: the floating tab bar; pages push. A narrow Split View on an iPad gets this too. |
| **regular** | 700 to 1099 | iPad upright, two-thirds Split View: the sidebar, and one content pane; a habit's page pushes in it. |
| **wide** | 1100 and up | iPad sideways, 13" upright: the sidebar, the Habits list, and the selected habit's page beside it. |

Resizing a window switches tiers live, on the same section; a habit showing beside the list moves onto the tab's own stack when the window narrows.

## The pieces

- **Sidebar** (`AppSidebar`, in `IOSMainNavigation` from regular up): "Momentum", **Add habit**, Habits with the person's categories under it (a tap filters the list through the shared `CategoryProvider` filter, as the rings do; holding one opens Arrange; each shows "2/5" done today), Calendar, Insights, Inspire (when on), Settings. It keeps the tab bar's keys (`tab_habits`, `addHabitButton`) and tour anchors (`tabBar`, `addHabit`), so tours, tests and requests from outside work unchanged. No tab swipe, and no hiding while a page is open.
- **A habit beside its list** (`HabitPages.open` in `habit_pages.dart`): every place that opens a habit's page goes through it. On a wide window it sets the Habits tab's `HabitSelection`, and `HabitSplitView` shows the page in a navigator of its own beside the list (with its own `ScaffoldMessenger`, so a SnackBar shows in one column only); the card is tinted while it's showing; a notification tap selects it. Otherwise it pushes, as on a phone. Nothing selected: "Pick a habit" (`PickAHabit`).
- **Calendar** sizes its grid from its own pane (`LayoutBuilder`), with cells up to 52 points where there's room; wide, the month sits beside the chosen day's habits.
- **Insights** deals its cards into columns (`CardColumns`: as many as fit at 400 points or more, read across then down; one on a phone); the heatmap spans the width, and its squares grow to 20 points.
- **Readable widths:** `LargeTitleScaffold.maxContentWidth` centres a page's content within a cap (Settings and the week in review 680, a habit's page and Habits 760, Quotes 720, Achievements 900, Insights 1100); `ReadableWidth` and `ReadableColumn` do the same elsewhere (Inspire's quote 600, Arrange, How to).
- **Forms** (Add and Edit) open as a **form sheet** on regular and wide (`FormSheet.route`: a card up to 620 × 860, centred over the dimmed app, not dismissed by a stray tap); full screen on a phone.
- **Sheets and pickers:** bottom sheets stop at 640 wide (`bottomSheetTheme`), action sheets and date pickers at 500 (`_PopupWidth` in `adaptive.dart`).
- **Words:** `DeviceWords` says "this phone", "this iPad" or "this tablet" ("Your health data stays on this iPad", "restart your iPad"); the empty Habits list says "Tap Add habit" where there's a sidebar.
- **Tours:** no bar to keep clear of with a sidebar (`bottomCovered: 0`); a bubble that fits neither above nor below a tall target (the sidebar) goes beside it, its arrow pointing across (`RenderCallout.arrowSideways`).
- **Page transitions:** hidden tabs are under `HeroMode(enabled: false)`, so a SnackBar shown in every tab never flies from each when a page opens.
- **Widgets:** extra large (iPad only) for Habits (twelve habits in two columns, + on each) and Insights (the month beside its heatmap).

## Testing

- `test/widget/app_layout_test.dart`: tiers, columns, device words, readable widths.
- `test/widget/app_sidebar_test.dart`: the sidebar on iPads upright and sideways, Add, categories, live resizing.
- `test/widget/split_view_test.dart`: a habit beside the list, deleting it, a notification tap, narrowing the window, Calendar wide and on a phone, card columns.
- `test/widget/ipad_layouts_test.dart`: the whole app with a year of use and real fonts at 11" and 13" both ways and two Split View widths, at 100% and 135% text: every section, a habit and Add, nothing cut off.
- `small_screens_test` renders every screen at 834 and 1194 too; `tours_test` runs every tour on iPads; the monkey walks an 11" iPad both ways.
- **By eye:** `./flutter/bin/flutter test tool/screens/layout_shots_test.dart` writes pictures of the real app at iPad, Split View and iPhone sizes to `build/layout_shots/` (a simulator can't be turned from the command line).
- **On a simulator:** "Momentum iPad Pro 11" (iOS 27.0), with the iPhones.

## App Store

An app that runs on iPad needs 13" iPad screenshots. `tool/store_screens.sh "Store iPad Pro 13-inch"` takes them upright (`STORE_IPAD` names them `ipad_…`), and `python3 tool/store_frames.py --ipad` frames them in an iPad on a 2064 × 2752 canvas; the set to upload is `build/store_frames/final_ipad/`. They can't be taken sideways: iPadOS ignores an app's orientation lock when it supports multitasking, so `SystemChrome.setPreferredOrientations` doesn't turn an iPad.

## Later

- Several Momentum windows side by side (needs Flutter multi-window on iOS, and the global notifiers made per window).
- The habit page in a sheet from Calendar on wide windows, rather than pushed.
- Android tablets get these layouts already (the tiers are by width); check them on a tablet emulator when Android work resumes.
