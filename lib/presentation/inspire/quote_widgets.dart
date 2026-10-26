import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/copy/quotes.dart';
import '../../core/feedback/haptics.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/quote.dart';
import '../providers/habit_provider.dart';
import '../providers/quote_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/adaptive.dart';
import '../widgets/large_title_scaffold.dart';
import '../widgets/orb_button.dart';
import '../widgets/settings_list.dart';
import '../widgets/unsaved_changes_guard.dart';
import '../layout/app_layout.dart';

/// "— Epictetus" with the source under it, as quotes are signed everywhere.
class QuoteByline extends StatelessWidget {
  final Quote quote;
  final double size;
  final TextAlign align;

  const QuoteByline(this.quote, {super.key, this.size = 15, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final crossAxis = align == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: crossAxis,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (quote.author.isNotEmpty)
          Text(
            '— ${quote.author}',
            textAlign: align,
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: palette.text),
          ),
        if (quote.source.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              quote.source,
              textAlign: align,
              style: TextStyle(fontSize: size - 2, color: palette.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// A quote in a list: its words, then who said it. Tap to open it.
class QuoteTile extends StatelessWidget {
  final Quote quote;
  final VoidCallback onTap;
  final Widget? trailing;

  const QuoteTile({super.key, required this.quote, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('quote_${quote.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.text,
                      style: TextStyle(
                        fontFamily: LargeTitleHeader.fontFamily,
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    QuoteByline(quote, size: 13),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// The quote with its text and source, ready to paste.
String quoteToCopy(Quote quote) => [
      '"${quote.text}"',
      // Verses carry their translation, as its copyright notice asks
      if (quote.source == Quotes.nkjv)
        '— ${quote.author} (NKJV)'
      else if (quote.author.isNotEmpty)
        '— ${quote.author}${quote.source.isNotEmpty ? ', ${quote.source}' : ''}',
    ].join('\n');

Future<void> copyQuote(BuildContext context, Quote quote) async {
  await Clipboard.setData(ClipboardData(text: quoteToCopy(quote)));
  Haptics.selection();
  if (context.mounted) _snack(context, 'Copied');
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}

/// Saves the quote, or unsaves it.
Future<void> toggleSavedQuote(BuildContext context, Quote quote) async {
  final quotes = context.read<QuoteProvider>();
  final save = !quotes.isSaved(quote.id);
  Haptics.selection();
  final ok = await quotes.setSaved(quote.id, save);
  if (!context.mounted) return;
  if (!ok) _snack(context, quotes.error ?? 'Could not save that');
}

/// Asks which habit to keep the quote with, and adds it there.
Future<void> addQuoteToHabit(BuildContext context, Quote quote) async {
  final habitProvider = context.read<HabitProvider>();
  final habits = habitProvider.habits;
  if (habits.isEmpty) {
    _snack(context, 'Add a habit first');
    return;
  }
  final habit = await chooseAdaptive<Habit>(
    context,
    title: 'Keep with a habit',
    message: 'It shows on the habit\'s page.',
    options: [
      for (final h in habits)
        AdaptiveOption(
          h,
          h.name,
          key: Key('quoteHabit_${h.id}'),
          subtitle: h.quoteIds.contains(quote.id) ? 'Already there' : null,
        ),
    ],
  );
  if (habit == null || !context.mounted) return;
  if (habit.quoteIds.contains(quote.id)) {
    _snack(context, 'Already with ${habit.name}');
    return;
  }
  final ok = await habitProvider.addQuote(habit.id, quote.id);
  if (!context.mounted) return;
  _snack(context, ok ? 'Added to ${habit.name}' : (habitProvider.error ?? 'Could not add it'));
}

/// Deletes one of the person's own quotes (after asking), also taking it
/// off any habit that kept it. True if deleted.
Future<bool> deleteMyQuote(BuildContext context, Quote quote) async {
  final confirmed = await confirmAdaptive(
    context,
    title: 'Delete this quote?',
    message: 'It comes off any habit it\'s kept with.',
    confirmLabel: 'Delete',
    destructive: true,
    confirmKey: const Key('confirmDeleteQuote'),
  );
  if (!confirmed || !context.mounted) return false;
  final habitProvider = context.read<HabitProvider>();
  final quotes = context.read<QuoteProvider>();
  final ok = await quotes.deleteMine(quote.id);
  if (!ok) {
    if (context.mounted) _snack(context, quotes.error ?? 'Could not delete it');
    return false;
  }
  for (final habit in habitProvider.habits.where((h) => h.quoteIds.contains(quote.id)).toList()) {
    await habitProvider.removeQuote(habit.id, quote.id);
  }
  return true;
}

/// One quote, large, with what can be done with it: save, keep with a
/// habit, copy, and for the person's own, edit or delete.
Future<void> showQuoteSheet(BuildContext context, Quote quote) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).surface,
    builder: (_) => QuoteSheet(quoteId: quote.id),
  );
}

class QuoteSheet extends StatelessWidget {
  final String quoteId;

  const QuoteSheet({super.key, required this.quoteId});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final quotes = context.watch<QuoteProvider>();
    final quote = quotes.find(quoteId);
    if (quote == null) return const SizedBox(height: 120);
    final saved = quotes.isSaved(quote.id);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              quote.text,
              key: const Key('quoteSheetText'),
              style: TextStyle(
                fontFamily: LargeTitleHeader.fontFamily,
                fontSize: 21,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 12),
            QuoteByline(quote),
            const SizedBox(height: 20),
            QuoteActions(quote: quote, saved: saved),
            if (quote.isMine) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: const Key('quoteSheetEdit'),
                    onPressed: () => showMyQuoteSheet(context, editing: quote),
                    icon: const Icon(CupertinoIcons.pencil, size: 18),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(foregroundColor: palette.text, minimumSize: const Size(44, 44)),
                  ),
                  TextButton.icon(
                    key: const Key('quoteSheetDelete'),
                    onPressed: () async {
                      if (await deleteMyQuote(context, quote) && context.mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(CupertinoIcons.delete, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(foregroundColor: palette.danger, minimumSize: const Size(44, 44)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Save, keep with a habit and copy: three quiet round buttons with labels.
class QuoteActions extends StatelessWidget {
  final Quote quote;
  final bool saved;

  const QuoteActions({super.key, required this.quote, required this.saved});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 12,
      children: [
        _QuoteAction(
          key: const Key('quoteSave'),
          icon: saved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
          label: saved ? 'Saved' : 'Save',
          semanticsLabel: saved ? 'Saved. Tap to unsave' : 'Save quote',
          highlighted: saved,
          onTap: () => toggleSavedQuote(context, quote),
        ),
        _QuoteAction(
          key: const Key('quoteAddToHabit'),
          icon: CupertinoIcons.plus_circle,
          label: 'Add to habit',
          onTap: () => addQuoteToHabit(context, quote),
        ),
        _QuoteAction(
          key: const Key('quoteCopy'),
          icon: CupertinoIcons.doc_on_doc,
          label: 'Copy',
          semanticsLabel: 'Copy quote',
          onTap: () => copyQuote(context, quote),
        ),
      ],
    );
  }
}

class _QuoteAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? semanticsLabel;
  final bool highlighted;
  final VoidCallback onTap;

  const _QuoteAction({
    super.key,
    required this.icon,
    required this.label,
    this.semanticsLabel,
    this.highlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: palette.raised, shape: BoxShape.circle),
                  child: Icon(icon, size: 21, color: highlighted ? palette.accent : palette.text),
                ),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: palette.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Adds a quote of the person's own, or edits one ([editing]). Returns the
/// quote saved, or null if dismissed.
Future<Quote?> showMyQuoteSheet(BuildContext context, {Quote? editing}) {
  return showModalBottomSheet<Quote>(
    context: context,
    isScrollControlled: true,
    // Below the notch, so the Back button can be reached
    useSafeArea: true,
    // A drag would close it without asking about a quote half typed; Back
    // and tapping outside do ask
    enableDrag: false,
    backgroundColor: AppPalette.of(context).surface,
    builder: (_) => MyQuoteSheet(editing: editing),
  );
}

class MyQuoteSheet extends StatefulWidget {
  final Quote? editing;

  const MyQuoteSheet({super.key, this.editing});

  @override
  State<MyQuoteSheet> createState() => _MyQuoteSheetState();
}

class _MyQuoteSheetState extends State<MyQuoteSheet> {
  late final _text = TextEditingController(text: widget.editing?.text ?? '');
  late final _author = TextEditingController(text: widget.editing?.author ?? '');
  late final _source = TextEditingController(text: widget.editing?.source ?? '');
  late QuoteFamily _family = widget.editing?.family ?? QuoteFamily.mine;
  late final Set<QuoteTheme> _themes = {...?widget.editing?.themes};
  final _authorFocus = FocusNode();
  String? _error;
  bool _saving = false;

  bool get _hasChanges {
    final editing = widget.editing;
    return _text.text != (editing?.text ?? '') ||
        _author.text != (editing?.author ?? '') ||
        _source.text != (editing?.source ?? '') ||
        _family != (editing?.family ?? QuoteFamily.mine) ||
        !setEquals(_themes, {...?editing?.themes});
  }

  @override
  void initState() {
    super.initState();
    // Rebuilds, so leaving asks once something's typed
    for (final controller in [_text, _author, _source]) {
      controller.addListener(_onEdited);
    }
  }

  void _onEdited() => setState(() {});

  @override
  void dispose() {
    _text.dispose();
    _author.dispose();
    _source.dispose();
    _authorFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) return setState(() => _error = 'Type the quote');
    setState(() => _saving = true);
    final quotes = context.read<QuoteProvider>();
    final editing = widget.editing;
    Quote? saved;
    if (editing == null) {
      saved = await quotes.addMine(
        text: _text.text,
        author: _author.text,
        source: _source.text,
        family: _family,
        themes: _themes,
      );
    } else if (await quotes.updateMine(editing.copyWith(
      text: _text.text,
      author: _author.text,
      source: _source.text,
      family: _family,
      themes: {..._themes},
    ))) {
      saved = quotes.find(editing.id);
    }
    if (!mounted) return;
    if (saved == null) {
      setState(() {
        _saving = false;
        _error = quotes.error ?? 'Could not save it';
      });
      return;
    }
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final authors = context.read<QuoteProvider>().authors;
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.textSecondary)),
        );

    return UnsavedChangesGuard(
      hasChanges: _hasChanges && !_saving,
      child: Padding(
        // Rides above the keyboard
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Back',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: const Key('myQuoteBack'),
                        // maybePop, so a quote half typed is confirmed first
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: palette.raised, shape: BoxShape.circle),
                          child: Icon(CupertinoIcons.chevron_left, size: 20, color: palette.text),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          widget.editing == null ? 'Add a quote' : 'Edit quote',
                          style: TextStyle(
                            fontFamily: LargeTitleHeader.fontFamily,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),
                Text(
                  'From a book you love, a friend, anywhere. Only you see it.',
                  style: TextStyle(fontSize: 14, color: palette.textSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('myQuoteText'),
                  controller: _text,
                  autofocus: widget.editing == null,
                  maxLength: Quote.maxTextLength,
                  minLines: 3,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: 'Quote', errorText: _error, errorMaxLines: 2),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 8),
                // Names already in the library are offered, so quotes by one
                // author find each other
                RawAutocomplete<String>(
                  textEditingController: _author,
                  focusNode: _authorFocus,
                  optionsBuilder: (value) {
                    final typed = value.text.trim().toLowerCase();
                    if (typed.isEmpty) return const [];
                    return authors.where((a) => a.toLowerCase().contains(typed) && a.toLowerCase() != typed).take(5);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
                    key: const Key('myQuoteAuthor'),
                    controller: controller,
                    focusNode: focusNode,
                    maxLength: Quote.maxAuthorLength,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Who said it (optional)'),
                  ),
                  optionsViewBuilder: (context, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: palette.raised,
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: [
                            for (final name in options)
                              InkWell(
                                key: Key('authorSuggestion_$name'),
                                onTap: () => onSelected(name),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Text(name, style: TextStyle(fontSize: 15, color: palette.text)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('myQuoteSource'),
                  controller: _source,
                  maxLength: Quote.maxSourceLength,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Where it\'s from (optional)', hintText: 'A book, a talk…'),
                ),
                label('FILE UNDER'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final family in QuoteFamily.values)
                      QuoteChoiceChip(
                        key: Key('myQuoteFamily_${family.name}'),
                        label: family.label,
                        selected: _family == family,
                        onTap: () => setState(() => _family = family),
                      ),
                  ],
                ),
                label('THEMES'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final theme in QuoteTheme.values)
                      QuoteChoiceChip(
                        key: Key('myQuoteTheme_${theme.name}'),
                        label: theme.label,
                        selected: _themes.contains(theme),
                        onTap: () =>
                            setState(() => _themes.contains(theme) ? _themes.remove(theme) : _themes.add(theme)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                OrbButton(
                    key: const Key('myQuoteSave'), label: 'Save', busy: _saving, onPressed: _saving ? null : _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded choice: filled when chosen. [count] shows after the label.
class QuoteChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int? count;
  final VoidCallback? onTap;

  const QuoteChoiceChip({super.key, required this.label, required this.selected, this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final foreground = selected ? palette.onAccent : palette.text;
    return Semantics(
      button: true,
      selected: selected,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: selected ? palette.accent : palette.raised,
          disabledForegroundColor: palette.textSecondary,
          minimumSize: const Size(44, 36),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: label),
            if (count != null)
              TextSpan(
                text: '  $count',
                style: TextStyle(fontWeight: FontWeight.w500, color: foreground.withValues(alpha: 0.7)),
              ),
          ]),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Switches for each quote source; the last one on can't be turned off.
Future<void> showQuoteSourcesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).background,
    builder: (_) => const QuoteSourcesSheet(),
  );
}

class QuoteSourcesSheet extends StatelessWidget {
  const QuoteSourcesSheet({super.key});

  static const icons = {
    QuoteFamily.stoic: CupertinoIcons.building_2_fill,
    QuoteFamily.christian: CupertinoIcons.book_fill,
    QuoteFamily.puritans: CupertinoIcons.flame_fill,
    QuoteFamily.scripture: CupertinoIcons.book_circle_fill,
    QuoteFamily.stories: CupertinoIcons.sparkles,
    QuoteFamily.thinkers: CupertinoIcons.lightbulb_fill,
    QuoteFamily.mine: CupertinoIcons.person_fill,
  };

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final settings = context.watch<SettingsProvider>();
    final on = settings.quoteFamilies;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Semantics(
                header: true,
                child: Text(
                  'Quote sources',
                  style: TextStyle(
                    fontFamily: LargeTitleHeader.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
            ),
            SettingsSection(
              footer: 'The quote of the day and search use the sources turned on.',
              children: [
                for (final family in QuoteFamily.values)
                  SettingsSwitchTile(
                    tileKey: Key('quoteFamily_${family.name}'),
                    icon: icons[family]!,
                    iconColor: palette.accent,
                    title: family.label,
                    subtitle: _subtitles[family],
                    value: on.contains(family),
                    // The last one on stays on
                    onChanged: on.contains(family) && on.length == 1
                        ? null
                        : (value) => settings.setQuoteFamily(family, value),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _subtitles = {
    QuoteFamily.stoic: 'Epictetus, Seneca, Marcus Aurelius',
    QuoteFamily.christian: 'Chesterton, Spurgeon, à Kempis and more',
    QuoteFamily.puritans: 'Owen, Watson, Baxter, Sibbes and more',
    QuoteFamily.scripture: 'New King James Version',
    QuoteFamily.stories: 'Aesop, Bunyan, Dickens, Alcott and more',
    QuoteFamily.thinkers: 'Johnson, Twain, Franklin, William James',
    QuoteFamily.mine: 'Quotes you add',
  };
}

/// Where the app's quotes come from: the translations, and the notice the
/// NKJV asks for.
Future<void> showQuoteCreditsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).surface,
    builder: (_) => const QuoteCreditsSheet(),
  );
}

class QuoteCreditsSheet extends StatelessWidget {
  const QuoteCreditsSheet({super.key});

  static const credits = [
    ('Scripture', Quotes.nkjvNotice),
    ('Epictetus and Marcus Aurelius', 'Translated by George Long (1862, 1877).'),
    ('Seneca', 'Letters to Lucilius, translated by Richard M. Gummere (1917–1925).'),
    ('Augustine', 'Confessions, translated by E. B. Pusey (1838).'),
    ('Everything else', 'From works in the public domain. Quotes you add stay on this phone.'),
  ];

  /// [credits] as said on this device ("stay on this iPad").
  static List<(String, String)> creditsOn(BuildContext context) => [
        for (final (title, text) in credits)
          (title, text.replaceFirst('this phone', DeviceWords.thisDevice(context))),
      ];

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('quoteCredits'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Sources & credits',
                style: TextStyle(
                  fontFamily: LargeTitleHeader.fontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
            ),
            for (final (title, text) in creditsOn(context)) ...[
              const SizedBox(height: 16),
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.textSecondary)),
              const SizedBox(height: 4),
              Text(text, style: TextStyle(fontSize: 15, height: 1.4, color: palette.text)),
            ],
          ],
        ),
      ),
    );
  }
}
