import '../../core/demo/demo_persona.dart';
import '../../screens/ios_main_navigation.dart';
import 'spotlight.dart';
import 'tour.dart';
import 'tour_anchor.dart';

/// The tours' words and steps (docs/design/onboarding-tours.md). Short,
/// warm, second person, like the explainers. Every step can be done in the
/// spotlight or moved on with Next.
abstract final class Tours {
  /// The first launch's tour, on the example habits, ending in the person's
  /// own app at Add habit.
  static const habits = Tour(
    id: TourId.habits,
    title: 'Habits',
    summary: 'Logging, momentum, hard days and freezes',
    world: TourWorld.example,
    tab: AppTab.habits,
    steps: [
      TourStep(
        eyebrow: 'Welcome',
        text: 'Here are some example habits, after half a year of use. A quick look around, '
            'then your own.',
      ),
      TourStep(
        anchor: TourAnchorId.overallMomentum,
        text: "This is your momentum: how steadily you've been showing up. "
            'Steady practice reaches 80 in about 66 days.',
        side: BubbleSide.below,
      ),
      TourStep(
        anchor: TourAnchorId.habitPlus,
        habit: DemoPersona.water,
        text: 'Tap + to log one more glass, or tap Next.',
        wait: TourWait.plus,
      ),
      TourStep(
        anchor: TourAnchorId.habitRing,
        habit: DemoPersona.read,
        text: 'Hold a ring to finish the whole day in one go (Undo puts it back). Try it, or tap Next.',
        wait: TourWait.hold,
      ),
      TourStep(
        anchor: TourAnchorId.habitTwoMinute,
        habit: DemoPersona.meditate,
        text: "Missed yesterday? Don't miss twice. On a hard day, tap 2 min: "
            'the tiny version still keeps your streak.',
        wait: TourWait.twoMinute,
      ),
      TourStep(
        anchor: TourAnchorId.habitCard,
        habit: DemoPersona.gym,
        text: "Can't make it today? Swipe right to freeze the day: streak and momentum hold. "
            'Try it, or tap Next.',
        wait: TourWait.swipeToFreeze,
      ),
      TourStep(
        anchor: TourAnchorId.tabBar,
        text: 'Calendar, Insights (your statistics), Inspire and Settings each have a short tour '
            'the first time you open them.',
        before: [CloseSwipes()],
        side: BubbleSide.above,
      ),
      TourStep(
        anchor: TourAnchorId.addHabit,
        eyebrow: 'Your turn',
        text: 'These are your own habits now. Tap here to add your first one.',
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
        text: "Every day of the month, with how it went. Tap a day to see it, or tap Next.",
        wait: TourWait.calendarDay,
      ),
      TourStep(
        anchor: TourAnchorId.calendarDayHabit,
        habit: DemoPersona.water,
        text: 'Forgot to log something? Fix any past day here, with + and −.',
      ),
      TourStep(
        text: 'A habit added later shows grayed on the days before. "Start from this day" moves '
            'when it began.',
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
        text: 'Your momentum, month by month. The line marks 80: habit formed.',
      ),
      TourStep(
        anchor: TourAnchorId.insightsHeatmap,
        text: 'Every day at a glance: the deeper the colour, the more you did. Tap a day, or tap Next.',
        wait: TourWait.heatmapDay,
      ),
      TourStep(
        anchor: TourAnchorId.insightsAchievements,
        text: "What you've earned, and what's next. Milestones can earn freezes too.",
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
        text: 'Tap the number to type an amount, or hold the ring to finish the day.',
        before: [OpenHabitPage(DemoPersona.read)],
      ),
      TourStep(
        anchor: TourAnchorId.detailMomentum,
        text: "This habit's own momentum. Tap it to see how momentum works.",
      ),
      TourStep(
        anchor: TourAnchorId.detailHeatmap,
        text: 'Its last six months. Expand it for the whole history.',
      ),
      TourStep(
        anchor: TourAnchorId.detailEdit,
        text: 'Name, schedule, reminders and the tiny version: all in Edit.',
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
        text: 'A quote for today, new every morning. Save it, or add it to a habit.',
      ),
      TourStep(
        anchor: TourAnchorId.inspireSearch,
        text: 'Search every quote by word, author or theme, and keep your own.',
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
        text: 'Every tour lives here, to take again any time.',
      ),
      TourStep(
        anchor: TourAnchorId.settingsNotifications,
        text: 'Reminders: the time new habits remind you, the sound, and quiet hours.',
      ),
      TourStep(
        anchor: TourAnchorId.settingsFreezes,
        text: "Freezes you've earned, and vacation mode for longer breaks.",
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
        text: 'Your habit, as one sentence. Tap any underlined part to change it.',
      ),
      TourStep(
        anchor: TourAnchorId.storyHardDay,
        text: 'Plan a tiny version for hard days: it still keeps your streak.',
      ),
      TourStep(
        anchor: TourAnchorId.editorStyleSwitch,
        text: 'Prefer a form? Switch to Builder any time.',
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
