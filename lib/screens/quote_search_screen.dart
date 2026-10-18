import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/quote.dart';
import '../domain/services/quote_search.dart';
import '../presentation/inspire/quote_widgets.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/quote_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/widgets/large_title_scaffold.dart';

/// Which quotes the list opens on.
enum QuoteListStart { all, saved, mine }

/// Search every quote from the sources turned on, or just the saved ones, or
/// the person's own, narrowed by theme. With [pickForHabitId] a tap keeps
/// the quote with that habit and closes the page.
class QuoteSearchScreen extends StatefulWidget {
  final QuoteListStart start;
  final String? pickForHabitId;

  const QuoteSearchScreen({super.key, this.start = QuoteListStart.all, this.pickForHabitId});

  @override
  State<QuoteSearchScreen> createState() => _QuoteSearchScreenState();
}

class _QuoteSearchScreenState extends State<QuoteSearchScreen> {
  final _query = TextEditingController();
  late QuoteListStart _list = widget.start;
  QuoteTheme? _theme;

  bool get _picking => widget.pickForHabitId != null;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _tap(Quote quote) async {
    if (!_picking) return showQuoteSheet(context, quote);
    final habits = context.read<HabitProvider>();
    final ok = await habits.addQuote(widget.pickForHabitId!, quote.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(quote.id);
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(habits.error ?? 'Could not add it')));
    }
  }

  Future<void> _addMine() async {
    final quote = await showMyQuoteSheet(context);
    if (quote == null || !mounted) return;
    if (_picking) {
      await _tap(quote);
    } else {
      setState(() => _list = QuoteListStart.mine);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final quotes = context.watch<QuoteProvider>();
    final families = context.watch<SettingsProvider>().quoteFamilies;
    final kept = _picking
        ? (context.watch<HabitProvider>().habits.where((h) => h.id == widget.pickForHabitId).firstOrNull?.quoteIds ??
            const <String>[])
        : const <String>[];

    final base = switch (_list) {
      QuoteListStart.all => quotes.from(families),
      QuoteListStart.saved => quotes.resolve(quotes.savedIds),
      QuoteListStart.mine => quotes.mine,
    };
    final results = QuoteSearch.find(base, query: _query.text, themes: {if (_theme != null) _theme!});

    final title = _picking
        ? 'Choose a quote'
        : switch (_list) {
            QuoteListStart.all => 'Quotes',
            QuoteListStart.saved => 'Saved quotes',
            QuoteListStart.mine => 'My quotes',
          };

    String emptyText() {
      if (_query.text.trim().isNotEmpty || _theme != null) return 'Nothing matches. Try other words.';
      return switch (_list) {
        QuoteListStart.all => 'Turn on a quote source to see quotes here.',
        QuoteListStart.saved => 'Tap the heart on a quote to keep it here.',
        QuoteListStart.mine => 'Quotes you add show here. Tap + to add one.',
      };
    }

    return LargeTitleScaffold(
      title: title,
      backgroundColor: palette.background,
      header: LargeTitleHeader(title: title, titleKey: const Key('quoteSearchTitle')),
      trailing: CupertinoButton(
        key: const Key('quoteSearchAdd'),
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: _addMine,
        child: Semantics(label: 'Add a quote', child: Icon(CupertinoIcons.add, color: palette.accent)),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 4, AppStyle.screenPadding, 0),
            child: CupertinoSearchTextField(
              key: const Key('quoteSearchField'),
              controller: _query,
              placeholder: 'Words, or who said it',
              style: TextStyle(color: palette.text),
              backgroundColor: palette.surface,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 12, AppStyle.screenPadding, 4),
            child: Row(
              children: [
                for (final list in QuoteListStart.values)
                  _Chip(
                    key: Key('quoteList_${list.name}'),
                    label: switch (list) {
                      QuoteListStart.all => 'All',
                      QuoteListStart.saved => 'Saved',
                      QuoteListStart.mine => 'Mine',
                    },
                    selected: _list == list,
                    onTap: () => setState(() => _list = list),
                  ),
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: palette.separator,
                ),
                for (final theme in QuoteTheme.values)
                  _Chip(
                    key: Key('quoteTheme_${theme.name}'),
                    label: theme.label,
                    selected: _theme == theme,
                    onTap: () => setState(() => _theme = _theme == theme ? null : theme),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 8, AppStyle.screenPadding, 24),
          sliver: results.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      emptyText(),
                      key: const Key('quoteSearchEmpty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: palette.textSecondary),
                    ),
                  ),
                )
              : SliverList.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final quote = results[i];
                    final isKept = kept.contains(quote.id);
                    return QuoteTile(
                      quote: quote,
                      onTap: isKept ? () => Navigator.of(context).pop() : () => _tap(quote),
                      trailing: isKept
                          ? Icon(CupertinoIcons.checkmark_alt, size: 20, color: palette.accent, semanticLabel: 'Kept')
                          : (!_picking && quotes.isSaved(quote.id)
                              ? Icon(CupertinoIcons.heart_fill, size: 16, color: palette.accent, semanticLabel: 'Saved')
                              : null),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: selected ? palette.onAccent : palette.text,
            backgroundColor: selected ? palette.accent : palette.raised,
            minimumSize: const Size(44, 36),
            tapTargetSize: MaterialTapTargetSize.padded,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
