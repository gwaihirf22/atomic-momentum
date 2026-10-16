import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shared sizes, so every screen matches the habit cards.
class AppStyle {
  const AppStyle._();

  /// Cards, sheets and dialogs.
  static const double cardRadius = 14;

  /// Steppers, pills and other controls inside a card.
  static const double controlRadius = 12;

  static const double smallRadius = 8;

  /// Side margin for screen content.
  static const double screenPadding = 16;

  /// Gap between cards in a list.
  static const double cardGap = 10;
}

/// True on iPhone, iPad and Mac, where controls should look like iOS's.
bool isCupertino(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// A list section heading in the iOS style: small, in the secondary label
/// color, as in Settings.
class SectionHeader extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(AppStyle.screenPadding + 4, 20, AppStyle.screenPadding, 6),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Text(
          isCupertino(context) ? text.toUpperCase() : text,
          style: TextStyle(
            fontSize: 13,
            letterSpacing: isCupertino(context) ? 0.2 : 0,
            fontWeight: isCupertino(context) ? FontWeight.w400 : FontWeight.w600,
            color: secondaryLabel(context),
          ),
        ),
      ),
    );
  }
}

/// iOS's secondary text color, resolved for light or dark.
Color secondaryLabel(BuildContext context) => CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
