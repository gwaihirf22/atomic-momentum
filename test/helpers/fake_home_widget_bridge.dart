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
  ValueChanged<String>? _onOpenHabit;

  /// The habit whose widget launched the app, if one did.
  String? openedHabit;

  /// A widget tapped outside its + while the app is running.
  void open(String habitId) => _onOpenHabit?.call(habitId);

  Map<String, dynamic>? get last => saved.isEmpty ? null : jsonDecode(saved.last) as Map<String, dynamic>;

  /// A habit from the last snapshot, by name.
  Map<String, dynamic> habit(String name) =>
      (last!['habits'] as List).cast<Map<String, dynamic>>().firstWhere((h) => h['name'] == name);

  /// A widget's + tapped: queues it and tells the app, as the intent does.
  void tap(String habitId, DateTime day, {bool notify = true}) {
    queue.add(WidgetLog(id: 'tap${queue.length}_${day.day}', habitId: habitId, day: day));
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
  Future<String?> takeOpenedHabit() async {
    final id = openedHabit;
    openedHabit = null;
    return id;
  }

  @override
  set onOpenHabit(ValueChanged<String>? callback) => _onOpenHabit = callback;
}
