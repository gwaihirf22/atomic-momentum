import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/services/home_widget_bridge.dart';

/// The logs queued by widgets, Siri, the watch and a reminder's Log, as the
/// Swift side writes them (every value a string).
void main() {
  test("a widget's + is a step on its day", () {
    final log = WidgetLog.fromJson({'id': 'a', 'habit': 'h1', 'day': '2026-10-18'})!;
    expect(log.kind, WidgetLogKind.step);
    expect(log.day, DateTime(2026, 10, 18));
    expect(log.amount, isNull);
  });

  test("the watch's Crown carries the amount it set", () {
    final log = WidgetLog.fromJson({'id': 'b', 'habit': 'h1', 'day': '2026-10-18', 'kind': 'set', 'amount': '6'})!;
    expect(log.kind, WidgetLogKind.set);
    expect(log.amount, 6);
  });

  test("the watch's 2 min", () {
    final log = WidgetLog.fromJson({'id': 'c', 'habit': 'h1', 'day': '2026-10-18', 'kind': 'twoMinute'})!;
    expect(log.kind, WidgetLogKind.twoMinute);
  });

  test("what can't be read is left out: a kind from a newer watch, a set without an amount, a missing day", () {
    expect(WidgetLog.fromJson({'id': 'd', 'habit': 'h1', 'day': '2026-10-18', 'kind': 'teleport'}), isNull);
    expect(WidgetLog.fromJson({'id': 'e', 'habit': 'h1', 'day': '2026-10-18', 'kind': 'set'}), isNull);
    expect(WidgetLog.fromJson({'id': 'f', 'habit': 'h1', 'day': '2026-10-18', 'kind': 'set', 'amount': '-2'}), isNull);
    expect(WidgetLog.fromJson({'id': 'g', 'habit': 'h1'}), isNull);
    expect(WidgetLog.fromJson('nonsense'), isNull);
  });
}
