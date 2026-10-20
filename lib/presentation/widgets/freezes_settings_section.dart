import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/freeze_bank.dart';
import '../../core/theme/app_palette.dart';
import '../help/explainers.dart';
import '../providers/habit_provider.dart';
import '../providers/settings_provider.dart';
import 'adaptive.dart';
import 'info_button.dart';
import 'settings_list.dart';

/// Settings → Freezes: how many are in the bank, how they're earned, and
/// vacation mode (with its return date and notifications).
class FreezesSettingsSection extends StatelessWidget {
  const FreezesSettingsSection({super.key});

  /// "Sat, Oct 24".
  static String dayLabel(DateTime day) => DateFormat('EEE, MMM d').format(day);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final habits = context.watch<HabitProvider>();
    final settings = context.watch<SettingsProvider>();
    final bank = habits.freezes;
    final back = habits.vacationBack;
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
        if (habits.onVacation)
          SettingsTile(
            tileKey: const Key('vacationBack'),
            icon: CupertinoIcons.calendar,
            iconColor: palette.ice,
            title: 'Back on',
            subtitle: back == null ? 'Optional: it ends by itself that morning' : null,
            value: back == null ? 'Add a date' : dayLabel(back),
            onTap: () => _pickReturn(context, habits, back),
          ),
        SettingsSwitchTile(
          tileKey: const Key('vacationNotices'),
          icon: CupertinoIcons.bell,
          iconColor: palette.ice,
          title: 'Vacation check-ins',
          subtitle: !habits.onVacation
              ? 'While away: a check-in every few days, or a welcome back on your return date'
              : back == null
                  ? 'A check-in every few days, with "I\'m back"'
                  : 'A welcome back on ${dayLabel(back)}',
          value: settings.vacationNotices,
          onChanged: (on) async {
            await settings.setVacationNotices(on);
            await habits.resyncVacationNotices();
          },
        ),
      ],
    );
  }

  /// The return day: a date from tomorrow, or none (it lasts until turned
  /// off, with check-ins).
  static Future<void> _pickReturn(BuildContext context, HabitProvider habits, DateTime? back) async {
    if (back != null) {
      final choice = await chooseAdaptive<bool>(
        context,
        title: 'Back on ${dayLabel(back)}',
        options: const [
          AdaptiveOption(true, 'Change the date', key: Key('vacationBackChange')),
          AdaptiveOption(false, 'No return date',
              key: Key('vacationBackClear'), subtitle: 'Until you turn it off, with a check-in every few days'),
        ],
      );
      if (choice == null) return;
      if (!choice) {
        await habits.setVacationReturn(null);
        return;
      }
    }
    if (!context.mounted) return;
    final now = clock.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final picked = await pickDateAdaptive(
      context,
      initial: back ?? DateTime(now.year, now.month, now.day + 7),
      first: tomorrow,
      last: DateTime(now.year + 1, now.month, now.day),
      helpText: 'Back on',
    );
    if (picked != null) await habits.setVacationReturn(picked);
  }
}
