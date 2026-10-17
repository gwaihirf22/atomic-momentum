import 'dart:math';
import 'package:flutter/material.dart' show TimeOfDay;

/// Parts of the day the Habits header greets.
enum DayPart { morning, afternoon, evening, night }

/// The Habits screen's greeting: a line picked at random for the time of
/// day, encouraging and now and then a little cheeky. A new one is picked
/// each time the app is opened (see HomeScreen), never the same line twice
/// in a row.
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
    ],
    DayPart.night: [
      'Still up?',
      'Night owl mode',
      'Late-night momentum',
      'Sleep is a habit too',
      'Go to bed. Soon.',
      'Up past bedtime?',
      'Quiet hours, big wins',
    ],
  };

  /// A random greeting for [now]'s part of the day, other than [avoid]
  /// (the one just shown).
  static String pick(DateTime now, {Random? random, String? avoid, TimeOfDay dayStart = defaultDayStart}) {
    final options = lines[partOf(now, dayStart: dayStart)]!.where((line) => line != avoid).toList();
    return options[(random ?? Greetings.random).nextInt(options.length)];
  }
}
