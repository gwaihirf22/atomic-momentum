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
Smart reminders follow each habit's due days and stop once it's done. Quiet hours, a choice of sounds, and time-sensitive alerts if you want them.

APPLE HEALTH
Link a habit to steps, exercise, workouts, sleep, mindful minutes or water, and it fills itself in.

INSIGHTS AND ACHIEVEMENTS
A heatmap of every day, your momentum month by month, your best weekdays, and achievements for real milestones, plus a few silly ones. On the last evening of each week, a week in review sums up your wins and comebacks. Share any of them as a card.

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
- **Age rating:** "None" or "No" to every question except:
  - **Alcohol, tobacco or drug use or references: Infrequent.** The habits being broken have quick picks "Smoking" and "Alcohol" ("I will keep [alcohol] to [2 drinks]"): references made to quit, but references. It gives 13+ (confirmed in App Store Connect, 2026-10-21) rather than 4+; "None" would keep 4+ at a small risk of App Review asking. (Checked 2026-10-21.)
  - **Health or wellness topics: Yes** (habits, Apple Health). Medical or treatment information: None (no advice or diagnosis).
  - Unrestricted web access: No (the links open fixed pages in Safari). User-generated content: No (your own quotes stay on the phone).
  - There's no user-generated content shared with others, no web browsing and no chat.
  - **Social media capabilities: No** (Apple's question since July 2026: redistributing, amplifying or interacting with user-generated content through a feed). Share cards go out through iOS's share sheet to other apps, and sync (1.1) is only between the person's own devices.
  - The "Buy me a coffee" link opens Safari and isn't a purchase in the app.
- **Price:** Free. No in-app purchases.

## Links

| Field | Value |
|---|---|
| **Privacy policy URL** | https://paul-blake.com/momentum/privacy |
| **Support URL** | https://paul-blake.com/momentum/support (email momentum@paul-blake.com) |
| **Marketing URL** | optional, leave empty |
| **Copyright** | 2026 Blake Built (a brand: the seller line shows Paul's legal name, as on any individual account) |

## Screenshots

**Made:** 10 at 6.9" (1320 × 2868), framed with a headline, and uploaded with build 2. Apple scales them for the smaller iPhones. The uploaded set is kept in [screenshots/](screenshots/), in order, with the raw lock screen and home screen captures in `screenshots/system/` (the hard ones to retake: copy them into `build/store_screens/` to reframe without step 2). A fresh run writes `build/store_frames/final/`.

**To remake them** after a screen changes:
1. `tool/store_screens.sh` captures the example habits on the "Store iPhone 17 Pro Max" simulator (iOS 27), in Sepia, Charged and Light. It leaves the app installed, with the example habits in its widgets.
2. `tool/widget_screens.sh` uses a UI test (`tool/springboard_shots/`) to drive SpringBoard. It adds Momentum's widgets to the home screen and the lock screen and takes both.
   - It needs a simulator whose home screen and lock screen haven't been edited before: delete and recreate it.
   - Don't erase it instead: the app's first launch after an erase hangs.
3. `python3 tool/store_frames.py` adds the headline and the phone frame.

**iPad (1.1, `plus` branch):** an app that runs on iPad needs 13" iPad screenshots too.
1. `tool/store_screens.sh "Store iPad Pro 13-inch"` takes the same app screens upright (2064 × 2752), with the sidebar, as `ipad_<theme>_<name>.png`.
2. `python3 tool/store_frames.py --ipad` frames them in an iPad under the same headlines. The set to upload, in the iPhone set's order without the lock and home screens, is `build/store_frames/final_ipad/`.

The words and the order of looks are in `SCREENS` and `FINAL` in that script.

| # | Look | Headline | Screen |
|---|---|---|---|
| 1 | Sepia | Momentum, not perfection | Habits |
| 2 | Sepia | Small steps add up | Drink water's page |
| 3 | Charged | Miss once. Never twice. | Meditate, "Freeze yesterday" |
| 4 | Sepia | Right on your lock screen | The lock screen: Habit rectangle with +, Momentum, Streak |
| 5 | Light | Log it from home screen | Habit, Momentum, Habits (Today), Quote |
| 6 | Charged | Hard day? 2 minutes counts | The Story editor's hard-day line |
| 7 | Sepia | See your momentum grow | Insights |
| 8 | Light | Every day, at a glance | Calendar |
| 9 | Charged | Words to keep you going | Inspire |
| 10 | Sepia | Celebrate the milestones | Achievements |

The first three show in search results.

## 1.1 draft (Momentum Plus, iPad; not live)

*Written 2026-10-26 on `plus`, to paste in when 1.1 is submitted. The text above stays live until then.*

**Promotional text (170):** Now on iPad. Momentum Plus keeps your iPhone and iPad in sync, with more on the way. Momentum itself stays free: no ads, no subscriptions. [154]

**Description, changed sections** (the rest stays as above):

> SYNC WITH MOMENTUM PLUS
> One purchase, yours for good and shared with your family: your habits on your iPhone and iPad, kept in your own iCloud. Coming to Plus: an Apple Watch app, new icons and themes, a year in review, Health insights, and Siri and Shortcuts. Buy once, get everything that comes.
>
> IPHONE AND IPAD
> On iPad, a sidebar with your categories, a habit's page beside the list, and every screen laid out for the bigger display, any way up.
>
> PRIVATE BY DESIGN
> No account, no ads, no tracking. Your habits stay on your devices, and in your own iCloud if you turn on sync. I never see them.
>
> FREE
> Every habit-building feature is free, and nothing that's free today will ever cost money. Momentum Plus is an optional one-time purchase.

**Price and in-app purchases:** Free, with in-app purchases: Momentum Plus ($1.99, non-consumable, Family Sharing), and tips of $0.99, $2.99 and $4.99 (consumable; outside the US, where the coffee link doesn't show). The listing shows "In-App Purchases" under the Get button.

**Screenshots:** the iPad set too (`build/store_frames/final_ipad/`; see "iPad" under Screenshots).
