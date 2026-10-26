import 'dart:async';

import 'package:atomic_momentum/core/sync/cloud_transport.dart';

/// A cloud shared by simulated devices: each bucket with the version it was
/// last saved at. Each device reaches it through its own [FakeCloudLink].
class FakeCloud {
  final Map<String, ({String contents, int version})> buckets = {};
  int _version = 0;

  /// Bumped when the copy in the cloud is deleted.
  int deletions = 0;

  final _links = <FakeCloudLink>[];

  FakeCloudLink link({CloudAvailability availability = CloudAvailability.available}) {
    final link = FakeCloudLink._(this, availability);
    _links.add(link);
    return link;
  }

  void _save(Map<String, String> changed) {
    for (final entry in changed.entries) {
      buckets[entry.key] = (contents: entry.value, version: ++_version);
    }
    for (final link in _links) {
      link._wakes.add(null);
    }
  }
}

/// One device's way to [FakeCloud]; it can go offline.
class FakeCloudLink implements CloudTransport {
  final FakeCloud cloud;
  CloudAvailability availabilityNow;

  FakeCloudLink._(this.cloud, this.availabilityNow);

  /// No connection: pushes and pulls fail as offline.
  bool offline = false;

  int _cursor = 0;
  int _deletionsSeen = 0;
  final _wakes = StreamController<void>.broadcast();

  /// Every push made, for tests that count them.
  final pushes = <Map<String, String>>[];

  void _check() {
    if (offline) throw const CloudException(CloudProblem.offline);
    if (cloud.deletions != _deletionsSeen) {
      _deletionsSeen = cloud.deletions;
      throw const CloudException(CloudProblem.deleted);
    }
  }

  @override
  Future<CloudAvailability> availability() async => availabilityNow;

  @override
  Future<void> push(Map<String, String> buckets) async {
    _check();
    pushes.add(buckets);
    cloud._save(buckets);
  }

  @override
  Future<Map<String, String>> pull() async {
    _check();
    final changed = {
      for (final entry in cloud.buckets.entries)
        if (entry.value.version > _cursor) entry.key: entry.value.contents,
    };
    _cursor = cloud._version;
    return changed;
  }

  @override
  Future<void> resetCursor() async {
    _cursor = 0;
    _deletionsSeen = cloud.deletions;
  }

  @override
  Future<void> deleteAll() async {
    _check();
    cloud.buckets.clear();
    cloud.deletions++;
    _deletionsSeen = cloud.deletions;
  }

  @override
  Stream<void> get wakes => _wakes.stream;
}
