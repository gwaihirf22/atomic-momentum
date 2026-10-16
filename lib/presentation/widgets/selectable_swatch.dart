import 'package:flutter/material.dart';

/// A circular, 44pt selectable swatch with a VoiceOver label, used for color
/// and icon pickers.
class SelectableSwatch extends StatelessWidget {
  // Apple's Human Interface Guidelines: tap targets at least 44x44 pt
  static const double size = 44;

  final String semanticLabel;
  final bool isSelected;
  final VoidCallback onTap;
  final Color fill;
  final Color? borderColor;
  final double borderWidth;
  final Widget? child;

  const SelectableSwatch({
    Key? key,
    required this.semanticLabel,
    required this.isSelected,
    required this.onTap,
    required this.fill,
    required this.borderColor,
    required this.borderWidth,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: borderColor != null ? Border.all(color: borderColor!, width: borderWidth) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
