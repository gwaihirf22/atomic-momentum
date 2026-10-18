import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/dev/dev_tools.dart';

void main() {
  test('Settings → Developer shows in debug builds, and in others only when built with DEV_TOOLS', () {
    expect(DevTools.fromBuild, isFalse, reason: 'no build turns it on unless asked');
    expect(DevTools.enabled, kDebugMode || DevTools.fromBuild);
    expect(DevTools.enabled, isTrue, reason: 'tests run as a debug build');
  });
}
