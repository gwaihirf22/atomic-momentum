import 'package:flutter/foundation.dart';

/// A diagnostic for developers. Silent in release builds, so nothing about
/// people's habits reaches the device log.
void logWarning(String message) {
  if (kDebugMode) debugPrint(message);
}
