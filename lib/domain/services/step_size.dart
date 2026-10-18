/// How much + and − change a habit by: 1 for small targets, then 10, 100,
/// 1,000 and 10,000 as targets grow, so 8,000 steps is eight taps, not
/// eight thousand.
class StepSize {
  const StepSize._();

  /// The step for a habit aiming at [target] (a habit being broken: its
  /// limit; quitting, target 0: 1).
  static int forTarget(int target) {
    if (target < 100) return 1;
    if (target < 300) return 10;
    if (target < 3000) return 100;
    if (target < 30000) return 1000;
    return 10000;
  }

  /// [value] after +: up to the next whole step (7,450 → 8,000), and no
  /// further than [target] when below it (a habit being broken may go on
  /// past its limit).
  static int up(int value, int target) {
    final step = forTarget(target);
    final next = (value ~/ step + 1) * step;
    return value < target && next > target ? target : next;
  }

  /// [value] after −: down to the whole step below (7,450 → 7,000), never
  /// under 0.
  static int down(int value, int target) {
    final step = forTarget(target);
    final next = value % step == 0 ? value - step : value ~/ step * step;
    return next < 0 ? 0 : next;
  }
}
