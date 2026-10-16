import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/ios_colors.dart';

/// The navigation bar shared by the main tabs: the standard iOS title style,
/// the page background and a hairline divider.
CupertinoNavigationBar appNavigationBar({
  required String title,
  required bool isDark,
  Widget? leading,
  Widget? trailing,
}) {
  final background = isDark ? IOSColors.systemBackgroundDark : IOSColors.systemBackground;
  return CupertinoNavigationBar(
    backgroundColor: background,
    border: Border(
      bottom: BorderSide(color: isDark ? IOSColors.separatorDark : IOSColors.separator, width: 0.5),
    ),
    middle: Text(title),
    leading: leading,
    trailing: trailing,
  );
}
