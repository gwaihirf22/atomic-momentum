# Inspire: quote of the day, quote library, quotes on habits

## What it is
A fifth tab, **Inspire**, just left of Settings. It opens on the **quote of the day**, alone on a calm page; the tab bar fades after 3 seconds untouched and any touch brings it back. A search icon opens the library; the options add a quote of one's own, open My quotes and Saved quotes, and choose sources. Any quote can be saved, copied or **kept with a habit**, where it shows on the habit page ("Words for this habit").

The tab can be turned off (Settings → Inspire → Inspire tab). Each source can be turned off: Stoics, Christian writers, Scripture, Classic stories, My quotes (Settings → Inspire → Quote sources, or the Inspire options). One source always stays on.

## Copyright rule
The app's own quotes are **public domain only**:
- **Stoics** in old translations, named in each quote's source: George Long (Epictetus 1877, Marcus Aurelius 1862) and Richard M. Gummere (Seneca, 1917–1925). Modern translations (Hays, Robin Hard and others) are under copyright, even though the authors are ancient.
- **Scripture** in the King James Version. The NIV and ESV need permission, beyond their short-quote allowances.
- **Writers and stories** published before 1930 whose authors died more than 70 years ago (Chesterton, Spurgeon, à Kempis, Bunyan, Dickens, Alcott, Burnett, Montgomery, Barrie, Margery Williams, Aesop).

Tolkien, C. S. Lewis, Sanderson and other copyrighted authors come in only as the person's **own quotes**. The person types them in for themselves, and the app never shares them. Before adding any copyrighted quote to the built-in library, get written permission from its rights holder. `test/unit/core/quotes_library_test.dart` guards a few known names.

Check the wording of every built-in quote against the named public-domain edition before release.

## How it works
- `Quote` (id, text, author, source, family, themes). Built-in quotes are `const` data in `core/copy/quotes.dart`, and their ids are stable because habits and the saved list keep quotes by id.
- **Quote of the day** (`QuoteOfTheDay`): quotes take turns in an order set by a hash of their ids, indexed by the number of days since 2024-01-01 (counted from the calendar date). Every device shows the same quote all day, a new one at local midnight, and none repeats until all have shown. Adding a quote doesn't reorder the rest. Turning sources off just narrows the pool.
- **Browse and filters** (`QuoteFacets`, `QuoteFilter`): with nothing typed or chosen, Quotes shows what the library holds:
  - the sources turned on, with counts, and a link to the ones turned off
  - themes
  - authors, A–Z (Scripture's verse references aren't listed as authors)
  - Saved and My quotes

  A tap filters to any of these. The Filter sheet combines a list (All, Saved or Mine), sources, themes and one author; each choice shows how many quotes it would give with the other choices kept. Active filters show as chips with an ×. Saved and Mine ignore the source switches.
- **Search** (`QuoteSearch`): every word typed must appear in the text, author or source, within the filters. Case, accents and apostrophe styles are ignored.
- **Your own quotes** are filed under the source you choose (My quotes by default) and themes. The author field suggests names already in the library, so quotes by the same person group together. A quote follows its source's switch, and it's always in My quotes.
- **(i) explainer** (`InfoTopic.inspire`): on the Inspire tab and in Quotes.
- **Storage**: the person's own quotes go under `quotes_mine_v1` (unreadable data is kept under `quotes_mine_v1_corrupt`), saved ids under `quotes_saved_v1`, and a habit's quotes in the habit JSON as `quotes`. Settings: `showInspireTab`, `quoteFamiliesOff`.
- **Navigation**: `AppTab` names the tabs. Per-tab state is keyed by tab, so hiding Inspire never moves another tab's stack.

## Later
- Widgets (WidgetKit extension in `ios/`, fed through an App Group, via `home_widget`):
  - the quote of the day (medium)
  - the momentum gauge (small, plus the lock-screen circular gauge)
  - one habit's ring with a + button (interactive needs iOS 17; on iOS 16 it opens the app)

  A progress change made in a widget must merge into history and cancel that habit's pending reminders natively.
- A habit's quote as its reminder text.
- Quotes on moments: a comeback, a two-minute day, a habit formed (themes already mark them).
- Sharing a quote card, after `share_plus` lands.
