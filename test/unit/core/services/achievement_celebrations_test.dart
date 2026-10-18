import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/services/achievement_celebrations.dart';
import 'package:atomic_momentum/domain/services/achievements.dart';

void main() {
  final now = DateTime(2026, 10, 18, 21);

  Achievement earned(String id, DateTime on, {AchievementKind kind = AchievementKind.streak}) => Achievement(
        id: id,
        kind: kind,
        title: id,
        badge: '7',
        unit: 'DAYS',
        message: '',
        earnedOn: on,
      );

  CelebrationDecision decide(List<Achievement> list, {bool started = true, Set<String> seen = const {}, bool busy = false}) =>
      AchievementCelebrations.decide(earned: list, started: started, seen: seen, now: now, busy: busy);

  test('the first check files everything quietly', () {
    final d = decide([earned('a', DateTime(2026, 10, 18))], started: false);
    expect(d.celebrate, isNull);
    expect(d.markSeen, ['a']);
  });

  test('one reached today or yesterday is celebrated, once', () {
    final d = decide([earned('a', DateTime(2026, 10, 17))]);
    expect(d.celebrate?.id, 'a');
    expect(d.markSeen, ['a']);
    expect(decide([earned('a', DateTime(2026, 10, 17))], seen: {'a'}).celebrate, isNull);
  });

  test('older ones go to the shelf quietly', () {
    final d = decide([earned('old', DateTime(2026, 10, 16))]);
    expect(d.celebrate, isNull);
    expect(d.markSeen, ['old']);
  });

  test('several at once: the highest ranked is celebrated, all are filed', () {
    final d = decide([
      earned('streak', DateTime(2026, 10, 18)),
      earned('formed', DateTime(2026, 10, 18), kind: AchievementKind.formed),
    ]);
    expect(d.celebrate?.id, 'formed');
    expect(d.markSeen, unorderedEquals(['streak', 'formed']));
  });

  test('waits while a page or sheet is open, marking nothing', () {
    final d = decide([earned('a', DateTime(2026, 10, 18))], busy: true);
    expect(d.wait, isTrue);
    expect(d.markSeen, isEmpty);
    // Nothing to celebrate: filed even while busy
    expect(decide([earned('old', DateTime(2026, 10, 1))], busy: true).markSeen, ['old']);
  });
}
