import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/copy/greetings.dart';

void main() {
  test('parts of the day', () {
    DayPart at(int hour) => Greetings.partOf(DateTime(2026, 10, 16, hour));
    expect(at(5), DayPart.morning);
    expect(at(11), DayPart.morning);
    expect(at(12), DayPart.afternoon);
    expect(at(17), DayPart.evening);
    expect(at(22), DayPart.night);
    expect(at(2), DayPart.night);
  });

  test('a greeting suits the time of day', () {
    for (var i = 0; i < 20; i++) {
      expect(Greetings.lines[DayPart.morning], contains(Greetings.pick(DateTime(2026, 10, 16, 7, 5))));
      expect(Greetings.lines[DayPart.evening], contains(Greetings.pick(DateTime(2026, 10, 16, 19))));
    }
  });

  test('never repeats the line just shown, and varies', () {
    final evening = DateTime(2026, 10, 16, 19);
    var last = Greetings.pick(evening);
    final seen = {last};
    for (var i = 0; i < 50; i++) {
      final next = Greetings.pick(evening, avoid: last);
      expect(next, isNot(last));
      seen.add(next);
      last = next;
    }
    expect(seen.length, greaterThan(3));
  });

  test('every greeting is short enough for the large title', () {
    for (final line in Greetings.lines.values.expand((l) => l)) {
      expect(line.length, lessThanOrEqualTo(22), reason: line);
    }
  });
}
