# App Store listing (draft)

What goes into App Store Connect. Character limits are Apple's; counts are in brackets.

## Names

| Field | Text | Notes |
|---|---|---|
| **Name** (30) | Atomic Momentum [15] | Paul's choice (2026-10-20). "Momentum" alone is taken on the App Store several times over. The name under the icon stays "Momentum" (`CFBundleDisplayName`). |
| **Subtitle** (30) | Build habits, never miss twice [30] | Searchable like the name, so it carries "habits". Alternative: "Momentum, not perfection" [24] |
| **Bundle ID** | com.paulblake.momentum | |
| **SKU** | momentum-ios | Any unique text; only you see it. |

## Promotional text (170, can change any time without review)

Miss a day? It happens. Momentum keeps your progress, counts the two-minute days, and only asks one thing: don't miss twice. Free, private, no ads.

## Description (4,000)

Momentum is a habit tracker built on how habits really form: not by being perfect, but by showing up most days and never missing twice.

MOMENTUM, NOT PERFECTION
Most trackers drop you back to zero the moment you miss a day. Momentum doesn't. Every habit has a momentum score from 0 to 100 that grows as you show up and dips gently when you don't. Reach 80 and the habit is formed, which takes about 66 days of steady practice on average.

NEVER MISS TWICE
One miss is life. Two in a row is the start of a new habit. Your streak survives a single miss, and Momentum warns you before the miss that would end it.

THE TWO-MINUTE VERSION
Give each habit a tiny version for hard days: one push-up, one page, one glass of water. Doing it keeps your streak, and your momentum never drops for it.

FREEZES AND VACATION MODE
Earn freezes from your streak milestones and spend one to hold a habit for a day, ahead of time or after the fact. Going away? Vacation mode pauses everything at once.

BUILD OR BREAK
Track habits you're building (read, run, drink water) or breaking (quit smoking, keep drinks to two a week), on any schedule: daily, on chosen days, every few days, weekly or monthly.

REMINDERS THAT KNOW YOUR SCHEDULE
Smart reminders follow each habit's due days and stop once it's done. Quiet hours, your own sounds, and time-sensitive alerts if you want them.

APPLE HEALTH
Link a habit to steps, exercise, workouts, sleep, mindful minutes or water, and it fills itself in.

INSIGHTS AND ACHIEVEMENTS
A heatmap of every day, your momentum month by month, your best weekdays, and achievements for real milestones, plus a few silly ones. Share any of them as a card.

WIDGETS
Log a habit from your home screen with one tap, keep momentum on your lock screen, and start the day with a quote.

INSPIRE
A quote for every day from the Stoics, classic writers and Scripture, and space for your own. Pin your favourites to the habits they help with.

PRIVATE BY DESIGN
No account, no ads, no tracking. Your habits never leave your phone.

FREE
Every feature is free, with no subscription and no Pro version.

## Keywords (100, comma-separated, no spaces needed)

habit,tracker,streak,routine,goals,daily,two minute rule,quit,reminder,widget,heatmap,journal,health [100]

- Words already in the name and subtitle (atomic, momentum, build, habits, never, miss, twice) count without being repeated here.
- No other apps' or books' names (Apple rejects that).

## Categories and rating

- **Primary category:** Health & Fitness
- **Secondary category:** Productivity
- **Age rating:** answer "None" to every question in the questionnaire, which gives **4+**.
  - There's no user-generated content shared with others, no web browsing and no chat.
  - The "Buy me a coffee" link opens Safari and isn't a purchase in the app.
- **Price:** Free. No in-app purchases.

## Links

| Field | Value |
|---|---|
| **Privacy policy URL** | https://paul-blake.com/momentum/privacy |
| **Support URL** | https://paul-blake.com/momentum/support (email momentum@paul-blake.com) |
| **Marketing URL** | optional, leave empty |
| **Copyright** | 2026 Paul Blake (or the LLC's name) |

## Screenshots

**Made:** 8 at 6.9" (1320 × 2868), framed with a headline. Upload `build/store_frames/final/` in order. Apple scales them for the smaller iPhones.

**To remake them** after a screen changes:
1. `tool/store_screens.sh` captures the example habits on the "Store iPhone 17 Pro Max" simulator, in Sepia, Charged and Light.
2. `python3 tool/store_frames.py` adds the headline and the phone frame.

The words and the order of looks are in `SCREENS` and `FINAL` in that script.

| # | Look | Headline | Screen |
|---|---|---|---|
| 1 | Sepia | Momentum, not perfection | Habits |
| 2 | Sepia | Small steps add up | Drink water's page |
| 3 | Charged | Miss once. Never twice. | Meditate, "Freeze yesterday" |
| 4 | Light | Hard day? 2 minutes counts | The Story editor's hard-day line |
| 5 | Sepia | See your momentum grow | Insights |
| 6 | Charged | Every day, at a glance | Calendar |
| 7 | Light | Words to keep you going | Inspire |
| 8 | Sepia | Celebrate the milestones | Achievements |

The first three show in search results.

**Still to add:** a home screen widgets shot, which needs widgets placed on the 6.9" simulator's home screen.
