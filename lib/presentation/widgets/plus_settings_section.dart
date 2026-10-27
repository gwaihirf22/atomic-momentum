import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../core/dev/dev_tools.dart';
import '../../core/injection/injection_container.dart';
import '../../core/services/plus_store.dart';
import '../../core/sync/sync_service.dart';
import '../../screens/plus_screen.dart';
import '../../screens/sync_log_screen.dart';
import '../../domain/entities/habit_color.dart';
import '../help/explainers.dart';
import 'adaptive.dart';
import 'health_settings_section.dart' show healthSyncAgo;
import 'info_button.dart';
import 'settings_list.dart';
import '../layout/app_layout.dart';

/// Settings → Momentum Plus: the Plus row (what it is, buying it), sync
/// behind it (one switch, where it stands, Sync now), and what sync does.
/// Wherever Plus is sold (iPhone and iPad; anywhere with Developer tools).
class PlusSettingsSection extends StatelessWidget {
  const PlusSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!sl.isRegistered<PlusStore>() || !sl.isRegistered<SyncService>()) return const SizedBox.shrink();
    final plus = get<PlusStore>();
    if (!plus.isSupported) return const SizedBox.shrink();
    final sync = get<SyncService>();
    return ListenableBuilder(
      listenable: Listenable.merge([sync, plus]),
      builder: (context, _) => _PlusSection(sync: sync, plus: plus),
    );
  }
}

class _PlusSection extends StatelessWidget {
  final SyncService sync;
  final PlusStore plus;

  const _PlusSection({required this.sync, required this.plus});

  bool get _android => defaultTargetPlatform == TargetPlatform.android;
  String get _cloud => _android ? 'Google Drive' : 'iCloud';

  /// Where it stands, in a few words.
  String get status => switch (sync.state) {
        SyncState.off => _android ? 'Your habits on your other Android devices' : 'Your habits on your other iPhones and iPads',
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
      // Sync comes with Plus; already on, it stays on whatever happens to it
      if (!plus.unlocked) {
        await PlusScreen.open(context);
        return;
      }
      await sync.turnOn();
      return;
    }
    final device = _android ? DeviceWords.thisDevice(context) : 'this ${DeviceWords.appleDevice(context)}';
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
      header: 'Momentum Plus',
      footer: 'Sync puts your habits, settings and quotes on every device signed in to your '
          '${_android ? 'Google account' : 'Apple ID'}, kept in your own $_cloud. I never see them.',
      children: [
        SettingsTile(
          tileKey: const Key('plusRow'),
          icon: CupertinoIcons.star_circle_fill,
          iconColor: HabitColor.orange.color,
          title: 'Momentum Plus',
          subtitle: plus.unlocked ? 'Thank you! Plus is yours' : 'Sync with your iPad, and what comes next',
          onTap: () => PlusScreen.open(context),
        ),
        SettingsSwitchTile(
          tileKey: const Key('syncSwitch'),
          icon: CupertinoIcons.cloud_fill,
          iconColor: HabitColor.blue.color,
          title: 'Sync with $_cloud',
          subtitle: plus.unlocked || sync.isOn ? status : 'With Momentum Plus',
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
        // What sync did here, to trace a problem between devices
        if (DevTools.enabled && (sync.isOn || sync.log.entries.isNotEmpty))
          SettingsTile(
            tileKey: const Key('syncLog'),
            icon: CupertinoIcons.list_bullet,
            iconColor: HabitColor.blueGrey.color,
            title: 'Sync log',
            onTap: () => SyncLogScreen.open(context, sync.log),
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
