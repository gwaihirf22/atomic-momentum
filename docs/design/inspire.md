# Inspire: quote of the day, quote library, quotes on habits

## What it is
A fifth tab, **Inspire**, just left of Settings. It opens on the **quote of the day**, alone on a calm page; the tab bar fades after 3 seconds untouched and any touch brings it back. A search icon opens the library; the options add a quote of one's own, open My quotes and Saved quotes, and choose sources. Any quote can be saved, copied or **kept with a habit**, where it shows on the habit page ("Words for this habit").

The tab can be turned off (Settings → Inspire → Inspire tab). Each source can be turned off: Stoics, Christian writers, Scripture, Classic stories, My quotes (Settings → Inspire → Quote sources, or the Inspire options). One source always stays on.

## Copyright rule
The app's own quotes are **public domain, with one exception: Scripture is in the NKJV.**
- **The Stoics** are in old translations, named in each source: George Long (Epictetus, Marcus Aurelius) and Richard M. Gummere (Seneca). Modern translations (Hays, Robin Hard and others) are under copyright.
- **Writers, Puritans, thinkers and stories** come from works published before 1930 whose authors died long ago. They include Chesterton, Spurgeon, Murray, Müller, Bounds, Owen, Watson, Baxter, Sibbes, Flavel, Brooks, Rutherford, Edwards, Johnson, Twain, Franklin, William James, Bunyan, Dickens, Burnett, Kipling, Thoreau, Emerson, Longfellow, Henley, Carlyle, Lincoln, Booker T. Washington, Helen Keller, Theodore Roosevelt, and Confucius and Laozi in James Legge's translations (1861, 1891).
- **Scripture** is in the **New King James Version, © 1982 Thomas Nelson.** It's quoted under the publisher's free-quotation allowance, with this notice in Settings → Inspire → Sources & credits: "Scripture taken from the New King James Version®. Copyright © 1982 by Thomas Nelson. Used by permission. All rights reserved." Copied and shared verses end "(NKJV)".
  - **Gratis use** (decided 2026-10-20): HarperCollins' published terms allow the NKJV without written permission, with the notice, in any form, provided that no more than 500 verses are quoted, Scripture is under 25% of the work, no complete book is quoted, and the work isn't a commentary or Bible reference. Momentum has 31 passages (about 34 verses), and Scripture is 23.5% of the quote library's text (and far less of the app's), with the notice above. The app is free; Inspire is a side of it meant to encourage. `quotes_library_test` keeps it under 500 verses and under a quarter of the library, so adding Scripture means adding other public-domain quotes too. Written confirmation from HarperCollins' permissions department is optional.
  - **Wording:** every verse must match the NKJV word for word. Only line-start capitals (from the NKJV's poetry layout) and the final punctuation have been changed.

Tolkien, C. S. Lewis, Sanderson and other copyrighted authors come in only as the person's own quotes. "We are what we repeatedly do" is Will Durant (1926), not Aristotle, so it isn't included. Before adding any copyrighted quote to the built-in library, get written permission. `test/unit/core/quotes_library_test.dart` guards a few known names.

## Review before release (Paul)
Check each against its source and correct the wording here and in `lib/core/copy/quotes.dart`:
- **Scripture (NKJV):** all 31 verses (ids start `kjv-`), against an NKJV.
- **Puritans:**
  - Owen (*Mortification of Sin*), Watson, Sibbes (*The Bruised Reed*), Rutherford (*Letters*)
  - Flavel ×2 (*Mystery of Providence*, *Keeping the Heart*)
  - Baxter ×2 (*Christian Directory*; the "dying man" line)
  - Brooks (*Precious Remedies*), Edwards (*Resolutions* 5, 6), Bunyan (on prayer)
  - Watson, Baxter's second line and Bunyan's have no source named yet; add one if found.
- **Thinkers:**
  - Johnson (*Vision of Theodore*, *Rasselas*)
  - Twain ×2 (*Pudd'nhead Wilson*)
  - Franklin ×3 (*Poor Richard*)
  - William James ×4 (*Principles of Psychology*, "Habit")
- **Christian writers:** Murray (*Humility*), Müller, Bounds (*Power Through Prayer*), Hudson Taylor, Chambers (*My Utmost*)
- **Stoics:** Seneca Letters 1 and 76, and Marcus 6.2 (Gummere and Long)
- **Stories:** Bunyan (Hill Difficulty), Dickens (Marley), Burnett (thistle), Kipling ("If—")
- **Attributions flagged earlier:** Hudson Taylor ("faithfulness in a little thing"), Moody, de Sales, Carey, the Epictetus fragment, Chambers ("drudgery")

## How it works
- `Quote` (id, text, author, source, family, themes). Built-in quotes are `const` data in `core/copy/quotes.dart`, and their ids are stable because habits and the saved list keep quotes by id.
- **Quote of the day** (`QuoteOfTheDay`): quotes take turns in an order set by a hash of their ids, indexed by the number of days since 2024-01-01 (counted from the calendar date). Every device shows the same quote all day, a new one at local midnight, and none repeats until all have shown. Adding a quote doesn't reorder the rest. Turning sources off just narrows the pool.
- **Another quote**: the button under the quote swaps in a different one at random from the sources turned on. It stays for the rest of that day, after a restart too (`quote_today_v1`). The normal turns resume at midnight, and the day's turn comes back if the chosen quote's source is turned off.
- **Sharing**: ⋯ → Share this quote opens the app's share sheet with a quote card (a 1080 × 1350 picture), in any share style.
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
  - one habit's ring with a + button (interactive, iOS 17)

  A progress change made in a widget must merge into history and cancel that habit's pending reminders natively.
- A habit's quote as its reminder text.
- Quotes on moments: a comeback, a two-minute day, a habit formed (themes already mark them).
- Sharing a quote card, after `share_plus` lands.
