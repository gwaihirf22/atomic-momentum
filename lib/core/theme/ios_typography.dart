import 'package:flutter/cupertino.dart';
import 'app_palette.dart';

/// iOS's text scale. Styles carry no color: it comes from the palette.
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

  static const largeTitle = TextStyle(fontSize: largeTitleSize, fontWeight: bold, letterSpacing: 0.37);
  static const title3 = TextStyle(fontSize: title3Size, fontWeight: regular, letterSpacing: 0.38);
  static const headline = TextStyle(fontSize: headlineSize, fontWeight: semibold, letterSpacing: -0.41);
  static const body = TextStyle(fontSize: bodySize, fontWeight: regular, letterSpacing: -0.41);
  static const callout = TextStyle(fontSize: calloutSize, fontWeight: regular, letterSpacing: -0.32);
  static const caption1 = TextStyle(fontSize: caption1Size, fontWeight: regular, letterSpacing: 0.0);

  /// Cupertino's text theme in [palette]'s colors.
  static CupertinoTextThemeData textTheme(AppPalette palette) {
    TextStyle inText(TextStyle style) => style.copyWith(color: palette.text);
    return CupertinoTextThemeData(
      primaryColor: palette.accent,
      textStyle: inText(body),
      navTitleTextStyle: inText(headline),
      navLargeTitleTextStyle: inText(largeTitle),
      navActionTextStyle: body.copyWith(color: palette.accent),
      pickerTextStyle: inText(body),
      dateTimePickerTextStyle: inText(body),
      tabLabelTextStyle: inText(caption1),
    );
  }

  /// A message's heading (empty and error states).
  static TextStyle habitTitle(AppPalette palette) => title3.copyWith(color: palette.text);

  /// A message's explanation (empty and error states).
  static TextStyle habitSubtitle(AppPalette palette) => callout.copyWith(color: palette.textSecondary);
}
