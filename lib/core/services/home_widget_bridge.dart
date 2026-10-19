import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A tap on a home screen widget's +, waiting for the app to log it.
///
/// The widget can't change habits itself: it queues the tap in the App Group
/// and the app applies it the way a tap on the card would, so streaks,
/// momentum, Health and reminders all follow.
@immutable
class WidgetLog {
  /// Unique per tap, so a log is never applied twice.
  final String id;
  final String habitId;

  /// The local day the tap was made on (a tap before midnight still counts
  /// for that day if the app only gets it after).
  final DateTime day;

  const WidgetLog({required this.id, required this.habitId, required this.day});

  /// From the queue's JSON ({"id", "habit", "day": "2026-10-18"}); null when
  /// it can't be read.
  static WidgetLog? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final habitId = json['habit'];
    final day = DateTime.tryParse('${json['day']}');
    if (id is! String || habitId is! String || day == null) return null;
    return WidgetLog(id: id, habitId: habitId, day: DateTime(day.year, day.month, day.day));
  }

  @override
  bool operator ==(Object other) => other is WidgetLog && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'WidgetLog($id, $habitId, $day)';
}

/// The app's side of the home screen widgets (iOS WidgetKit): hands them a
/// snapshot to draw and takes the taps made on them. Tests use a fake.
abstract class HomeWidgetBridge {
  /// Whether this phone has the widgets (iOS 17 and later).
  bool get isSupported;

  /// Stores the snapshot (JSON) where the widgets read it, and asks them to
  /// redraw.
  Future<void> save(String snapshot);

  /// Takes every queued tap, oldest first, and clears the queue.
  Future<List<WidgetLog>> takeLogs();

  /// Tells a waiting widget tap that its log has been applied (and the
  /// snapshot rewritten), so the app can be suspended again.
  Future<void> applied();

  /// Called when a widget has queued a tap while the app is running.
  set onLogsWaiting(VoidCallback? callback);

  /// Where the widget that opened the app (tapped outside a button) leads,
  /// once: `habit/<id>`, `inspire`, `insights` or `habits`; null if a widget
  /// didn't open it.
  Future<String?> takeOpened();

  /// Called with where a widget leads when it's tapped while the app is
  /// running.
  set onOpen(ValueChanged<String>? callback);
}

class PlatformHomeWidgetBridge implements HomeWidgetBridge {
  static const _channel = MethodChannel('momentum/widgets');

  VoidCallback? _onLogsWaiting;
  ValueChanged<String>? _onOpen;

  PlatformHomeWidgetBridge() {
    if (isSupported) _channel.setMethodCallHandler(_handle);
  }

  @override
  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<Object?> _handle(MethodCall call) async {
    switch (call.method) {
      case 'logsWaiting':
        _onLogsWaiting?.call();
      case 'open':
        if (call.arguments is String) _onOpen?.call(call.arguments as String);
    }
    return null;
  }

  @override
  set onLogsWaiting(VoidCallback? callback) => _onLogsWaiting = callback;

  @override
  set onOpen(ValueChanged<String>? callback) => _onOpen = callback;

  @override
  Future<String?> takeOpened() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('takeOpened');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> save(String snapshot) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('save', snapshot);
    } on MissingPluginException {
      // An older build without the widget extension
    } on PlatformException catch (e) {
      debugPrint('Widget snapshot not saved: $e');
    }
  }

  @override
  Future<List<WidgetLog>> takeLogs() async {
    if (!isSupported) return const [];
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('takeLogs');
      return (raw ?? const []).map(WidgetLog.fromJson).whereType<WidgetLog>().toList();
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e) {
      debugPrint('Widget taps not read: $e');
      return const [];
    }
  }

  @override
  Future<void> applied() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('applied');
    } on MissingPluginException {
      // Nothing waiting
    } on PlatformException {
      // Nothing waiting
    }
  }
}
