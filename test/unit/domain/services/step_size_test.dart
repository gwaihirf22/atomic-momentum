import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/domain/services/step_size.dart';

/// + and − step by the size of the target.
void main() {
  test('the step grows with the target', () {
    expect([0, 1, 8, 99].map(StepSize.forTarget), everyElement(1));
    expect(StepSize.forTarget(100), 10);
    expect(StepSize.forTarget(299), 10);
    expect(StepSize.forTarget(300), 100);
    expect(StepSize.forTarget(2999), 100);
    expect(StepSize.forTarget(8000), 1000);
    expect(StepSize.forTarget(30000), 10000);
  });

  test('+ goes to the next whole step, stopping at the target', () {
    expect(StepSize.up(3, 8), 4);
    expect(StepSize.up(0, 8000), 1000);
    expect(StepSize.up(7450, 8000), 8000);
    expect(StepSize.up(7450, 8500), 8000);
    expect(StepSize.up(8000, 8500), 8500, reason: 'not past the target');
    expect(StepSize.up(120, 250), 130);
  });

  test('+ goes on past a limit (a habit being broken logs slips)', () {
    expect(StepSize.up(120, 120), 130);
    expect(StepSize.up(0, 0), 1, reason: 'quitting steps by one');
  });

  test('− goes to the whole step below, never under 0', () {
    expect(StepSize.down(4, 8), 3);
    expect(StepSize.down(8000, 8000), 7000);
    expect(StepSize.down(7450, 8000), 7000);
    expect(StepSize.down(450, 8000), 0);
    expect(StepSize.down(0, 8000), 0);
  });
}
