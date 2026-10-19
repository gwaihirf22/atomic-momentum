import '../../core/demo/demo_persona.dart';
import '../../screens/ios_main_navigation.dart';
import '../tour/tour_anchor.dart';
import 'phone_frame.dart';

/// One card of a guide: a live picture of the app, and a sentence or two.
class GuideCard {
  final HowToScene scene;
  final String text;
  const GuideCard(this.scene, this.text);
}

class Guide {
  final String id;
  final String title;
  final String summary;
  final List<GuideCard> cards;
  const Guide({required this.id, required this.title, required this.summary, required this.cards});
}

/// Settings → Help → How to: the app explained in pictures of itself (on the
/// example habits, in the reader's theme), a sentence or two each.
abstract final class Guides {
  static const all = [
    Guide(
      id: 'add',
      title: 'Add a habit',
      summary: 'Where new habits start',
      cards: [
        GuideCard(
          HowToScene(tab: AppTab.habits, highlight: TourAnchorId.addHabit, height: 260, alt: 'The Add habit button'),
          'Tap Add habit at the bottom of Habits. Say it as one sentence ("I will drink water, 8 glasses, every '
          'day"), or build it step by step.',
        ),
        GuideCard(
          HowToScene(
            tab: AppTab.habits,
            highlight: TourAnchorId.habitCard,
            habit: DemoPersona.water,
            height: 300,
            alt: "A habit's card",
          ),
          "Each habit gets a card: its ring, today's progress, its streak and momentum, and the last seven days.",
        ),
      ],
    ),
    Guide(
      id: 'log',
      title: 'Log your day',
      summary: '+ and −, holding a ring, typing an amount',
      cards: [
        GuideCard(
          HowToScene(
            tab: AppTab.habits,
            highlight: TourAnchorId.habitPlus,
            habit: DemoPersona.water,
            height: 300,
            alt: "A habit's + and − buttons",
          ),
          '+ and − log one more or one less. Big targets step in bigger amounts, like 1,000 steps at a time.',
        ),
        GuideCard(
          HowToScene(
            tab: AppTab.habits,
            highlight: TourAnchorId.habitRing,
            habit: DemoPersona.read,
            height: 300,
            alt: "A habit's ring",
          ),
          'Hold a ring to finish the whole day in one go, or hold again to clear it. Undo shows for a few seconds.',
        ),
        GuideCard(
          HowToScene(
            tab: AppTab.habits,
            habitPage: DemoPersona.read,
            highlight: TourAnchorId.detailRing,
            height: 380,
            alt: "A habit's page, with its ring",
          ),
          "On a habit's page, tap the number to type any amount, even past the target.",
        ),
      ],
    ),
    Guide(
      id: 'twoMinute',
      title: 'Hard days',
      summary: 'The two-minute version keeps the day',
      cards: [
        GuideCard(
          HowToScene(
            tab: AppTab.habits,
            highlight: TourAnchorId.habitTwoMinute,
            habit: DemoPersona.meditate,
            height: 300,
            alt: 'The 2 min button on a card',
          ),
          'Give a habit a tiny version ("take three slow breaths"). On a hard day tap 2 min: the day still counts, '
          'and momentum never drops for it.',
        ),
      ],
    ),
    Guide(
      id: 'streaks',
      title: 'Never miss twice',
      summary: 'How streaks bend instead of break',
      cards: [
        GuideCard(
          HowToScene(
            tab: AppTab.habits,
            highlight: TourAnchorId.habitCard,
            habit: DemoPersona.meditate,
            height: 300,
            alt: "A card saying Don't miss twice",
          ),
          "Miss a day and the card says Don't miss twice: one miss keeps the streak, two in a row end it. "
          'Show up the next day and momentum wins back half of what the miss cost.',
        ),
      ],
    ),
    Guide(
      id: 'momentum',
      title: 'Momentum',
      summary: 'What the 0 to 100 score means',
      cards: [
        GuideCard(
          HowToScene(
            tab: AppTab.habits,
            highlight: TourAnchorId.overallMomentum,
            height: 300,
            alt: 'The momentum ring',
          ),
          'Momentum shows how steadily you show up, from 0 to 100. Steady practice reaches 80, a habit formed, '
          'in about 66 days. Tap the ring to see the levels.',
        ),
        GuideCard(
          HowToScene(
            tab: AppTab.habits,
            habitPage: DemoPersona.read,
            highlight: TourAnchorId.detailMomentum,
            height: 340,
            alt: "A habit's momentum tile",
          ),
          'Each habit has its own, with the last 30 days as a line.',
        ),
      ],
    ),
    Guide(
      id: 'freezes',
      title: 'Freezes and vacation',
      summary: 'Days you can\'t make, and longer breaks',
      cards: [
        GuideCard(
          HowToScene(
            tab: AppTab.habits,
            highlight: TourAnchorId.habitCard,
            habit: DemoPersona.gym,
            height: 300,
            alt: "A habit's card",
          ),
          "Swipe a card right to freeze today: the day is neither kept nor missed, so the streak and momentum hold. "
          'Freeze ahead from its page, up to 30 days.',
        ),
        GuideCard(
          HowToScene(
            tab: AppTab.settings,
            highlight: TourAnchorId.settingsFreezes,
            height: 320,
            alt: 'Freezes and vacation mode in Settings',
          ),
          'Freezes are earned with milestones, five at most. Away for longer? Vacation mode pauses every habit.',
        ),
      ],
    ),
    Guide(
      id: 'break',
      title: 'Breaking a habit',
      summary: 'Quitting, or keeping to a limit',
      cards: [
        GuideCard(
          HowToScene(
            tab: AppTab.habits,
            highlight: TourAnchorId.habitCard,
            habit: DemoPersona.social,
            height: 300,
            alt: 'A habit being broken',
          ),
          'Choose Break when adding a habit: quit completely, or set a limit. + logs a slip, and a day stays '
          'clean while you keep under it.',
        ),
      ],
    ),
    Guide(
      id: 'calendar',
      title: 'Calendar',
      summary: 'Any day, and fixing one you forgot',
      cards: [
        GuideCard(
          HowToScene(tab: AppTab.calendar, highlight: TourAnchorId.calendarGrid, height: 460, alt: 'The calendar'),
          'Every day of the month with how it went. Tap a day to see it.',
        ),
        GuideCard(
          HowToScene(
            tab: AppTab.calendar,
            highlight: TourAnchorId.calendarDayHabit,
            habit: DemoPersona.water,
            height: 300,
            alt: "A habit on the day's list",
          ),
          'Forgot to log? Fix a past day with + and −.',
        ),
      ],
    ),
    Guide(
      id: 'insights',
      title: 'Insights',
      summary: 'Your statistics',
      cards: [
        GuideCard(
          HowToScene(tab: AppTab.insights, highlight: TourAnchorId.insightsMomentum, height: 420, alt: 'Momentum by month'),
          'Momentum month by month; the line marks 80.',
        ),
        GuideCard(
          HowToScene(tab: AppTab.insights, highlight: TourAnchorId.insightsHeatmap, height: 420, alt: 'Every day at a glance'),
          'Every day at a glance: the deeper the colour, the more you did. Tap a day, or expand it for your whole '
          'history.',
        ),
      ],
    ),
    Guide(
      id: 'inspire',
      title: 'Inspire',
      summary: 'A quote a day, and quotes for your habits',
      cards: [
        GuideCard(
          HowToScene(tab: AppTab.inspire, highlight: TourAnchorId.inspireQuote, height: 520, alt: "Today's quote"),
          'A quote for today, new every morning. Save it, add it to a habit, or ask for another.',
        ),
      ],
    ),
    Guide(
      id: 'reminders',
      title: 'Reminders',
      summary: 'When they come, and quiet hours',
      cards: [
        GuideCard(
          HowToScene(
            tab: AppTab.settings,
            highlight: TourAnchorId.settingsNotifications,
            height: 340,
            alt: 'Notifications in Settings',
          ),
          "Reminders follow each habit's schedule and stop once it's done. Set the default time, the sound and "
          "quiet hours here, and each habit's own in Edit.",
        ),
      ],
    ),
  ];
}
