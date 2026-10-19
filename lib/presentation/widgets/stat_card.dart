import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// A card on the habit page and in Insights.
class StatCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Instead of the surface (a frozen day's icy card).
  final Color? color;
  final Color? borderColor;

  const StatCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? AppPalette.of(context).surface,
          borderRadius: BorderRadius.circular(20),
          border: borderColor == null ? null : Border.all(color: borderColor!, width: 1.2),
        ),
        child: child,
      );
}

/// A card's heading, with an optional action on the right.
class StatCardHeading extends StatelessWidget {
  final String text;
  final Widget? action;

  const StatCardHeading(this.text, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final heading = Semantics(
      header: true,
      child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.text)),
    );
    if (action == null) return heading;
    // Side by side when they fit; with large text the action moves under it
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 2,
      children: [heading, action!],
    );
  }
}

/// A small rounded button for a card's heading ("Show month", "Add note").
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PillButton({super.key, required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: palette.text,
        backgroundColor: palette.raised,
        minimumSize: const Size(44, 36),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Wraps rather than overflowing with large text
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        if (icon != null) ...[const SizedBox(width: 4), Icon(icon, size: 12)],
      ]),
    );
  }
}
