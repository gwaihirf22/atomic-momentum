import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/presentation/widgets/freeze_time_left.dart';

void main() {
  test('days for a long freeze, hours on the day, minutes in the last hour', () {
    expect(freezeTimeLeft(const Duration(days: 5, hours: 3)), '5 days left');
    expect(freezeTimeLeft(const Duration(hours: 47, minutes: 59)), '47 hours left');
    expect(freezeTimeLeft(const Duration(hours: 13, minutes: 59)), '13 hours left');
    expect(freezeTimeLeft(const Duration(hours: 1, minutes: 30)), '1 hour left');
    expect(freezeTimeLeft(const Duration(minutes: 59, seconds: 10)), '59 min left');
    expect(freezeTimeLeft(const Duration(minutes: 42)), '42 min left');
    expect(freezeTimeLeft(const Duration(seconds: 20)), '1 min left');
    expect(freezeTimeLeft(Duration.zero), '0 min left');
  });
}
