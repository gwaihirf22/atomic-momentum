# Freezes, vacation mode and fun achievements

*Built October 19, 2026. This replaces the strategy's earlier "rewards" idea (a freeze day for a week straight, a break day for a month straight).*

## What people get

**Freezes.** One bank for every habit.
- **The bank:** you start with 3 and can hold 5. Each streak milestone (7, 21, 66 days and so on, kept or clean) and each "Habit formed" adds one, and the celebration says "+1 freeze · 4 of 5" (or "Freeze bank full").
- **What a freeze does:** spending one holds a single habit **exactly as it was for one period** (a day, or the week or month for longer habits). That period is neither kept nor missed: the streak doesn't grow or break, momentum stays put, and that period's reminders and "Don't miss twice" warnings stop.
- **When:** a freeze can go ahead (up to 30 days), on the day, or after a miss (as far back as the period that started 7 days ago). It can't go before the habit was tracked, on a rest day, or on a period that's already kept.
- **Where:** from the habit's page, on the chosen day. The page's week and month strips let you pick days ahead too, but only for freezing. There's also a swipe right on the card (freeze today), and "Freeze yesterday" on the habit's page when the card says "Don't miss twice".
- **A kept period wins.** A frozen period that gets done anyway (or kept with the two-minute version, or, breaking a habit, that ends clean) gives its freeze back: "You kept Read anyway, so its freeze came back." Unfreezing gives it back too.

**Vacation mode** (Settings → Freezes) pauses every habit at once and costs no freezes.
- **While it's on:** nothing is due, there are no reminders or warnings, streaks and momentum hold, and the Habits screen shows a banner with "Turn off".
- **Turning it off:** the pause closes on today, so today stays paused too.
- **What it covers:** a period the vacation touches is paused unless it was kept anyway. Logging still works.

**Fun achievements** are in the app's voice ("I…"), or the atoms' where that reads better. They're celebrated after the real milestones and don't earn freezes:

| Id | Title | When |
|---|---|---|
| `fun_over_<habit>` | Overachiever | 3× the target in one period |
| `fun_tiny5_<habit>` | Speedrunner | the two-minute version 5 periods in a row |
| `fun_respawn_<habit>` | Respawned | kept again right after a streak ended |
| `fun_lap_<habit>` | A lap around the sun | tracked for 365 days |
| `fun_noIce` | No ice required | a run of 30 with no freeze in it (the first, on any habit) |
| `fun_sweep` | Clean sweep | every habit done in full on a day with at least 5 due |
| `fun_weekend` | Weekend warrior | every habit kept on a Saturday and the Sunday after |
| `fun_diary` | Dear diary | notes on 10 days |
| `fun_juggler` | Juggler | 10 habits tracked at once |
| `fun_postcard` | Postcard | logged on the day a vacation ended |
| `fun_firstFreeze` | Brain freeze | the first freeze spent |
| `fun_fund` | Rainy-day fund | the bank full for 30 days |

The wording lives in `Achievements._funFor` / `_funAcross` (`lib/domain/services/achievements.dart`).

## How it works

- **`Habit.frozenDays`** (one day per period) and **`Habit.pauses`** (`HabitPause`, from–to, open while vacation mode is on) are stored with the habit (JSON keys `frozen` and `pauses`).
- **One rule for both: a paused period that wasn't kept is skipped like a rest day.** `Habit` hands the streak and momentum calculators a `PausedSchedule` (`lib/domain/entities/habit_pause.dart`), whose `isDueOn` is false for those periods.
  - So streaks, the never-miss-twice bridge, momentum (including the comeback refund), `streakDeadline` and `nextMissAt` all skip them without knowing about freezes.
  - An open vacation only pauses up to today, and searches are bounded, so a long vacation can't loop forever.
- **Marks and statistics:**
  - `PeriodMark.frozen` marks these periods; `PeriodMark.isDue` is false for rest, untracked and frozen alike.
  - Insights' `DayRecord.frozen` counts them apart from what was due, and the heatmap outlines a frozen-only day in ice.
  - Achievement walks skip frozen periods.
- **Notifications:** `ReminderPlanner` and `StreakWarningPlanner` stop for paused days and while vacation mode is on.
- **`FreezeBank`** (`lib/core/services/freeze_bank.dart`, `freeze_bank_v1`):
  - It holds the count, the milestone ids already credited, and dates that never change once set: `firstSpentOn`, and `fundReachedOn` for "Rainy-day fund". Achievements read those through `Achievements.freezeSource`.
  - Crediting happens in `IOSMainNavigation._checkAchievements`. The first look files what's already earned quietly, so existing people start with 3.
  - "Load a year of use" keeps the bank aside with the person's data.
- **`HabitProvider`:**
  - `freeze` / `unfreeze` spend and refund through the bank.
  - `startVacation` / `endVacation` write every habit.
  - After each save, load and new day it hands back freezes that weren't needed (`Habit.unneededFreezes`), leaving a notice for Habits (`takeFreezeNotice`).
- **Home screen widgets:** the snapshot carries `frozen` per habit. A frozen habit shows "Frozen" with no +.

## Testing

- **Unit:**
  - `test/unit/domain/entities/habit_freeze_test.dart`: the rules (neutral streaks and momentum, the gap, kept beats frozen, break habits, weekly, limits, vacation, reminders, storage).
  - `test/unit/domain/services/fun_achievements_test.dart`: each fun achievement.
- **Integration:** `test/integration/freezes_flow_test.dart` covers the bank, spending, refunds, the cap and vacation, with real storage.
- **Widget:** `test/widget/freezes_test.dart` covers the habit page, the swipe, Settings and the banner. `test/widget/small_screens_test.dart` covers the frozen habit page, Habits on vacation, the explainer and the fun celebration.
- **Notification simulator, scenario 14:** a freeze ahead, one on the day that's then kept (it comes back), one after a miss, an empty bank, and four days of vacation. No reminder or warning arrives for any of them.
- **Year simulator:**
  - The persona freezes three times, where the app allows it, and spends its fortnight holiday in vacation mode.
  - `Reference` models paused periods (`RefMark.frozen`, `skipped`), the fun achievements and the first freeze, independently.
  - "Load a year of use" replays the same.

## Later

- **A habit's own pause** (one habit on vacation, the others not).
- **Freezes in Insights** (how many spent, and when).
- **Freezes on Android widgets**, when those come.
