import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_palette.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/habit_goal.dart';
import '../presentation/widgets/adaptive.dart';
import '../presentation/habit_form/habit_draft.dart';
import '../presentation/providers/settings_provider.dart';
import 'add_habit_screen.dart';
import 'builder_add_screen.dart';
import 'story_habit_screen.dart';
import '../presentation/tour/tour.dart';
import '../presentation/tour/tour_controller.dart';
import '../presentation/tour/world_scope.dart';

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
    // The first new habit, in Story, brings the editor's tour
    if (widget.editHabit == null && _style == AddHabitStyle.story && !WorldScope.isDemo(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) TourController.maybeOf(context)?.firstVisit(TourId.editor);
      });
    }
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

  /// Build or Break. Breaking works the other way round, so it's explained
  /// (and confirmed) each time it's picked.
  Future<void> _chooseGoal(bool breaking) async {
    if (breaking == _draft.isBreak) return;
    if (!breaking) return _draft.setGoal(HabitGoal.build);
    final ok = await confirmAdaptive(
      context,
      title: 'Breaking a habit',
      message: 'This works the other way round: every day without a slip counts toward your streak. '
          "The app can't tell when you slip, so log slips honestly. An evening check-in will remind you.",
      confirmLabel: 'Got it',
      confirmKey: const Key('breakGotIt'),
      cancelKey: const Key('breakCancel'),
    );
    if (ok && mounted) _draft.setGoal(HabitGoal.quit);
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.editHabit;
    final topControls = ListenableBuilder(
      listenable: _draft,
      builder: (context, _) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          // A habit's goal is set when it's added: changing it would flip
          // what its history means
          if (habit == null)
            GoalPill(breaking: _draft.isBreak, onChanged: _chooseGoal)
          else if (habit.isBreak)
            _GoalLabel(goal: habit.goal)
          else
            const SizedBox.shrink(),
          StyleSwitch(
            to: _style == AddHabitStyle.story ? AddHabitStyle.builder : AddHabitStyle.story,
            onPressed: _switch,
          ),
        ],
      ),
    );
    final Widget page = switch (_style) {
      AddHabitStyle.story => StoryHabitScreen(editHabit: habit, draft: _draft, topControls: topControls),
      AddHabitStyle.builder when habit != null =>
        AddHabitScreen(editHabit: habit, draft: _draft, topControls: topControls),
      AddHabitStyle.builder => BuilderAddScreen(draft: _draft, topControls: topControls),
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

/// Build | Break: what a new habit is for.
class GoalPill extends StatelessWidget {
  final bool breaking;
  final ValueChanged<bool> onChanged;

  const GoalPill({super.key, required this.breaking, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    Widget segment(String label, bool isBreak, Key key) {
      final selected = isBreak == breaking;
      return Semantics(
        button: true,
        selected: selected,
        label: isBreak ? 'Break a habit' : 'Build a habit',
        excludeSemantics: true,
        onTap: () => onChanged(isBreak),
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(isBreak),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              widthFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? palette.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? palette.text : palette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(color: palette.raised, borderRadius: BorderRadius.circular(17)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        segment('Build', false, const Key('habitGoalBuild')),
        segment('Break', true, const Key('habitGoalBreak')),
      ]),
    );
  }
}

/// Shows that a habit being edited is one being broken (it can't change).
class _GoalLabel extends StatelessWidget {
  final HabitGoal goal;

  const _GoalLabel({required this.goal});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      key: const Key('habitGoalLabel'),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: palette.raised, borderRadius: BorderRadius.circular(16)),
      child: Text(
        goal == HabitGoal.quit ? 'Breaking: quit' : 'Breaking: limit',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textSecondary),
      ),
    );
  }
}
