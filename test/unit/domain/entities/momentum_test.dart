import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/entities/momentum.dart';

void main() {
  group('Momentum.overall', () {
    test('nothing to average: null', () {
      expect(Momentum.overall([]), isNull);
    });

    test('one habit: its own score, however formed', () {
      expect(Momentum.overall([const Momentum(score: 37, trend: -2, formed: 0.05)])!.score, closeTo(37, 1e-9));
    });

    test('each counts as much as it has formed, trend too', () {
      final overall = Momentum.overall(const [
        Momentum(score: 90, trend: 1, formed: 0.9),
        Momentum(score: 2, trend: 2, formed: 0.02),
      ])!;
      expect(overall.score, closeTo((90 * 0.9 + 2 * 0.02) / 0.92, 1e-9));
      expect(overall.trend, closeTo((1 * 0.9 + 2 * 0.02) / 0.92, 1e-9));
      expect(overall.score, greaterThan(88), reason: 'a habit just started barely moves it');
    });
  });
}
