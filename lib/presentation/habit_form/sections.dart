import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/locale/week_start.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/habit_color.dart';
import '../../domain/entities/habit_goal.dart';
import '../../domain/entities/habit_notify.dart';
import '../../core/services/notification_service.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/entities/two_minute_version.dart';
import '../../domain/services/reminder_planner.dart';
import '../../screens/categories_screen.dart';
import '../providers/category_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/adaptive.dart';
import '../widgets/category_icons.dart';
import '../widgets/color_picker.dart';
import '../help/explainers.dart';
import '../widgets/habit_icons.dart';
import '../widgets/info_button.dart';
import '../widgets/selectable_swatch.dart';
import 'habit_draft.dart';

// The parts of the habit form, each bound to a HabitDraft and rebuilt when it
// changes, so the same part works on a page, in a step, or in a sheet.

// Apple's Human Interface Guidelines: tap targets at least 44x44 pt
const double _swatchSpacing = 12;
const double _chipSpacing = 8;
const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _headerPadding = EdgeInsets.only(left: 4, bottom: 4);

Widget? _noCounter(BuildContext context, {required int currentLength, required bool isFocused, required int? maxLength}) =>
    null;

/// Rebuilds [builder] whenever [draft] changes.
class _DraftBuilder extends StatelessWidget {
  final HabitDraft draft;
  final WidgetBuilder builder;

  const _DraftBuilder(this.draft, this.builder);

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: draft, builder: (context, _) => builder(context));
}

/// A section heading with the space under it.
class FormSectionHeader extends StatelessWidget {
  final String text;

  /// Shown at the end of the header, such as an (i).
  final Widget? trailing;

  const FormSectionHeader(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final header = SectionHeader(text, padding: _headerPadding);
    return Padding(
      padding: EdgeInsets.only(bottom: trailing == null ? 8 : 0),
      child: trailing == null
          ? header
          : Row(children: [Expanded(child: header), trailing!]),
    );
  }
}

/// The habit's own example for the two-minute explainer ("Read 10 pages",
/// "Read one page"), once it has a name and a tiny version.
TwoMinuteExample? twoMinuteExample(HabitDraft draft) {
  final name = draft.name.text.trim();
  final tiny = draft.tiny.text.trim();
  if (name.isEmpty || tiny.isEmpty) return null;
  final target = draft.target.text.trim();
  final units = draft.units.text.trim();
  final amount = target.isEmpty || target == '1' && units.isEmpty ? '' : ' $target${units.isEmpty ? '' : ' $units'}';
  return (usual: '$name$amount', tiny: tiny);
}

class NameField extends StatelessWidget {
  final HabitDraft draft;
  final bool autofocus;

  /// Larger, in the display font, led by the habit's icon (Builder's first step).
  final bool prominent;

  const NameField(this.draft, {super.key, this.autofocus = false, this.prominent = false});

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      key: const Key('habitNameField'),
      controller: draft.name,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.sentences,
      style: prominent ? const TextStyle(fontFamily: 'Sora', fontSize: 19, fontWeight: FontWeight.w600) : null,
      decoration: InputDecoration(
        labelText: prominent ? null : 'Habit Name',
        hintText: 'e.g. Drink water',
        errorMaxLines: 2,
        prefixIcon: prominent ? _IconChip(draft) : null,
      ),
      validator: HabitDraft.validateName,
    );
    if (!prominent) return field;
    return Semantics(label: 'Habit name', child: field);
  }
}

/// The habit's icon in a chip tinted with its color.
class _IconChip extends StatelessWidget {
  final HabitDraft draft;

  const _IconChip(this.draft);

  @override
  Widget build(BuildContext context) {
    return _DraftBuilder(draft, (context) {
      final palette = AppPalette.of(context);
      final icon = HabitIcons.of(draft.icon) ?? Icons.edit_outlined;
      return Padding(
        padding: const EdgeInsets.only(left: 10, right: 8),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: palette.tint(draft.color.color), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 20, color: palette.habitColor(draft.color.color)),
        ),
      );
    });
  }
}

/// The target, which reads "per day", "per week" and so on after it.
class TargetField extends StatelessWidget {
  final HabitDraft draft;

  const TargetField(this.draft, {super.key});

  @override
  Widget build(BuildContext context) {
    return _DraftBuilder(
      draft,
      (context) => TextFormField(
        key: const Key('habitTargetField'),
        controller: draft.target,
        decoration: InputDecoration(
          labelText: 'Target Number',
          hintText: 'e.g. 8',
          errorMaxLines: 2,
          // Makes "3 per week" style goals explicit
          suffixText: draft.schedule.periodLabel,
        ),
        keyboardType: TextInputType.number,
        validator: HabitDraft.validateTarget,
      ),
    );
  }
}

class UnitsField extends StatelessWidget {
  final HabitDraft draft;

  const UnitsField(this.draft, {super.key});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const Key('habitUnitsField'),
      controller: draft.units,
      decoration: const InputDecoration(
        labelText: 'Units (Optional)',
        hintText: 'e.g. glasses',
        errorMaxLines: 2,
      ),
      maxLength: HabitDraft.maxUnitsLength,
      // Enforce the limit without Material's "0/20" counter
      buildCounter: _noCounter,
      validator: HabitDraft.validateUnits,
    );
  }
}

/// Target and units together.
class AmountFields extends StatelessWidget {
  final HabitDraft draft;

  const AmountFields(this.draft, {super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [TargetField(draft), const SizedBox(height: 16), UnitsField(draft)],
      );
}

/// The category chips, and a way to manage categories without losing the form.
class CategoryChips extends StatelessWidget {
  final HabitDraft draft;
  final bool showHeader;

  const CategoryChips(this.draft, {super.key, this.showHeader = true});

  /// Active categories, plus Uncategorized when editing a habit whose
  /// category was deleted (it's never offered for a new habit).
  List<Category> _choices(CategoryProvider provider) {
    final original = draft.original?.categoryId;
    return [
      ...provider.categories,
      if (original != null && !provider.isActive(original)) Category.uncategorized,
    ];
  }

  /// Opens the Categories page on top of the form (so nothing typed is
  /// lost), then picks up what changed there.
  Future<void> _openCategories(BuildContext context) async {
    final provider = context.read<CategoryProvider>();
    final before = provider.categories.map((c) => c.id).toSet();

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen()));

    final categories = provider.categories;
    final added = categories.where((c) => !before.contains(c.id)).toList();
    draft.edit(() {
      if (added.length == 1) {
        // Most likely made for this habit
        draft.categoryId = added.single.id;
      } else if (!draft.isEditing && !provider.isActive(draft.categoryId) && categories.isNotEmpty) {
        // The chosen category was deleted while away
        draft.categoryId = categories.first.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final palette = AppPalette.of(context);
    return _DraftBuilder(draft, (context) {
      // Which chip shows as selected for a stored id
      final selectedChip = provider.isActive(draft.categoryId) ? draft.categoryId : Category.uncategorizedId;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) const FormSectionHeader('Category'),
          Wrap(
            spacing: _chipSpacing,
            runSpacing: _chipSpacing,
            children: [
              for (final category in _choices(provider))
                FilterChip(
                  key: Key('categoryChip_${category.id == Category.uncategorizedId ? 'uncategorized' : category.id}'),
                  // A long name shrinks to fit the row rather than overflowing
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(category.icon, size: 16, color: palette.habitColor(category.color)),
                        const SizedBox(width: 4),
                        Text(category.name),
                      ],
                    ),
                  ),
                  selected: selectedChip == category.id,
                  // Choosing Uncategorized again keeps the habit's original id,
                  // so restoring its category brings it back
                  onSelected: (_) => draft.edit(() => draft.categoryId =
                      category.id == Category.uncategorizedId ? draft.original!.categoryId : category.id),
                  backgroundColor: selectedChip == category.id ? palette.tint(category.color, alpha: 0.2) : null,
                ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('manageCategories'),
              onPressed: () => _openCategories(context),
              child: const Text('Manage Categories'),
            ),
          ),
        ],
      );
    });
  }
}

/// The color: the current one, suggestions, and "More colors".
class ColorRow extends StatelessWidget {
  final HabitDraft draft;
  final bool showHeader;

  const ColorRow(this.draft, {super.key, this.showHeader = true});

  // Colors other habits use (newest first), then common basics
  List<HabitColor> _suggestions(BuildContext context) {
    final habits = List.of(context.read<HabitProvider>().habits)
      ..sort((a, b) => b.metadata.createdDate.compareTo(a.metadata.createdDate));
    return ColorPalette.suggestions(habits.map((h) => h.color.value));
  }

  @override
  Widget build(BuildContext context) {
    return _DraftBuilder(
      draft,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) const FormSectionHeader('Color'),
          CompactColorPicker(
            selectedValue: draft.color.value,
            onChanged: (color) => draft.edit(() => draft.color = color),
            suggestions: _suggestions(context),
          ),
        ],
      ),
    );
  }
}

/// The icon swatches, "No icon" first. With [limit], only that many icons
/// show, then a "More" swatch calling [onMore].
class IconGrid extends StatelessWidget {
  final HabitDraft draft;
  final bool showHeader;
  final int? limit;
  final VoidCallback? onMore;

  const IconGrid(this.draft, {super.key, this.showHeader = true, this.limit, this.onMore});

  @override
  Widget build(BuildContext context) {
    return _DraftBuilder(draft, (context) {
      final palette = AppPalette.of(context);
      final color = palette.habitColor(draft.color.color);
      var icons = HabitIcons.library.entries.toList();
      // The chosen icon always shows, even past the limit
      if (limit != null && icons.length > limit!) {
        final shown = icons.take(limit!).toList();
        final chosen = icons.where((e) => e.key == draft.icon && !shown.contains(e));
        icons = [...chosen, ...shown.take(limit! - chosen.length)];
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) const FormSectionHeader('Icon'),
          Wrap(
            spacing: _swatchSpacing,
            runSpacing: _swatchSpacing,
            children: [
              SelectableSwatch(
                key: const Key('iconSwatch_none'),
                semanticLabel: 'No icon',
                isSelected: draft.icon == null,
                onTap: () => draft.edit(() => draft.icon = null),
                fill: palette.raised,
                borderColor: draft.icon == null ? palette.accent : null,
                borderWidth: 3,
                child: Icon(Icons.close, color: palette.textSecondary, size: 22),
              ),
              for (final entry in icons)
                SelectableSwatch(
                  key: Key('iconSwatch_${entry.key}'),
                  semanticLabel: '${entry.key} icon',
                  isSelected: draft.icon == entry.key,
                  onTap: () => draft.edit(() => draft.icon = entry.key),
                  fill: draft.icon == entry.key ? color.withOpacity(0.2) : palette.raised,
                  borderColor: draft.icon == entry.key ? color : null,
                  borderWidth: 2,
                  child: Icon(entry.value, color: draft.icon == entry.key ? color : palette.textSecondary, size: 22),
                ),
              if (onMore != null)
                SelectableSwatch(
                  key: const Key('iconSwatch_more'),
                  semanticLabel: 'More icons',
                  isSelected: false,
                  onTap: onMore!,
                  fill: Colors.transparent,
                  borderColor: palette.separator,
                  borderWidth: 1.5,
                  child: Icon(Icons.more_horiz, color: palette.textSecondary, size: 22),
                ),
            ],
          ),
        ],
      );
    });
  }
}

/// How often: the frequency, its interval, the due days, and a summary
/// with the start date where it matters.
class ScheduleSection extends StatelessWidget {
  final HabitDraft draft;
  final bool showHeader;

  const ScheduleSection(this.draft, {super.key, this.showHeader = true});

  static IconData frequencyIcon(ResetFrequency frequency) => switch (frequency) {
        ResetFrequency.daily => Icons.today,
        ResetFrequency.weekly => Icons.view_week,
        ResetFrequency.monthly => Icons.calendar_month,
        ResetFrequency.never => Icons.all_inclusive,
      };

  Future<void> _pickResetDay(BuildContext context) async {
    final picked = await pickDateAdaptive(
      context,
      initial: draft.anchor,
      first: draft.anchor.isBefore(DateTime(2020)) ? draft.anchor : DateTime(2020),
      last: clock.now().add(const Duration(days: 366)),
      helpText: draft.frequency == ResetFrequency.weekly
          ? 'Resets on this weekday'
          : draft.frequency == ResetFrequency.monthly
              ? 'Resets on this day each month'
              : 'Start date',
    );
    if (picked != null) draft.edit(() => draft.anchor = DateUtils.dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    // Weekday chips start on the user's first day of the week
    final weekdays = weekdaysStartingOn(context.watch<SettingsProvider>().firstDayOfWeek);
    return _DraftBuilder(draft, (context) {
      final frequency = draft.frequency;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) const FormSectionHeader('Schedule'),
          Wrap(
            spacing: _chipSpacing,
            runSpacing: _chipSpacing,
            children: [
              for (final option in ResetFrequency.values)
                ChoiceChip(
                  key: Key('frequency_${option.name}'),
                  avatar: Icon(frequencyIcon(option), size: 18),
                  label: Text(option.displayName),
                  selected: frequency == option,
                  onSelected: (_) => draft.edit(() => draft.frequency = option),
                ),
            ],
          ),
          if (frequency.isPeriodic) ...[
            const SizedBox(height: 8),
            // Wraps at large text sizes rather than overflowing
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Every', style: TextStyle(fontSize: 16)),
                IconButton(
                  key: const Key('intervalMinus'),
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Decrease interval',
                  onPressed: draft.interval > 1 ? () => draft.edit(() => draft.interval--) : null,
                ),
                Text(
                  '${draft.interval}',
                  key: const Key('intervalValue'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  key: const Key('intervalPlus'),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Increase interval',
                  onPressed:
                      draft.interval < HabitDraft.maxInterval ? () => draft.edit(() => draft.interval++) : null,
                ),
                Text(
                  '${frequency.periodUnit}${draft.interval == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],
          if (draft.showsDueDays) ...[
            const SizedBox(height: 4),
            const Text('Due on', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final day in weekdays)
                  FilterChip(
                    key: Key('scheduleDay_$day'),
                    label: Text(_weekdayShort[day - 1]),
                    selected: draft.scheduleDays.contains(day),
                    onSelected: (_) => draft.toggleScheduleDay(day),
                  ),
              ],
            ),
          ],
          ListTile(
            key: const Key('scheduleSummary'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_repeat),
            title: Text(draft.schedule.describe()),
            trailing: draft.startDateMatters
                ? TextButton(
                    key: const Key('changeStartDate'),
                    onPressed: () => _pickResetDay(context),
                    child: const Text('Change'),
                  )
                : null,
            onTap: draft.startDateMatters ? () => _pickResetDay(context) : null,
          ),
        ],
      );
    });
  }
}

/// The tiny version for hard days ("Put on running shoes"), an optional
/// amount that counts by itself, and whether the card shows "2 min".
class TwoMinuteSection extends StatelessWidget {
  final HabitDraft draft;
  final bool showHeader;
  final bool autofocus;

  const TwoMinuteSection(this.draft, {super.key, this.showHeader = true, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return _DraftBuilder(draft, (context) {
      final units = draft.units.text.trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            FormSectionHeader(
              'Two-minute version',
              trailing: InfoButton(topic: InfoTopic.twoMinute, example: twoMinuteExample(draft)),
            ),
          TextFormField(
            key: const Key('twoMinuteField'),
            controller: draft.tiny,
            autofocus: autofocus,
            decoration: const InputDecoration(
              labelText: 'Tiny version (optional)',
              hintText: 'e.g. Put on running shoes',
              errorMaxLines: 2,
            ),
            maxLength: TwoMinuteVersion.maxLength,
            buildCounter: _noCounter,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (draft.hasTiny && draft.tinyMinimumApplies) ...[
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('twoMinuteMinimum'),
              controller: draft.tinyMinimum,
              decoration: InputDecoration(
                labelText: 'Minimum (optional)',
                hintText: 'e.g. 1',
                helperText: 'Logging this much counts too',
                helperMaxLines: 2,
                errorMaxLines: 2,
                suffixText: units.isEmpty ? null : units,
              ),
              keyboardType: TextInputType.number,
              validator: draft.validateMinimum,
            ),
          ],
          if (draft.hasTiny)
            SwitchListTile.adaptive(
              key: const Key('twoMinuteOnCard'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Show on card'),
              value: draft.tinyShowOnCard,
              onChanged: (value) => draft.edit(() => draft.tinyShowOnCard = value),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              'On a hard day, do just this. It keeps your streak and never lowers your momentum.',
              style: TextStyle(fontSize: 13, color: secondaryLabel(context)),
            ),
          ),
        ],
      );
    });
  }
}

/// Whether to remind, when, on which days (smart or custom), and the message.
class ReminderSection extends StatelessWidget {
  final HabitDraft draft;
  final bool showHeader;

  const ReminderSection(this.draft, {super.key, this.showHeader = true});

  /// Smart (follows the schedule) or Custom days.
  Widget _modeControl(BuildContext context) {
    const labels = {ReminderMode.smart: 'Smart', ReminderMode.custom: 'Custom days'};
    void choose(ReminderMode? mode) {
      if (mode != null) draft.edit(() => draft.reminderMode = mode);
    }

    if (isCupertino(context)) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<ReminderMode>(
          key: const Key('reminderMode'),
          groupValue: draft.reminderMode,
          onValueChanged: choose,
          children: {for (final e in labels.entries) e.key: Text(e.value)},
        ),
      );
    }
    return SegmentedButton<ReminderMode>(
      key: const Key('reminderMode'),
      segments: [for (final e in labels.entries) ButtonSegment(value: e.key, label: Text(e.value))],
      selected: {draft.reminderMode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => choose(selection.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final weekdays = weekdaysStartingOn(settings.firstDayOfWeek);
    return _DraftBuilder(draft, (context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) FormSectionHeader(draft.isBreak ? 'Check-in' : 'Reminder'),
          // The label is part of the switch: tappable, and read with it by VoiceOver
          SwitchListTile.adaptive(
            key: const Key('reminderSwitch'),
            contentPadding: EdgeInsets.zero,
            title: Text(draft.isBreak ? 'Check in to log any slips' : 'Remind me about this habit'),
            value: draft.reminderEnabled,
            onChanged: (value) => draft.edit(() => draft.reminderEnabled = value),
          ),
          if (draft.reminderEnabled) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Reminder time: ${draft.reminderTime.format(context)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                TextButton(
                  key: const Key('changeReminderTime'),
                  onPressed: () async {
                    final time = await pickTimeAdaptive(context, initial: draft.reminderTime);
                    if (time != null) draft.edit(() => draft.reminderTime = time);
                  },
                  child: const Text('Change Time'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // A check-in is simply on the chosen days
            if (!draft.isBreak) ...[_modeControl(context), const SizedBox(height: 12)],
            if (draft.reminderMode == ReminderMode.smart && !draft.isBreak)
              Text(
                "${ReminderPlanner.describeSmart(draft.schedule)}. Skipped once you're done.",
                key: const Key('reminderSummary'),
                style: TextStyle(fontSize: 14, color: secondaryLabel(context)),
              )
            else
              Wrap(
                spacing: _chipSpacing,
                runSpacing: _chipSpacing,
                children: [
                  for (final day in weekdays)
                    FilterChip(
                      key: Key('reminderDay_$day'),
                      label: Text(_weekdayShort[day - 1]),
                      selected: draft.reminderDays.contains(day),
                      onSelected: (_) => draft.toggleReminderDay(day),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('reminderMessageField'),
              controller: draft.message,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
                hintText: 'e.g. Time for a walk!',
              ),
              maxLength: HabitDraft.maxMessageLength,
              buildCounter: _noCounter,
            ),
            _SoundRow(draft),
            if (settings.allowTimeSensitive)
              SwitchListTile.adaptive(
                key: const Key('habitTimeSensitive'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Time-sensitive'),
                subtitle: const Text('Comes through Focus and Do Not Disturb'),
                value: draft.notify.timeSensitive,
                onChanged: (value) => draft.edit(() => draft.notify = draft.notify.copyWith(timeSensitive: value)),
              ),
          ],
          // "Don't miss twice" warnings, for a habit being built
          if (!draft.isBreak && settings.streakWarnings.enabled && draft.frequency.isPeriodic)
            SwitchListTile.adaptive(
              key: const Key('habitStreakWarnings'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Streak warnings'),
              subtitle: const Text("A nudge before a miss would end the streak"),
              value: draft.notify.streakWarnings,
              onChanged: (value) => draft.edit(() => draft.notify = draft.notify.copyWith(streakWarnings: value)),
            ),
        ],
      );
    });
  }
}

/// How strict a habit being broken is: quit entirely, or stay at or under a
/// limit per day, week or month.
class StrictnessSection extends StatelessWidget {
  final HabitDraft draft;
  final bool showHeader;

  const StrictnessSection(this.draft, {super.key, this.showHeader = true});

  static const _periods = [ResetFrequency.daily, ResetFrequency.weekly, ResetFrequency.monthly];
  static const _periodNames = {
    ResetFrequency.daily: 'a day',
    ResetFrequency.weekly: 'a week',
    ResetFrequency.monthly: 'a month',
  };

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return _DraftBuilder(draft, (context) {
      final limit = draft.goal == HabitGoal.limit;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) const FormSectionHeader('How strict'),
          Wrap(
            spacing: _chipSpacing,
            runSpacing: _chipSpacing,
            children: [
              ChoiceChip(
                key: const Key('strictQuit'),
                label: const Text('Quit completely'),
                selected: !limit,
                onSelected: (_) => draft.setGoal(HabitGoal.quit),
              ),
              ChoiceChip(
                key: const Key('strictLimit'),
                label: const Text('Set a limit'),
                selected: limit,
                onSelected: (_) => draft.setGoal(HabitGoal.limit),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            limit
                ? 'A day you stay at or under the limit counts. Going over is a slip.'
                : 'Every day without it counts. Any slip breaks the day.',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          if (limit) ...[
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('habitTargetField'),
              controller: draft.target,
              decoration: const InputDecoration(labelText: 'At most', hintText: 'e.g. 2', errorMaxLines: 2),
              keyboardType: TextInputType.number,
              validator: HabitDraft.validateLimit,
            ),
            const SizedBox(height: 16),
            UnitsField(draft),
            const SizedBox(height: 4),
            Wrap(
              spacing: _chipSpacing,
              runSpacing: _chipSpacing,
              children: [
                for (final period in _periods)
                  ChoiceChip(
                    key: Key('frequency_${period.name}'),
                    label: Text(_periodNames[period]!),
                    selected: draft.frequency == period,
                    onSelected: (_) => draft.edit(() => draft.frequency = period),
                  ),
              ],
            ),
          ],
        ],
      );
    });
  }
}

/// The habit's notification sound: Settings' default, a Momentum tone,
/// iOS's own, or silent. Choosing one plays it.
class _SoundRow extends StatelessWidget {
  final HabitDraft draft;

  const _SoundRow(this.draft);

  static String labelOf(NotifySound? sound, NotifySound fallback) =>
      sound == null ? 'Default (${fallback.label})' : sound.label;

  @override
  Widget build(BuildContext context) {
    final fallback = context.watch<SettingsProvider>().notifySound;
    final palette = AppPalette.of(context);
    return ListTile(
      key: const Key('habitSound'),
      contentPadding: EdgeInsets.zero,
      title: const Text('Sound'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(labelOf(draft.notify.sound, fallback), style: TextStyle(color: palette.textSecondary)),
        const SizedBox(width: 4),
        Icon(CupertinoIcons.chevron_right, size: 15, color: palette.textSecondary),
      ]),
      onTap: () async {
        // 0: Settings' default; then each sound
        final choices = [null, ...NotifySound.values];
        final picked = await chooseAdaptive<int>(
          context,
          title: 'Sound',
          selected: choices.indexOf(draft.notify.sound),
          options: [
            for (var i = 0; i < choices.length; i++)
              AdaptiveOption(i, labelOf(choices[i], fallback), key: Key('habitSound_${choices[i]?.name ?? 'default'}')),
          ],
        );
        if (picked == null) return;
        final sound = choices[picked];
        draft.edit(() => draft.notify = draft.notify.copyWith(sound: sound, clearSound: sound == null));
        await NotificationService.preview(sound ?? fallback);
      },
    );
  }
}
