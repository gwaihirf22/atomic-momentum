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

  static const all = {TourId.habits: habits};
}
