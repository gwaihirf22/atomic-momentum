import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

import 'package:atomic_momentum/core/copy/greetings.dart';
import 'package:atomic_momentum/domain/entities/momentum.dart';

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

  group('taking turns', () {
    test('plenty for each part of the day, and none twice', () {
      for (final part in DayPart.values) {
        expect(Greetings.lines[part]!.length, greaterThanOrEqualTo(25), reason: part.name);
        expect(Greetings.lines[part]!.toSet().length, Greetings.lines[part]!.length, reason: part.name);
      }
      expect(Greetings.allDone.length, greaterThanOrEqualTo(12));
    });

    test("no line comes back until the rest of its part of the day have shown", () {
      final morning = DateTime(2026, 10, 16, 8);
      final pool = Greetings.lines[DayPart.morning]!;
      var seen = <String>{};
      String? last;
      final shown = <String>[];
      for (var i = 0; i < pool.length; i++) {
        last = Greetings.pick(morning, random: Random(i), avoid: last, seen: seen);
        shown.add(last);
        seen = Greetings.remember(seen, last);
      }
      expect(shown.toSet().length, pool.length, reason: 'every one, once');
      // Then they start over, never with the one just shown
      final next = Greetings.pick(morning, random: Random(99), avoid: last, seen: seen);
      expect(pool, contains(next));
      expect(next, isNot(last));
    });

    test('one part of the day running out leaves the others alone', () {
      final evening = Greetings.lines[DayPart.evening]!;
      var seen = {Greetings.lines[DayPart.morning]!.first, ...evening.skip(1)};
      seen = Greetings.remember(seen, evening.first);
      expect(seen, {Greetings.lines[DayPart.morning]!.first, evening.first});
    });
  });

  group("from the person's own day", () {
    const facts = GreetingFacts(
      due: 5,
      done: 2,
      streak: (name: 'Read', length: 12, unit: 'day'),
      atRisk: 'Gym',
      level: MomentumLevel.unstoppable,
    );

    test("what's left, the longest streak, a habit at risk, the level", () {
      final lines = Greetings.personal(facts, DayPart.morning);
      expect(lines, containsAll(['3 to go today', '2 down already', 'Day 12 of Read', 'Gym needs you', 'Unstoppable, truly']));
      expect(Greetings.personal(const GreetingFacts(due: 3, done: 2), DayPart.evening), contains('Just one to go'));
      expect(Greetings.personal(const GreetingFacts(streak: (name: 'Review', length: 4, unit: 'week')), DayPart.evening),
          contains('Review: week 4'));
    });

    test("names too long for the title, short streaks and empty days say nothing", () {
      final lines = Greetings.personal(
        const GreetingFacts(streak: (name: 'Practise the violin', length: 30, unit: 'day'), atRisk: 'Stretch every morning'),
        DayPart.morning,
      );
      expect(lines, isEmpty);
      expect(Greetings.personal(const GreetingFacts(streak: (name: 'Read', length: 2, unit: 'day')), DayPart.morning),
          isEmpty);
    });

    test('everything done: always celebratory', () {
      const done = GreetingFacts(due: 4, done: 4);
      expect(done.allDone, isTrue);
      for (var i = 0; i < 20; i++) {
        expect(Greetings.allDone, contains(Greetings.pick(DateTime(2026, 10, 16, 20), random: Random(i), facts: done)));
      }
    });

    test('now and then, not always', () {
      final own = Greetings.personal(facts, DayPart.afternoon).toSet();
      var mine = 0;
      for (var i = 0; i < 200; i++) {
        if (own.contains(Greetings.pick(DateTime(2026, 10, 16, 14), random: Random(i), facts: facts))) mine++;
      }
      expect(mine, inInclusiveRange(40, 110));
    });
  });
}
