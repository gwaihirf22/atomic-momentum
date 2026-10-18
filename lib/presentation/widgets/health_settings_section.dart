import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/injection/injection_container.dart';
import '../../core/services/health_source.dart';
import '../../domain/entities/habit_color.dart';
import '../providers/habit_provider.dart';
import 'settings_list.dart';

/// "5 min ago", for when Health was last read.
String healthSyncAgo(DateTime? at, {DateTime? now}) {
  if (at == null) return 'Not yet';
  final gap = (now ?? clock.now()).difference(at);
  if (gap.inMinutes < 1) return 'Just now';
  if (gap.inHours < 1) return '${gap.inMinutes} min ago';
  if (gap.inDays < 1) return '${gap.inHours} h ago';
  return '${gap.inDays} d ago';
}

/// Settings → Apple Health (or Health Connect): sync now, install Health
/// Connect where it's missing, and where permissions live. Hidden where
/// there's no health store.
class HealthSettingsSection extends StatefulWidget {
  const HealthSettingsSection({super.key});

  @override
  State<HealthSettingsSection> createState() => _HealthSettingsSectionState();
}

class _HealthSettingsSectionState extends State<HealthSettingsSection> {
  late final HealthSource _source = get<HealthSource>();
  late Future<HealthAvailability> _availability = _source.availability();
  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    await context.read<HabitProvider>().syncHealth(force: true);
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<HabitProvider>();
    final linked = habits.habits.where((h) => h.health != null).length;
    return FutureBuilder<HealthAvailability>(
      future: _availability,
      builder: (context, snapshot) {
        final availability = snapshot.data;
        if (availability == null || availability == HealthAvailability.unsupported) return const SizedBox.shrink();
        final where = _source.isAndroid ? 'Health Connect → App permissions' : 'Health → Sharing → Apps';
        return SettingsSection(
          header: _source.name,
          footer: 'Link a habit in its editor. Numbers staying at 0? Allow Momentum in $where.',
          children: [
            if (availability == HealthAvailability.needsHealthConnect)
              SettingsTile(
                tileKey: const Key('healthInstall'),
                icon: CupertinoIcons.arrow_down_circle_fill,
                iconColor: HabitColor.green.color,
                title: 'Install Health Connect',
                onTap: () async {
                  await _source.installHealthConnect();
                  if (mounted) setState(() => _availability = _source.availability());
                },
              )
            else
              SettingsTile(
                tileKey: const Key('healthSyncNow'),
                icon: CupertinoIcons.heart_fill,
                iconColor: HabitColor.red.color,
                title: _syncing ? 'Syncing…' : 'Sync now',
                subtitle: linked == 0 ? 'No habits linked yet' : (linked == 1 ? '1 habit linked' : '$linked habits linked'),
                value: healthSyncAgo(habits.lastHealthSync),
                onTap: _syncing || linked == 0 ? null : _syncNow,
              ),
          ],
        );
      },
    );
  }
}
