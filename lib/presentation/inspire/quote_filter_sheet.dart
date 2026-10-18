import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/quote.dart';
import '../../domain/services/quote_facets.dart';
import '../providers/quote_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/large_title_scaffold.dart';
import '../widgets/orb_button.dart';
import 'quote_widgets.dart';

/// Every filter at once: which list, sources (those turned on), themes and
/// an author, each choice with how many quotes it would show. Returns the
/// new filter, or null if dismissed.
Future<QuoteFilter?> showQuoteFilterSheet(BuildContext context, QuoteFilter current) {
  return showModalBottomSheet<QuoteFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).surface,
    builder: (_) => QuoteFilterSheet(initial: current),
  );
}

class QuoteFilterSheet extends StatefulWidget {
  final QuoteFilter initial;

  const QuoteFilterSheet({super.key, required this.initial});

  @override
  State<QuoteFilterSheet> createState() => _QuoteFilterSheetState();
}

class _QuoteFilterSheetState extends State<QuoteFilterSheet> {
  late QuoteFilter _filter = widget.initial;

  static const _lists = {QuoteList.all: 'All', QuoteList.saved: 'Saved', QuoteList.mine: 'Mine'};

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final quotes = context.watch<QuoteProvider>();
    final enabled = context.watch<SettingsProvider>().quoteFamilies;
    final shown = QuoteFacets.apply(quotes.all, _filter, enabled: enabled, savedIds: quotes.savedIds).length;
    final counts = QuoteFacets.counts(quotes.all, _filter, enabled: enabled, savedIds: quotes.savedIds);
    // All holds only the sources turned on; Saved and Mine hold whatever is there
    final families = [
      for (final f in QuoteFamily.values)
        if (_filter.families.contains(f) ||
            (_filter.list == QuoteList.all ? enabled.contains(f) : (counts.families[f] ?? 0) > 0))
          f,
    ];
    final themes = [
      for (final t in QuoteTheme.values)
        if (_filter.themes.contains(t) || (counts.themes[t] ?? 0) > 0) t,
    ];

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.textSecondary)),
          ),
        );

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Filter',
                    style: TextStyle(
                      fontFamily: LargeTitleHeader.fontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                ),
              ),
              TextButton(
                key: const Key('quoteFilterClear'),
                onPressed: _filter.hasFilters ? () => setState(() => _filter = _filter.cleared()) : null,
                style: TextButton.styleFrom(foregroundColor: palette.accent, minimumSize: const Size(44, 44)),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              heading('SHOW'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final entry in _lists.entries)
                  QuoteChoiceChip(
                    key: Key('filterList_${entry.key.name}'),
                    label: entry.value,
                    selected: _filter.list == entry.key,
                    onTap: () => setState(() => _filter = _filter.copyWith(list: entry.key)),
                  ),
              ]),
              heading('SOURCES'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final family in families)
                  QuoteChoiceChip(
                    key: Key('filterFamily_${family.name}'),
                    label: family.label,
                    count: counts.families[family],
                    selected: _filter.families.contains(family),
                    onTap: () => setState(() => _filter = _filter.toggleFamily(family)),
                  ),
              ]),
              heading('THEMES'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final theme in themes)
                  QuoteChoiceChip(
                    key: Key('filterTheme_${theme.name}'),
                    label: theme.label,
                    count: counts.themes[theme],
                    selected: _filter.themes.contains(theme),
                    onTap: () => setState(() => _filter = _filter.toggleTheme(theme)),
                  ),
              ]),
              heading('AUTHOR'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final author in counts.authors)
                  QuoteChoiceChip(
                    key: Key('filterAuthor_${author.name}'),
                    label: author.name,
                    count: author.count,
                    selected: _filter.author != null &&
                        QuoteFacets.authorKey(_filter.author!) == QuoteFacets.authorKey(author.name),
                    onTap: () => setState(() => _filter = _filter.author != null &&
                            QuoteFacets.authorKey(_filter.author!) == QuoteFacets.authorKey(author.name)
                        ? _filter.copyWith(clearAuthor: true)
                        : _filter.copyWith(author: author.name)),
                  ),
              ]),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: OrbButton(
              key: const Key('quoteFilterApply'),
              label: shown == 0 ? 'No quotes match' : (shown == 1 ? 'Show 1 quote' : 'Show $shown quotes'),
              onPressed: () => Navigator.of(context).pop(_filter),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
