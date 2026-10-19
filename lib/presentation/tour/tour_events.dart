import 'dart:async';

/// Something the person did that a tour step can wait for ("Tap + to log one
/// more glass"). Screens report them with one line in the handler that does
/// the thing; with no tour running, nobody listens and it costs nothing.
sealed class TourEvent {
  const TourEvent();
}

/// + on a habit's card (or the habit page).
final class PlusTapped extends TourEvent {
  final String habitId;
  const PlusTapped(this.habitId);
}

/// A ring held to finish its period, or to clear it.
final class HoldFinished extends TourEvent {
  final String habitId;
  const HoldFinished(this.habitId);
}

/// Undo on the strip after a hold.
final class HoldUndone extends TourEvent {
  final String habitId;
  const HoldUndone(this.habitId);
}

/// "2 min" on a card.
final class TwoMinuteTapped extends TourEvent {
  final String habitId;
  const TwoMinuteTapped(this.habitId);
}

/// A card swiped open: [freeze] for the right swipe (Freeze), false for
/// the left (Edit and Delete).
final class CardSwiped extends TourEvent {
  final String habitId;
  final bool freeze;
  const CardSwiped(this.habitId, {required this.freeze});
}

/// A habit's page opened.
final class HabitPageOpened extends TourEvent {
  final String habitId;
  const HabitPageOpened(this.habitId);
}

/// A day picked on a heatmap.
final class HeatmapDaySelected extends TourEvent {
  const HeatmapDaySelected();
}

/// A day picked on Calendar.
final class CalendarDaySelected extends TourEvent {
  const CalendarDaySelected();
}

/// Add habit (the Habits tab's orb).
final class AddHabitTapped extends TourEvent {
  const AddHabitTapped();
}

/// Where screens report [TourEvent]s and tours hear them.
abstract final class TourEvents {
  static final _controller = StreamController<TourEvent>.broadcast(sync: true);

  static Stream<TourEvent> get stream => _controller.stream;

  static void emit(TourEvent event) {
    if (_controller.hasListener) _controller.add(event);
  }
}
