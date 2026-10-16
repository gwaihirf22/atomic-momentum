import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/exceptions/friendly_error.dart';
import 'package:atomic_momentum/core/exceptions/storage_exceptions.dart';

void main() {
  group('friendlyError', () {
    test('shows a validation problem as written', () {
      final raw = 'StorageException: Failed to update habit: ${const ValidationException('Name cannot be empty')}';
      expect(friendlyError(raw, fallback: 'x'), 'Name cannot be empty');
    });

    test('hides storage details and other technical text', () {
      expect(friendlyError(const StorageException('Disk full').toString(), fallback: 'Try again'), 'Try again');
      expect(friendlyError(null, fallback: 'Try again'), 'Try again');
    });
  });

  test('no DEBUG print statements are left in the app', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => RegExp(r"(?<![\w.])print\(").hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty, reason: 'use logWarning (silent in release) instead of print');
  });
}
