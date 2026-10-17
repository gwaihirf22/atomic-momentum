import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/exceptions/friendly_error.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/habit.dart';
import '../presentation/habit_form/habit_draft.dart';
import '../presentation/habit_form/sections.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/widgets/confirm_delete_habit.dart';
import '../presentation/widgets/orb_button.dart';
import '../presentation/widgets/unsaved_changes_guard.dart';

/// The habit form on one page: every part at once, grouped into cards.
/// Builder uses it for editing (changing one thing shouldn't take three
/// steps), and it adds a habit when opened without one.
class AddHabitScreen extends StatefulWidget {
  final Habit? editHabit;

  /// The draft to edit, when the habit editor owns it (so switching styles
  /// keeps what's entered); otherwise this screen starts its own.
  final HabitDraft? draft;

  /// The "Switch to Story" control, shown at the top.
  final Widget? styleSwitch;

  const AddHabitScreen({Key? key, this.editHabit, this.draft, this.styleSwitch}) : super(key: key);

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  late final HabitDraft _draft;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft ?? HabitDraft.start(context, widget.editHabit);
  }

  @override
  void dispose() {
    if (widget.draft == null) _draft.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final saved = await _draft.save(context.read<HabitProvider>());
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (saved) {
      // pop (not maybePop): the changes are saved, so no unsaved-changes prompt
      Navigator.of(context).pop();
    } else {
      // Stay on the form so nothing typed is lost
      showSaveError(context, _draft);
    }
  }

  Future<void> _deleteFromForm() async {
    if (await deleteHabitFromForm(context, widget.editHabit!) && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild when the appearance changes
    final palette = AppPalette.of(context);
    final title = widget.editHabit != null ? 'Edit Habit' : 'New Habit';

    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) => UnsavedChangesGuard(
        hasChanges: _draft.hasChanges,
        child: Scaffold(
          backgroundColor: palette.background,
          appBar: habitFormBar(context, title),
          body: Column(children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.styleSwitch != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Align(alignment: AlignmentDirectional.centerEnd, child: widget.styleSwitch),
                        ),
                      FormCard(children: [
                        NameField(_draft),
                        const SizedBox(height: 16),
                        TargetField(_draft),
                        const SizedBox(height: 16),
                        UnitsField(_draft),
                      ]),
                      FormCard(children: [CategoryChips(_draft)]),
                      FormCard(children: [ColorRow(_draft)]),
                      FormCard(children: [IconGrid(_draft)]),
                      FormCard(children: [ScheduleSection(_draft)]),
                      if (_draft.frequency.isPeriodic) FormCard(children: [TwoMinuteSection(_draft)]),
                      FormCard(children: [ReminderSection(_draft)]),
                      // Another way to delete, besides swiping the habit card
                      if (widget.editHabit != null)
                        Center(
                          child: TextButton.icon(
                            key: const Key('deleteHabitFromForm'),
                            onPressed: _isSubmitting ? null : _deleteFromForm,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete Habit'),
                            style: TextButton.styleFrom(
                              foregroundColor: palette.danger,
                              minimumSize: const Size(44, 44),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Pinned below the scrolling form; rides above the keyboard
            HabitFormActionBar(
              child: OrbButton(
                key: const Key('saveHabitButton'),
                label: widget.editHabit != null ? 'Save Changes' : 'Add Habit',
                busy: _isSubmitting,
                onPressed: _submitForm,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A habit form's navigation bar: the title and a Cancel that asks before
/// discarding changes (iOS), or a Material app bar.
PreferredSizeWidget habitFormBar(BuildContext context, String title, {Widget? trailing}) {
  final palette = AppPalette.of(context);
  if (!isCupertino(context)) {
    return AppBar(title: Text(title), centerTitle: true, actions: [if (trailing != null) trailing]);
  }
  return CupertinoNavigationBar(
    backgroundColor: palette.background,
    border: null,
    middle: Text(title),
    // maybePop, so unsaved changes are confirmed first
    leading: CupertinoButton(
      key: const Key('cancelHabitForm'),
      padding: EdgeInsets.zero,
      onPressed: () => Navigator.of(context).maybePop(),
      child: const Text('Cancel'),
    ),
    trailing: trailing,
  );
}

/// A group of form parts on a card, as Settings groups its rows.
class FormCard extends StatelessWidget {
  final List<Widget> children;

  const FormCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: AppPalette.of(context).surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// The bar pinned to the bottom of a habit form, holding its main button so
/// it's reachable without scrolling.
class HabitFormActionBar extends StatelessWidget {
  final Widget child;

  const HabitFormActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('habitActionBar'),
      color: AppPalette.of(context).background,
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 12), child: child),
      ),
    );
  }
}

/// Says why a habit couldn't be saved.
void showSaveError(BuildContext context, HabitDraft draft) {
  final name = draft.name.text.trim();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(friendlyError(
        draft.saveError,
        fallback: "Couldn't save${name.isEmpty ? ' this habit' : ' "$name"'}. Please try again.",
      )),
    ),
  );
}

/// Asks, then deletes [habit]; true once it's gone.
Future<bool> deleteHabitFromForm(BuildContext context, Habit habit) async {
  if (!await confirmDeleteHabit(context, habit.name) || !context.mounted) return false;
  if (await context.read<HabitProvider>().deleteHabit(habit.id)) return true;
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Couldn't delete \"${habit.name}\". Please try again.")),
    );
  }
  return false;
}
