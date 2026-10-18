import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/habit.dart';
import '../domain/entities/habit_goal.dart';
import '../domain/entities/reminder_settings.dart';
import '../presentation/habit_form/habit_draft.dart';
import '../presentation/help/explainers.dart';
import '../presentation/habit_form/sections.dart';
import '../presentation/habit_form/sentence.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/widgets/adaptive.dart';
import '../presentation/widgets/category_icons.dart';
import '../presentation/widgets/habit_icons.dart';
import '../presentation/widgets/info_button.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/orb_button.dart';
import '../presentation/widgets/unsaved_changes_guard.dart';
import 'add_habit_screen.dart';

/// The parts of the Story sentence that open a sheet.
enum StoryPart { name, amount, schedule, reminder, tiny, strictness }

/// Story: a habit written as one sentence, from the Calm design. "I will
/// [drink water] [8 glasses] [every day], [reminded at 9:00 AM]. On a hard
/// day, I'll just [fill one glass]." Tap any underlined part to change it.
/// Used for adding and editing.
class StoryHabitScreen extends StatefulWidget {
  final Habit? editHabit;

  /// The draft to edit, when the habit editor owns it (so switching styles
  /// keeps what's entered); otherwise this screen starts its own.
  final HabitDraft? draft;

  /// The editor's controls (Build | Break, Switch to Story/Builder), shown
  /// at the top.
  final Widget? topControls;

  const StoryHabitScreen({super.key, this.editHabit, this.draft, this.topControls});

  @override
  State<StoryHabitScreen> createState() => _StoryHabitScreenState();
}

class _StoryHabitScreenState extends State<StoryHabitScreen> {
  late final HabitDraft _draft;
  bool _saving = false;

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

  /// The first part that needs fixing before saving, if any.
  StoryPart? get _firstProblem {
    if (_draft.nameError != null) return StoryPart.name;
    if (_draft.targetError != null || _draft.unitsError != null) return StoryPart.amount;
    if (_draft.minimumError != null) return StoryPart.tiny;
    return null;
  }

  Future<void> _save() async {
    final problem = _firstProblem;
    if (problem != null) return _openPart(problem, showErrors: true);

    setState(() => _saving = true);
    final saved = await _draft.save(context.read<HabitProvider>());
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      Navigator.of(context).pop();
    } else {
      showSaveError(context, _draft);
    }
  }

  Future<void> _delete() async {
    if (await deleteHabitFromForm(context, widget.editHabit!) && mounted) Navigator.of(context).pop();
  }

  /// Opens the sheet for one part of the sentence, bound to the same draft.
  /// With [showErrors], its fields say what's wrong straight away.
  Future<void> _openPart(StoryPart part, {bool showErrors = false}) {
    final (title, content) = switch (part) {
      StoryPart.name => ('The habit', <Widget>[NameField(_draft, autofocus: !showErrors), const SizedBox(height: 18), IconGrid(_draft)]),
      // A habit being broken: quit or limit, its amount and period, in one place
      StoryPart.amount || StoryPart.schedule || StoryPart.strictness when _draft.isBreak =>
        ('How strict', <Widget>[StrictnessSection(_draft, showHeader: false)]),
      StoryPart.strictness => ('How strict', <Widget>[StrictnessSection(_draft, showHeader: false)]),
      StoryPart.amount => ('How much', <Widget>[AmountFields(_draft)]),
      StoryPart.schedule => ('How often', <Widget>[ScheduleSection(_draft, showHeader: false)]),
      StoryPart.reminder =>
        (_draft.isBreak ? 'Check-in' : 'Reminder', <Widget>[ReminderSection(_draft, showHeader: false)]),
      StoryPart.tiny => ('On a hard day', <Widget>[TwoMinuteSection(_draft, showHeader: false, autofocus: !showErrors)]),
    };
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppPalette.of(context).surface,
      builder: (context) => _PartSheet(
        key: Key('storySheet_${part.name}'),
        title: title,
        showErrors: showErrors,
        titleTrailing: part == StoryPart.tiny
            ? InfoButton(topic: InfoTopic.twoMinute, example: twoMinuteExample(_draft))
            : null,
        children: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild when the appearance changes
    final palette = AppPalette.of(context);
    final editing = widget.editHabit != null;

    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) => UnsavedChangesGuard(
        hasChanges: _draft.hasChanges,
        child: Scaffold(
          backgroundColor: palette.background,
          appBar: habitFormBar(context, editing ? 'Edit Habit' : 'New Habit'),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.topControls != null) ...[widget.topControls!, const SizedBox(height: 10)],
                      Text('Tap any underlined part to change it.',
                          style: TextStyle(fontSize: 13, color: palette.textSecondary)),
                      const SizedBox(height: 18),
                      _StorySentence(draft: _draft, onTap: _openPart),
                      const SizedBox(height: 26),
                      _details(palette),
                      if (editing)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Center(
                            child: TextButton.icon(
                              key: const Key('deleteHabitFromForm'),
                              onPressed: _saving ? null : _delete,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete Habit'),
                              style: TextButton.styleFrom(
                                foregroundColor: palette.danger,
                                minimumSize: const Size(44, 44),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              HabitFormActionBar(
                child: OrbButton(
                  key: const Key('saveHabitButton'),
                  label: editing ? 'Save Changes' : 'Add Habit',
                  busy: _saving,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Color, category and reminder days: the parts that aren't words.
  Widget _details(AppPalette palette) {
    final categories = context.watch<CategoryProvider>();
    final category = categories.resolve(_draft.categoryId);
    final reminderDays = !_draft.reminderEnabled
        ? 'Off'
        : _draft.reminderMode == ReminderMode.smart
            ? 'Smart'
            : _draft.reminderDays.isEmpty
                ? 'None'
                : HabitSentence.dayList(List.of(_draft.reminderDays)..sort());

    Widget row({required Key key, required String title, required Widget value, VoidCallback? onTap}) => InkWell(
          key: key,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: TextStyle(fontSize: 16, color: palette.text))),
                  const SizedBox(width: 12),
                  Flexible(child: value),
                  if (onTap != null) ...[
                    const SizedBox(width: 6),
                    Icon(CupertinoIcons.chevron_right, size: 15, color: palette.textSecondary),
                  ],
                ],
              ),
            ),
          ),
        );

    Widget valueText(String text) =>
        Text(text, textAlign: TextAlign.end, style: TextStyle(fontSize: 16, color: palette.textSecondary));

    return Container(
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: ColorRow(_draft),
            ),
            Divider(height: 1, indent: 16, color: palette.separator),
            row(
              key: const Key('storyCategory'),
              title: 'Category',
              value: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category.icon, size: 17, color: palette.habitColor(category.color)),
                  const SizedBox(width: 6),
                  Flexible(child: valueText(category.name)),
                ],
              ),
              onTap: () async {
                final id = await chooseAdaptive<String>(
                  context,
                  title: 'Category',
                  selected: _draft.categoryId,
                  options: [
                    for (final c in categories.categories) AdaptiveOption(c.id, c.name, key: Key('storyCategory_${c.id}')),
                  ],
                );
                if (id != null) _draft.edit(() => _draft.categoryId = id);
              },
            ),
            Divider(height: 1, indent: 16, color: palette.separator),
            row(
              key: const Key('storyReminderDays'),
              title: 'Reminder days',
              value: valueText(reminderDays),
              onTap: () => _openPart(StoryPart.reminder),
            ),
          ],
        ),
      ),
    );
  }
}

/// The habit as a sentence, each changeable part a tappable token.
class _StorySentence extends StatelessWidget {
  final HabitDraft draft;
  final void Function(StoryPart part) onTap;

  const _StorySentence({required this.draft, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = MaterialLocalizations.of(context);
    final textStyle = TextStyle(
      fontFamily: LargeTitleHeader.fontFamily,
      fontSize: 25,
      height: 1.6,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.2,
      color: palette.text,
    );
    final color = palette.habitColor(draft.color.color);

    InlineSpan token(StoryPart part, String text, {String? placeholder, IconData? icon, bool accent = false}) =>
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _Token(
            key: Key('story${part.name[0].toUpperCase()}${part.name.substring(1)}'),
            text: text.isEmpty ? placeholder! : text,
            empty: text.isEmpty,
            icon: icon,
            color: accent ? color : palette.text,
            fill: accent ? palette.tint(draft.color.color) : palette.surface,
            style: textStyle,
            semanticsPart: switch (part) {
              StoryPart.name => 'Habit',
              StoryPart.amount => 'How much',
              StoryPart.schedule => 'How often',
              StoryPart.reminder => draft.isBreak ? 'Check-in' : 'Reminder',
              StoryPart.tiny => 'On a hard day',
              StoryPart.strictness => 'How strict',
            },
            onTap: () => onTap(part),
          ),
        );

    if (draft.isBreak) return _breakSentence(token, textStyle, localizations);
    final tiny = draft.tiny.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          key: const Key('storySentence'),
          TextSpan(style: textStyle, children: [
            const TextSpan(text: 'I will '),
            token(StoryPart.name, HabitSentence.name(draft.name.text),
                placeholder: 'name your habit', icon: HabitIcons.of(draft.icon), accent: true),
            const TextSpan(text: ' '),
            token(StoryPart.amount, HabitSentence.amount(draft.enteredTarget, draft.units.text),
                placeholder: 'how much'),
            const TextSpan(text: ' '),
            token(StoryPart.schedule, HabitSentence.schedule(draft.schedule)),
            const TextSpan(text: ', '),
            token(StoryPart.reminder, HabitSentence.reminderOf(draft, localizations.formatTimeOfDay)),
            const TextSpan(text: '.'),
          ]),
        ),
        // Habits that never reset have no streak, so no two-minute version
        if (draft.frequency.isPeriodic) ...[
          const SizedBox(height: 22),
          Text.rich(
            key: const Key('storyHardDay'),
            TextSpan(
              style: textStyle.copyWith(fontSize: 20, color: palette.textSecondary),
              children: [
                const TextSpan(text: "On a hard day, I'll just "),
                token(StoryPart.tiny, tiny.isEmpty ? '' : tiny[0].toLowerCase() + tiny.substring(1),
                    placeholder: 'add a tiny version'),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// "I will quit [smoking], checking in at [9:00 PM]." or "I will keep
  /// [alcohol] to [2 drinks] [a day], checking in at [9:00 PM]."
  Widget _breakSentence(
    InlineSpan Function(StoryPart, String, {String? placeholder, IconData? icon, bool accent}) token,
    TextStyle textStyle,
    MaterialLocalizations localizations,
  ) {
    final limit = draft.goal == HabitGoal.limit;
    return Text.rich(
      key: const Key('storySentence'),
      TextSpan(style: textStyle, children: [
        const TextSpan(text: 'I will '),
        token(StoryPart.strictness, HabitSentence.breakVerb(draft.goal)),
        const TextSpan(text: ' '),
        token(StoryPart.name, HabitSentence.name(draft.name.text),
            placeholder: 'name the habit', icon: HabitIcons.of(draft.icon), accent: true),
        if (limit) ...[
          const TextSpan(text: ' to '),
          token(StoryPart.amount, HabitSentence.amount(draft.enteredTarget, draft.units.text), placeholder: 'how much'),
          const TextSpan(text: ' '),
          token(StoryPart.schedule, HabitSentence.perPeriod(draft.frequency)),
        ],
        const TextSpan(text: ', '),
        token(StoryPart.reminder, HabitSentence.checkInOf(draft, localizations.formatTimeOfDay)),
        const TextSpan(text: '.'),
      ]),
    );
  }
}

/// One changeable part of the sentence: underlined, at least 44pt tall, and
/// wrapping inside itself when it's long.
class _Token extends StatelessWidget {
  final String text;
  final bool empty;
  final IconData? icon;
  final Color color;
  final Color fill;
  final TextStyle style;
  final String semanticsPart;
  final VoidCallback onTap;

  const _Token({
    super.key,
    required this.text,
    required this.empty,
    required this.icon,
    required this.color,
    required this.fill,
    required this.style,
    required this.semanticsPart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final ink = empty ? palette.textSecondary : color;
    return Semantics(
      button: true,
      label: '$semanticsPart: ${empty ? 'not set' : text}',
      hint: 'Change',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: empty ? Colors.transparent : fill,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9), bottom: Radius.circular(3)),
              border: empty
                  ? Border.all(color: palette.textSecondary.withValues(alpha: 0.6), width: 1.2)
                  : Border(bottom: BorderSide(color: ink, width: 2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null && !empty) ...[
                  Icon(icon, size: (style.fontSize ?? 25) * 0.7, color: ink),
                  const SizedBox(width: 5),
                ],
                Flexible(child: Text(text, style: style.copyWith(color: ink, height: 1.3))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A sheet for one part of the sentence, with Done.
class _PartSheet extends StatefulWidget {
  final String title;
  final bool showErrors;
  final List<Widget> children;

  /// Shown after the title, such as an (i).
  final Widget? titleTrailing;

  const _PartSheet({
    super.key,
    required this.title,
    required this.showErrors,
    required this.children,
    this.titleTrailing,
  });

  @override
  State<_PartSheet> createState() => _PartSheetState();
}

class _PartSheetState extends State<_PartSheet> {
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.showErrors) WidgetsBinding.instance.addPostFrameCallback((_) => _form.currentState?.validate());
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      // Rides above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _form,
            autovalidateMode: widget.showErrors ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontFamily: LargeTitleHeader.fontFamily,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                    ),
                  ),
                  if (widget.titleTrailing != null) widget.titleTrailing!,
                ]),
                const SizedBox(height: 14),
                ...widget.children,
                const SizedBox(height: 18),
                OrbButton(
                  key: const Key('storySheetDone'),
                  label: 'Done',
                  onPressed: () {
                    // Close only once what's here is right
                    if (_form.currentState!.validate()) Navigator.of(context).pop();
                  },
                ),
                SizedBox(height: AppStyle.cardGap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
