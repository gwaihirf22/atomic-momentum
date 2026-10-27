import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/health_link.dart';
import '../logging/log.dart';

/// Hears from Apple Health when what it holds changes: steps as they're
/// counted, or another device's arriving through iCloud. iOS only
/// (`HealthWatch` in HealthWatch.swift, HKObserverQuery); Health Connect
/// can't say, so elsewhere this does nothing and the app reads every few
/// minutes instead (HealthLive).
abstract class HealthWatch {
  /// Watches [metrics] (none: stops), calling [onChange] when any of them
  /// changes while the app is open. iOS keeps the list, so with the app
  /// closed a change wakes it in the background (BackgroundRun, "health").
  Future<void> watch(Set<HealthMetric> metrics, VoidCallback onChange);
}

class PlatformHealthWatch implements HealthWatch {
  static const channel = MethodChannel('momentum/health_watch');

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> watch(Set<HealthMetric> metrics, VoidCallback onChange) async {
    if (!isSupported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') onChange();
    });
    try {
      await channel.invokeMethod<void>('watch', [for (final metric in metrics) metric.name]);
    } catch (e) {
      // Older builds, or HealthKit not there (an iPad without it)
      logWarning('Health watch: $e');
    }
  }
}
