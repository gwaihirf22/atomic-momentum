import 'package:flutter/material.dart';
import '../../domain/entities/quote.dart';
import '../share/share_cards.dart';
import '../share/share_sheet.dart';
import '../widgets/large_title_scaffold.dart';

/// Shares a quote as a designed card (see showShareSheet).
Future<void> shareQuote(BuildContext context, Quote quote) => showShareSheet(
      context,
      card: (look, _) => QuoteShareCard(quote: quote, look: look),
      fileName: 'momentum-quote.png',
    );

/// A quote on a share card: a large opening mark, the words (smaller the
/// longer they are), and who said it, with the source in the corner.
class QuoteShareCard extends StatelessWidget {
  final Quote quote;
  final ShareLook look;

  const QuoteShareCard({super.key, required this.quote, required this.look});

  /// Type size for a quote of [length] characters, so any quote fits.
  static double fontSizeFor(int length) {
    if (length <= 60) return 34;
    if (length <= 110) return 28;
    if (length <= 170) return 23;
    if (length <= 250) return 19;
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    final size = fontSizeFor(quote.text.length);
    return ShareCardFrame(
      key: const Key('shareCard_quote'),
      look: look,
      caption: quote.source,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '“',
          style: TextStyle(
            fontFamily: LargeTitleHeader.fontFamily,
            fontSize: 64,
            height: 0.9,
            fontWeight: FontWeight.w700,
            color: look.accent,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            // Shrinks rather than cutting off, whatever the quote
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: ShareCardFrame.size.width - 60,
                child: Text(
                  quote.text,
                  style: TextStyle(
                    fontFamily: LargeTitleHeader.fontFamily,
                    fontSize: size,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: look.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (quote.author.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            '— ${quote.author}',
            maxLines: 2,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: look.ink),
          ),
        ],
      ]),
    );
  }
}
