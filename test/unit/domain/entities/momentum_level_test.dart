import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/momentum.dart';

void main() {
  test('levels follow the shown (rounded) score', () {
    expect(MomentumLevel.of(0), MomentumLevel.building);
    expect(MomentumLevel.of(39.4), MomentumLevel.building);
    expect(MomentumLevel.of(39.5), MomentumLevel.rolling);
    expect(MomentumLevel.of(69), MomentumLevel.rolling);
    expect(MomentumLevel.of(70), MomentumLevel.strong);
    expect(MomentumLevel.of(79), MomentumLevel.strong);
    expect(MomentumLevel.of(79.5), MomentumLevel.unstoppable);
    expect(MomentumLevel.of(89), MomentumLevel.unstoppable);
    expect(MomentumLevel.of(89.5), MomentumLevel.atomic);
    expect(MomentumLevel.of(100), MomentumLevel.atomic);
  });

  test('Unstoppable starts where a habit has formed', () {
    expect(MomentumLevel.unstoppable.from, Momentum.habitFormed);
    expect(MomentumLevel.values.last, MomentumLevel.atomic);
    expect(const Momentum(score: 93, trend: 0).level.label, 'Atomic');
  });

  test('a momentum reads its level by name', () {
    expect(const Momentum(score: 72, trend: 3).level.label, 'Strong');
    expect(Momentum.habitFormed, 80);
  });
}
