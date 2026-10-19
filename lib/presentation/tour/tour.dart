import '../../screens/ios_main_navigation.dart';
import 'spotlight.dart';
import 'tour_anchor.dart';
import 'tour_events.dart';

/// The tours, one per screen (docs/design/onboarding-tours.md).
enum TourId { habits, habitPage, calendar, insights, inspire, settings, editor }

/// Where a tour runs: on the example habits, or the person's own screen.
enum TourWorld { example, real }

/// What a step can wait for, besides Next: the thing it shows, done for
/// real ("Tap + to log one more glass, or tap Next").
enum TourWait {
  plus,
  hold,
  undo,
  twoMinute,
  swipeToFreeze,
  openHabit,
  heatmapDay,
  calendarDay,
  addHabit;

  /// Whether [event] is it, on the step's habit ([habitId], if it has one).
  bool matches(TourEvent event, String? habitId) {
    bool on(String id) => habitId == null || id == habitId;
    return switch (this) {
      plus => event is PlusTapped && on(event.habitId),
      hold => event is HoldFinished && on(event.habitId),
      undo => event is HoldUndone && on(event.habitId),
      twoMinute => event is TwoMinuteTapped && on(event.habitId),
      swipeToFreeze => event is CardSwiped && event.freeze && on(event.habitId),
      openHabit => event is HabitPageOpened && on(event.habitId),
      heatmapDay => event is HeatmapDaySelected,
      calendarDay => event is CalendarDaySelected,
      addHabit => event is AddHabitTapped,
    };
  }
}

/// What has to happen before a step shows.
sealed class TourMove {
  const TourMove();
}

/// Shows a tab.
final class ShowTab extends TourMove {
  final AppTab tab;
  const ShowTab(this.tab);
}

/// Opens an example habit's page (by name) in the tab showing.
final class OpenHabitPage extends TourMove {
  final String habit;
  const OpenHabitPage(this.habit);
}

/// Closes pages and sheets back to the tabs' first pages.
final class BackToTabs extends TourMove {
  const BackToTabs();
}

/// Leaves the example habits for the person's own (the first tour's last
/// step: "Your turn").
final class ToOwnHabits extends TourMove {
  const ToOwnHabits();
}

class TourStep {
  /// What it points at; null for a bubble in the middle.
  final TourAnchorId? anchor;

  /// The example habit it's about (by name), for anchors there are several
  /// of and for [wait].
  final String? habit;

  /// Overrides the tour's title above the words.
  final String? eyebrow;
  final String text;
  final BubbleSide side;

  /// Done for real, it moves on like Next.
  final TourWait? wait;
  final List<TourMove> before;

  /// The last step's Next reads like this.
  final String? nextLabel;

  const TourStep({
    this.anchor,
    this.habit,
    this.eyebrow,
    required this.text,
    this.side = BubbleSide.auto,
    this.wait,
    this.before = const [],
    this.nextLabel,
  });
}

class Tour {
  final TourId id;
  final String title;
  final TourWorld world;
  final AppTab tab;
  final List<TourStep> steps;

  const Tour({required this.id, required this.title, required this.world, required this.tab, required this.steps});
}
