import 'dart:math' as math;

/// The freeze bank worked out from what syncs, rather than counted: every
/// device replays the same events in the same order and gets the same
/// balance. A freeze given back on two devices comes back once (it's the
/// frozen day that's gone), and a milestone earned while the bank was full
/// adds nothing, whichever device saw it first.
class FreezeReplay {
  const FreezeReplay._();

  /// The balance after [credits] (milestones, by the day each was credited)
  /// and [spends] (the days frozen now, by the day each was frozen), from
  /// [start] and never past [cap], plus [adjust] (what the bank held before
  /// sync that the events don't explain).
  static int balance({
    required Map<String, DateTime> credits,
    required Iterable<DateTime> spends,
    int adjust = 0,
    int start = 3,
    int cap = 5,
  }) {
    final events = <(DateTime, int, String)>[
      for (final spend in spends) (spend, 0, ''),
      for (final credit in credits.entries) (credit.value, 1, credit.key),
    ]..sort((a, b) {
        final byDay = a.$1.compareTo(b.$1);
        if (byDay != 0) return byDay;
        // A spend and a credit on the same day: the spend first, so the
        // credit isn't lost to a bank that was about to have room
        final byKind = a.$2.compareTo(b.$2);
        return byKind != 0 ? byKind : a.$3.compareTo(b.$3);
      });
    var balance = start;
    for (final event in events) {
      balance = event.$2 == 0 ? math.max(0, balance - 1) : math.min(cap, balance + 1);
    }
    return (balance + adjust).clamp(0, cap);
  }
}
