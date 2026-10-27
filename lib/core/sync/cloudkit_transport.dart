import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cloud_transport.dart';

/// iCloud, through `CloudSync.swift` (channel `momentum/sync`): CloudKit's
/// `CKSyncEngine` keeps buckets in the person's private database and wakes
/// the app when another device changes something.
class CloudKitTransport implements CloudTransport {
  static const _channel = MethodChannel('momentum/sync');

  CloudKitTransport() {
    if (isSupported) _channel.setMethodCallHandler(_handle);
  }

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  final _wakes = StreamController<void>.broadcast();

  Future<dynamic> _handle(MethodCall call) async {
    if (call.method == 'changed') _wakes.add(null);
  }

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    if (!isSupported) throw const CloudException(CloudProblem.other, 'iCloud is only on iPhone and iPad');
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      throw const CloudException(CloudProblem.other, 'This build has no iCloud');
    } on PlatformException catch (e) {
      throw CloudException(
        switch (e.code) {
          'offline' => CloudProblem.offline,
          'full' => CloudProblem.full,
          'accountChanged' => CloudProblem.accountChanged,
          'deleted' => CloudProblem.deleted,
          _ => CloudProblem.other,
        },
        e.message ?? '',
      );
    }
  }

  @override
  Future<CloudAvailability> availability() async {
    if (!isSupported) return CloudAvailability.unavailable;
    try {
      final status = await _call<String>('accountStatus');
      return switch (status) {
        'available' => CloudAvailability.available,
        'noAccount' => CloudAvailability.noAccount,
        'restricted' => CloudAvailability.restricted,
        _ => CloudAvailability.unavailable,
      };
    } on CloudException {
      return CloudAvailability.unavailable;
    }
  }

  @override
  Future<void> push(Map<String, String> buckets) => _call<void>('push', {'buckets': buckets});

  @override
  Future<Map<String, String>> pull() async {
    final result = await _call<Map<Object?, Object?>>('pull');
    return {
      for (final entry in (result ?? const {}).entries)
        if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
    };
  }

  @override
  Future<void> acknowledge(Iterable<String> names) async {
    if (names.isEmpty) return;
    await _call<void>('acknowledge', {'names': names.toList()});
  }

  @override
  Future<void> setActive(bool active) => _call<void>('setActive', {'active': active});

  @override
  Future<void> resetCursor() => _call<void>('resetCursor');

  @override
  Future<void> deleteAll() => _call<void>('deleteAll');

  @override
  Stream<void> get wakes => _wakes.stream;
}

/// Where there's no cloud to sync with (Android until Google Drive is
/// built, the web, tests that don't sync).
class NoCloudTransport implements CloudTransport {
  const NoCloudTransport();

  static const _none = CloudException(CloudProblem.other, 'No cloud on this device');

  @override
  Future<CloudAvailability> availability() async => CloudAvailability.unavailable;

  @override
  Future<void> push(Map<String, String> buckets) => Future.error(_none);

  @override
  Future<Map<String, String>> pull() => Future.error(_none);

  @override
  Future<void> acknowledge(Iterable<String> names) async {}

  @override
  Future<void> setActive(bool active) async {}

  @override
  Future<void> resetCursor() async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Stream<void> get wakes => const Stream.empty();
}
