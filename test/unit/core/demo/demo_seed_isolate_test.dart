import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/demo/demo_world.dart';

void main() {
  test("today's example habits build off the main thread, as on a phone", () async {
    DemoSeed.clearCache();
    final now = DateTime.now();
    final seed = await DemoSeed.forDay(now);
    expect(seed.habits, isNotEmpty);
    expect(seed.day, DateTime(now.year, now.month, now.day));
    expect(identical(await DemoSeed.forDay(now), seed), isTrue, reason: 'kept for the day');
  });

  test('asked for twice while building, it builds once', () async {
    DemoSeed.clearCache();
    final now = DateTime.now();
    final first = DemoSeed.forDay(now), second = DemoSeed.forDay(now);
    expect(identical(first, second), isTrue);
    expect(identical(await first, await second), isTrue);
  });
}
