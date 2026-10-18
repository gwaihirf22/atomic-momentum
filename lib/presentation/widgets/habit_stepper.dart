import 'package:intl/intl.dart' show NumberFormat;
import '../../domain/entities/habit.dart';
import '../../domain/services/step_size.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_style.dart';

/// A compact −/+ control tinted with the habit's color, with 44pt tap targets.
class HabitStepper extends StatelessWidget {
  final Color color;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;
  final Key? removeKey;
  final Key? addKey;
  final String removeTooltip;
  final String addTooltip;

  const HabitStepper({
    super.key,
    required this.color,
    this.onRemove,
    this.onAdd,
    this.removeKey,
    this.addKey,
    this.removeTooltip = 'Remove one',
    this.addTooltip = 'Add one',
  });

  @override
  Widget build(BuildContext context) {
    Widget button(Key? key, IconData icon, String tooltip, VoidCallback? onPressed) => IconButton(
          key: key,
          icon: Icon(icon, size: 18),
          tooltip: tooltip,
          color: color,
          disabledColor: color.withOpacity(0.3),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: EdgeInsets.zero,
          onPressed: onPressed,
        );

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppStyle.controlRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(removeKey, CupertinoIcons.minus, removeTooltip, onRemove),
          Container(width: 1, height: 20, color: color.withOpacity(0.25)),
          button(addKey, CupertinoIcons.plus, addTooltip, onAdd),
        ],
      ),
    );
  }
}

/// What + or − does, for its tooltip and VoiceOver: [one] ("Add one") for
/// steps of 1, otherwise the amount ("Add 1,000 steps").
String stepTooltip(Habit habit, {required bool adding, required String one}) {
  final step = StepSize.forTarget(habit.target);
  if (step == 1) return one;
  final amount = NumberFormat.decimalPattern().format(step);
  final units = habit.units.isEmpty ? '' : ' ${habit.units}';
  return '${adding ? 'Add' : 'Remove'} $amount$units';
}
