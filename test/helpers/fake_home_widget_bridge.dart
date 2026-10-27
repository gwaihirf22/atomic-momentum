import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:atomic_momentum/core/services/home_widget_bridge.dart';

/// The home screen widgets' side, in memory: keeps what the app saved and a
/// queue of taps a test can add to.
class FakeHomeWidgetBridge implements HomeWidgetBridge {
  @override
  bool isSupported;

  FakeHomeWidgetBridge({this.isSupported = true});

  /// Every snapshot saved, oldest first.
  final List<String> saved = [];

  /// Taps waiting for the app.
  final List<WidgetLog> queue = [];

  /// How many times the app said a tap was applied.
  int appliedCount = 0;

  VoidCallback? _onLogsWaiting;
  ValueChanged<String>? _onOpen;

  /// Where the widget that launched the app leads, if one did.
  String? opened;

  /// A widget tapped outside its buttons while the app is running.
  void open(String route) => _onOpen?.call(route);

  Map<String, dynamic>? get last => saved.isEmpty ? null : jsonDecode(saved.last) as Map<String, dynamic>;

  /// A habit from the last snapshot, by name.
  Map<String, dynamic> habit(String name) =>
      (last!['habits'] as List).cast<Map<String, dynamic>>().firstWhere((h) => h['name'] == name);

  /// A widget's + tapped (or, with [kind], the watch's Crown or "2 min"):
  /// queues it and tells the app, as the intent does.
  void tap(String habitId, DateTime day, {bool notify = true, WidgetLogKind kind = WidgetLogKind.step, int? amount}) {
    queue.add(WidgetLog(id: 'tap${queue.length}_${day.day}', habitId: habitId, day: day, kind: kind, amount: amount));
    if (notify) _onLogsWaiting?.call();
  }

  @override
  Future<void> save(String snapshot) async => saved.add(snapshot);

  @override
  Future<List<WidgetLog>> takeLogs() async {
    final taken = List.of(queue);
    queue.clear();
    return taken;
  }

  @override
  Future<void> applied() async => appliedCount++;

  @override
  set onLogsWaiting(VoidCallback? callback) => _onLogsWaiting = callback;

  @override
  Future<String?> takeOpened() async {
    final route = opened;
    opened = null;
    return route;
  }

  @override
  set onOpen(ValueChanged<String>? callback) => _onOpen = callback;
}
