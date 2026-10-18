import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/copy/quotes.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/quote.dart';
import '../domain/services/quote_facets.dart';
import '../presentation/help/explainers.dart';
import '../presentation/inspire/quote_filter_sheet.dart';
import '../presentation/inspire/quote_widgets.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/quote_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/widgets/info_button.dart';
import '../presentation/widgets/large_title_scaffold.dart';

/// The quote library. With nothing typed or chosen it shows what's there:
/// the sources turned on, themes, authors, and the person's saved and own
/// quotes, each with a count; a tap filters to it. Filter combines them,
/// and words typed search within. With [pickForHabitId] a tap keeps the
/// quote with that habit and closes the page.
class QuoteSearchScreen extends StatefulWidget {
  final QuoteList start;
  final String? pickForHabitId;

  const QuoteSearchScreen({super.key, this.start = QuoteList.all, this.pickForHabitId});

  @override
  State<QuoteSearchScreen> createState() => _QuoteSearchScreenState();
}

class _QuoteSearchScreenState extends State<QuoteSearchScreen> {
  final _query = TextEditingController();
  late QuoteFilter _filter = QuoteFilter(list: widget.start);

  bool get _picking => widget.pickForHabitId != null;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  final _top = GlobalKey();

  void _set(QuoteFilter filter) => setState(() => _filter = filter);

  /// A choice from browsing: the list starts at its top, not where the
  /// choice was.
  void _choose(QuoteFilter filter) {
    _set(filter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _top.currentContext;
      if (context != null) Scrollable.maybeOf(context)?.position.jumpTo(0);
    });
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
      _set(_filter.cleared().copyWith(list: QuoteList.mine));
    }
  }

  Future<void> _openFilters() async {
    final filter = await showQuoteFilterSheet(context, _filter);
    if (filter != null && mounted) _set(filter);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final quotes = context.watch<QuoteProvider>();
    final enabled = context.watch<SettingsProvider>().quoteFamilies;
    final kept = _picking
        ? (context.watch<HabitProvider>().habits.where((h) => h.id == widget.pickForHabitId).firstOrNull?.quoteIds ??
            const <String>[])
        : const <String>[];

    final title = _picking ? 'Choose a quote' : 'Quotes';
    final browsing = _filter.isEmpty;

    return LargeTitleScaffold(
      title: title,
      backgroundColor: palette.background,
      header: LargeTitleHeader(title: title, titleKey: const Key('quoteSearchTitle')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const InfoButton(topic: InfoTopic.inspire),
          CupertinoButton(
            key: const Key('quoteSearchAdd'),
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            onPressed: _addMine,
            child: Semantics(label: 'Add a quote', child: Icon(CupertinoIcons.add, color: palette.accent)),
          ),
        ],
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
              onChanged: (text) => _set(_filter.copyWith(query: text)),
            ),
          ),
        ),
        SliverToBoxAdapter(key: _top, child: _FilterBar(filter: _filter, onOpen: _openFilters, onChange: _set)),
        if (browsing)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 4, AppStyle.screenPadding, 24),
            sliver: SliverToBoxAdapter(child: _Browse(enabled: enabled, onChoose: _choose)),
          )
        else
          ..._results(context, quotes, enabled, kept),
      ],
    );
  }

  List<Widget> _results(BuildContext context, QuoteProvider quotes, Set<QuoteFamily> enabled, List<String> kept) {
    final palette = AppPalette.of(context);
    final results = QuoteFacets.apply(quotes.all, _filter, enabled: enabled, savedIds: quotes.savedIds);
    String emptyText() {
      if (_filter.query.trim().isNotEmpty || _filter.families.isNotEmpty || _filter.themes.isNotEmpty || _filter.author != null) {
        return 'Nothing matches. Try other words, or fewer filters.';
      }
      return switch (_filter.list) {
        QuoteList.all => 'Turn on a quote source to see quotes here.',
        QuoteList.saved => 'Tap the heart on a quote to keep it here.',
        QuoteList.mine => 'Quotes you add show here. Tap + to add one.',
      };
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding + 4, 4, AppStyle.screenPadding, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            results.length == 1 ? '1 quote' : '${results.length} quotes',
            key: const Key('quoteResultCount'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.textSecondary),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 0, AppStyle.screenPadding, 24),
        sliver: results.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      Text(
                        emptyText(),
                        key: const Key('quoteSearchEmpty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: palette.textSecondary),
                      ),
                      if (_filter.families.isNotEmpty || _filter.themes.isNotEmpty || _filter.author != null)
                        TextButton(
                          key: const Key('quoteClearFilters'),
                          onPressed: () => _set(_filter.cleared()),
                          style: TextButton.styleFrom(foregroundColor: palette.accent),
                          child: const Text('Clear filters'),
                        ),
                    ],
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
    ];
  }
}

/// "Filter" (with how many are on), then each filter on as a chip whose ×
/// takes it off.
class _FilterBar extends StatelessWidget {
  final QuoteFilter filter;
  final VoidCallback onOpen;
  final ValueChanged<QuoteFilter> onChange;

  const _FilterBar({required this.filter, required this.onOpen, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final chips = <Widget>[
      if (filter.list != QuoteList.all)
        _ActiveChip(
          key: const Key('activeFilter_list'),
          label: filter.list == QuoteList.saved ? 'Saved' : 'Mine',
          onRemove: () => onChange(filter.copyWith(list: QuoteList.all)),
        ),
      for (final family in filter.families)
        _ActiveChip(
          key: Key('activeFilter_family_${family.name}'),
          label: family.label,
          onRemove: () => onChange(filter.toggleFamily(family)),
        ),
      for (final theme in filter.themes)
        _ActiveChip(
          key: Key('activeFilter_theme_${theme.name}'),
          label: theme.label,
          onRemove: () => onChange(filter.toggleTheme(theme)),
        ),
      if (filter.author != null)
        _ActiveChip(
          key: const Key('activeFilter_author'),
          label: filter.author!,
          onRemove: () => onChange(filter.copyWith(clearAuthor: true)),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 10, AppStyle.screenPadding, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton.icon(
            key: const Key('quoteFilterButton'),
            onPressed: onOpen,
            icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 16),
            label: Text(filter.count == 0 ? 'Filter' : 'Filter · ${filter.count}'),
            style: TextButton.styleFrom(
              foregroundColor: filter.count == 0 ? palette.text : palette.onAccent,
              backgroundColor: filter.count == 0 ? palette.raised : palette.accent,
              minimumSize: const Size(44, 36),
              tapTargetSize: MaterialTapTargetSize.padded,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          ...chips,
        ],
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveChip({super.key, required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      button: true,
      label: '$label filter',
      hint: 'Removes it',
      excludeSemantics: true,
      onTap: onRemove,
      child: TextButton(
        onPressed: onRemove,
        style: TextButton.styleFrom(
          foregroundColor: palette.text,
          backgroundColor: palette.surface,
          minimumSize: const Size(44, 36),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const EdgeInsets.only(left: 14, right: 10),
          shape: StadiumBorder(side: BorderSide(color: palette.accent, width: 1.2)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(label)),
          const SizedBox(width: 6),
          Icon(CupertinoIcons.xmark, size: 13, color: palette.textSecondary),
        ]),
      ),
    );
  }
}

/// What the library holds: sources turned on, themes, authors, and the
/// person's own lists, each with a count. A tap filters to it.
class _Browse extends StatelessWidget {
  final Set<QuoteFamily> enabled;
  final ValueChanged<QuoteFilter> onChoose;

  const _Browse({required this.enabled, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final quotes = context.watch<QuoteProvider>();
    final all = quotes.all;
    final counts = QuoteFacets.counts(all, const QuoteFilter(), enabled: enabled, savedIds: quotes.savedIds);
    final off = QuoteFamily.values.length - enabled.length;

    String sourceSubtitle(QuoteFamily family) {
      if (family == QuoteFamily.scripture) return Quotes.nkjv;
      final names = QuoteFacets.authors([for (final q in all) if (q.family == family) q])
        ..sort((a, b) => b.count.compareTo(a.count));
      if (names.isEmpty) return family == QuoteFamily.mine ? 'Quotes you add' : '';
      final top = names.take(3).map((a) => a.name).join(', ');
      return names.length > 3 ? '$top and more' : top;
    }

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Semantics(
            header: true,
            child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.textSecondary)),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('SOURCES'),
        _Group(rows: [
          for (final family in QuoteFamily.values)
            if (enabled.contains(family))
              _Row(
                key: Key('browseFamily_${family.name}'),
                title: family.label,
                subtitle: sourceSubtitle(family),
                count: counts.families[family] ?? 0,
                onTap: () => onChoose(QuoteFilter(families: {family})),
              ),
        ]),
        if (off > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('browseSourcesOff'),
              onPressed: () => showQuoteSourcesSheet(context),
              style: TextButton.styleFrom(foregroundColor: palette.accent, minimumSize: const Size(44, 44)),
              child: Text(off == 1 ? '1 source off · Quote sources' : '$off sources off · Quote sources'),
            ),
          ),
        heading('THEMES'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final theme in QuoteTheme.values)
            if ((counts.themes[theme] ?? 0) > 0)
              QuoteChoiceChip(
                key: Key('browseTheme_${theme.name}'),
                label: theme.label,
                count: counts.themes[theme],
                selected: false,
                onTap: () => onChoose(QuoteFilter(themes: {theme})),
              ),
        ]),
        heading('AUTHORS'),
        _Group(rows: [
          for (final author in counts.authors)
            _Row(
              key: Key('browseAuthor_${author.name}'),
              title: author.name,
              count: author.count,
              onTap: () => onChoose(QuoteFilter(author: author.name)),
            ),
        ]),
        heading('YOURS'),
        _Group(rows: [
          _Row(
            key: const Key('browseSaved'),
            icon: CupertinoIcons.heart_fill,
            title: 'Saved',
            count: quotes.resolve(quotes.savedIds).length,
            onTap: () => onChoose(const QuoteFilter(list: QuoteList.saved)),
          ),
          _Row(
            key: const Key('browseMine'),
            icon: CupertinoIcons.person_fill,
            title: 'My quotes',
            count: quotes.mine.length,
            onTap: () => onChoose(const QuoteFilter(list: QuoteList.mine)),
          ),
        ]),
      ],
    );
  }
}

/// Rows on one rounded card, with hairlines between them.
class _Group extends StatelessWidget {
  final List<Widget> rows;

  const _Group({required this.rows});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppStyle.cardRadius),
      child: Material(
        color: palette.surface,
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 16, color: palette.separator),
            rows[i],
          ],
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final int count;
  final VoidCallback onTap;

  const _Row({super.key, required this.title, this.subtitle, this.icon, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(children: [
            if (icon != null) ...[Icon(icon, size: 18, color: palette.accent), const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.text)),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: TextStyle(fontSize: 13, color: palette.textSecondary)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('$count', style: TextStyle(fontSize: 15, color: palette.textSecondary)),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.chevron_right, size: 15, color: palette.textSecondary),
          ]),
        ),
      ),
    );
  }
}
