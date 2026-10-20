import 'package:flutter/foundation.dart';

import 'tour.dart';

/// What a tour step lets through to the app, for widgets that do several
/// things in one spotlight (a habit card: open, +, −, hold, swipes). Only the
/// step's own gesture works, so nothing else can take the tour somewhere it
/// isn't expecting. With no tour, or on a step that lets no touches through
/// at all (the spotlight blocks those), everything is allowed.
abstract final class TourGate {
  /// The wait of the try-it step showing; null when nothing is gated.
  static final step = ValueNotifier<TourWait?>(null);

  /// No try-it step is showing: everything works.
  static bool get isFree => step.value == null;

  /// [gesture] is free, or it's what the step showing waits for (Freeze's
  /// step lets the swipe that reveals it through too).
  static bool allows(TourWait gesture) {
    final wait = step.value;
    return wait == null || wait == gesture || (wait == TourWait.freeze && gesture == TourWait.swipeToFreeze);
  }
}
