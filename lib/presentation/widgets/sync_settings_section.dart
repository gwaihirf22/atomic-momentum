import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../core/dev/dev_tools.dart';
import '../../core/injection/injection_container.dart';
import '../../core/sync/sync_service.dart';
import '../../domain/entities/habit_color.dart';
import '../help/explainers.dart';
import 'adaptive.dart';
import 'health_settings_section.dart' show healthSyncAgo;
import 'info_button.dart';
import 'settings_list.dart';

/// Settings → Sync (Momentum Plus): one switch, where it stands, Sync now,
/// and what it does. Until the purchase is built, only in builds with
/// Developer tools.
class SyncSettingsSection extends StatelessWidget {
  /// Shown in store builds too (tests); otherwise only with Developer tools.
  final bool always;

  const SyncSettingsSection({super.key, this.always = false});

  @override
  Widget build(BuildContext context) {
    if (!(always || DevTools.enabled) || !sl.isRegistered<SyncService>()) return const SizedBox.shrink();
    final sync = get<SyncService>();
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) => _SyncSection(sync: sync),
    );
  }
}

class _SyncSection extends StatelessWidget {
  final SyncService sync;

  const _SyncSection({required this.sync});

  bool get _android => defaultTargetPlatform == TargetPlatform.android;
  String get _cloud => _android ? 'Google Drive' : 'iCloud';

  /// Where it stands, in a few words.
  String get status => switch (sync.state) {
        SyncState.off => _android ? 'Your habits on your other Android devices' : 'Your habits on your iPad and other iPhones',
        SyncState.syncing => 'Syncing',
        SyncState.synced => 'Synced ${healthSyncAgo(sync.lastSynced).toLowerCase()}',
        SyncState.offline => 'Waiting for a connection',
        SyncState.noAccount => _android ? 'Sign in to a Google account first' : 'Sign in to iCloud in Settings first',
        SyncState.full => '$_cloud is full',
        SyncState.stopped => 'Stopped: the account changed, or the copy was deleted. Turn on to sync again.',
        SyncState.needsUpdate => 'Update Momentum to keep syncing',
        SyncState.paused => 'Waits while a year of use is loaded',
        SyncState.unavailable => 'Needs the App Store version of Momentum',
        SyncState.failed => "Couldn't sync. It'll try again.",
      };

  Future<void> _toggle(BuildContext context, bool on) async {
    if (on) {
      await sync.turnOn();
      return;
    }
    final device = _android ? 'this phone' : 'this iPhone';
    final choice = await showAdaptiveAlert<String>(
      context,
      title: 'Turn off sync?',
      message: 'Everything stays on $device. You can also delete the copy in $_cloud, for every device.',
      actions: [
        AdaptiveAction(label: 'Keep on $device', value: 'keep', key: const Key('syncOffKeep')),
        AdaptiveAction(
          label: 'Delete the copy in $_cloud',
          value: 'delete',
          isDestructive: true,
          key: const Key('syncOffDelete'),
        ),
        const AdaptiveAction(label: 'Cancel', value: 'cancel', isDefault: true, key: Key('syncOffCancel')),
      ],
    );
    if (choice == 'keep' || choice == 'delete') await sync.turnOff(deleteCloud: choice == 'delete');
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      header: 'Sync',
      footer: 'Your habits, settings and quotes on every device signed in to your '
          '${_android ? 'Google account' : 'Apple ID'}, kept in your own $_cloud. I never see them.',
      children: [
        SettingsSwitchTile(
          tileKey: const Key('syncSwitch'),
          icon: CupertinoIcons.cloud_fill,
          iconColor: HabitColor.blue.color,
          title: 'Sync with $_cloud',
          subtitle: status,
          value: sync.isOn,
          onChanged: sync.state == SyncState.syncing && !sync.isOn ? null : (on) => _toggle(context, on),
        ),
        if (sync.isOn)
          SettingsTile(
            tileKey: const Key('syncNow'),
            icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
            iconColor: HabitColor.green.color,
            title: 'Sync now',
            onTap: sync.state == SyncState.syncing ? null : sync.syncNow,
          ),
        SettingsTile(
          tileKey: const Key('syncAbout'),
          icon: CupertinoIcons.info_circle_fill,
          iconColor: HabitColor.blueGrey.color,
          title: 'About sync',
          onTap: () => showInfoSheet(context, InfoTopic.sync),
        ),
      ],
    );
  }
}
