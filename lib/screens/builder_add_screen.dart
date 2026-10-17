import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../presentation/habit_form/habit_draft.dart';
import '../presentation/habit_form/quick_picks.dart';
import '../presentation/habit_form/sections.dart';
import '../presentation/habit_form/sentence.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/orb_button.dart';
import '../presentation/widgets/unsaved_changes_guard.dart';
import 'add_habit_screen.dart';

/// Builder: a new habit in three quick steps (what, how often, make it
/// easy), from the Charged design. Editing uses the one-page form.
class BuilderAddScreen extends StatefulWidget {
  /// The draft to fill, when the habit editor owns it (so switching styles
  /// keeps what's entered); otherwise this screen starts its own.
  final HabitDraft? draft;

  /// The editor's controls (Build | Break, Switch to Story/Builder), shown
  /// at the top.
  final Widget? topControls;

  const BuilderAddScreen({super.key, this.draft, this.topControls});

  static const stepCount = 3;

  @override
  State<BuilderAddScreen> createState() => _BuilderAddScreenState();
}

class _BuilderAddScreenState extends State<BuilderAddScreen> {
  static const _titles = ["What's the habit?", 'How often?', 'Make it easy'];
  static const _subtitles = [
    'Small and specific works best.',
    'Pick an amount that feels easy to keep.',
    'A tiny version for hard days, and a nudge at the right time.',
  ];
  static const _nextLabels = ['Next: how often', 'Next: make it easy'];

  // Breaking a habit
  static const _breakTitles = ['What do you want to break?', 'How strict?', 'Stay honest'];
  static const _breakSubtitles = [
    'Name the habit you want less of.',
    'Quit it, or keep it under a limit.',
    "The app can't tell when you slip, so a check-in helps you log it.",
  ];
  static const _breakNextLabels = ['Next: how strict', 'Next: stay honest'];

  List<String> get _stepTitles => _draft.isBreak ? _breakTitles : _titles;
  List<String> get _stepSubtitles => _draft.isBreak ? _breakSubtitles : _subtitles;
  List<String> get _stepNextLabels => _draft.isBreak ? _breakNextLabels : _nextLabels;

  late final HabitDraft _draft;
  final _formKeys = [for (var i = 0; i < BuilderAddScreen.stepCount; i++) GlobalKey<FormState>()];
  final _scroll = ScrollController();
  int _step = 0;
  bool _saving = false;

  /// Whether this step has been seen to its end. Until then the button is
  /// dimmed and its first tap scrolls down, so nothing below is skipped by
  /// accident on a small screen.
  bool _seenAll = false;

  bool get _isLast => _step == BuilderAddScreen.stepCount - 1;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft ?? HabitDraft.start(context, null);
    _scroll.addListener(_checkSeenAll);
  }

  void _checkSeenAll() {
    if (_seenAll || !_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 24) setState(() => _seenAll = true);
  }

  @override
  void dispose() {
    if (widget.draft == null) _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _seenAll = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _next() async {
    if (!_seenAll && _scroll.hasClients) {
      // First tap: show the rest of the step
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
      if (mounted) setState(() => _seenAll = true);
      return;
    }
    if (!_formKeys[_step].currentState!.validate()) {
      // The fields that need fixing are near the top of each step
      if (_scroll.hasClients) {
        await _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      return;
    }
    if (!_isLast) return _goTo(_step + 1);

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

  /// Leaves, first asking about anything entered.
  Future<void> _close() async {
    if (!_draft.hasChanges || await confirmDiscardChanges(context)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild when the appearance changes
    // A step that fits on screen (or grew shorter) is seen at once
    if (!_seenAll) WidgetsBinding.instance.addPostFrameCallback((_) => _checkSeenAll());
    final palette = AppPalette.of(context);

    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) => PopScope<Object?>(
        // Back steps back; on the first step it leaves (asking about changes)
        canPop: _step == 0 && !_draft.hasChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _step > 0 ? _goTo(_step - 1) : _close();
        },
        child: Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(palette),
                Expanded(
                  child: Form(
                    key: _formKeys[_step],
                    child: SingleChildScrollView(
                      key: ValueKey('builderStep_$_step'),
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.topControls != null)
                            Padding(padding: const EdgeInsets.only(bottom: 10), child: widget.topControls),
                          Semantics(
                            header: true,
                            child: Text(
                              _stepTitles[_step],
                              key: const Key('builderStepTitle'),
                              style: TextStyle(
                                fontFamily: LargeTitleHeader.fontFamily,
                                fontSize: 30,
                                height: 1.12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                                color: palette.text,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_stepSubtitles[_step], style: TextStyle(fontSize: 15, color: palette.textSecondary)),
                          const SizedBox(height: 22),
                          ...switch (_step) {
                            0 => _whatStep(),
                            1 => _draft.isBreak
                                ? [FormCard(children: [StrictnessSection(_draft, showHeader: false)])]
                                : _howOftenStep(palette),
                            _ => _makeItEasyStep(),
                          },
                          _ahead(palette),
                        ],
                      ),
                    ),
                  ),
                ),
                HabitFormActionBar(
                  child: OrbButton(
                    key: Key(_isLast ? 'saveHabitButton' : 'builderNext'),
                    label: _isLast ? 'Add Habit' : _stepNextLabels[_step],
                    showArrow: !_isLast,
                    busy: _saving,
                    dimmed: !_seenAll,
                    hint: _seenAll ? null : 'Shows the rest of this step first',
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Close, back (after the first step), the progress bar and "1 of 3".
  Widget _header(AppPalette palette) {
    Widget roundButton({required Key key, required IconData icon, required String label, required VoidCallback onTap}) =>
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          onTap: onTap,
          child: GestureDetector(
            key: key,
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: palette.raised, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: palette.text),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 0),
      child: Row(
        children: [
          roundButton(key: const Key('cancelHabitForm'), icon: CupertinoIcons.xmark, label: 'Close', onTap: _close),
          if (_step > 0) ...[
            const SizedBox(width: 8),
            roundButton(
              key: const Key('builderBack'),
              icon: CupertinoIcons.chevron_left,
              label: 'Back',
              onTap: () => _goTo(_step - 1),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              key: const Key('builderProgress'),
              label: 'Step ${_step + 1} of ${BuilderAddScreen.stepCount}',
              excludeSemantics: true,
              child: Row(
                children: [
                  for (var i = 0; i < BuilderAddScreen.stepCount; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i <= _step ? null : palette.track,
                          gradient: i <= _step ? palette.orb : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ExcludeSemantics(
            child: Text(
              '${_step + 1} of ${BuilderAddScreen.stepCount}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _whatStep() {
    final activeIds = context.read<CategoryProvider>().categories.map((c) => c.id);
    return [
      NameField(_draft, prominent: true),
      const SizedBox(height: 22),
      const FormSectionHeader('Quick picks'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final pick in _draft.isBreak ? QuickPick.breaking : QuickPick.all)
            ChoiceChip(
              key: Key('quickPick_${pick.name}'),
              label: Text(pick.name),
              selected: pick.isChosenIn(_draft),
              onSelected: (_) => pick.applyTo(_draft, activeIds),
            ),
        ],
      ),
      const SizedBox(height: 22),
      IconGrid(_draft, limit: 10, onMore: _showAllIcons),
      const SizedBox(height: 22),
      ColorRow(_draft),
      const SizedBox(height: 22),
      CategoryChips(_draft),
    ];
  }

  Future<void> _showAllIcons() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IconGrid(_draft),
                const SizedBox(height: 16),
                OrbButton(key: const Key('iconSheetDone'), label: 'Done', onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ),
      );

  List<Widget> _howOftenStep(AppPalette palette) {
    final summary = HabitSentence.howOften(_draft);
    return [
      FormCard(children: [
        AmountFields(_draft),
        if (_draft.enteredTarget != null && _draft.targetError == null) ...[
          const SizedBox(height: 10),
          Text(
            // "8 glasses every day"
            summary[0].toUpperCase() + summary.substring(1),
            key: const Key('builderAmountSummary'),
            style: TextStyle(fontFamily: LargeTitleHeader.fontFamily, fontSize: 17, fontWeight: FontWeight.w600, color: palette.text),
          ),
        ],
      ]),
      FormCard(children: [ScheduleSection(_draft)]),
    ];
  }

  List<Widget> _makeItEasyStep() => [
        if (_draft.frequency.isPeriodic && !_draft.isBreak) FormCard(children: [TwoMinuteSection(_draft)]),
        FormCard(children: [ReminderSection(_draft)]),
      ];

  /// What the next steps hold, filled in from what's chosen so far.
  Widget _ahead(AppPalette palette) {
    final upcoming = <(int, String)>[
      if (_draft.isBreak) ...[
        if (_step < 1) (2, 'How strict: ${HabitSentence.strictness(_draft)}'),
        if (_step < 2) (3, 'Stay honest: an evening check-in'),
      ] else ...[
        if (_step < 1)
          (2, 'How often: ${_draft.enteredTarget == null ? 'how much, and which days' : HabitSentence.howOften(_draft)}'),
        if (_step < 2) (3, 'Make it easy: two-minute version and reminder'),
      ],
    ];
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('builderAhead'),
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(AppStyle.cardRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (number, text) in upcoming)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text('$number', style: TextStyle(fontWeight: FontWeight.w700, color: palette.accent)),
                  ),
                  Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: palette.textSecondary))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
