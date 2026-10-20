import 'package:equatable/equatable.dart';

import '../entities/quiet_hours.dart';

/// Vacation mode as notifications see it: the day it started, and the
/// planned return day, if there is one.
class VacationPlan extends Equatable {
  final DateTime since;
  final DateTime? back;

  VacationPlan({required DateTime since, DateTime? back})
      : since = DateTime(since.year, since.month, since.day),
        back = back == null ? null : DateTime(back.year, back.month, back.day);

  @override
  List<Object?> get props => [since, back];
}

enum VacationNoticeKind {
  /// "Still away?", with an "I'm back" button.
  checkIn,

  /// The morning of the return day: vacation mode has ended by itself.
  welcomeBack,
}

/// One vacation notification to deliver.
class PlannedVacationNotice extends Equatable {
  final VacationNoticeKind kind;
  final DateTime at;
  final String title;
  final String body;

  const PlannedVacationNotice({required this.kind, required this.at, required this.title, required this.body});

  @override
  List<Object?> get props => [kind, at, title, body];

  @override
  String toString() => 'PlannedVacationNotice(${kind.name} at $at: $title)';
}

/// What vacation mode sends while habit reminders are quiet, at Settings'
/// default reminder time (moved out of quiet hours):
/// - with a return date: nothing while away, then a welcome back that
///   morning, when vacation mode ends by itself;
/// - without one: a check-in every 3 days, easing to once a week after two
///   weeks, each with an "I'm back" button.
class VacationNoticePlanner {
  const VacationNoticePlanner._();

  /// Days after the start that check in: every 3 days for two weeks…
  static const _early = [3, 6, 9, 12];

  /// …then once a week after the last of those.
  static const _weekly = 7;

  /// How far ahead check-ins are scheduled; opening the app plans again.
  static const horizonDays = 28;

  /// At most this many are pending at once.
  static const maxPending = 4;

  static const welcomeTitle = 'Welcome back!';
  static const welcomeBody = 'Your habits pick up today, right where you left them.';

  /// Check-ins take turns through these, in the app's voice (the atoms get
  /// one).
  static const checkIns = [
    ('Still away?', 'Your streaks are safe with me. Nothing is due until you\'re back.'),
    ('Enjoying the break?', 'I\'m keeping everything just as you left it.'),
    ('Hope it\'s a good one', 'Your habits are paused and your momentum is holding.'),
    ('Checking in', 'The atoms are resting too. Tell me when you\'re back.'),
  ];

  /// The day [n] (from 0) of the check-ins comes, counted from the start.
  static int checkInDay(int n) =>
      n < _early.length ? _early[n] : _early.last + _weekly * (n - _early.length + 1);

  static List<PlannedVacationNotice> plan(
    VacationPlan vacation, {
    required DateTime now,
    required int hour,
    required int minute,
    QuietHours quiet = QuietHours.off,
  }) {
    DateTime at(DateTime day) => quiet.shift(DateTime(day.year, day.month, day.day, hour, minute));

    final back = vacation.back;
    if (back != null) {
      final when = at(back);
      return [
        if (when.isAfter(now))
          PlannedVacationNotice(kind: VacationNoticeKind.welcomeBack, at: when, title: welcomeTitle, body: welcomeBody),
      ];
    }

    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(today.year, today.month, today.day + horizonDays);
    final notices = <PlannedVacationNotice>[];
    for (var n = 0; notices.length < maxPending; n++) {
      final s = vacation.since;
      final day = DateTime(s.year, s.month, s.day + checkInDay(n));
      if (day.isAfter(last)) break;
      final when = at(day);
      if (!when.isAfter(now)) continue;
      final (title, body) = checkIns[n % checkIns.length];
      notices.add(PlannedVacationNotice(kind: VacationNoticeKind.checkIn, at: when, title: title, body: body));
    }
    return notices;
  }
}
