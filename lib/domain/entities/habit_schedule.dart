import 'package:equatable/equatable.dart';
import 'reset_frequency.dart';

/// When a habit's progress resets and which days it is due.
///
/// Periods repeat every [interval] days/weeks/months, counted from [anchor]
/// (so "every 2 days starting Oct 16", or weeks that begin on the anchor's
/// weekday). A daily habit can instead be due only on some [weekdays]; the
/// other days are rest days that never break a streak.
class HabitSchedule extends Equatable {
  final ResetFrequency frequency;
  final int interval;
  final DateTime anchor;

  /// Days the habit is due (DateTime.monday..sunday), or null for every day.
  /// Only meaningful for a daily schedule with an interval of 1.
  final Set<int>? weekdays;

  HabitSchedule({
    required this.frequency,
    int interval = 1,
    required DateTime anchor,
    Iterable<int>? weekdays,
  })  : interval = interval < 1 ? 1 : interval,
        anchor = _dateOnly(anchor),
        weekdays = normalizeWeekdays(weekdays, frequency: frequency, interval: interval)?.toSet();

  /// Null when the weekdays don't restrict anything (none, all seven, or a
  /// schedule they don't apply to); otherwise the sorted days.
  static List<int>? normalizeWeekdays(Iterable<int>? days,
      {required ResetFrequency frequency, required int interval}) {
    if (days == null || frequency != ResetFrequency.daily || interval > 1) return null;
    final valid = days.where((d) => d >= DateTime.monday && d <= DateTime.sunday).toSet();
    if (valid.isEmpty || valid.length == 7) return null;
    return valid.toList()..sort();
  }

  bool get isPeriodic => frequency.isPeriodic;
  bool get hasRestDays => weekdays != null;

  /// Plain daily: due every day, resetting each day (the default schedule).
  bool get isEveryDay => frequency == ResetFrequency.daily && interval == 1 && !hasRestDays;

  /// Local midnight at which the period containing [date] began.
  DateTime periodStart(DateTime date) {
    final day = _dateOnly(date);
    switch (frequency) {
      case ResetFrequency.daily:
        return _addDays(anchor, _floorDiv(_daysBetween(anchor, day), interval) * interval);
      case ResetFrequency.weekly:
        final length = 7 * interval;
        return _addDays(anchor, _floorDiv(_daysBetween(anchor, day), length) * length);
      case ResetFrequency.monthly:
        final monthsSinceAnchor = (day.year * 12 + day.month) - (anchor.year * 12 + anchor.month);
        var k = _floorDiv(monthsSinceAnchor, interval);
        var start = _monthlyResetDate(anchor.year, anchor.month + k * interval, anchor.day);
        if (start.isAfter(day)) {
          k -= 1;
          start = _monthlyResetDate(anchor.year, anchor.month + k * interval, anchor.day);
        }
        return start;
      case ResetFrequency.never:
        return anchor;
    }
  }

  /// Local midnight at which the period after the one containing [date] begins.
  DateTime nextPeriodStart(DateTime date) {
    final start = periodStart(date);
    switch (frequency) {
      case ResetFrequency.daily:
        return _addDays(start, interval);
      case ResetFrequency.weekly:
        return _addDays(start, 7 * interval);
      case ResetFrequency.monthly:
        return _monthlyResetDate(start.year, start.month + interval, anchor.day);
      case ResetFrequency.never:
        throw StateError('Cannot calculate next reset date for never frequency');
    }
  }

  /// True when [currentDate] falls in a later period than [lastResetDate].
  bool shouldReset(DateTime lastResetDate, DateTime currentDate) {
    if (!isPeriodic) return false;
    return periodStart(currentDate).isAfter(periodStart(lastResetDate));
  }

  /// False only on rest days.
  bool isDueOn(DateTime date) => weekdays == null || weekdays!.contains(date.weekday);

  /// Start of the nearest due period before the one starting at [periodStartDate].
  DateTime previousDuePeriodStart(DateTime periodStartDate) {
    var start = periodStart(_addDays(_dateOnly(periodStartDate), -1));
    while (!isDueOn(start)) {
      start = periodStart(_addDays(start, -1));
    }
    return start;
  }

  /// Start of the first due period after the one containing [date].
  DateTime nextDuePeriodStart(DateTime date) {
    var start = nextPeriodStart(date);
    while (!isDueOn(start)) {
      start = nextPeriodStart(start);
    }
    return start;
  }

  /// Typical gap between due periods in days: 1 for daily, 7/3 for Mon/Wed/Fri,
  /// 14 for every 2 weeks. Infinite for habits that never reset.
  double get averageDaysBetweenDuePeriods {
    switch (frequency) {
      case ResetFrequency.daily:
        return hasRestDays ? 7 / weekdays!.length : interval.toDouble();
      case ResetFrequency.weekly:
        return 7.0 * interval;
      case ResetFrequency.monthly:
        return 30.44 * interval;
      case ResetFrequency.never:
        return double.infinity;
    }
  }

  /// What the target is measured over, e.g. "per day" or "per 2 weeks".
  String get periodLabel {
    if (!isPeriodic) return 'in total';
    final unit = frequency.periodUnit;
    return interval == 1 ? 'per $unit' : 'per $interval ${unit}s';
  }

  /// Short form for habit cards, e.g. "Daily", "Mon, Wed, Fri", "Every 2 days".
  String get shortLabel {
    if (!isPeriodic) return frequency.displayName;
    if (hasRestDays) return _weekdayList();
    if (interval == 1) return frequency.displayName;
    return 'Every $interval ${frequency.periodUnit}s';
  }

  /// Full sentence for the form, e.g. "Resets every 2 days, starting Thu, Oct 16".
  String describe() {
    switch (frequency) {
      case ResetFrequency.never:
        return 'Never resets';
      case ResetFrequency.daily:
        if (hasRestDays) return 'Due ${_weekdayList()}; other days are rest days';
        if (interval == 1) return 'Resets every day';
        return 'Resets every $interval days, starting ${_formatDate(anchor)}';
      case ResetFrequency.weekly:
      case ResetFrequency.monthly:
        final resetDay = frequency.describeResetDay(anchor)!;
        if (interval == 1) return resetDay;
        final unit = '${frequency.periodUnit}s';
        final onDay = frequency == ResetFrequency.weekly
            ? 'on ${_weekdayNames[anchor.weekday - 1]}s'
            : 'on the ${_ordinal(anchor.day)}';
        return 'Resets every $interval $unit $onDay, starting ${_formatDate(anchor)}';
    }
  }

  /// Streak text for habit cards, e.g. "3 day streak" or "3 in a row".
  String streakLabel(int count) =>
      interval == 1 ? '$count ${frequency.periodUnit} streak' : '$count in a row';

  String _weekdayList() => weekdays!.toList().map((d) => _weekdayShort[d - 1]).join(', ');

  static const _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime d) =>
      '${_weekdayShort[d.weekday - 1]}, ${_monthShort[d.month - 1]} ${d.day}';

  static String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  // A date's own calendar fields are the day (see Habit._dateOnly)
  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  // Calendar-field arithmetic, so daylight-saving changes don't shift days
  static DateTime _addDays(DateTime date, int days) => DateTime(date.year, date.month, date.day + days);

  static int _daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  // Rounds towards negative infinity, so dates before the anchor work
  static int _floorDiv(int a, int b) => (a - a % b) ~/ b;

  // DateTime normalises month overflow (month 0 or 13), so callers can pass any month
  static DateTime _monthlyResetDate(int year, int month, int anchorDay) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, anchorDay > lastDayOfMonth ? lastDayOfMonth : anchorDay);
  }

  @override
  List<Object?> get props => [frequency, interval, anchor, weekdays?.toList()?..sort()];
}
