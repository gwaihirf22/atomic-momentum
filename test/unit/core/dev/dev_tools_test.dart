import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/dev/dev_tools.dart';

void main() {
  test('Settings → Developer shows in debug builds, and in others only when built with DEV_TOOLS', () {
    expect(DevTools.fromBuild, isFalse, reason: 'no build turns it on unless asked');
    expect(DevTools.enabled, kDebugMode || DevTools.fromBuild);
    expect(DevTools.enabled, isTrue, reason: 'tests run as a debug build');
  });

  // The safety nets around it: a store build must never carry DEV_TOOLS
  group('a store build never has Settings → Developer', () {
    Future<int> check({required String action, required List<String> defines}) async {
      final encoded = defines.map((d) => base64.encode(utf8.encode(d))).join(',');
      final result = await Process.run('tool/check_no_dev_tools.sh', [],
          environment: {'ACTION': action, 'DART_DEFINES': encoded});
      return result.exitCode;
    }

    test('archiving (an App Store or TestFlight upload) with DEV_TOOLS fails', () async {
      expect(await check(action: 'install', defines: ['FLUTTER_VERSION=3', 'DEV_TOOLS=true']), isNot(0));
      expect(await check(action: 'install', defines: ['FLUTTER_VERSION=3']), 0);
      expect(await check(action: 'build', defines: ['DEV_TOOLS=true']), 0, reason: 'test builds may have it');
    });

    test('Xcode runs that check for the app', () {
      final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(project, contains(r'tool/check_no_dev_tools.sh'));
      final phases = RegExp(r'97C146ED1CF9000F007C117D /\* Runner \*/ = \{[^}]*buildPhases = \(([^)]*)\)')
          .firstMatch(project)!
          .group(1)!;
      expect(phases, contains('Check no dev tools'));
    });

    test('the install script puts the build settings back afterwards', () {
      final script = File('tool/install_on_iphone.sh').readAsStringSync();
      expect(script, contains('trap'));
      expect(script, contains('--config-only'));
    });

    test('the Developer section is gated on DevTools, nothing else', () {
      final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(settings, contains('if (DevTools.enabled)'));
      expect(settings, isNot(contains('kDebugMode')));
    });
  });
}
