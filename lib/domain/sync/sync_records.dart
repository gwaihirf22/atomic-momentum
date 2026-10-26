import 'hlc.dart';

/// A synced value with when, and on which device, it was set. Values are
/// plain JSON (maps, lists, strings, numbers, booleans, null).
class Stamped {
  final Object? value;
  final Hlc stamp;

  const Stamped(this.value, this.stamp);

  List<Object?> toJson() => [stamp.encode(), value];

  static Stamped fromJson(Object? json) {
    final list = json as List<dynamic>;
    return Stamped(list[1], Hlc.decode(list[0] as String));
  }

  @override
  bool operator ==(Object other) => other is Stamped && other.stamp == stamp && jsonEquals(other.value, value);

  @override
  int get hashCode => stamp.hashCode;

  @override
  String toString() => 'Stamped($value @ ${stamp.encode()})';
}

/// One device's records: what it has set, by key. Each device writes only
/// its own, so the cloud never sees two devices write the same record.
typedef Records = Map<String, Stamped>;

/// How the records under a key combine across devices.
enum MergeRule {
  /// The latest stamp wins (a habit's name, a setting, a note).
  latest,

  /// Every device's numbers add up (a day's count).
  sum,

  /// Present if any device has it; the first one set gives the value
  /// (achievements celebrated, saved quotes).
  union,

  /// The smallest value wins (the first day something happened).
  earliest,
}

/// The keys records are filed under. The first letter says how they merge
/// ([ruleOf]); habit keys carry the habit's id second.
abstract final class SyncKeys {
  /// A habit's settings, in groups that change together (`h/<id>/<group>`).
  static String field(String habitId, String group) => 'h/$habitId/$group';

  /// A habit was deleted, for good (`x/<id>`).
  static String deleted(String habitId) => 'x/$habitId';

  /// This device's part of a day's count, in a history generation's units.
  static String count(String habitId, String day, String generation) => 'd/$habitId/$day/$generation';

  /// A day's whole count, for habits filled in from Health
  /// (`{"v": count, "g": generation}`).
  static String dayValue(String habitId, String day) => 'r/$habitId/$day';

  /// A day's two-minute, frozen or note mark.
  static String mark(String habitId, String day, String kind) => 'm/$habitId/$day/$kind';

  /// A history generation: units changed, history rescaled
  /// (`{"p": previous, "s": scale}`).
  static String generation(String habitId, String generation) => 'g/$habitId/$generation';

  /// A member of a set that only grows.
  static String element(String set, String item) => 'e/$set/$item';

  /// A value where the earliest wins.
  static String earliest(String name) => 'n/$name';

  /// Anything else that takes the latest: categories, quotes, order,
  /// settings (`o/…`).
  static String other(String name) => 'o/$name';

  static const twoMinuteMark = 'two';
  static const frozenMark = 'frozen';
  static const noteMark = 'note';

  /// The first history generation, before any change of units.
  static const firstGeneration = '0';

  static MergeRule ruleOf(String key) => switch (key.codeUnitAt(0)) {
        0x64 => MergeRule.sum, // d
        0x65 || 0x67 => MergeRule.union, // e, g
        0x6E => MergeRule.earliest, // n
        _ => MergeRule.latest,
      };

  /// The habit a key belongs to, or null for keys that aren't a habit's.
  static String? habitOf(String key) {
    if (key.length < 3 || key.codeUnitAt(1) != 0x2F) return null; // '/'
    final kind = key.codeUnitAt(0);
    const habitKinds = {0x68, 0x78, 0x64, 0x72, 0x6D, 0x67}; // h x d r m g
    if (!habitKinds.contains(kind)) return null;
    final end = key.indexOf('/', 2);
    return end < 0 ? key.substring(2) : key.substring(2, end);
  }

  /// A date as records write it: `yyyy-MM-dd`.
  static String day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime parseDay(String day) {
    final parts = day.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}

/// Whether two JSON values are the same (maps by key, lists in order).
bool jsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is num && b is num) return a == b;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || !jsonEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
