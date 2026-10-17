import 'package:flutter/material.dart' show TimeOfDay;
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

  group('my day starts at', () {
    DayPart at(int hour, int minute, TimeOfDay start) =>
        Greetings.partOf(DateTime(2026, 10, 16, hour, minute), dayStart: start);

    test('a night shift waking at 3 PM: morning from 3 PM, night from 8 AM', () {
      const threePm = TimeOfDay(hour: 15, minute: 0);
      expect(at(15, 0, threePm), DayPart.morning);
      expect(at(21, 59, threePm), DayPart.morning);
      expect(at(22, 0, threePm), DayPart.afternoon);
      expect(at(2, 59, threePm), DayPart.afternoon);
      expect(at(3, 0, threePm), DayPart.evening);
      expect(at(8, 0, threePm), DayPart.night);
      expect(at(14, 59, threePm), DayPart.night);
    });

    test('minutes count, and the default is the usual 5 AM', () {
      const halfPastFive = TimeOfDay(hour: 5, minute: 30);
      expect(at(5, 29, halfPastFive), DayPart.night);
      expect(at(5, 30, halfPastFive), DayPart.morning);
      expect(Greetings.defaultDayStart, const TimeOfDay(hour: 5, minute: 0));
    });

    test('an earlier start works across midnight too', () {
      const twoAm = TimeOfDay(hour: 2, minute: 0);
      expect(at(2, 0, twoAm), DayPart.morning);
      expect(at(1, 59, twoAm), DayPart.night);
      expect(at(19, 0, twoAm), DayPart.night);
    });

    test('picks come from the shifted part of the day', () {
      const threePm = TimeOfDay(hour: 15, minute: 0);
      expect(Greetings.lines[DayPart.morning],
          contains(Greetings.pick(DateTime(2026, 10, 16, 16), dayStart: threePm)));
    });
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
