import 'dart:math';
import 'package:flutter/material.dart' show TimeOfDay;
import '../../domain/entities/momentum.dart' show MomentumLevel;

/// Parts of the day the Habits header greets.
enum DayPart { morning, afternoon, evening, night }

/// The Habits screen's greeting: a line for the time of day, encouraging
/// and now and then a little cheeky, sometimes from the person's own day,
/// celebratory once everything due today is done. A new one is picked each
/// time the app is opened (see HomeScreen), taking turns: no line comes back
/// until the rest of its part of the day have shown (about a week of
/// opening the app).
class Greetings {
  const Greetings._();

  /// Source of the picks; tests seed it (test/flutter_test_config.dart) so
  /// layouts are the same on every run.
  static Random random = Random();

  /// When morning starts on a usual schedule; Settings → "My day starts
  /// at" moves every part of the day with it.
  static const defaultDayStart = TimeOfDay(hour: 5, minute: 0);

  /// The part of the day [time] falls in, for someone whose day starts at
  /// [dayStart]: morning for 7 hours, afternoon 5, evening 5, night 7. A
  /// night-shift worker who wakes at 3 PM gets morning greetings from 3 PM
  /// and night ones from 8 AM.
  static DayPart partOf(DateTime time, {TimeOfDay dayStart = defaultDayStart}) {
    final shift = (dayStart.hour - defaultDayStart.hour) * 60 + dayStart.minute - defaultDayStart.minute;
    // Minutes since midnight on a usual 5 AM schedule
    final minutes = (time.hour * 60 + time.minute - shift) % (24 * 60);
    final hour = minutes ~/ 60;
    if (hour >= 5 && hour < 12) return DayPart.morning;
    if (hour >= 12 && hour < 17) return DayPart.afternoon;
    if (hour >= 17 && hour < 22) return DayPart.evening;
    return DayPart.night;
  }

  static const Map<DayPart, List<String>> lines = {
    DayPart.morning: [
      'Good morning',
      'Coffee and momentum?',
      'Seize the day',
      'Rise and grind',
      'Fresh day, clean slate',
      'Morning, overachiever',
      "Let's get rolling",
      'The day is young',
      'Up and at it',
      'Rise and shine',
      'Today is yours',
      'First things first',
      'Small steps today',
      "Let's make it count",
      'Hello, early bird',
      'Ready when you are',
      'Today, we build',
      'Bright and early',
      'Morning, champion',
      'One habit at a time',
      'Start small, start now',
      'Morning momentum',
      "Let's do this",
      'Morning, go-getter',
      'Big day ahead?',
      'A good day to begin',
      'Wakey wakey',
      'New day, new wins',
    ],
    DayPart.afternoon: [
      'Good afternoon',
      'Keep it rolling',
      'Halfway there',
      'The post-lunch push',
      'Still going strong?',
      'Momentum check',
      'Nap later, habits now',
      'Afternoon, achiever',
      'Afternoon check-in',
      "How's it going?",
      'Midday momentum',
      'Still got it',
      'Back at it',
      'Second wind?',
      'Plenty of day left',
      'Small wins add up',
      'Steady does it',
      'Afternoon, hero',
      "You're doing great",
      'Onward',
      'Coffee number two?',
      'Stay the course',
      'Hello again',
      "Don't stop now",
      'Lunch, then habits',
      'Keep showing up',
      'The middle counts too',
      'Afternoon, legend',
    ],
    DayPart.evening: [
      'Good evening',
      'Finish strong',
      'Evening, legend',
      'One more for today?',
      'Close out the day',
      'The couch can wait',
      'Wind down, check in',
      'Strong finish ahead',
      'Evening check-in',
      'How did today go?',
      'Almost there',
      'Home stretch',
      'Golden hour',
      'Time to wrap up',
      'Evening, achiever',
      'Still time today',
      'Last call for habits',
      'Make tonight count',
      'Ease into the evening',
      "The day's last lap",
      'Good work today',
      'Ready to wind down?',
      'Evening, star',
      'Nearly done',
      'One last push',
      'Tidy up the day',
      'Dinner, then done',
      'Evening, overachiever',
    ],
    DayPart.night: [
      'Still up?',
      'Night owl mode',
      'Late-night momentum',
      'Sleep is a habit too',
      'Go to bed. Soon.',
      'Up past bedtime?',
      'Quiet hours, big wins',
      'Midnight oil, again?',
      'Sleep counts too',
      'Late check-in?',
      'The night is quiet',
      'Rest is progress',
      'Tomorrow thanks you',
      'Moonlight momentum',
      'Owls need sleep too',
      'Last one, then bed',
      'The stars are out',
      'Lights out soon?',
      'Night, night owl',
      'Dream big, sleep well',
      'Sleep on it',
      'Late, but not lazy',
      'Night mode: on',
      'Pillow is calling',
      'Burning the late oil?',
      'Quiet night, steady',
      'Tuck in the day',
      'Night shift, habits on',
    ],
  };

  /// When every habit due today is done: celebratory, whatever the hour.
  static const allDone = [
    'All done today!',
    'Clean sweep!',
    'Every habit, done',
    'Nailed it today',
    'Perfect day',
    'Done and dusted',
    "That's a wrap!",
    'You did it all',
    '100% today',
    "Today's in the bag",
    'Full house!',
    'Day: conquered',
    'Look at you go',
    'Everything. Done.',
    'Habits: all checked',
    'A perfect day',
  ];

  /// How often a greeting comes from the person's own day, when it can.
  static const personalShare = 0.35;

  /// Habit names longer than this aren't put in a greeting (it must fit
  /// two lines of the large title).
  static const maxName = 12;

  /// Greetings worked out from the person's own data: what's left today,
  /// their longest streak going, a habit one miss from losing its streak,
  /// their momentum level.
  static List<String> personal(GreetingFacts facts, DayPart part) {
    final lines = <String>[];
    final toGo = facts.toGo;
    if (facts.due > 0 && toGo == 1) lines.addAll(['Just one to go', 'One more today', 'One left. Go!']);
    if (toGo > 1) lines.addAll(['$toGo to go today', '$toGo habits left', 'Only $toGo left today']);
    if (facts.done >= 2 && toGo > 0 && part != DayPart.night) {
      lines.addAll(['${facts.done} down already', '${facts.done} done, $toGo to go']);
    }
    final streak = facts.streak;
    if (streak != null && streak.length >= 3 && streak.name.length <= maxName) {
      final (name, n) = (streak.name, streak.length);
      lines.addAll(switch (streak.unit) {
        'day' => ['Day $n of $name', '$name: $n days strong', '$n days of $name'],
        'week' => ['$name: week $n', '$n weeks of $name'],
        'month' => ['$name: month $n', '$n months of $name'],
        _ => ['$name, $n in a row'],
      });
    }
    final atRisk = facts.atRisk;
    if (atRisk != null && atRisk.length <= maxName) lines.addAll(['$atRisk needs you', '$atRisk: back today?']);
    lines.addAll(switch (facts.level) {
      MomentumLevel.atomic => const ['Atomic momentum!', 'Fully atomic'],
      MomentumLevel.unstoppable => const ['Unstoppable, truly', 'Habits: formed'],
      MomentumLevel.strong => const ['Momentum: strong'],
      _ => const <String>[],
    });
    return lines;
  }

  /// A greeting for [now]'s part of the day (on the person's own day, from
  /// [dayStart]), other than [avoid] (the one just shown) and, while any
  /// are left, the ones in [seen] (shown lately: see [remember]). With
  /// [facts]: celebratory once everything due today is done, and now and
  /// then one from the person's own day.
  static String pick(
    DateTime now, {
    Random? random,
    String? avoid,
    TimeOfDay dayStart = defaultDayStart,
    GreetingFacts? facts,
    Set<String> seen = const {},
  }) {
    final r = random ?? Greetings.random;
    final part = partOf(now, dayStart: dayStart);
    final List<String> pool;
    if (facts != null && facts.allDone) {
      pool = allDone;
    } else {
      final own = facts == null ? const <String>[] : personal(facts, part);
      pool = own.isNotEmpty && r.nextDouble() < personalShare ? own : lines[part]!;
    }
    final fresh = [for (final line in pool) if (line != avoid && !seen.contains(line)) line];
    final options = fresh.isNotEmpty ? fresh : [for (final line in pool) if (line != avoid) line];
    return options.isEmpty ? pool.first : options[r.nextInt(options.length)];
  }

  /// [seen] with [line] added: once every line of its pool has been shown,
  /// that pool starts over (all but [line], so it doesn't come straight
  /// back). Lines from the person's own data don't build up for long.
  static Set<String> remember(Set<String> seen, String line) {
    final next = {...seen, line};
    for (final pool in [...lines.values, allDone]) {
      if (pool.contains(line) && pool.every(next.contains)) next.removeAll(pool.where((l) => l != line));
    }
    final fixed = {...lines.values.expand((l) => l), ...allDone};
    final own = next.where((l) => !fixed.contains(l)).toList();
    if (own.length > 40) next.removeAll(own.take(own.length - 40));
    return next;
  }
}

/// What the person's own data lets a greeting say (see [Greetings.personal]).
class GreetingFacts {
  /// Habits being built that are due today, and how many of them are done
  /// (in full, or with the two-minute version).
  final int due;
  final int done;

  /// The longest streak going: its habit's name, its length, and what it's
  /// counted in ("day", "week", "month"; null: "in a row").
  final ({String name, int length, String? unit})? streak;

  /// A habit one miss from losing its streak, not yet done today.
  final String? atRisk;

  /// Overall momentum's level.
  final MomentumLevel? level;

  const GreetingFacts({this.due = 0, this.done = 0, this.streak, this.atRisk, this.level});

  /// Every habit due today is done.
  bool get allDone => due > 0 && done >= due;

  int get toGo => due > done ? due - done : 0;
}
