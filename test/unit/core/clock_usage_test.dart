import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// App code reads the time from package:clock, so tests (the notification
/// simulator above all) can move time forward. One stray DateTime.now()
/// would read the real time in the middle of a simulated month.
void main() {
  test('lib/ never calls DateTime.now(); it uses clock.now()', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'DateTime\.now\b').hasMatch(lines[i])) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'Use clock.now() from package:clock');
  });
}
