import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/ios_colors.dart';
import '../../domain/entities/category.dart';
import '../providers/category_provider.dart';
import 'category_icons.dart';

/// One row of progress rings, one per category, that doubles as the filter.
///
/// Each ring fills with the category's average progress toward its habits'
/// targets in the current period, so it moves with every tick. Tapping a ring filters to it; tapping the selected
/// ring again shows all habits. Sized to fit a 375pt-wide iPhone without
/// scrolling, with 44pt tap targets.
class CategoryRingsBar extends StatelessWidget {
  final List<Category> categories;

  /// Keyed by category id.
  final Map<String, CategoryStats> stats;
  final String? selectedId;
  final ValueChanged<String> onTap;

  /// Long-pressing any ring (e.g. to manage categories).
  final VoidCallback? onLongPress;
  final bool isDark;

  const CategoryRingsBar({
    Key? key,
    required this.categories,
    required this.stats,
    required this.selectedId,
    required this.onTap,
    this.onLongPress,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final category in categories)
            Expanded(
              child: _CategoryRing(
                category: category,
                stats: stats[category.id],
                isSelected: selectedId == category.id,
                isDark: isDark,
                onTap: () => onTap(category.id),
                onLongPress: onLongPress,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryRing extends StatelessWidget {
  static const double _ringSize = 48;
  static const double _strokeWidth = 4.5;

  final Category category;
  final CategoryStats? stats;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CategoryRing({
    required this.category,
    required this.stats,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final total = stats?.totalHabits ?? 0;
    final completed = stats?.completedHabits ?? 0;
    final fraction = total == 0 ? 0.0 : stats!.averageProgress.clamp(0.0, 1.0);
    final percent = (fraction * 100).round();
    final color = category.color;
    final labelColor = isDark ? IOSColors.labelDark : IOSColors.label;

    return Semantics(
      key: Key('categoryRing_${category.id}'),
      button: true,
      selected: isSelected,
      label: total == 0
          ? '${category.name}, no habits'
          : '${category.name}, $percent percent, $completed of $total habits complete',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Opacity(
          // Empty categories stay tappable but recede
          opacity: total == 0 && !isSelected ? 0.45 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _ringSize,
                height: _ringSize,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: fraction),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedFraction, child) => CustomPaint(
                    painter: _RingPainter(
                      fraction: animatedFraction,
                      color: color,
                      trackColor: color.withOpacity(isDark ? 0.35 : 0.25),
                      fillColor: isSelected ? color.withOpacity(0.18) : Colors.transparent,
                      strokeWidth: _strokeWidth,
                    ),
                    child: child,
                  ),
                  child: Center(
                    child: Icon(category.icon, size: 20, color: color),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  category.name,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? color : labelColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  _RingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (fillColor.opacity > 0) {
      canvas.drawCircle(center, radius, Paint()..color = fillColor);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, stroke..color = trackColor);
    if (fraction > 0) {
      // Start at 12 o'clock and run clockwise, like Apple's activity rings
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction.clamp(0.0, 1.0), false,
          stroke..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor;
}
