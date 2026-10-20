import '../entities/habit.dart';

/// The order habits show in everywhere (the Habits list, Calendar, widgets,
/// pickers): the person's own ([order], habit ids), grouped by their
/// category's place when [grouped]. Habits the order doesn't list yet come
/// after those it does, oldest first; a category that's gone (deleted, or
/// unknown) counts as Uncategorized, last.
abstract final class HabitArrangement {
  /// [categoryRanks]: each active category's place (its sort order).
  static List<Habit> arrange(
    List<Habit> habits, {
    required List<String> order,
    required Map<String, int> categoryRanks,
    required bool grouped,
  }) {
    final position = {for (var i = 0; i < order.length; i++) order[i]: i};
    const last = 1 << 30;
    int compare(Habit a, Habit b) {
      if (grouped) {
        final byCategory = (categoryRanks[a.categoryId] ?? last).compareTo(categoryRanks[b.categoryId] ?? last);
        if (byCategory != 0) return byCategory;
      }
      final pa = position[a.id], pb = position[b.id];
      if (pa != null && pb != null) return pa.compareTo(pb);
      if (pa != null) return -1;
      if (pb != null) return 1;
      final byAge = a.metadata.createdDate.compareTo(b.metadata.createdDate);
      return byAge != 0 ? byAge : a.id.compareTo(b.id);
    }

    return [...habits]..sort(compare);
  }

  /// [arranged] (as shown) with [id] moved to [index] of it: the order to
  /// keep. Every habit is listed, so nothing shown moves but [id].
  static List<String> move(List<Habit> arranged, String id, int index) {
    final ids = [for (final h in arranged) h.id]..remove(id);
    ids.insert(index.clamp(0, ids.length), id);
    return ids;
  }
}
