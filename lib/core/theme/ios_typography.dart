import 'package:flutter/cupertino.dart';
import 'ios_colors.dart';

class IOSTypography {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // iOS Typography Scale
  static const double largeTitleSize = 34.0;
  static const double title3Size = 20.0;
  static const double headlineSize = 17.0;
  static const double bodySize = 17.0;
  static const double calloutSize = 16.0;
  static const double caption1Size = 12.0;

  // Light Theme Text Styles
  static TextStyle get largeTitleLight => const TextStyle(
        fontSize: largeTitleSize,
        fontWeight: bold,
        color: IOSColors.label,
        letterSpacing: 0.37,
      );

  static TextStyle get title3Light => const TextStyle(
        fontSize: title3Size,
        fontWeight: regular,
        color: IOSColors.label,
        letterSpacing: 0.38,
      );

  static TextStyle get headlineLight => const TextStyle(
        fontSize: headlineSize,
        fontWeight: semibold,
        color: IOSColors.label,
        letterSpacing: -0.41,
      );

  static TextStyle get bodyLight => const TextStyle(
        fontSize: bodySize,
        fontWeight: regular,
        color: IOSColors.label,
        letterSpacing: -0.41,
      );

  static TextStyle get calloutLight => const TextStyle(
        fontSize: calloutSize,
        fontWeight: regular,
        color: IOSColors.label,
        letterSpacing: -0.32,
      );

  static TextStyle get caption1Light => const TextStyle(
        fontSize: caption1Size,
        fontWeight: regular,
        color: IOSColors.label,
        letterSpacing: 0.0,
      );

  // Dark Theme Text Styles
  static TextStyle get largeTitleDark => const TextStyle(
        fontSize: largeTitleSize,
        fontWeight: bold,
        color: IOSColors.labelDark,
        letterSpacing: 0.37,
      );

  static TextStyle get title3Dark => const TextStyle(
        fontSize: title3Size,
        fontWeight: regular,
        color: IOSColors.labelDark,
        letterSpacing: 0.38,
      );

  static TextStyle get headlineDark => const TextStyle(
        fontSize: headlineSize,
        fontWeight: semibold,
        color: IOSColors.labelDark,
        letterSpacing: -0.41,
      );

  static TextStyle get bodyDark => const TextStyle(
        fontSize: bodySize,
        fontWeight: regular,
        color: IOSColors.labelDark,
        letterSpacing: -0.41,
      );

  static TextStyle get calloutDark => const TextStyle(
        fontSize: calloutSize,
        fontWeight: regular,
        color: IOSColors.labelDark,
        letterSpacing: -0.32,
      );

  static TextStyle get caption1Dark => const TextStyle(
        fontSize: caption1Size,
        fontWeight: regular,
        color: IOSColors.labelDark,
        letterSpacing: 0.0,
      );

  // Cupertino Text Themes
  static CupertinoTextThemeData get lightTextTheme => CupertinoTextThemeData(
        primaryColor: IOSColors.label,
        textStyle: bodyLight,
        navTitleTextStyle: headlineLight,
        navLargeTitleTextStyle: largeTitleLight,
        navActionTextStyle: bodyLight.copyWith(color: IOSColors.systemBlue),
        pickerTextStyle: bodyLight,
        dateTimePickerTextStyle: bodyLight,
        tabLabelTextStyle: caption1Light,
      );

  static CupertinoTextThemeData get darkTextTheme => CupertinoTextThemeData(
        primaryColor: IOSColors.labelDark,
        textStyle: bodyDark,
        navTitleTextStyle: headlineDark,
        navLargeTitleTextStyle: largeTitleDark,
        navActionTextStyle: bodyDark.copyWith(color: IOSColors.systemBlue),
        pickerTextStyle: bodyDark,
        dateTimePickerTextStyle: bodyDark,
        tabLabelTextStyle: caption1Dark,
      );

  // Helper methods for common text styles
  static TextStyle getHabitTitle(bool isDark) => 
      isDark ? title3Dark : title3Light;

  static TextStyle getHabitSubtitle(bool isDark) => 
      isDark ? calloutDark : calloutLight;

}