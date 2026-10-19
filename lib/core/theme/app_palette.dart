import 'package:flutter/material.dart';

/// The app's three looks. Dark is "Charged", the signature look; Light and
/// Sepia are its daytime versions.
enum AppTheme { light, sepia, dark }

/// Every color the app draws with, for one [AppTheme]. Widgets read it with
/// [AppPalette.of] and never pick colors by brightness themselves, so a theme
/// is just a palette. Values come from the chosen design (the "Charged"
/// mockups, artifact EU7hXyzsDR8ydkNNSBnmfk).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final AppTheme theme;

  /// Sepia draws as a light theme for the status bar and system controls.
  final Brightness brightness;

  /// Behind everything.
  final Color background;

  /// Cards, grouped lists and sheets.
  final Color surface;

  /// Chips, fields and buttons sitting on a surface.
  final Color raised;

  /// Empty progress tracks.
  final Color track;

  /// Hairlines between rows.
  final Color separator;

  final Color text;
  final Color textSecondary;

  /// Buttons, links, selection and the navigation bar's actions.
  final Color accent;

  /// Text and icons drawn on [accent] or the orb.
  final Color onAccent;

  /// The momentum gauge.
  final Color gauge;

  /// The orb gradient (the main "+" and calls to action), top-left to bottom-right.
  final Color orbStart;
  final Color orbEnd;

  /// "Streak saved" and other good news: text and its chip.
  final Color good;
  final Color goodTint;

  /// Records and perfect days: text and its chip.
  final Color gold;
  final Color goldTint;

  /// The streak flame.
  final Color flame;

  /// "Don't miss twice".
  final Color warning;

  /// Delete and other destructive actions.
  final Color danger;

  /// Freezes: a frozen day, the freeze bank (3:1 on [surface]).
  final Color ice;

  /// The floating tab bar: translucent over the blurred content behind it,
  /// with a hairline edge and a soft shadow.
  final Color bar;
  final Color barEdge;
  final Color barShadow;

  /// The glow under the orb.
  final Color orbShadow;

  /// What dims the screen behind a tour's spotlight.
  final Color scrim;

  const AppPalette({
    required this.theme,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.raised,
    required this.track,
    required this.separator,
    required this.text,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.gauge,
    required this.orbStart,
    required this.orbEnd,
    required this.good,
    required this.goodTint,
    required this.gold,
    required this.goldTint,
    required this.flame,
    required this.warning,
    required this.danger,
    required this.ice,
    required this.bar,
    required this.barEdge,
    required this.barShadow,
    required this.orbShadow,
    required this.scrim,
  });

  static const dark = AppPalette(
    theme: AppTheme.dark,
    brightness: Brightness.dark,
    background: Color(0xFF0E1013),
    surface: Color(0xFF171A20),
    raised: Color(0xFF22262E),
    track: Color(0xFF2A2E36),
    separator: Color(0xFF2A2E36),
    text: Color(0xFFF4F4F6),
    textSecondary: Color(0xFF9A9DA6),
    accent: Color(0xFFFFB020),
    onAccent: Color(0xFF1A1206),
    gauge: Color(0xFFFFB020),
    orbStart: Color(0xFFFFC24D),
    orbEnd: Color(0xFFFF7A1A),
    good: Color(0xFF6EE7A0),
    goodTint: Color(0xFF12301F),
    gold: Color(0xFFFFC24D),
    goldTint: Color(0xFF3A2A06),
    flame: Color(0xFFFF8A3D),
    warning: Color(0xFFFFB020),
    danger: Color(0xFFFF6B6B),
    ice: Color(0xFF8EC5FF),
    bar: Color(0xC71C1F26),
    barEdge: Color(0x14FFFFFF),
    barShadow: Color(0x80000000),
    orbShadow: Color(0x73FF8A3D),
    scrim: Color(0xB8000000),
  );

  static const light = AppPalette(
    theme: AppTheme.light,
    brightness: Brightness.light,
    background: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFECEEF1),
    track: Color(0xFFE3E5EA),
    separator: Color(0xFFE0E2E7),
    text: Color(0xFF111318),
    textSecondary: Color(0xFF5F636B),
    accent: Color(0xFFC26A08),
    onAccent: Color(0xFFFFFFFF),
    gauge: Color(0xFFF29A0C),
    orbStart: Color(0xFFFFC24D),
    orbEnd: Color(0xFFF27A12),
    good: Color(0xFF17723A),
    goodTint: Color(0xFFDDF5E6),
    gold: Color(0xFF7A5200),
    goldTint: Color(0xFFFFF0CC),
    flame: Color(0xFFD9480F),
    warning: Color(0xFFB45309),
    danger: Color(0xFFD93025),
    ice: Color(0xFF2B73B8),
    bar: Color(0xCCFFFFFF),
    barEdge: Color(0x14000000),
    barShadow: Color(0x2414161C),
    orbShadow: Color(0x59F27A12),
    scrim: Color(0x9E111318),
  );

  static const sepia = AppPalette(
    theme: AppTheme.sepia,
    brightness: Brightness.light,
    background: Color(0xFFF3EBDD),
    surface: Color(0xFFFBF6EC),
    raised: Color(0xFFEDE3D1),
    track: Color(0xFFE4D7C1),
    separator: Color(0xFFE0D3BD),
    text: Color(0xFF3B2F22),
    textSecondary: Color(0xFF76664F),
    accent: Color(0xFFA85A0E),
    onAccent: Color(0xFFFBF6EC),
    gauge: Color(0xFFD9821E),
    orbStart: Color(0xFFE8AE57),
    orbEnd: Color(0xFFC9671C),
    good: Color(0xFF4A6526),
    goodTint: Color(0xFFE3EAD2),
    gold: Color(0xFF6E4708),
    goldTint: Color(0xFFF2E0B6),
    flame: Color(0xFFB3541A),
    warning: Color(0xFF9A5A0C),
    danger: Color(0xFFA8432F),
    ice: Color(0xFF3F7095),
    bar: Color(0xD1FBF6EC),
    barEdge: Color(0x1A3B2F22),
    barShadow: Color(0x29503C1E),
    orbShadow: Color(0x4DC9671C),
    scrim: Color(0xA32A2016),
  );

  static AppPalette forTheme(AppTheme theme) => switch (theme) {
        AppTheme.light => light,
        AppTheme.sepia => sepia,
        AppTheme.dark => dark,
      };

  /// The palette in effect. Outside the app's theme (some tests build a bare
  /// MaterialApp) it falls back to Light or Dark by brightness.
  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppPalette>() ?? (theme.brightness == Brightness.dark ? dark : light);
  }

  /// Marks on the orb (its "+", a call to action's label): dark ink in every
  /// theme, since the orb is always bright amber.
  static const onOrb = Color(0xFF1A1206);

  /// The orb gradient, for the main "+" and calls to action.
  LinearGradient get orb => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [orbStart, orbEnd],
      );

  /// How a habit's or category's stored color is drawn in this theme. Saved
  /// colors never change; Light deepens colors too pale to see on white,
  /// Sepia warms and softens them to sit on paper, and Dark lifts colors too
  /// dark to see on its surfaces.
  Color habitColor(Color stored) =>
      _adjusted.putIfAbsent((theme, stored.toARGB32()), () => _adjust(stored));

  static final _adjusted = <(AppTheme, int), Color>{};

  /// Contrast every habit color keeps against [surface] (WCAG's 3:1 for
  /// graphics, a little more on Light so colors read as "deepened").
  double get minHabitContrast => theme == AppTheme.light ? 3.2 : 3.0;

  static const _sepiaInk = Color(0xFF8A5A2B);

  Color _adjust(Color stored) {
    var hsl = HSLColor.fromColor(stored);
    if (theme == AppTheme.sepia) {
      final softened = hsl.withSaturation(hsl.saturation * 0.62).toColor();
      hsl = HSLColor.fromColor(Color.lerp(softened, _sepiaInk, 0.15)!);
    }
    final lighten = theme == AppTheme.dark;
    for (var i = 0; i < 60 && contrast(hsl.toColor(), surface) < minHabitContrast; i++) {
      final next = (hsl.lightness + (lighten ? 0.02 : -0.02)).clamp(0.0, 1.0);
      if (next == hsl.lightness) break;
      hsl = hsl.withLightness(next);
    }
    return hsl.toColor();
  }

  /// A soft background in [color] on [surface]: the chip behind a habit's
  /// icon, or (with a stronger [alpha]) a highlighted card.
  Color tint(Color color, {double? alpha}) => Color.alphaBlend(
      habitColor(color).withValues(alpha: alpha ?? (theme == AppTheme.dark ? 0.22 : 0.12)), surface);

  /// Text or an icon that reads on [fill] (a habit color, a done ring):
  /// near-black or near-white, whichever stands out more.
  Color onColor(Color fill) {
    const ink = Color(0xFF0E1013);
    final paper = theme == AppTheme.sepia ? sepia.surface : const Color(0xFFFFFFFF);
    return contrast(ink, fill) > contrast(paper, fill) ? ink : paper;
  }

  /// WCAG contrast ratio between two colors, 1 to 21.
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
  }

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) => other == null || t < 0.5 ? this : other;
}
