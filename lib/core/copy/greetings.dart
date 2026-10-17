import 'dart:math';

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

  static DayPart partOf(DateTime time) {
    final hour = time.hour;
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
  static String pick(DateTime now, {Random? random, String? avoid}) {
    final options = lines[partOf(now)]!.where((line) => line != avoid).toList();
    return options[(random ?? Greetings.random).nextInt(options.length)];
  }
}
