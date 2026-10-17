import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/feedback/haptics.dart';
import '../../core/theme/app_palette.dart';

/// One tab in the [FloatingTabBar].
class FloatingTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const FloatingTab({required this.label, required this.icon, required this.activeIcon});
}

/// The main tab bar: a rounded, translucent bar floating above the content
/// (which scrolls under it, blurred), with the orb (the app's main "+") in
/// the middle. Built by hand rather than with CupertinoTabBar, which can't
/// float or hold the orb; it works the same on iOS 16 and later.
class FloatingTabBar extends StatelessWidget {
  /// The bar's height (labels are capped at [maxLabelScale], as iOS caps tab
  /// bar labels, so it never grows).
  static const height = 66.0;
  static const orbSize = 58.0;

  /// How far the orb rises above the bar.
  static const orbRise = 13.0;
  static const sideMargin = 16.0;
  static const maxLabelScale = 1.35;

  /// Space between the bar and the bottom of the screen, given the device's
  /// bottom safe area (the home indicator): it sits a little into that area,
  /// as iOS's own floating bars do.
  static double bottomGap(double safeBottom) => math.max(12.0, safeBottom - 12);

  /// How much of the bottom of the screen the bar covers, so the end of a
  /// scrolling list can clear it.
  static double coveredHeight(double safeBottom) => bottomGap(safeBottom) + height + orbRise;

  final List<FloatingTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  /// The orb sits after this many tabs.
  final int orbAfter;

  const FloatingTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
    required this.orbAfter,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final shape = BorderRadius.circular(height / 2);

    Widget tab(int index) => Expanded(
          child: _TabButton(
            key: Key('tab_${tabs[index].label.toLowerCase()}'),
            tab: tabs[index],
            selected: index == currentIndex,
            onTap: () => onTap(index),
          ),
        );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxLabelScale,
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: shape,
                  boxShadow: [BoxShadow(color: palette.barShadow, blurRadius: 30, offset: const Offset(0, 10))],
                ),
                child: ClipRRect(
                  borderRadius: shape,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.bar,
                        borderRadius: shape,
                        border: Border.all(color: palette.barEdge, width: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  for (var i = 0; i < orbAfter; i++) tab(i),
                  _Orb(onTap: onAdd),
                  for (var i = orbAfter; i < tabs.length; i++) tab(i),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final FloatingTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({super.key, required this.tab, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = selected ? palette.accent : palette.textSecondary;
    void tap() {
      Haptics.selection();
      onTap();
    }

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: SizedBox(
          height: FloatingTabBar.height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? tab.activeIcon : tab.icon, size: 24, color: color),
              const SizedBox(height: 3),
              // Shrinks rather than being cut off in a narrow slot
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The amber "+" that adds a habit, raised out of the bar.
class _Orb extends StatelessWidget {
  final VoidCallback onTap;

  const _Orb({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    void tap() {
      Haptics.selection();
      onTap();
    }

    return Semantics(
      button: true,
      label: 'Add habit',
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('addHabitOrb'),
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: Transform.translate(
          offset: const Offset(0, -FloatingTabBar.orbRise),
          child: Container(
            width: FloatingTabBar.orbSize,
            height: FloatingTabBar.orbSize,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: palette.orb,
              // A ring in the page color separates it from the bar
              border: Border.all(color: palette.background, width: 3),
              boxShadow: [BoxShadow(color: palette.orbShadow, blurRadius: 22, offset: const Offset(0, 8))],
            ),
            child: const Icon(CupertinoIcons.add, size: 26, color: AppPalette.onOrb),
          ),
        ),
      ),
    );
  }
}

/// How much of a main tab's page the floating bar covers (0 outside the
/// tabs, e.g. in tests or on pushed pages, where the bar is hidden).
class TabBarInset extends InheritedWidget {
  final double height;

  const TabBarInset({super.key, required this.height, required super.child});

  /// The covered height for the page at [context]: only a tab's first page
  /// has the bar over it.
  static double of(BuildContext context) {
    final inset = context.dependOnInheritedWidgetOfExactType<TabBarInset>()?.height ?? 0;
    if (inset == 0) return 0;
    return ModalRoute.of(context)?.isFirst ?? true ? inset : 0;
  }

  @override
  bool updateShouldNotify(TabBarInset oldWidget) => oldWidget.height != height;
}
