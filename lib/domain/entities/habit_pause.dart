import 'package:equatable/equatable.dart';

import 'habit_schedule.dart';

/// A stretch of vacation mode on a habit: from [from] to [to] (both days
/// included), or still going while [to] is null. A period the pause touches
/// is neither kept nor missed, unless it was kept anyway.
///
/// [back] is a planned return day: the pause covers the days before it and
/// ends by itself that morning, so habits (and their reminders) pick up
/// without the app being opened. Ending it early sets [to].
class HabitPause extends Equatable {
  final DateTime from;
  final DateTime? to;
  final DateTime? back;

  HabitPause({required DateTime from, DateTime? to, DateTime? back})
      : from = DateTime(from.year, from.month, from.day),
        to = to == null ? null : DateTime(to.year, to.month, to.day),
        back = to != null || back == null ? null : DateTime(back.year, back.month, back.day);

  /// Still going with no end decided: it pauses up to today, and later days
  /// aren't decided yet.
  bool get isOpen => to == null && back == null;

  /// The pause's last day: [to], the day before [back], or null while open.
  DateTime? get lastDay {
    if (to != null) return to;
    final b = back;
    return b == null ? null : DateTime(b.year, b.month, b.day - 1);
  }

  /// Whether vacation mode is still on on [day]: not ended, and not yet back.
  bool isOnAt(DateTime day) {
    if (to != null) return false;
    final b = back;
    return b == null || DateTime(day.year, day.month, day.day).isBefore(b);
  }

  /// Whether the pause touches any day from [start] up to (not including) [end].
  bool overlaps(DateTime start, DateTime end) {
    if (!from.isBefore(end)) return false;
    final last = lastDay;
    return last == null || !last.isBefore(DateTime(start.year, start.month, start.day));
  }

  /// Whether [day] is one of the pause's days.
  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (d.isBefore(from)) return false;
    final last = lastDay;
    return last == null || !d.isAfter(last);
  }

  /// Ended on [day] (never before it began, nor after a planned return).
  HabitPause closedOn(DateTime day) {
    var last = day.isBefore(from) ? from : day;
    final planned = lastDay;
    if (planned != null && last.isAfter(planned)) last = planned.isBefore(from) ? from : planned;
    return HabitPause(from: from, to: last);
  }

  /// The same pause, back on [day] (null: no return date).
  HabitPause returningOn(DateTime? day) => HabitPause(from: from, back: day);

  Map<String, String> toJson() => {
        'from': _day(from),
        if (to != null) 'to': _day(to!),
        if (back != null) 'back': _day(back!),
      };

  static HabitPause? fromJson(dynamic json) {
    if (json is! Map) return null;
    final from = DateTime.tryParse('${json['from']}');
    if (from == null) return null;
    final to = json['to'] == null ? null : DateTime.tryParse('${json['to']}');
    final back = json['back'] == null ? null : DateTime.tryParse('${json['back']}');
    return HabitPause(from: from, to: to, back: back);
  }

  static List<HabitPause> listFromJson(dynamic json) {
    if (json is! List) return const [];
    return [for (final item in json) if (fromJson(item) case final pause?) pause];
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [from, to, back];
}

/// A habit's schedule as streaks and momentum see it: periods that are
/// paused (frozen, or on vacation) and weren't kept are skipped like rest
/// days, so they're neither counted nor missed.
class PausedSchedule extends HabitSchedule {
  /// Whether the period starting at a given start is paused and not kept.
  final bool Function(DateTime periodStart) skips;

  /// The schedule without pauses (what a search falls back to).
  final HabitSchedule base;

  PausedSchedule(this.base, this.skips)
      : super(
          frequency: base.frequency,
          interval: base.interval,
          anchor: base.anchor,
          weekdays: base.weekdays,
        );

  @override
  bool isDueOn(DateTime date) => super.isDueOn(date) && !skips(periodStart(date));

  /// How many periods a search skips at most before giving up on pauses (a
  /// long vacation can't make it loop forever).
  static const _maxSkipped = 4000;

  @override
  DateTime previousDuePeriodStart(DateTime periodStartDate) {
    var start = periodStart(DateTime(periodStartDate.year, periodStartDate.month, periodStartDate.day - 1));
    for (var i = 0; i < _maxSkipped; i++) {
      if (isDueOn(start)) return start;
      start = periodStart(DateTime(start.year, start.month, start.day - 1));
    }
    return base.previousDuePeriodStart(periodStartDate);
  }

  @override
  DateTime nextDuePeriodStart(DateTime date) {
    var start = nextPeriodStart(date);
    for (var i = 0; i < _maxSkipped; i++) {
      if (isDueOn(start)) return start;
      start = nextPeriodStart(start);
    }
    return base.nextDuePeriodStart(date);
  }
}
