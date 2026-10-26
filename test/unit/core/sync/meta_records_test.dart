import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atomic_momentum/core/demo/memory_prefs.dart';
import 'package:atomic_momentum/core/sync/meta_records.dart';
import 'package:atomic_momentum/domain/sync/hlc.dart';
import 'package:atomic_momentum/domain/sync/sync_merge.dart';
import 'package:atomic_momentum/presentation/providers/settings_provider.dart';

void main() {
  test('every setting is either synced, in a group, or kept on the device', () {
    final grouped = MetaRecords.settingGroups.values.expand((keys) => keys).toList();
    expect(grouped.toSet().length, grouped.length, reason: 'a setting in two groups');
    for (final key in SettingsProvider.storedKeys) {
      expect(grouped.contains(key) || MetaRecords.localSettings.contains(key), isTrue, reason: '$key: sync it or not?');
    }
  });

  test('settings read, change and write back, hour and minute together, local ones never', () async {
    final phone = MemoryPrefs({
      'defaultReminderHour': 7,
      'defaultReminderMinute': 30,
      'weekStartDay': 7,
      'greetingsSeen': ['a'],
      'allowTimeSensitive': false,
    });
    final base = MetaRecords.read(phone);
    expect(base.keys.where((k) => k.contains('greetings') || k.contains('allowTime')), isEmpty);

    await phone.setInt('defaultReminderHour', 18);
    await phone.remove('weekStartDay');
    final clock = HlcClock('phone');
    final records = withClock(Clock.fixed(DateTime(2026, 10, 25)), () {
      return MetaRecords.changes(base, MetaRecords.read(phone), clock.tick);
    });
    expect(records.keys, containsAll(['o/s/reminderTime', 'o/s/weekStart']));
    expect(records['o/s/reminderTime']!.value, {'defaultReminderHour': 18, 'defaultReminderMinute': 30});
    expect(records['o/s/weekStart']!.value, isNull);

    final ipad = MemoryPrefs({'weekStartDay': 1, 'greetingsSeen': ['b']});
    final merged = MetaRecords.viewOf(SyncMerge.merge({'phone': records}));
    final changed = await MetaRecords.write(ipad, merged, MetaRecords.read(ipad));
    expect(changed, {MetaArea.settings});
    expect(ipad.getInt('defaultReminderHour'), 18);
    expect(ipad.getInt('defaultReminderMinute'), 30);
    expect(ipad.containsKey('weekStartDay'), isFalse, reason: 'back to Automatic');
    expect(ipad.getStringList('greetingsSeen'), ['b']);
  });
}
