# Atomic Momentum: product strategy

*Decided October 16, 2026. Progress marks updated October 18, 2026.* Smaller follow-ups and loose ends are in [../future-improvements.md](../future-improvements.md).

The core habit tracker is built: habits, categories, flexible schedules, streaks, the Calendar and streak warnings. This document covers four things:
- what will make the app stand out;
- what people will pay for;
- which platform to build on;
- the order we build in.

## 1. Positioning: "Momentum, not perfection"

**The pitch:** the habit tracker built on *Atomic Habits*. It rewards momentum instead of punishing a missed day, and runs your routines instead of just ticking boxes.

**Why it's believable:** the name already makes this promise.

**What it competes with:**
- **Streaks:** the best-known Apple habit app, a one-time $5.99.
- **Habitify, Way of Life, Habitica, Loop.**

Most of them are checklists with a streak counter. People quit when a single missed day wipes out a long streak.

We stand out on three things, in priority order.

### Pillar A: the Atomic Habits method (the app's identity)

| Feature | What the user sees | Notes |
|---|---|---|
| **Momentum score** (done) | A 0–100 score for each habit, plus an overall one, shown as the main number on the Habits screen | Rises with each completed scheduled period and dips gently on a miss. Rest days don't count. Tuned so that steady practice reaches about 80 in about 66 days, the average time to form a habit (Lally et al., 2009). Calculated from the same per-day history that `StreakCalculator` uses. Named in five levels: Building 0–39, Rolling 40–69, Strong 70–79, Unstoppable 80–89 (from "habit formed"), Atomic 90+. |
| **Never miss twice** (done) | One missed period bends the streak and the card says "Don't miss twice". Two misses in a row end it. | This is the cure for losing a streak to one bad day. The streak warning notification becomes "Don't miss twice". |
| **Two-minute version** (done) | Each habit can have a tiny version, such as "put on running shoes", and optionally a minimum amount that counts by itself | Logging it with the card's "2 min" button keeps the day: the streak continues and grows, and momentum never drops for it (it holds, or lifts toward 50). Two-minute days are recorded separately, for statistics and rewards. Book: "make it easy". |
| **Habit stacking** | "After I [habit], I will [habit]." | Finishing one habit prompts the next, in the app or by notification. Leads into Routines. |
| **Identity** | Each category gets an "I am someone who…" statement | Each completion counts as a "vote" for that identity, a phrase from the book. |

### Pillar B: routines with timers

**A routine** is a stack of habits played in order. For example, a morning routine might be water, then 10 minutes of meditation, then stretching.

**A timed habit** has its target in minutes. The timer runs:
- in the app;
- on the iPhone lock screen and in the Dynamic Island, as a Live Activity;
- on Android, as an ongoing notification with a running clock.

Finishing a step logs it and moves on to the next one.

### Pillar C: insight and beauty

- **Year heatmap** (done): Insights shows the last 6 months, for each habit or all of them; its full-screen view holds the whole history, scrolls sideways and pinch-zooms. Each habit's page has its own.
- **Momentum trend chart** (done): 6 months on Insights with the 80 line, and a 30-day line on each habit's page.
- **Patterns:** your best days (done: "Your week" on Insights) and times (not yet).
- **Weekly review** (not yet): a Sunday summary with your wins, the times you didn't miss twice, and next week's focus. Designed to look good when shared as an image.
- **Statistics** include two-minute days, shown apart from full days (done).
- **Rewards** (not yet; Paul's idea, built with statistics):
  - a week straight earns a freeze day; a month straight earns a break day; the user spends them when life gets in the way;
  - can be turned off in Settings, with a gentle note: try to do your habits, but life gets in the way, and that's okay and how it's meant to work.
- **Achievements** (done): streak milestones, habit formed, comebacks, perfect weeks, two-minute days and more. Separate from rewards, shown on Insights and each habit's page, and celebrated when earned.
- **Sharing** (done): designed cards (an achievement, a streak, the heatmap, momentum, a quote) in four styles, sent as pictures.
- **Celebrations:** satisfying completion animations and haptics. "Make it satisfying" is the book's fourth law. (Haptics and the achievement celebration are done.)
- **A visual identity of our own** (done) rather than an imitation of iOS. It looks better, and it hides Flutter's weak spot (see section 3). It includes the Charged, Light and Sepia themes, a floating tab bar, Sora titles, the intro on launch, and a choice of app icon.

### Built beyond the original plan

- **Breaking a habit:** quit, or keep it under a limit. A day counts as kept while it's under the limit, and the app checks in daily instead of reminding.
- **Inspire:** a fifth tab with the quote of the day from a public-domain library, the person's own quotes, and quotes kept with a habit. Design: [../design/inspire.md](../design/inspire.md).
- **Apple Health and Health Connect:** habits fill in from steps, exercise, sleep and water, and water is logged back. Design: [../design/health.md](../design/health.md).
- **App icon choice:** Match system, Charged or Light (Settings → App icon).
- **An intro on launch:** "Building … Atomic Momentum".

### Deliberately later

These are expected from top apps but aren't the reason someone switches:
- interactive home and lock screen widgets;
- the Apple Watch;
- Siri and Shortcuts;
- logging automatically from Apple Health (brought forward and built in October 2026: habits fill in from Apple Health / Health Connect and log water and mindful minutes back).

## 2. Money

People who use habit apps strongly dislike subscriptions, so we sell a generous free app plus a one-time upgrade.

**Free:**
- all tracking and categories;
- the momentum score;
- never miss twice;
- the two-minute version;
- one routine;
- this month's insights.

A stingy free tier kills word of mouth.

**Atomic Momentum Pro** is a single purchase of about $9.99–14.99, priced the same on both stores. It includes:
- unlimited routines and timers, with Live Activities;
- insights across your full history: year heatmaps, trends, the weekly review archive and CSV export;
- themes and alternate app icons (both are free in the app today; decide before launch, see [../future-improvements.md](../future-improvements.md));
- **later:** backup and syncing between devices. Sync is the feature people most reliably pay for, but with Android in the picture it needs a server.

**The tip jar ("buy me a coffee")** is built from *in-app purchases*, such as Small, Medium and Large coffee, in Settings. Don't use a Buy Me a Coffee link:
- Apple's reviewers have rejected external tip links under guideline 3.1.1, even for US apps after the 2025 rule change.
- Google Play has similar billing rules.

For the code, use RevenueCat's `purchases_flutter`, which is the simplest for one developer handling both stores, or the official `in_app_purchase` package.

## 3. Platform: stay on Flutter

**The decision:** Flutter is the long-term platform. Swift is written only for the small parts Apple requires.

**Why:**
- **Android matters.** A SwiftUI app would mean writing the Android app a second time.
- **The lead features are ordinary app screens:** the method features, charts, heatmaps and animations. Flutter does these well and they look the same on both phones.
- **Nothing is wasted.** The existing logic and tests (371 at the time of this decision, over 1,300 by October 18) carry over unchanged.

**What needs Swift (and Android's native code) anyway:** these are small native add-ons inside the Flutter project, not a rewrite. They share data with the app through an App Group.

| Feature | iOS | Android | Flutter package |
|---|---|---|---|
| Routine timer on the lock screen | A Live Activity: a SwiftUI widget extension | An ongoing notification with a running clock | `live_activities` (or `flow_widget`); `flutter_local_notifications` |
| Home and lock screen widgets (v2) | A WidgetKit extension in SwiftUI. Tappable buttons (iOS 17 and later) need a small AppIntent that calls back into Dart. | An app widget | `home_widget` |
| Apple Watch (v2) | A watchOS app in SwiftUI | Wear OS (optional) | none (native) |

**Known Flutter cost:** Flutter draws its own controls, so it lags behind new Apple design changes such as iOS 26's Liquid Glass. Our answer is a distinctive look of our own rather than chasing iOS's.

**When to reconsider Swift:**
- we drop Android;
- the native Swift add-ons grow bigger than the Flutter app they support; or
- an Apple Watch app becomes central.

The `swift` branch and its worktree (see CLAUDE.md, "Branches and Worktrees") stay ready as the fallback.

## 4. Roadmap

| Phase | Contents, in order |
|---|---|
| **v1: App Store and Google Play** | 1. Momentum score and never miss twice (done). 2. Smart reminders (done): on by default, counting down to when a habit is due, with per-habit control. 3. Two-minute version (done). 4. Statistics: year heatmap, two-minute days and achievements (done, with Insights and sharing); weekly review and rewards (earned freeze and break days) still to come. 5. Onboarding tutorial that teaches the method. 6. Store readiness: privacy label and screenshots (name, icon and app id are done; notification permission is asked at first launch). |
| **v1.x** | 1. Habit stacking. 2. Routines with timers (Live Activity on iOS, ongoing notification on Android). 3. Pro upgrade and tip jar. |
| **v2** | Widgets (home screen, lock screen, StandBy), sync between devices (accounts, Pro), Apple Watch. Logging from Apple Health was brought forward and is done. |

Every feature ships with tests, as with everything so far.

## Sources

- [Apple Developer Forums: "Tips" external link rejected under 3.1.1](https://developer.apple.com/forums/thread/844046)
- [Apple Developer Forums: donation link removed after review](https://developer.apple.com/forums/thread/114186)
- [Apple's May 2025 guideline update for US apps](https://512pixels.net/2025/05/apple-updates-app-review-guidelines/)
- [home_widget: interactive widgets](https://docs.page/ABausG/home_widget/features/interactive-widgets)
- [live_activities_flutter](https://pub.dev/documentation/live_activities_flutter/latest/)
- [Apple: adding interactivity to widgets and Live Activities](https://developer.apple.com/tutorials/data/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities.md)
- [2026 habit tracker roundup (Streaks pricing)](https://timingapp.com/blog/habit-tracker-apps-iphone-mac/)
- Lally, P. et al. (2009), "How are habits formed", *European Journal of Social Psychology* 40(6).
