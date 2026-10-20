import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/feedback/haptics.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/category.dart';
import '../providers/category_provider.dart';
import 'category_icons.dart';
import '../tour/tour_anchor.dart';

/// Progress rings, one per category, that double as the filter.
///
/// Each ring fills with the category's average progress toward its habits'
/// targets in the current period, so it moves with every tick. Tapping a
/// ring filters to it; tapping the selected ring again shows all habits.
/// Up to [ringsPerPage] rings sit in one row; more are split into pages of
/// that many, swiped sideways with page dots, so every ring keeps the same
/// width (a 44pt+ tap target on a 375pt-wide iPhone).
class CategoryRingsBar extends StatefulWidget {
  static const ringsPerPage = 6;

  final List<Category> categories;

  /// Keyed by category id.
  final Map<String, CategoryStats> stats;
  final String? selectedId;
  final ValueChanged<String> onTap;

  /// Long-pressing any ring (e.g. to manage categories).
  final VoidCallback? onLongPress;

  const CategoryRingsBar({
    Key? key,
    required this.categories,
    required this.stats,
    required this.selectedId,
    required this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<CategoryRingsBar> createState() => _CategoryRingsBarState();
}

class _CategoryRingsBarState extends State<CategoryRingsBar> {
  PageController? _pageController;
  int _page = 0;

  // Fewer rings per page with large text, so labels stay readable
  int _perPage = CategoryRingsBar.ringsPerPage;

  int get _pageCount => (widget.categories.length / _perPage).ceil();
  bool get _paged => widget.categories.length > _perPage;

  int _pageOf(String? id) {
    final index = widget.categories.indexWhere((c) => c.id == id);
    return index < 0 ? 0 : index ~/ _perPage;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perPage = MediaQuery.textScalerOf(context).scale(1) > 1.15 ? 4 : CategoryRingsBar.ringsPerPage;
    if (_pageController != null && perPage == _perPage) return;
    _perPage = perPage;
    // Open on the page that holds the selected ring
    _page = _pageOf(widget.selectedId);
    _pageController?.dispose();
    _pageController = PageController(initialPage: _page);
  }

  @override
  void didUpdateWidget(CategoryRingsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fewer categories (after a delete) can leave us past the last page
    final lastPage = _pageCount == 0 ? 0 : _pageCount - 1;
    if (_page > lastPage) {
      _page = lastPage;
      if (_pageController!.hasClients) _pageController!.jumpToPage(lastPage);
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController!.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Widget _ring(Category category) => _CategoryRing(
        category: category,
        stats: widget.stats[category.id],
        isSelected: widget.selectedId == category.id,
        onTap: () => widget.onTap(category.id),
        onLongPress: widget.onLongPress,
      );

  @override
  Widget build(BuildContext context) => TourAnchor(id: TourAnchorId.categoryRings, child: _bar(context));

  Widget _bar(BuildContext context) {
    if (!_paged) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final category in widget.categories) Expanded(child: _ring(category))],
        ),
      );
    }

    final perPage = _perPage;
    // Ring, gap and up to two lines of label, growing with the text size
    final pageHeight = _CategoryRing.ringSize + 4 + 2 * MediaQuery.textScalerOf(context).scale(12) * 1.3 + 4;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        children: [
          SizedBox(
            height: pageHeight,
            child: PageView.builder(
              key: const Key('ringPager'),
              controller: _pageController,
              itemCount: _pageCount,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, page) {
                final pageCategories = widget.categories.skip(page * perPage).take(perPage).toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final category in pageCategories) Expanded(child: _ring(category)),
                      // Pad the last page so its rings are as wide as the others
                      for (var i = pageCategories.length; i < perPage; i++) const Expanded(child: SizedBox()),
                    ],
                  ),
                );
              },
            ),
          ),
          _PageDots(
            count: _pageCount,
            current: _page,
            onPrevious: _page > 0 ? () => _goToPage(_page - 1) : null,
            onNext: _page < _pageCount - 1 ? () => _goToPage(_page + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PageDots({required this.count, required this.current, this.onPrevious, this.onNext});

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.of(context).text;
    // Adjustable for VoiceOver: swipe up/down to change page
    return Semantics(
      key: const Key('ringPageDots'),
      label: 'Category page ${current + 1} of $count',
      onIncrease: onNext,
      onDecrease: onPrevious,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(i == current ? 0.8 : 0.25),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRing extends StatelessWidget {
  static const double ringSize = 48;
  static const double _strokeWidth = 4.5;

  final Category category;
  final CategoryStats? stats;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CategoryRing({
    required this.category,
    required this.stats,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final total = stats?.totalHabits ?? 0;
    final completed = stats?.completedHabits ?? 0;
    final fraction = total == 0 ? 0.0 : stats!.averageProgress.clamp(0.0, 1.0);
    final percent = (fraction * 100).round();
    final palette = AppPalette.of(context);
    final color = palette.habitColor(category.color);
    final labelColor = palette.text;

    return Semantics(
      key: Key('categoryRing_${category.id}'),
      button: true,
      selected: isSelected,
      label: total == 0
          ? '${category.name}, no habits'
          : '${category.name}, $percent percent, $completed of $total habits complete',
      excludeSemantics: true,
      onLongPressHint: onLongPress != null ? 'Arrange' : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        onLongPress: onLongPress,
        child: Opacity(
          // Empty categories stay tappable but recede
          opacity: total == 0 && !isSelected ? 0.45 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: fraction),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedFraction, child) => CustomPaint(
                    painter: _RingPainter(
                      fraction: animatedFraction,
                      color: color,
                      trackColor: color.withOpacity(palette.brightness == Brightness.dark ? 0.35 : 0.25),
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
              // Wraps to a second line rather than shrinking below 12pt
              Text(
                category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: isSelected ? color : labelColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction.clamp(0.0, 1.0), false, stroke..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.trackColor != trackColor || old.fillColor != fillColor;
}
