import 'dart:convert';

import '../../domain/sync/sync_records.dart';

/// Whether this device can sync now.
enum CloudAvailability {
  available,

  /// Not signed in to iCloud (or a Google account) on this device.
  noAccount,

  /// Signed in, but iCloud is turned off for the app, or restricted.
  restricted,

  /// This build can't sync (a free-team build without iCloud, or web).
  unavailable,
}

/// Why a sync didn't go through.
enum CloudProblem {
  /// No connection; it'll go when there is one.
  offline,

  /// The person's iCloud or Drive is full.
  full,

  /// The account on this device changed or signed out.
  accountChanged,

  /// Another device deleted the copy in the cloud.
  deleted,

  /// Anything else.
  other,
}

class CloudException implements Exception {
  final CloudProblem problem;
  final String message;

  const CloudException(this.problem, [this.message = '']);

  @override
  String toString() => 'CloudException($problem${message.isEmpty ? '' : ': $message'})';
}

/// Where buckets of records are kept: iCloud (CloudKit), Google Drive's app
/// folder, or a fake in tests. It only stores and hands back buckets; the
/// merge is all Dart.
abstract class CloudTransport {
  Future<CloudAvailability> availability();

  /// Saves [buckets] (name → contents), replacing what was there.
  Future<void> push(Map<String, String> buckets);

  /// Every bucket changed since the last pull (all of them the first time,
  /// or after [resetCursor]), this device's own included. Until they're
  /// [acknowledge]d they come again, so an app stopped before it saved
  /// them loses nothing.
  Future<Map<String, String>> pull();

  /// The buckets [pull] handed over that are now saved on this device.
  Future<void> acknowledge(Iterable<String> names);

  /// Sync is on here (or off): iCloud then listens for other devices'
  /// changes from launch, and in the background, before the app asks.
  Future<void> setActive(bool active);

  /// Starts the next [pull] from the beginning.
  Future<void> resetCursor();

  /// Deletes everything in the cloud, for every device.
  Future<void> deleteAll();

  /// Fires when the cloud says something changed (iCloud's pushes); Drive
  /// never does.
  Stream<void> get wakes;
}

/// Records grouped into buckets, each owned by one device: a habit's
/// settings, a habit's month of days, and everything else.
class SyncBuckets {
  const SyncBuckets._();

  /// The format of a bucket. A device that finds a newer one stops syncing
  /// and asks for the app to be updated, rather than misreading it.
  static const schema = 1;

  /// The bucket [key] goes in, for [device].
  static String nameFor(String device, String key) {
    final habit = SyncKeys.habitOf(key);
    if (habit == null) return '$device~meta';
    final kind = key.codeUnitAt(0);
    // d, r, m: days, by month (their key's third part is the day)
    if (kind == 0x64 || kind == 0x72 || kind == 0x6D) {
      final day = key.split('/')[2];
      return '$device~d~$habit~${day.length >= 7 ? day.substring(0, 7) : day}';
    }
    return '$device~h~$habit';
  }

  /// The device a bucket belongs to.
  static String deviceOf(String bucket) => bucket.split('~').first;

  /// [device]'s records split into buckets, only those named in [names]
  /// (all of them when null).
  static Map<String, String> encode(String device, Records records, {Set<String>? names}) {
    final grouped = <String, Map<String, Object?>>{};
    for (final entry in records.entries) {
      final name = nameFor(device, entry.key);
      if (names != null && !names.contains(name)) continue;
      (grouped[name] ??= {})[entry.key] = entry.value.toJson();
    }
    // A named bucket with nothing left in it is saved empty
    for (final name in names ?? const <String>{}) {
      grouped[name] ??= {};
    }
    return {
      for (final entry in grouped.entries)
        entry.key: jsonEncode({'schema': schema, 'device': device, 'records': entry.value}),
    };
  }

  /// A bucket's records, or null when it's in a newer format than this app
  /// knows.
  static Records? decode(String contents) {
    final json = jsonDecode(contents) as Map<String, dynamic>;
    if (((json['schema'] as num?) ?? 0) > schema) return null;
    final records = json['records'] as Map<String, dynamic>? ?? const {};
    return {for (final entry in records.entries) entry.key: Stamped.fromJson(entry.value)};
  }
}
