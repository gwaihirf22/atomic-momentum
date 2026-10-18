import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Drives integration_test/year_on_device_test.dart, saving its screenshots
/// to $YEAR_SCREENS (build/year_screens by default).
Future<void> main() => integrationDriver(
      onScreenshot: (name, image, [args]) async {
        final dir = Platform.environment['YEAR_SCREENS'] ?? 'build/year_screens';
        File('$dir/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(image);
        return true;
      },
    );
