import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/quote.dart';
import '../presentation/inspire/quote_widgets.dart';
import '../presentation/providers/quote_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/widgets/adaptive.dart';
import '../presentation/widgets/floating_tab_bar.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import 'quote_search_screen.dart';

/// The Inspire tab: the quote of the day, on its own, with nothing else to
/// look at (the tab bar fades away, see IOSMainNavigation). Search finds
/// more; the options pick sources and add quotes of one's own.
class InspireScreen extends StatefulWidget {
  const InspireScreen({super.key});

  /// Type size for a quote of [length] characters: short ones large.
  static double fontSizeFor(int length) {
    if (length <= 70) return 30;
    if (length <= 140) return 26;
    if (length <= 220) return 23;
    return 20;
  }

  @override
  State<InspireScreen> createState() => _InspireScreenState();
}

class _InspireScreenState extends State<InspireScreen> with WidgetsBindingObserver {
  /// Rebuilds at midnight for the new day's quote.
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waitForMidnight();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    super.dispose();
  }

  // Coming back to the app on a new day shows that day's quote
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _waitForMidnight();
    }
  }

  void _waitForMidnight() {
    _midnight?.cancel();
    final now = clock.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {});
      _waitForMidnight();
    });
  }

  Future<void> _options() async {
    final choice = await chooseAdaptive<_Option>(
      context,
      title: 'Inspire',
      options: const [
        AdaptiveOption(_Option.add, 'Add a quote', key: Key('inspireOption_add')),
        AdaptiveOption(_Option.mine, 'My quotes', key: Key('inspireOption_mine')),
        AdaptiveOption(_Option.saved, 'Saved quotes', key: Key('inspireOption_saved')),
        AdaptiveOption(_Option.sources, 'Quote sources', key: Key('inspireOption_sources')),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _Option.add:
        await showMyQuoteSheet(context);
      case _Option.mine:
        _openSearch(const QuoteSearchScreen(start: QuoteListStart.mine));
      case _Option.saved:
        _openSearch(const QuoteSearchScreen(start: QuoteListStart.saved));
      case _Option.sources:
        await showQuoteSourcesSheet(context);
    }
  }

  void _openSearch(Widget screen) =>
      Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild when the appearance changes
    final palette = AppPalette.of(context);
    final quotes = context.watch<QuoteProvider>();
    final families = context.watch<SettingsProvider>().quoteFamilies;
    final now = clock.now();
    final quote = quotes.today(families, now: now);
    final barInset = TabBarInset.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      // Keeps SnackBars above the floating tab bar
      bottomNavigationBar: barInset > 0 ? SizedBox(height: barInset) : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding + 4, 4, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'TODAY · ${DateFormat.MMMd().format(now).toUpperCase()}',
                      key: const Key('inspireDate'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  _TopButton(
                    key: const Key('inspireSearch'),
                    icon: CupertinoIcons.search,
                    label: 'Search quotes',
                    onTap: () => _openSearch(const QuoteSearchScreen()),
                  ),
                  _TopButton(
                    key: const Key('inspireOptions'),
                    icon: CupertinoIcons.ellipsis_circle,
                    label: 'Options',
                    onTap: _options,
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: quote == null ? const _NoQuotes() : _TodaysQuote(quote: quote, saved: quotes.isSaved(quote.id)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: barInset),
          ],
        ),
      ),
    );
  }
}

enum _Option { add, mine, saved, sources }

class _TodaysQuote extends StatelessWidget {
  final Quote quote;
  final bool saved;

  const _TodaysQuote({required this.quote, required this.saved});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      key: Key('inspireQuote_${quote.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            '“',
            style: TextStyle(
              fontFamily: LargeTitleHeader.fontFamily,
              fontSize: 72,
              height: 0.9,
              fontWeight: FontWeight.w700,
              color: palette.accent,
            ),
          ),
        ),
        Text(
          quote.text,
          key: const Key('inspireQuoteText'),
          style: TextStyle(
            fontFamily: LargeTitleHeader.fontFamily,
            fontSize: InspireScreen.fontSizeFor(quote.text.length),
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: palette.text,
          ),
        ),
        const SizedBox(height: 18),
        QuoteByline(quote, size: 16),
        const SizedBox(height: 36),
        Center(child: QuoteActions(quote: quote, saved: saved)),
      ],
    );
  }
}

/// Every source is off but the person's own, and they have none yet.
class _NoQuotes extends StatelessWidget {
  const _NoQuotes();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'No quotes to show',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: LargeTitleHeader.fontFamily,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: palette.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add one of your own, or turn on a source.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: palette.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              key: const Key('inspireAddFirst'),
              onPressed: () => showMyQuoteSheet(context),
              child: const Text('Add a quote'),
            ),
            TextButton(
              key: const Key('inspireSources'),
              onPressed: () => showQuoteSourcesSheet(context),
              child: const Text('Quote sources'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TopButton({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        tooltip: label,
        icon: Icon(icon, size: 22, color: AppPalette.of(context).textSecondary),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      );
}
