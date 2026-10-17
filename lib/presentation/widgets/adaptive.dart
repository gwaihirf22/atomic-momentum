import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';
import 'package:clock/clock.dart';

/// One button in an [showAdaptiveAlert].
class AdaptiveAction<T> {
  final String label;
  final T value;
  final Key? key;
  final bool isDestructive;
  final bool isDefault;

  const AdaptiveAction({
    required this.label,
    required this.value,
    this.key,
    this.isDestructive = false,
    this.isDefault = false,
  });
}

/// An alert that looks native: iOS-style on iPhone and Mac, Material on
/// Android. Returns the chosen action's value, or null if dismissed.
Future<T?> showAdaptiveAlert<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<AdaptiveAction<T>> actions,
}) {
  return showAdaptiveDialog<T>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        for (final action in actions)
          isCupertino(context)
              ? CupertinoDialogAction(
                  key: action.key,
                  isDestructiveAction: action.isDestructive,
                  isDefaultAction: action.isDefault,
                  onPressed: () => Navigator.of(context).pop(action.value),
                  child: Text(action.label),
                )
              : TextButton(
                  key: action.key,
                  style: action.isDestructive ? TextButton.styleFrom(foregroundColor: AppPalette.of(context).danger) : null,
                  onPressed: () => Navigator.of(context).pop(action.value),
                  child: Text(action.label),
                ),
      ],
    ),
  );
}

/// Asks to confirm something. True only when the confirm button is chosen.
Future<bool> confirmAdaptive(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  Key? confirmKey,
  Key? cancelKey,
}) async {
  final confirmed = await showAdaptiveAlert<bool>(
    context,
    title: title,
    message: message,
    actions: [
      AdaptiveAction(label: cancelLabel, value: false, key: cancelKey, isDefault: destructive),
      AdaptiveAction(
        label: confirmLabel,
        value: true,
        key: confirmKey,
        isDestructive: destructive,
        isDefault: !destructive,
      ),
    ],
  );
  return confirmed == true;
}

/// One choice in [chooseAdaptive].
class AdaptiveOption<T> {
  final T value;
  final String label;
  final Key? key;

  const AdaptiveOption(this.value, this.label, {this.key});
}

/// Picks one of a few options: an action sheet on iPhone and Mac, a dialog
/// on Android. The current choice is marked. Null if cancelled.
Future<T?> chooseAdaptive<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<AdaptiveOption<T>> options,
  T? selected,
}) {
  if (isCupertino(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        message: message == null ? null : Text(message),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              key: option.key,
              isDefaultAction: option.value == selected,
              onPressed: () => Navigator.of(context).pop(option.value),
              child: Text(option.value == selected ? '${option.label}  ✓' : option.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(message),
          ),
        for (final option in options)
          SimpleDialogOption(
            key: option.key,
            onPressed: () => Navigator.of(context).pop(option.value),
            child: Row(
              children: [
                Expanded(child: Text(option.label)),
                if (option.value == selected) Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
      ],
    ),
  );
}

/// A time picker: the iOS wheel on iPhone and Mac, the clock on Android.
Future<TimeOfDay?> pickTimeAdaptive(BuildContext context, {required TimeOfDay initial}) async {
  if (!isCupertino(context)) {
    return showTimePicker(context: context, initialTime: initial);
  }
  final now = clock.now();
  final picked = await _cupertinoPicker(
    context,
    mode: CupertinoDatePickerMode.time,
    initial: DateTime(now.year, now.month, now.day, initial.hour, initial.minute),
  );
  return picked == null ? null : TimeOfDay(hour: picked.hour, minute: picked.minute);
}

/// A date picker: the iOS wheel on iPhone and Mac, the calendar on Android.
Future<DateTime?> pickDateAdaptive(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String? helpText,
}) async {
  if (!isCupertino(context)) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: helpText,
    );
  }
  final picked = await _cupertinoPicker(
    context,
    mode: CupertinoDatePickerMode.date,
    initial: initial,
    minimum: first,
    maximum: last,
    title: helpText,
  );
  return picked == null ? null : DateTime(picked.year, picked.month, picked.day);
}

/// A wheel in a bottom popup with Cancel and Done, as in iOS forms.
Future<DateTime?> _cupertinoPicker(
  BuildContext context, {
  required CupertinoDatePickerMode mode,
  required DateTime initial,
  DateTime? minimum,
  DateTime? maximum,
  String? title,
}) {
  var value = initial;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (context) {
      final background = AppPalette.of(context).surface;
      return Container(
        color: background,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    key: const Key('pickerCancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    key: const Key('pickerDone'),
                    onPressed: () => Navigator.of(context).pop(value),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              // A caption of its own, so it wraps rather than squeezing between the buttons
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: secondaryLabel(context)),
                  ),
                ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: mode,
                  initialDateTime: initial,
                  minimumDate: minimum,
                  maximumDate: maximum,
                  onDateTimeChanged: (picked) => value = picked,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
