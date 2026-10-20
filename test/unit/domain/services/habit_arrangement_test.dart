import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/habit.dart';
import 'package:atomic_momentum/domain/entities/habit_color.dart';
import 'package:atomic_momentum/domain/services/habit_arrangement.dart';

void main() {
  var minute = 0;
  Habit habit(String id, String category) {
    final h = Habit.create(name: id, target: 1, color: HabitColor.blue, categoryId: category);
    // Made a minute apart, in order
    return h.copyWith(
      id: id,
      metadata: h.metadata.copyWith(createdDate: DateTime(2026, 1, 1, 9, minute++)),
    );
  }

  final water = habit('water', 'body');
  final read = habit('read', 'mind');
  final gym = habit('gym', 'body');
  final pray = habit('pray', 'spirit');
  final old = habit('old', 'gone'); // a deleted category's
  final all = [water, read, gym, pray, old];
  const ranks = {'body': 0, 'spirit': 1, 'mind': 2};
  List<String> ids(List<Habit> habits) => [for (final h in habits) h.id];

  group('grouped by category', () {
    test('in the categories\' order, oldest first within each; a lost category last', () {
      expect(ids(HabitArrangement.arrange(all, order: const [], categoryRanks: ranks, grouped: true)),
          ['water', 'gym', 'pray', 'read', 'old']);
    });

    test('moving Spirit first puts its habits first', () {
      expect(
          ids(HabitArrangement.arrange(all, order: const [], categoryRanks: const {'spirit': 0, 'body': 1, 'mind': 2}, grouped: true)),
          ['pray', 'water', 'gym', 'read', 'old']);
    });

    test("the person's order within a category; habits it doesn't list yet come after", () {
      expect(ids(HabitArrangement.arrange(all, order: const ['gym', 'water'], categoryRanks: ranks, grouped: true)),
          ['gym', 'water', 'pray', 'read', 'old']);
      final added = habit('stretch', 'body');
      expect(ids(HabitArrangement.arrange([...all, added], order: const ['gym', 'water'], categoryRanks: ranks, grouped: true)),
          ['gym', 'water', 'stretch', 'pray', 'read', 'old']);
    });
  });

  group('in any order', () {
    test("the person's order, whatever the categories", () {
      expect(
          ids(HabitArrangement.arrange(all, order: const ['read', 'old', 'water', 'pray', 'gym'], categoryRanks: ranks, grouped: false)),
          ['read', 'old', 'water', 'pray', 'gym']);
    });

    test('with no order yet: oldest first', () {
      expect(ids(HabitArrangement.arrange(all, order: const [], categoryRanks: ranks, grouped: false)),
          ['water', 'read', 'gym', 'pray', 'old']);
    });
  });

  test('moving one keeps everything else where it is', () {
    final shown = HabitArrangement.arrange(all, order: const [], categoryRanks: ranks, grouped: true);
    expect(HabitArrangement.move(shown, 'gym', 0), ['gym', 'water', 'pray', 'read', 'old']);
    expect(HabitArrangement.move(shown, 'water', 99), ['gym', 'pray', 'read', 'old', 'water']);
  });
}
