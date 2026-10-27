import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atomic_momentum/core/demo/memory_prefs.dart';
import 'package:atomic_momentum/core/sync/sync_log.dart';

void main() {
  test('keeps the newest lines across a restart, and copies newest first', () {
    final prefs = MemoryPrefs();
    withClock(Clock.fixed(DateTime(2026, 10, 26, 21, 5, 32)), () {
      final log = SyncLog(prefs);
      for (var i = 0; i < SyncLog.most + 5; i++) {
        log.add('line $i');
      }
    });
    final again = SyncLog(prefs);
    expect(again.entries, hasLength(SyncLog.most));
    expect(again.entries.first.text, 'line 5');
    expect(again.text.split('\n').first, 'Oct 26 21:05:32  line ${SyncLog.most + 4}');
  });

  test('a line it cannot read is left out', () async {
    final prefs = MemoryPrefs();
    await prefs.setStringList(SyncLog.key, ['{not json', '[1, "ok"]']);
    expect(SyncLog(prefs).entries.map((e) => e.text), ['ok']);
  });
}
