# New app icons and themes (Momentum Plus)

*Proposed October 26, 2026, for 1.1. Not built: Paul picks from the mockups first (artifact `CqbmGuChPjgmg4RQB1tGkc`: both themes on the Habits screen beside Charged and Light, the icons at full size and on dark and light home screens).*

Light, Sepia and Charged, and the Charged and Light icons, stay free for everyone. Plus adds **two themes** and **three icons**. The Plus page already lists "new icons and themes" as coming.

## Themes

Each is a full `AppPalette` (every field, in `core/theme/app_palette.dart`), so every screen, the widgets, share cards and the intro take it with no screen-by-screen work. The palette test (`palette_usage_test`) already keeps screens from hardcoding colors.

### Midnight (dark)

A true-black theme for OLED phones and night reading. Charged's amber, with less glow.

| Field | Value | Note |
|---|---|---|
| background | `#000000` | true black: pixels off on OLED |
| surface | `#0E0F11` | cards just off black |
| raised | `#18191C` | |
| track / separator | `#222429` | |
| text / textSecondary | `#ECECEE` / `#8E9099` | slightly softer white than Charged |
| accent / gauge | `#FFB020` | Charged's amber |
| good / gold / flame / ice | Charged's | |
| bar | `#CC0A0A0C` | the tab bar, nearly opaque |

Under System, Midnight can be the night choice ("In dark mode: Charged / Midnight"), as "In light mode" picks Light or Sepia now (`ThemeProvider.defaultDayTheme` gains a night twin).

### Paper (light)

Warm white with ink: quieter than Light, cooler than Sepia. Black-ink text, an ink-blue accent for buttons and links, momentum's amber kept for the gauge so the brand stays.

| Field | Value | Note |
|---|---|---|
| background | `#F7F5F0` | warm paper |
| surface | `#FFFEFB` | |
| raised | `#EEEBE4` | |
| track / separator | `#E2DED5` | |
| text / textSecondary | `#1B1A17` / `#66625A` | ink |
| accent | `#2C4A7C` | ink blue (white on it is 8.8:1) |
| gauge | `#E39014` | momentum stays amber |
| good / gold / flame / danger | `#2F6B3A` / `#7A5200` / `#C2410C` / `#B3261E` | |
| ice | `#2B6CB0` | |

Habit colors are drawn with Light's rule on Paper (deepened to 3:1 on cards).

### Building them

1. `AppTheme.midnight` and `AppTheme.paper` with their palettes; `ThemeProvider` stores them (`theme_mode` gains two values; an unknown value falls back to System, so an older build reading a newer choice is safe).
2. Settings → Display → Appearance lists them with a small "Plus" mark; picking one without Plus opens the Plus page. If Plus goes away (refund), the theme returns to System.
3. Widgets: `WidgetSnapshot`'s palette already carries the colors, so widgets follow with no Swift change. Share cards keep their own four styles.
4. Native launch screens stay Sepia by day and Charged at night (they can't know the theme before Flutter runs).
5. Tests: the palette test covers new palettes; `small_screens_test` and the layout shots in each theme; contrast checks for text, secondary text and accent on surface (4.5:1) and habit colors (3:1).

## Icons

Three alternate icon sets, from the same ring-and-bolt mark (`MomentumMark`):

| Icon | Look | Pairs with |
|---|---|---|
| **Ember** | The ring and bolt in amber and orange on near-black (`#0E1013`): the icon in Charged's actual colors (today's Charged icon is blue) | Charged, Midnight |
| **Sepia** | A brown-ink ring and an amber bolt on cream (`#F3EBDD`) | Sepia |
| **Ink** | A black ring and bolt on warm paper, no color at all; a clean base for iOS 18's tinted icons | Paper |

### Building them

1. Source PNGs (1024 × 1024, no transparency) in `assets/branding/`: drawn from `MomentumMark` at size by a small Flutter golden test (so they match the app's mark exactly), or by Paul in a design tool from the mockup.
2. A line each in `tool/make_app_icons.py` (iOS sets `AppIcon-Ember`, `AppIcon-Sepia`, `AppIcon-Ink`, Settings previews; Android aliases when Android resumes), `AppIcons` entries, `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`; `app_icons_test` checks they agree.
3. Settings → App icon shows them with the "Plus" mark; picking one without Plus opens the Plus page. If Plus goes away, the icon is left as it is (changing it would show iOS's alert out of nowhere).

## What Paul needs to do

- **Pick:** both themes or one; which icons; any color changes (the mockup shows each theme on the Habits screen and a card, and each icon at home-screen size, light and dark).
- **Decide:** whether the System pairing should offer Midnight at night.
- Nothing in App Store Connect: alternate icons and themes need no portal steps.
