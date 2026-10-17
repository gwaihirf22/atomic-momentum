import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_color.dart';
import '../../domain/entities/habit_schedule.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/entities/reset_frequency.dart';
import '../../domain/entities/two_minute_version.dart';
import '../../domain/usecases/create_habit_usecase.dart';
import '../../domain/usecases/update_habit_usecase.dart';
import '../providers/category_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/settings_provider.dart';

/// A habit being added or edited: every value the form shows, how it's
/// checked, and how it's saved. The one-page form, Builder and Story all edit
/// a draft, so they save exactly the same habit.
///
/// Text lives in controllers (shared by whichever field shows it); other
/// values are fields changed through [edit], which tells listeners.
class HabitDraft extends ChangeNotifier {
  static const allDays = [1, 2, 3, 4, 5, 6, 7];
  static const maxInterval = 30;
  static const maxTarget = 1000;
  static const maxUnitsLength = 20;
  static const maxMessageLength = 100;

  /// The habit being edited, or null for a new one.
  final Habit? original;

  final name = TextEditingController();
  final target = TextEditingController();
  final units = TextEditingController();

  /// The two-minute version: what it is, and an amount that counts by itself.
  final tiny = TextEditingController();
  final tinyMinimum = TextEditingController();
  final message = TextEditingController();

  bool tinyShowOnCard = true;
  HabitColor color = HabitColor.blue;

  /// An id, so a habit in an unknown or deleted category keeps it unless changed.
  String categoryId;
  String? icon;
  ResetFrequency frequency = ResetFrequency.daily;

  /// Weekly habits reset on this date's weekday, monthly on its day of month.
  DateTime anchor = DateUtils.dateOnly(clock.now());
  int interval = 1;

  /// Days a daily habit is due; all seven means every day.
  List<int> scheduleDays = List.of(allDays);

  /// New habits remind by default, at the time chosen in Settings; smart
  /// reminders follow the schedule (see ReminderPlanner).
  bool reminderEnabled = true;
  ReminderMode reminderMode = ReminderMode.smart;
  TimeOfDay reminderTime;
  List<int> reminderDays = List.of(allDays);

  late final String _initialSnapshot;

  /// A new habit in [categoryId] (the first category), reminding at
  /// [reminderTime] (Settings → Default time).
  HabitDraft.newHabit({required this.categoryId, required this.reminderTime}) : original = null {
    _start();
  }

  /// The form for [habit], filled with what it has now.
  HabitDraft.fromHabit(Habit habit, {required TimeOfDay defaultReminderTime})
      : original = habit,
        categoryId = habit.categoryId,
        reminderTime = defaultReminderTime {
    name.text = habit.name;
    target.text = habit.target.toString();
    units.text = habit.units;
    color = habit.color;
    frequency = habit.resetFrequency;
    anchor = habit.resetAnchor;
    interval = habit.resetInterval;
    scheduleDays = List.of(habit.scheduledWeekdays ?? allDays);
    final reminder = habit.reminder;
    reminderEnabled = reminder?.enabled ?? false;
    if (reminder != null) {
      reminderMode = reminder.mode;
      reminderTime = reminder.time;
      reminderDays = List.of(reminder.daysOfWeek);
      message.text = reminder.customMessage ?? '';
    }
    icon = habit.metadata.icon;
    final twoMinute = habit.twoMinute;
    if (twoMinute != null) {
      tiny.text = twoMinute.description;
      tinyMinimum.text = twoMinute.minimum?.toString() ?? '';
      tinyShowOnCard = twoMinute.showOnCard;
    }
    _start();
  }

  /// The draft a form opens with: [habit] as it is, or a new habit in the
  /// first category, reminding at Settings → Default time.
  static HabitDraft start(BuildContext context, Habit? habit) {
    final reminderTime = context.read<SettingsProvider>().defaultReminderTime;
    if (habit != null) return HabitDraft.fromHabit(habit, defaultReminderTime: reminderTime);
    final categories = context.read<CategoryProvider>().categories;
    return HabitDraft.newHabit(
      categoryId: categories.isEmpty ? '' : categories.first.id,
      reminderTime: reminderTime,
    );
  }

  void _start() {
    // Unsaved-changes check: compare against the draft as it opened
    _initialSnapshot = snapshot();
    for (final controller in _controllers) {
      controller.addListener(notifyListeners);
    }
  }

  List<TextEditingController> get _controllers => [name, target, units, tiny, tinyMinimum, message];

  bool get isEditing => original != null;

  /// Changes some values and tells listeners: `draft.edit(() => draft.color = c)`.
  void edit(VoidCallback change) {
    change();
    notifyListeners();
  }

  HabitSchedule get schedule => HabitSchedule(
        frequency: frequency,
        interval: interval,
        anchor: anchor,
        weekdays: scheduleDays,
      );

  /// The start date only matters when periods don't simply follow the calendar day.
  bool get startDateMatters => frequency.isPeriodic && (frequency != ResetFrequency.daily || interval > 1);

  /// Weekday chips show for daily habits due on chosen days.
  bool get showsDueDays => frequency == ResetFrequency.daily && interval == 1;

  int? get enteredTarget => int.tryParse(target.text.trim());

  /// A minimum only makes sense when the target is more than one.
  bool get tinyMinimumApplies => (enteredTarget ?? 0) > 1;

  bool get hasTiny => tiny.text.trim().isNotEmpty;

  /// The two-minute version that would be saved, or null for none. Habits
  /// that never reset have no streak to keep, so they don't get one.
  TwoMinuteVersion? get twoMinute {
    final description = tiny.text.trim();
    if (description.isEmpty || !frequency.isPeriodic) return null;
    return TwoMinuteVersion(
      description: description,
      minimum: tinyMinimumApplies ? int.tryParse(tinyMinimum.text.trim()) : null,
      showOnCard: tinyShowOnCard,
    );
  }

  void toggleScheduleDay(int day) => edit(() {
        if (scheduleDays.contains(day)) {
          // At least one day must stay selected
          if (scheduleDays.length > 1) scheduleDays.remove(day);
        } else {
          scheduleDays.add(day);
        }
        scheduleDays.sort();
      });

  void toggleReminderDay(int day) => edit(() {
        if (!reminderDays.remove(day)) reminderDays.add(day);
      });

  // Checks, with the messages the form shows

  static String? validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter a habit name';
    if (text.length < 2) return 'Habit name must be at least 2 characters';
    if (text.length > 50) return 'Habit name cannot exceed 50 characters';
    return null;
  }

  static String? validateTarget(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter a target number';
    final number = int.tryParse(text);
    if (number == null || number <= 0) return 'Target must be a positive number';
    if (number > maxTarget) return 'Target cannot exceed $maxTarget';
    return null;
  }

  static String? validateUnits(String? value) =>
      (value?.trim().length ?? 0) > maxUnitsLength ? 'Units cannot exceed $maxUnitsLength characters' : null;

  String? validateMinimum(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final minimum = int.tryParse(text);
    final most = enteredTarget ?? 0;
    if (minimum == null || minimum < 1 || minimum >= most) return 'Enter a number from 1 to ${most - 1}';
    return null;
  }

  String? get nameError => validateName(name.text);
  String? get targetError => validateTarget(target.text);
  String? get unitsError => validateUnits(units.text);

  /// Only checked while the minimum field is showing.
  String? get minimumError => hasTiny && tinyMinimumApplies ? validateMinimum(tinyMinimum.text) : null;

  bool get isValid => nameError == null && targetError == null && unitsError == null && minimumError == null;

  // Unsaved changes

  bool get hasChanges => snapshot() != _initialSnapshot;

  /// Every value that would be saved, as one comparable string.
  String snapshot() => jsonEncode([
        name.text,
        target.text,
        units.text,
        color.value,
        categoryId,
        frequency.name,
        interval,
        anchor.toIso8601String(),
        scheduleDays,
        reminderEnabled,
        reminderMode.name,
        reminderTime.hour * 60 + reminderTime.minute,
        reminderDays,
        message.text,
        icon,
        tiny.text.trim(),
        tinyMinimum.text.trim(),
        tinyShowOnCard,
      ]);

  // Saving

  /// The reminder to save. When editing a habit that had one, turning it off
  /// must send a disabled reminder: null means "unchanged" to updateDetails,
  /// which would leave the old reminder firing.
  ReminderSettings? get reminder {
    final on = reminderEnabled && (reminderMode == ReminderMode.smart || reminderDays.isNotEmpty);
    if (!on && original?.reminder == null) return null;
    final text = message.text;
    return ReminderSettings(
      time: reminderTime,
      enabled: on,
      mode: reminderMode,
      daysOfWeek: List.of(reminderDays),
      customMessage: text.isNotEmpty ? text : null,
    );
  }

  /// A new habit with these values. Only call when [isValid].
  CreateHabitParams toCreateParams() => CreateHabitParams(
        name: name.text.trim(),
        target: int.parse(target.text.trim()),
        units: units.text.trim(),
        color: color,
        categoryId: categoryId,
        resetFrequency: frequency,
        reminder: reminder,
        icon: icon,
        resetAnchor: anchor,
        resetInterval: frequency.isPeriodic ? interval : 1,
        scheduledWeekdays: List.of(scheduleDays),
        twoMinute: twoMinute,
      );

  /// The edited habit's new values. Only call when editing and [isValid].
  UpdateHabitParams toUpdateParams() {
    final params = toCreateParams();
    return UpdateHabitParams(
      name: params.name,
      target: params.target,
      units: params.units,
      color: params.color,
      categoryId: params.categoryId,
      resetFrequency: params.resetFrequency,
      reminder: params.reminder,
      // '' tells updateDetails to remove an existing icon ("No icon")
      icon: icon ?? '',
      resetAnchor: params.resetAnchor,
      resetInterval: params.resetInterval,
      // All seven days means "every day", which also clears a weekday schedule
      scheduledWeekdays: params.scheduledWeekdays,
      twoMinute: params.twoMinute,
      removeTwoMinute: params.twoMinute == null && original!.twoMinute != null,
    );
  }

  /// Why the last [save] failed, for the message the form shows.
  String? saveError;

  /// Adds or updates the habit; false (with [saveError]) if it couldn't.
  Future<bool> save(HabitProvider habits) async {
    saveError = null;
    try {
      final saved = isEditing
          ? await habits.updateHabitDetails(original!.id, toUpdateParams())
          : await habits.createHabit(toCreateParams());
      if (!saved) saveError = habits.error;
      return saved;
    } catch (e) {
      saveError = e.toString();
      return false;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
