import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_style.dart';
import 'ios_colors.dart';
import 'ios_typography.dart';

class IOSTheme {
  static CupertinoThemeData lightTheme = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: IOSColors.systemBlue,
    primaryContrastingColor: IOSColors.white,
    scaffoldBackgroundColor: IOSColors.systemBackground,
    barBackgroundColor: IOSColors.systemBackground,
    textTheme: IOSTypography.lightTextTheme,
  );

  static CupertinoThemeData darkTheme = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: IOSColors.systemBlue,
    primaryContrastingColor: IOSColors.black,
    scaffoldBackgroundColor: IOSColors.systemBackgroundDark,
    barBackgroundColor: IOSColors.systemBackgroundDark,
    textTheme: IOSTypography.darkTextTheme,
  );

  // Helper method to get theme based on brightness
  static CupertinoThemeData getTheme(Brightness brightness) {
    return brightness == Brightness.light ? lightTheme : darkTheme;
  }

  // Material theme for the Material widgets inside the Cupertino app (and for
  // Android): iOS blue instead of Material 3's default purple, flat app bars,
  // and the app's corner radii
  static ThemeData getMaterialLightTheme() => _material(Brightness.light);

  static ThemeData getMaterialDarkTheme() => _material(Brightness.dark);

  static ThemeData _material(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? IOSColors.systemBackgroundDark : IOSColors.systemBackground;
    final card = dark ? IOSColors.secondarySystemBackgroundDark : IOSColors.secondarySystemBackground;
    final label = dark ? IOSColors.labelDark : IOSColors.label;
    final scheme = ColorScheme.fromSeed(seedColor: IOSColors.systemBlue, brightness: brightness).copyWith(
      primary: IOSColors.systemBlue,
      onPrimary: Colors.white,
      surface: background,
      onSurface: label,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: IOSColors.systemBlue,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: label,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardColor: card,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyle.cardRadius)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyle.cardRadius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppStyle.cardRadius)),
        ),
      ),
      dividerColor: dark ? IOSColors.separatorDark : IOSColors.separator,
    );
  }
}
