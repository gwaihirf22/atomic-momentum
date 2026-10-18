import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/habit.dart';
import '../../screens/quote_search_screen.dart';
import '../providers/habit_provider.dart';
import '../providers/quote_provider.dart';
import '../widgets/large_title_scaffold.dart';
import '../widgets/stat_card.dart';
import 'quote_widgets.dart';

/// The habit page's quotes: words the person keeps with this habit, chosen
/// from the library (or their own). Tap one to open it; × takes it off.
class HabitQuotesCard extends StatelessWidget {
  final Habit habit;

  const HabitQuotesCard({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    // Screens pumped alone in tests may not provide quotes
    final quotes = context.watch<QuoteProvider?>();
    if (quotes == null) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    final kept = quotes.resolve(habit.quoteIds);
    final full = habit.quoteIds.length >= Habit.maxQuotes;

    return StatCard(
      key: const Key('detailQuotes'),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: StatCardHeading(
              'Words for this habit',
              action: PillButton(
                key: const Key('detailAddQuote'),
                label: 'Add quote',
                onPressed: full
                    ? null
                    : () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(builder: (_) => QuoteSearchScreen(pickForHabitId: habit.id)),
                        ),
              ),
            ),
          ),
          if (kept.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
              child: Text(
                'A line to come back to on the days it\'s hard.',
                style: TextStyle(fontSize: 14, color: palette.textSecondary),
              ),
            ),
          for (final quote in kept)
            Container(
              key: Key('detailQuote_${quote.id}'),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.separator, width: 0.5))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => showQuoteSheet(context, quote),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                            const SizedBox(height: 6),
                            QuoteByline(quote, size: 13),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('detailRemoveQuote_${quote.id}'),
                    tooltip: 'Remove quote',
                    onPressed: () => context.read<HabitProvider>().removeQuote(habit.id, quote.id),
                    icon: Icon(CupertinoIcons.xmark, size: 16, color: palette.textSecondary),
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
