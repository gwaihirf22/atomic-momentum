import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'app_style.dart';
import 'ios_typography.dart';

/// The Cupertino and Material themes, both built from one [AppPalette].
class IOSTheme {
  static CupertinoThemeData cupertino(AppPalette palette) => CupertinoThemeData(
        brightness: palette.brightness,
        primaryColor: palette.accent,
        primaryContrastingColor: palette.onAccent,
        scaffoldBackgroundColor: palette.background,
        barBackgroundColor: palette.background,
        textTheme: IOSTypography.textTheme(palette),
      );

  /// Material theme for the Material widgets inside the Cupertino app (and
  /// for Android): the palette's accent instead of Material 3's default
  /// purple, flat app bars, the app's corner radii, and the palette itself as
  /// an extension so widgets can read it with [AppPalette.of].
  static ThemeData material(AppPalette palette) {
    final scheme = ColorScheme.fromSeed(seedColor: palette.accent, brightness: palette.brightness).copyWith(
      primary: palette.accent,
      onPrimary: palette.onAccent,
      surface: palette.background,
      onSurface: palette.text,
      onSurfaceVariant: palette.textSecondary,
      surfaceTint: Colors.transparent,
      error: palette.danger,
      outline: palette.separator,
    );

    return ThemeData(
      brightness: palette.brightness,
      colorScheme: scheme,
      primaryColor: palette.accent,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardColor: palette.surface,
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyle.cardRadius)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyle.cardRadius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppStyle.cardRadius)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.text,
        contentTextStyle: TextStyle(color: palette.background),
        // The bar is inverted (light on Dark, dark otherwise), so its action
        // takes the other side's amber
        actionTextColor: palette.brightness == Brightness.dark ? AppPalette.light.accent : palette.orbStart,
      ),
      dividerColor: palette.separator,
    );
  }
}
