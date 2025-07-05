import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  // Material theme data for compatibility where needed
  static ThemeData getMaterialLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: IOSColors.systemBlue,
      scaffoldBackgroundColor: IOSColors.systemBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: IOSColors.systemBackground,
        foregroundColor: IOSColors.label,
        elevation: 0,
      ),
      cardColor: IOSColors.secondarySystemBackground,
      dividerColor: IOSColors.separator,
    );
  }

  static ThemeData getMaterialDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: IOSColors.systemBlue,
      scaffoldBackgroundColor: IOSColors.systemBackgroundDark,
      appBarTheme: AppBarTheme(
        backgroundColor: IOSColors.systemBackgroundDark,
        foregroundColor: IOSColors.labelDark,
        elevation: 0,
      ),
      cardColor: IOSColors.secondarySystemBackgroundDark,
      dividerColor: IOSColors.separatorDark,
    );
  }
}