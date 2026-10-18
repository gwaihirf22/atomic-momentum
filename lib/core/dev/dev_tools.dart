import 'package:flutter/foundation.dart';

/// Settings → Developer (sample habits, a year of use, the notification
/// tester): always in debug builds, and in a release or profile build made
/// with `--dart-define=DEV_TOOLS=true`, for testing the real speed on a phone
/// (`DEV_TOOLS=1 tool/install_on_iphone.sh`). Never in a store build.
class DevTools {
  const DevTools._();

  static const fromBuild = bool.fromEnvironment('DEV_TOOLS');

  static const enabled = kDebugMode || fromBuild;
}
