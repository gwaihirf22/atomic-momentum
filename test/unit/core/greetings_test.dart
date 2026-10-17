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

  test('a greeting suits the time of day and stays put through that part of the day', () {
    final early = Greetings.forTime(DateTime(2026, 10, 16, 7, 5));
    expect(Greetings.lines[DayPart.morning], contains(early));
    expect(Greetings.forTime(DateTime(2026, 10, 16, 11, 59)), early);
    expect(Greetings.lines[DayPart.evening], contains(Greetings.forTime(DateTime(2026, 10, 16, 19))));
  });

  test('greetings vary from day to day', () {
    final picks = {for (var d = 1; d <= 30; d++) Greetings.forTime(DateTime(2026, 10, d, 9))};
    expect(picks.length, greaterThan(3));
  });

  test('every greeting is short enough for the large title', () {
    for (final line in Greetings.lines.values.expand((l) => l)) {
      expect(line.length, lessThanOrEqualTo(22), reason: line);
    }
  });
}
