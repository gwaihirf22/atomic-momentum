import 'package:flutter/foundation.dart';

import 'package:atomic_momentum/core/services/health_watch.dart';
import 'package:atomic_momentum/domain/entities/health_link.dart';

/// Health saying it changed, by hand: [change].
class FakeHealthWatch implements HealthWatch {
  /// Each list it was asked to watch, in order.
  final watched = <Set<HealthMetric>>[];
  VoidCallback? _onChange;

  @override
  Future<void> watch(Set<HealthMetric> metrics, VoidCallback onChange) async {
    watched.add(metrics);
    _onChange = metrics.isEmpty ? null : onChange;
  }

  /// Health changed (iOS's observer query firing).
  void change() => _onChange?.call();
}
