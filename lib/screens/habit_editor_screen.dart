import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_palette.dart';
import '../domain/entities/habit.dart';
import '../presentation/habit_form/habit_draft.dart';
import '../presentation/providers/settings_provider.dart';
import 'add_habit_screen.dart';
import 'builder_add_screen.dart';
import 'story_habit_screen.dart';

/// Adds or edits a habit in Story or Builder, switching between them at any
/// time without losing what's entered: both edit the same draft, owned here.
/// It opens in the style chosen in Settings (Story unless changed).
///
/// Adding: Story's sentence or Builder's three steps. Editing: Story's
/// sentence or the one-page form (changing one thing shouldn't take three
/// steps).
class HabitEditorScreen extends StatefulWidget {
  final Habit? editHabit;

  const HabitEditorScreen({super.key, this.editHabit});

  @override
  State<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends State<HabitEditorScreen> {
  late final HabitDraft _draft;
  late AddHabitStyle _style;

  @override
  void initState() {
    super.initState();
    _draft = HabitDraft.start(context, widget.editHabit);
    _style = context.read<SettingsProvider>().addHabitStyle;
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _switch() {
    FocusScope.of(context).unfocus();
    setState(() => _style = _style == AddHabitStyle.story ? AddHabitStyle.builder : AddHabitStyle.story);
  }

  @override
  Widget build(BuildContext context) {
    final styleSwitch = StyleSwitch(
      to: _style == AddHabitStyle.story ? AddHabitStyle.builder : AddHabitStyle.story,
      onPressed: _switch,
    );
    final habit = widget.editHabit;
    final Widget page = switch (_style) {
      AddHabitStyle.story => StoryHabitScreen(editHabit: habit, draft: _draft, styleSwitch: styleSwitch),
      AddHabitStyle.builder when habit != null =>
        AddHabitScreen(editHabit: habit, draft: _draft, styleSwitch: styleSwitch),
      AddHabitStyle.builder => BuilderAddScreen(draft: _draft, styleSwitch: styleSwitch),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(key: ValueKey(_style), child: page),
    );
  }
}

/// The small "Switch to Builder" / "Switch to Story" pill at the top of the
/// habit editor.
class StyleSwitch extends StatelessWidget {
  /// The style it switches to.
  final AddHabitStyle to;
  final VoidCallback onPressed;

  const StyleSwitch({super.key, required this.to, required this.onPressed});

  static String nameOf(AddHabitStyle style) => switch (style) {
        AddHabitStyle.story => 'Story',
        AddHabitStyle.builder => 'Builder',
      };

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final label = 'Switch to ${nameOf(to)}';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        key: const Key('switchHabitStyle'),
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        // A 44pt tap target around a small pill
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(color: palette.raised, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    to == AddHabitStyle.story ? CupertinoIcons.text_quote : CupertinoIcons.square_stack_3d_up,
                    size: 14,
                    color: palette.accent,
                  ),
                  const SizedBox(width: 5),
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
