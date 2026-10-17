import 'package:flutter/services.dart';

/// The app's haptic vocabulary, so the same moments always feel the same.
class Haptics {
  const Haptics._();

  /// Logging one more toward a habit.
  static Future<void> increment() => HapticFeedback.lightImpact();

  /// A habit reaching its target.
  static Future<void> completed() => HapticFeedback.mediumImpact();

  /// Logging a habit's two-minute version: the day is kept.
  static Future<void> twoMinute() => HapticFeedback.mediumImpact();

  /// Holding a habit's ring to finish or clear it: firmer than a tap, so a
  /// hold by accident is felt.
  static Future<void> held() => HapticFeedback.heavyImpact();

  /// Picking a filter or option.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// The right feedback for moving a habit from [from] to [to] out of [target].
  static Future<void> progressChanged({required int from, required int to, required int target}) {
    if (to > from && to >= target && from < target) return completed();
    if (to > from) return increment();
    return selection();
  }
}
