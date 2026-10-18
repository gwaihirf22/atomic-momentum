# Long history: load what's needed, compact what's settled

*Proposed October 18, 2026. Not built yet: measure first (see "When to build it").*

## Why

A habit keeps its whole per-day history (`Habit.history`, `twoMinuteDays`, `dayNotes`), and everything on screen is worked out from it: streaks, momentum, period totals, statistics, achievements and heatmaps. That keeps one source of truth, which is simple and correct. But **every launch replays every habit from its first day**.

A year isn't much data: 11 habits × 365 days is about 4,000 day entries, roughly 100 KB of JSON. The cost is the replay.
- **Before the speed pass:** on the iPhone 17 Pro simulator with a year of data, a debug launch froze the screen for about 3 s. Headless (debug VM), a cold start with a year takes about 51 ms after that pass.
- **Since then:** loading has moved off the main isolate (`2cafdc0`).
- **What grows:** the replay grows with every day the app is used. At five years it is five times the work, on every launch, for days that will never change.

## Two ideas

### 1. Only load what's needed, when it's needed

- **Launch** needs today: each habit's current period, its streak, its momentum, and the last 7 periods on the card. It doesn't need the full history.
- **Screens that look back** load more when they open:
  - Insights' 6 months;
  - a habit's page (8 weeks, its 6-month heatmap);
  - the full-history heatmap (`HeatmapScreen`).
- **This already happens in part:** caches are keyed per habit and per day (CLAUDE.md, "Performance with a long history"). The missing piece is the storage: today, decoding the habits list decodes every day of every habit.

### 2. Compact what's settled: checkpoint plus recent days

Days older than a **window** (about 60 days) almost never change. Instead of replaying them, keep:

1. **A checkpoint** for each habit, as of the day the window starts. It holds the running state that the replay would have reached.
2. **The recent days** inside the window, in full, exactly as today.
3. **The archive:** the old days themselves, stored apart (a separate key, compact encoding) and **not read at launch**. Nothing is thrown away.

At launch the app reads only the checkpoints and the recent days, then replays about 60 days. That stays the same size forever.

## What each worked-out value needs from the old days

Almost everything is a running total, so the checkpoint only has to hold where each one had got to:

| Value | Kept in the checkpoint | Notes |
|---|---|---|
| Momentum (`MomentumCalculator`) | The score at the window start, and where the current period stands | It's an exponential moving average, so it carries on exactly from its last value |
| Streak, best streak (`StreakCalculator`) | The streak running into the window (with its never-miss-twice state: whether the last period was missed), plus the best ever | The streak may reach back years; only its length and state are needed |
| Period totals | The total of a period that straddles the window start (weekly or monthly habits) | |
| Achievements | Already earned and remembered (`AchievementStore`); the checkpoint adds the running counts (perfect weeks, comebacks, days without slipping) | Milestones only need the counts |
| Insights by month, weekdays, kept and two-minute counts | One summary per archived month | Insights' charts show monthly points anyway |
| Heatmaps | One small level per day (0–4, two-minute, rest day), packed tightly | The full-history heatmap reads this, not the full records |
| Momentum over time (`Habit.momentumSeries`) | One value per archived day, or per week | For the 6-month chart, only the window and the months just before it are needed |

## Unpacking

Some actions need the old days back. Then that habit's archive is read, the change is made, and its checkpoint is rebuilt:
- **Editing an old day** on the Calendar or the habit page.
- **Moving a habit's start earlier:** "Start from this day" (`Habit.startFrom`) and "Counts from" (`Habit.countFrom`).
- **Changing a habit's target or schedule.** Past days are re-scored against the new target (see `docs/design/health.md`, "Later"), so every checkpointed value changes.
- **Changing its reset day** (`Habit.resetAnchor`), because period boundaries move.
- **The full-history heatmap,** if it needs more than the packed levels (it shouldn't).

None of these happen at launch, and they touch one habit at a time. A few hundred milliseconds there is fine.

## Storage and migration

- **New layout per habit:** `checkpoint`, `recent` (today's format, within the window) and `archive` (a separate key per habit, e.g. `habit_archive_<id>`). Prefs reads and writes stay on the main isolate; decoding can stay in `Isolate.run` as now.
- **Rolling the window:** done at most once a day, at the launch's period reset (`UpdateHabitUseCase.refreshAll`). Days that leave the window are folded into the checkpoint and appended to the archive in the same single write.
- **Migration:** one-time and per habit. Replay the full history, write the checkpoint and archive, and keep the old JSON until the new one is read back and checks out.
- **Backup, sync and CSV export** (Pro, later) read the archive as well. The archive is just the days, so nothing is lost.

## How we'll know it's right

The rule is that the compacted app gives **exactly** what the full replay gives:
- **Every value:** streaks, best streaks, momentum, achievements, Insights and heatmaps.
- **Every kind of habit:** daily, weekdays, every few days or weeks, monthly, breaking a habit (quit and limit), two-minute days, rest days, and changed targets.

We'll check that three ways:
- **The year simulator** (`test/simulation/year/`) already checks a scripted year every day against an independent model. Run it with compaction on; it must not change a line of the digest.
- **A property test:** random histories, compacted at random windows, compared value by value with the full replay.
- **The performance test** (`test/performance/year_performance_test.dart`, `tool/perf_check.sh`): a cold start at one, two and five years should take about the same time.

## When to build it

First measure profile mode, which is what ships: `tool/perf_check.sh <android device> [years]` and an iPhone profile build.
- **If a year (and two) loads in a small fraction of a second,** this is insurance for long-time users. Build it before launch, but it isn't urgent.
- **If it's slow,** build it now.

Either way it belongs with the performance work, because it changes the storage format the whole app reads.

## Open questions

- **Window length:** 60 days, or a calendar boundary such as "before last month"? A calendar boundary makes monthly habits and monthly Insights simpler.
- **Editing old days:** keep it free (unpack quietly), or ask first ("This day is archived; edit it anyway?")? Unpacking quietly is friendlier; it only costs time.
- **Packed heatmap levels:** keep them per day forever, or drop to per week after a few years?
