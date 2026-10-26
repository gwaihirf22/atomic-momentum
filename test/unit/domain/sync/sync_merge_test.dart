import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atomic_momentum/domain/sync/freeze_replay.dart';
import 'package:atomic_momentum/domain/sync/hlc.dart';
import 'package:atomic_momentum/domain/sync/sync_merge.dart';
import 'package:atomic_momentum/domain/sync/sync_records.dart';

Hlc at(int wall, String device, [int count = 0]) => Hlc(wall, count, device);

void main() {
  group('Hlc', () {
    test('orders by time, then count, then device, and round-trips', () {
      expect(at(2, 'a') > at(1, 'z'), isTrue);
      expect(at(1, 'a', 2) > at(1, 'z', 1), isTrue);
      expect(at(1, 'b') > at(1, 'a'), isTrue);
      const stamp = Hlc(1767225600123, 7, 'dev-1:x');
      expect(Hlc.decode(stamp.encode()), stamp);
    });

    test('a clock never goes back, even when the phone\'s does', () {
      var now = DateTime(2026, 10, 25, 12);
      withClock(Clock(() => now), () {
        final clock = HlcClock('a');
        final first = clock.tick();
        now = now.subtract(const Duration(hours: 1));
        final second = clock.tick();
        expect(second > first, isTrue);
        // Seeing a stamp from a device whose clock runs ahead
        clock.receive(Hlc(first.wall + 100000, 3, 'b'));
        final third = clock.tick();
        expect(third > Hlc(first.wall + 100000, 3, 'b'), isTrue);
        expect(third.device, 'a');
      });
    });
  });

  group('SyncMerge', () {
    test('the latest stamp wins a habit\'s settings', () {
      final merged = SyncMerge.merge({
        'a': {SyncKeys.field('h1', 'name'): Stamped('Walk', at(1, 'a'))},
        'b': {SyncKeys.field('h1', 'name'): Stamped('Run', at(2, 'b'))},
      });
      expect(merged.habits['h1']!.fields['name']!.value, 'Run');
    });

    test('days add up across devices; a later whole-day value replaces them', () {
      final merged = SyncMerge.merge({
        'a': {SyncKeys.count('h1', '2026-10-25', '0'): Stamped(3, at(1, 'a'))},
        'b': {SyncKeys.count('h1', '2026-10-25', '0'): Stamped(1, at(2, 'b'))},
      });
      final habit = merged.habits['h1']!;
      expect(habit.total('2026-10-25', '0'), 4);
      expect(habit.ownCountFor('2026-10-25', '0', 'a', 6), 5, reason: 'typing 6 on a: 5 + b\'s 1');

      final withValue = SyncMerge.merge({
        'a': {SyncKeys.count('h1', '2026-10-25', '0'): Stamped(3, at(1, 'a'))},
        'b': {SyncKeys.dayValue('h1', '2026-10-25'): Stamped({'v': 7, 'g': '0'}, at(5, 'b'))},
      });
      expect(withValue.habits['h1']!.total('2026-10-25', '0'), 7);
    });

    test('a count in old units is converted, not dropped', () {
      // Units changed on b (glasses → ml, ×250) while a logged a glass offline
      final merged = SyncMerge.merge({
        'a': {SyncKeys.count('h1', '2026-10-25', '0'): Stamped(1, at(1, 'a'))},
        'b': {
          SyncKeys.generation('h1', 'g1'): Stamped({'p': '0', 's': 250}, at(2, 'b')),
          SyncKeys.count('h1', '2026-10-25', 'g1'): Stamped(500, at(3, 'b')),
        },
      });
      expect(merged.habits['h1']!.total('2026-10-25', 'g1'), 750);
      expect(merged.habits['h1']!.total('2026-10-25', '0'), 3);
    });

    test('a deletion is kept, and sets only grow', () {
      final merged = SyncMerge.merge({
        'a': {
          SyncKeys.deleted('h1'): Stamped(true, at(1, 'a')),
          SyncKeys.element('seen', 'streak-7'): Stamped(true, at(1, 'a')),
        },
        'b': {
          SyncKeys.field('h1', 'name'): Stamped('Walk', at(9, 'b')),
          SyncKeys.element('seen', 'formed'): Stamped(true, at(2, 'b')),
        },
      });
      expect(merged.habits['h1']!.isDeleted, isTrue);
      expect(merged.members('seen'), {'streak-7', 'formed'});
    });

    test('the earliest value wins where asked', () {
      final merged = SyncMerge.merge({
        'a': {SyncKeys.earliest('firstSpent'): Stamped('2026-10-20', at(9, 'a'))},
        'b': {SyncKeys.earliest('firstSpent'): Stamped('2026-10-22', at(1, 'b'))},
      });
      expect(merged.valueOf(SyncKeys.earliest('firstSpent')), '2026-10-20');
    });

    test('three devices editing at random agree, in any order, delivered twice', () {
      final random = Random(7);
      const devices = ['a', 'b', 'c'];
      const keys = [
        'h/h1/name',
        'h/h1/amount',
        'd/h1/2026-10-25/0',
        'd/h1/2026-10-24/0',
        'r/h1/2026-10-23',
        'm/h1/2026-10-25/note',
        'e/seen/x',
        'n/fund',
        'o/order',
        'x/h2',
      ];
      for (var round = 0; round < 50; round++) {
        final records = {for (final d in devices) d: <String, Stamped>{}};
        for (var i = 0; i < 40; i++) {
          final device = devices[random.nextInt(3)];
          final key = keys[random.nextInt(keys.length)];
          records[device]![key] = Stamped(
            key.startsWith('r/') ? {'v': random.nextInt(9), 'g': '0'} : random.nextInt(9),
            at(random.nextInt(20), device, i),
          );
        }
        final expected = _summary(SyncMerge.merge(records));
        // Any order of devices, each device's records in any order, twice
        for (var shuffle = 0; shuffle < 5; shuffle++) {
          final order = [...devices]..shuffle(random);
          final replicas = <String, Records>{};
          for (final device in order) {
            final entries = records[device]!.entries.toList()..shuffle(random);
            replicas[device] = Map.fromEntries([...entries, ...entries]);
          }
          expect(_summary(SyncMerge.merge(replicas)), expected);
        }
      }
    });
  });

  group('FreezeReplay', () {
    final oct = [for (var d = 1; d <= 31; d++) DateTime(2026, 10, d)];

    test('credits stop at the cap, in whatever order they arrive', () {
      final credits = {'m1': oct[1], 'm2': oct[2], 'm3': oct[3]};
      expect(FreezeReplay.balance(credits: credits, spends: const []), 5);
      final reversed = Map.fromEntries(credits.entries.toList().reversed);
      expect(FreezeReplay.balance(credits: reversed, spends: [oct[4]]), 4);
    });

    test('a milestone earned while full adds nothing after a later spend', () {
      final balance = FreezeReplay.balance(
        credits: {'m1': oct[1], 'm2': oct[2], 'm3': oct[3]},
        spends: [oct[10]],
      );
      expect(balance, 4, reason: '3 + 2 (capped at 5, the third lost) − 1');
    });

    test('the adjustment carries over what the bank held before sync', () {
      expect(FreezeReplay.balance(credits: const {}, spends: [oct[1]], adjust: -1), 1);
      expect(FreezeReplay.balance(credits: const {}, spends: const [], adjust: 9), 5);
    });
  });
}

String _summary(MergedState state) {
  final lines = <String>[];
  for (final habit in state.habits.values.toList()..sort((a, b) => a.id.compareTo(b.id))) {
    lines.add('${habit.id} deleted=${habit.isDeleted}');
    for (final f in (habit.fields.keys.toList()..sort())) {
      lines.add('  $f=${habit.fields[f]!.value}');
    }
    for (final day in (habit.days.keys.toList()..sort())) {
      lines.add('  $day total=${habit.total(day, '0')} note=${habit.days[day]!.mark('note')}');
    }
  }
  for (final key in (state.values.keys.toList()..sort())) {
    lines.add('$key=${state.values[key]!.value}');
  }
  for (final set in (state.sets.keys.toList()..sort())) {
    lines.add('$set=${(state.members(set).toList()..sort())}');
  }
  return lines.join('\n');
}
