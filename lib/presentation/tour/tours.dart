import '../../core/demo/demo_persona.dart';
import '../../screens/ios_main_navigation.dart';
import 'spotlight.dart';
import 'tour.dart';
import 'tour_anchor.dart';

/// The tours' words and steps (docs/design/onboarding-tours.md), spoken by
/// the app itself: first person, warm, with a quip now and then (like the
/// fun achievements). Only a try-it step tells you to do something now, and
/// only its own gesture works; every other step describes, so nothing invites
/// a tap the tour can't follow.
abstract final class Tours {
  /// The first launch's tour, on the example habits, ending in the person's
  /// own app at Add habit. It opens with the app saying hello.
  static const habits = Tour(
    id: TourId.habits,
    title: 'Habits',
    summary: 'Logging, momentum, hard days and freezes',
    world: TourWorld.example,
    tab: AppTab.habits,
    steps: [
      TourStep(
        eyebrow: 'Welcome',
        headline: "Hi! I'm Momentum.",
        text: 'Thanks for downloading me! I help you build good habits and break bad ones, a day at a time. '
            "Miss a day? No drama, just don't miss two. I'll do the talking here, and I'm told I'm a bit "
            'cheeky.',
        nextLabel: 'Show me around',
      ),
      TourStep(
        eyebrow: 'Example habits',
        text: 'First, some example habits: half a year of a very committed imaginary person. Nothing here '
            'touches yours.',
      ),
      TourStep(
        anchor: TourAnchorId.overallMomentum,
        text: 'This is momentum: how steadily you show up, out of 100. Keep at it for about 66 days and '
            "you'll pass 80. That's a habit formed.",
        side: BubbleSide.below,
      ),
      TourStep(
        anchor: TourAnchorId.habitCard,
        habit: DemoPersona.water,
        text: 'Each habit gets a card: the ring fills as you log, the bolt is momentum, the flame its streak, '
            'the bars its last seven days.',
        align: 0.08,
      ),
      TourStep(
        anchor: TourAnchorId.habitPlus,
        habit: DemoPersona.water,
        text: 'Tap + to log another glass. Hydration never hurt anyone.',
        wait: TourWait.plus,
      ),
      TourStep(
        anchor: TourAnchorId.habitRing,
        habit: DemoPersona.read,
        text: "Hold Read's ring and I'll finish the whole day in one go.",
        wait: TourWait.hold,
      ),
      TourStep(
        anchor: TourAnchorId.habitTwoMinute,
        habit: DemoPersona.meditate,
        text: 'Rough day? Tap 2 min to do the tiny version. It still counts, and the streak lives on.',
        wait: TourWait.twoMinute,
      ),
      TourStep(
        anchor: TourAnchorId.habitCard,
        habit: DemoPersona.gym,
        text: "Can't make it at all? Swipe right on Gym, then tap Freeze: I'll hold the streak. You start "
            'with 3 freezes and earn one at milestones, up to 5.',
        wait: TourWait.freeze,
      ),
      TourStep(
        anchor: TourAnchorId.habitCard,
        habit: DemoPersona.read,
        text: "Swipe left on Read to edit or delete it. I won't take it personally.",
        before: [CloseSwipes()],
        wait: TourWait.swipeToEdit,
      ),
      TourStep(
        anchor: TourAnchorId.habitCard,
        habit: DemoPersona.read,
        text: "Edit changes its name, schedule and reminders. Delete removes it, but I'll ask first.",
        before: [OpenCardActions(DemoPersona.read)],
      ),
      TourStep(
        anchor: TourAnchorId.categoryRings,
        text: "Your categories. A tap shows just one's habits. Holding one, or a habit's name, opens Arrange "
            'to reorder everything.',
        before: [CloseSwipes()],
      ),
      TourStep(
        anchor: TourAnchorId.tabBar,
        text: "Calendar, Insights, Inspire and Settings each get a little tour the first time you visit. I'll "
            'be there.',
        before: [CloseSwipes()],
        side: BubbleSide.above,
      ),
      TourStep(
        anchor: TourAnchorId.addHabit,
        eyebrow: 'Your turn',
        text: "That's the tour! These are your own habits now. Tap Add habit to start one.",
        before: [CloseSwipes(), ToOwnHabits()],
        wait: TourWait.addHabit,
        nextLabel: 'Got it',
      ),
    ],
  );

  /// The first visit to Calendar.
  static const calendar = Tour(
    id: TourId.calendar,
    title: 'Calendar',
    summary: 'Any day of the month, and fixing a day you forgot',
    world: TourWorld.example,
    tab: AppTab.calendar,
    steps: [
      TourStep(
        anchor: TourAnchorId.calendarGrid,
        text: 'Every day of the month, and how it went. Tap a day to look back.',
        wait: TourWait.calendarDay,
      ),
      TourStep(
        anchor: TourAnchorId.calendarDayHabit,
        habit: DemoPersona.water,
        text: "Forgot to log something? Any past day can be fixed here with + and −. I won't tell.",
      ),
      TourStep(
        text: "A habit added later is grayed before its first day. 'Start from this day' moves its start.",
      ),
    ],
  );

  /// The first visit to Insights.
  static const insights = Tour(
    id: TourId.insights,
    title: 'Insights',
    summary: 'Momentum by month, every day at a glance, achievements',
    world: TourWorld.example,
    tab: AppTab.insights,
    steps: [
      TourStep(
        anchor: TourAnchorId.insightsMomentum,
        text: 'Your momentum, month by month. The line is 80: habit formed.',
      ),
      TourStep(
        anchor: TourAnchorId.insightsHeatmap,
        text: 'Every day at a glance: the deeper the colour, the more you did. Tap a day.',
        wait: TourWait.heatmapDay,
      ),
      TourStep(
        anchor: TourAnchorId.insightsAchievements,
        text: "Everything you've earned, and what's next. Some milestones even pay out in freezes.",
      ),
    ],
  );

  /// The first time a habit's page opens.
  static const habitPage = Tour(
    id: TourId.habitPage,
    title: 'A habit',
    summary: "One habit's day, its momentum and its history",
    world: TourWorld.example,
    tab: AppTab.habits,
    steps: [
      TourStep(
        anchor: TourAnchorId.detailRing,
        text: "A habit's own page. The number can be typed over, and holding the ring finishes the day.",
        before: [OpenHabitPage(DemoPersona.read)],
      ),
      TourStep(
        anchor: TourAnchorId.detailMomentum,
        text: 'Its own momentum. Tapping it, later, explains how I work it out.',
      ),
      TourStep(
        anchor: TourAnchorId.detailHeatmap,
        text: 'Its last six months. The expand button shows the whole history.',
      ),
      TourStep(
        anchor: TourAnchorId.detailEdit,
        text: 'Name, schedule, reminders and the tiny version all live in Edit.',
      ),
    ],
  );

  /// The first visit to Inspire, on the person's own screen.
  static const inspire = Tour(
    id: TourId.inspire,
    title: 'Inspire',
    summary: 'A quote a day, and quotes for your habits',
    world: TourWorld.real,
    tab: AppTab.inspire,
    steps: [
      TourStep(
        anchor: TourAnchorId.inspireQuote,
        text: 'A quote a day, fresh every morning. Save one, or give it to a habit.',
      ),
      TourStep(
        anchor: TourAnchorId.inspireSearch,
        text: 'Search every quote by word, author or theme, and add your own favourites.',
      ),
    ],
  );

  /// The first visit to Settings, on the person's own screen.
  static const settings = Tour(
    id: TourId.settings,
    title: 'Settings',
    summary: 'Tours, reminders, freezes and vacation',
    world: TourWorld.real,
    tab: AppTab.settings,
    steps: [
      TourStep(
        anchor: TourAnchorId.settingsHelp,
        text: "Every tour lives here, for when you'd like me to show you around again.",
      ),
      TourStep(
        anchor: TourAnchorId.settingsNotifications,
        text: "When I remind you, how I sound, and quiet hours when I'll keep it down.",
      ),
      TourStep(
        anchor: TourAnchorId.settingsFreezes,
        text: "Your freezes, and vacation mode for when you're truly away.",
      ),
    ],
  );

  /// The first new habit, in the Story editor, on the person's own screen.
  static const editor = Tour(
    id: TourId.editor,
    title: 'Your habit',
    summary: 'Writing a habit as one sentence',
    world: TourWorld.real,
    tab: AppTab.habits,
    steps: [
      TourStep(
        anchor: TourAnchorId.storySentence,
        text: "Your habit, written as one sentence. Once we're done, tap any underlined part to change it.",
      ),
      TourStep(
        anchor: TourAnchorId.storyHardDay,
        text: "Plan a tiny version for hard days. It keeps your streak, and I won't judge.",
      ),
      TourStep(
        anchor: TourAnchorId.editorStyleSwitch,
        text: 'Prefer a form? Builder does the same thing, step by step.',
      ),
    ],
  );

  /// The first visit to Arrange, on the person's own page.
  static const arrange = Tour(
    id: TourId.arrange,
    title: 'Arrange',
    summary: 'The order of categories and habits',
    world: TourWorld.real,
    tab: null,
    steps: [
      TourStep(
        anchor: TourAnchorId.arrangeSwitch,
        text: 'Grouped by category, habits sit with their category, in its order. Off, any order goes.',
        before: [OpenArrange()],
      ),
      TourStep(
        anchor: TourAnchorId.arrangeCategory,
        text: 'A category drags by its handle, and its habits fold up and come along. A tap renames or '
            'recolours it.',
      ),
      TourStep(
        anchor: TourAnchorId.arrangeAddCategory,
        text: 'The + adds a category of your own: a name, a colour and an icon.',
      ),
      TourStep(
        anchor: TourAnchorId.arrangeHabit,
        text: 'Habits drag by their handles too. Grouped, they stay in their category; edit one to move it.',
      ),
      TourStep(
        text: "Habits, Calendar and your widgets follow this order. Hold a category or a habit's name, on "
            'Habits or Calendar, to come back.',
      ),
    ],
  );

  static const all = {
    TourId.habits: habits,
    TourId.habitPage: habitPage,
    TourId.calendar: calendar,
    TourId.insights: insights,
    TourId.inspire: inspire,
    TourId.settings: settings,
    TourId.editor: editor,
    TourId.arrange: arrange,
  };

  /// The tour a tab's first visit brings.
  static TourId? forTab(AppTab tab) => switch (tab) {
        AppTab.calendar => TourId.calendar,
        AppTab.insights => TourId.insights,
        AppTab.inspire => TourId.inspire,
        AppTab.settings => TourId.settings,
        AppTab.habits => null,
      };
}
