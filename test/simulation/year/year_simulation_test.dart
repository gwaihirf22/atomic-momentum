import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/dev/year_of_use.dart';
import 'package:atomic_momentum/core/dev/year_persona.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/notification_service.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/services/achievements.dart';
import 'package:atomic_momentum/domain/services/insights.dart';
import 'package:atomic_momentum/domain/services/recent_periods.dart';

import '../simulated_phone.dart';
import 'year_run.dart';

/// A year of the real app, lived by [YearPersona] from Mon Oct 19 2026 to
/// Mon Oct 18 2027 on a simulated clock: twelve habits of every kind, a
/// fortnight's holiday, edits, start dates, quotes and settings changes, and
/// every clock change in the four zones tool/notification_sim.sh runs.
///
/// After every visit the app's numbers (streaks, momentum, the card's bars,
/// Calendar, quotes, overall momentum, which achievement to celebrate) are
/// checked against an independent [Reference]; at the end of each day, the
/// heatmap, Insights, the habit page and every achievement too. Every
/// notification is checked as it's delivered (as in the six-week
/// scenarios), and reminders that should have come are looked for. The 1st
/// of each month is a cold start from storage.
///
/// The month-by-month digest is compared with goldens/year_digest.txt: the
/// same in every zone (it has no clock times). Review a diff, then update
/// it with `./flutter/bin/flutter test test/simulation --update-goldens`.
void main() {
  // The week's first day comes from the device's locale
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    NotificationService.debugReset();
    await resetDependencies();
  });

  test('a year of the app, checked every day', () async {
    final persona = YearPersona(DateTime(2026, 10, 19));
    late YearRun year;
    final watch = Stopwatch()..start();
    final phone = await SimulatedPhone.run(persona.date(0).add(const Duration(hours: 7)), (phone) async {
      year = YearRun(phone, persona);
      await year.live();

      // "Load a year of use" builds the same year straight onto the habits
      final built = {for (final h in YearOfUse.build(persona, phone.now)) h.name: h};
      final lived = {for (final h in phone.habits.habits) h.name: h};
      expect(built.keys.toSet(), lived.keys.toSet());
      for (final name in lived.keys) {
        final a = lived[name]!, b = built[name]!;
        Map<DateTime, int> logged(Habit h) => {for (final e in h.history.entries) if (e.value > 0) e.key: e.value};
        expect(logged(b), logged(a), reason: '$name history');
        expect(b.twoMinuteDays, a.twoMinuteDays, reason: '$name two-minute days');
        expect(b.trackedFrom, a.trackedFrom, reason: '$name start');
        expect([b.target, b.resetInterval, b.schedule.anchor], [a.target, a.resetInterval, a.schedule.anchor], reason: name);
        expect(b.dayNotes, a.dayNotes, reason: '$name notes');
        expect(b.quoteIds, a.quoteIds, reason: '$name quotes');
        expect(b.streak, a.refresh(phone.now).streak, reason: '$name streak');
      }
      if (Platform.environment['YEAR_PROFILE'] != null) {
        final hs = phone.habits.habits;
        final now = phone.now;
        String t(String what, void Function() f) {
          final w = Stopwatch()..start();
          for (var i = 0; i < 10; i++) {
            f();
          }
          return '$what ${w.elapsedMicroseconds / 10000}ms';
        }
        // ignore: avoid_print
        print([
          t('earned', () => Achievements.earned(hs, now.add(const Duration(seconds: 1)))),
          t('days', () => Insights.days(hs, from: persona.start, to: now, now: now.add(const Duration(seconds: 2)))),
          for (final h in hs)
            t('periods ${h.name}', () => recentPeriods(h, now, count: 370)),
          for (final h in hs)
            t('series ${h.name}', () => h.momentumSeries([for (var i = 0; i < 365; i++) persona.date(i).add(const Duration(hours: 23))])),
        ].join('\n'));
      }
    });
    final took = watch.elapsed;
    File('build/year_report.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync([...phone.failures, ...year.problems].join('\n'));
    // ignore: avoid_print
    print('A year took ${took.inSeconds}s: ${year.timings.map((k, v) => MapEntry(k, '${v.inMilliseconds}ms'))}; '
        '${phone.delivered.length} notifications');

    final all = [...phone.failures, ...year.problems];
    expect(all, isEmpty, reason: '\n${all.length} problems:\n${all.take(60).join('\n')}');
    expect(year.reviewsChecked, greaterThan(40), reason: 'the week in review is checked most weeks');
    _expectGolden(year.digest, 'year_digest');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

void _expectGolden(List<String> lines, String name) {
  final file = File('test/simulation/goldens/$name.txt');
  final text = '${lines.join('\n')}\n';
  if (autoUpdateGoldenFiles) {
    file.writeAsStringSync(text);
    return;
  }
  if (!file.existsSync()) fail('No saved digest "$name"; run with --update-goldens and review it');
  final saved = file.readAsLinesSync();
  final now = text.trimRight().split('\n');
  final diffs = <String>[];
  for (var i = 0; i < saved.length || i < now.length; i++) {
    final a = i < saved.length ? saved[i] : '(none)';
    final b = i < now.length ? now[i] : '(none)';
    if (a != b) diffs.add('line ${i + 1}\n  saved: $a\n  now:   $b');
    if (diffs.length == 10) break;
  }
  expect(diffs, isEmpty, reason: 'Digest "$name" changed (TZ=${Platform.environment['TZ']}):\n${diffs.join('\n')}');
}
