import '../../domain/services/achievements.dart';

/// What to do about achievements when the app looks: which to file on the
/// shelf quietly, which (if any) to celebrate, or to wait.
class CelebrationDecision {
  /// Ids to remember as seen (the celebrated one too).
  final List<String> markSeen;

  /// The one to show the sheet for, or null.
  final Achievement? celebrate;

  /// Something is ready to celebrate but a page or sheet is open: nothing
  /// is marked, so it's still there next time.
  final bool wait;

  const CelebrationDecision({this.markSeen = const [], this.celebrate, this.wait = false});

  static const nothing = CelebrationDecision();
}

/// Celebrates an achievement just earned (today or yesterday), once. Ones
/// found in older history, or there before the first check, are filed on
/// the shelf quietly. Pure, so the year simulation runs the same rules the
/// app does.
class AchievementCelebrations {
  const AchievementCelebrations._();

  /// [earned] is everything earned by [now]; [started] is false before the
  /// first check ever; [busy] means Add, Edit or a sheet is open.
  static CelebrationDecision decide({
    required List<Achievement> earned,
    required bool started,
    required Set<String> seen,
    required DateTime now,
    required bool busy,
  }) {
    if (!started) return CelebrationDecision(markSeen: [for (final a in earned) a.id]);
    final fresh = earned.where((a) => !seen.contains(a.id)).toList();
    if (fresh.isEmpty) return CelebrationDecision.nothing;

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final recent = fresh.where((a) => !a.earnedOn.isBefore(yesterday)).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    if (recent.isNotEmpty && busy) return const CelebrationDecision(wait: true);
    return CelebrationDecision(markSeen: [for (final a in fresh) a.id], celebrate: recent.firstOrNull);
  }
}
