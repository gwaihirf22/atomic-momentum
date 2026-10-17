import 'dart:async';
import 'dart:math';

import 'package:atomic_momentum/core/copy/greetings.dart';

/// Runs before every test file: random parts of the app (the Habits
/// greeting) are seeded so a layout is the same on every run.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Greetings.random = Random(42);
  await testMain();
}
