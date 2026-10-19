import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/freeze_bank.dart';
import '../../core/theme/app_palette.dart';
import '../help/explainers.dart';
import '../providers/habit_provider.dart';
import 'info_button.dart';
import 'settings_list.dart';

/// Settings → Freezes: how many are in the bank, how they're earned, and
/// vacation mode.
class FreezesSettingsSection extends StatelessWidget {
  const FreezesSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final habits = context.watch<HabitProvider>();
    final bank = habits.freezes;
    return SettingsSection(
      header: 'Freezes',
      footer: 'A freeze holds one habit\'s day as it was: neither kept nor missed. Streak milestones and habits '
          'formed earn one each, up to ${FreezeBank.cap}. Vacation mode pauses everything without spending any.',
      children: [
        if (bank != null)
          ListenableBuilder(
            listenable: bank,
            builder: (context, _) => SettingsTile(
              tileKey: const Key('freezeBankTile'),
              icon: CupertinoIcons.snow,
              iconColor: palette.ice,
              title: 'In the bank',
              value: '${bank.available} of ${FreezeBank.cap}',
              showChevron: false,
              onTap: () => showInfoSheet(context, InfoTopic.freezes),
            ),
          ),
        SettingsSwitchTile(
          tileKey: const Key('vacationSwitch'),
          icon: CupertinoIcons.airplane,
          iconColor: palette.ice,
          title: 'Vacation mode',
          subtitle: habits.onVacation
              ? 'On: nothing is due, no reminders'
              : 'Pause every habit: streaks and momentum hold',
          value: habits.onVacation,
          onChanged: (on) => on ? habits.startVacation() : habits.endVacation(),
        ),
      ],
    );
  }
}
