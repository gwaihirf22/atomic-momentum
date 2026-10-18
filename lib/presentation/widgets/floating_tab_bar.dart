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

  /// When set, the tab turns into a "+" with this label while it's selected,
  /// and tapping it then adds (Habits: "Add habit").
  final String? addLabel;

  const FloatingTab({required this.label, required this.icon, required this.activeIcon, this.addLabel});
}

/// The main tab bar: a rounded, translucent bar floating above the content
/// (which scrolls under it, blurred). The Habits tab doubles as the app's
/// "+": selected, it becomes a small amber orb, and a tap adds a habit.
/// Built by hand rather than with CupertinoTabBar, which can't float; it
/// works the same on iOS 16 and later.
class FloatingTabBar extends StatelessWidget {
  /// The bar's height (labels are capped at [maxLabelScale], as iOS caps tab
  /// bar labels, so it never grows).
  static const height = 66.0;

  /// The "+" orb a tab with an add state shows while selected.
  static const addOrbSize = 34.0;
  static const sideMargin = 16.0;
  static const maxLabelScale = 1.35;

  /// Space between the bar and the bottom of the screen, given the device's
  /// bottom safe area (the home indicator): it sits a little into that area,
  /// as iOS's own floating bars do.
  static double bottomGap(double safeBottom) => math.max(12.0, safeBottom - 12);

  /// How much of the bottom of the screen the bar covers, so the end of a
  /// scrolling list can clear it.
  static double coveredHeight(double safeBottom) => bottomGap(safeBottom) + height;

  final List<FloatingTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// A tap on the selected tab that has an add state.
  final VoidCallback onAdd;

  /// A finger sliding along the bar is over this tab: it only switches to
  /// it (never adds, nor goes back to a tab's first page).
  final ValueChanged<int>? onSlide;

  const FloatingTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
    this.onSlide,
  });

  static const _padding = 6.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final shape = BorderRadius.circular(height / 2);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxLabelScale,
      child: SizedBox(
        height: height,
        child: Stack(
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
            LayoutBuilder(
              builder: (context, constraints) {
                void slide(Offset position) {
                  final slot = (position.dx - _padding) / ((constraints.maxWidth - 2 * _padding) / tabs.length);
                  onSlide?.call(slot.floor().clamp(0, tabs.length - 1));
                }

                return GestureDetector(
                  key: const Key('tabBarSlide'),
                  behavior: HitTestBehavior.translucent,
                  excludeFromSemantics: true,
                  onHorizontalDragStart: onSlide == null ? null : (details) => slide(details.localPosition),
                  onHorizontalDragUpdate: onSlide == null ? null : (details) => slide(details.localPosition),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _padding),
                    child: Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: _TabButton(
                              key: Key('tab_${tabs[i].label.toLowerCase()}'),
                              tab: tabs[i],
                              selected: i == currentIndex,
                              onTap: () => onTap(i),
                              onAdd: onAdd,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
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
  final VoidCallback onAdd;

  const _TabButton({super.key, required this.tab, required this.selected, required this.onTap, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final adding = selected && tab.addLabel != null;
    final color = selected ? palette.accent : palette.textSecondary;
    void tap() {
      Haptics.selection();
      adding ? onAdd() : onTap();
    }

    final Widget icon = adding
        ? Container(
            key: const Key('addHabitButton'),
            width: FloatingTabBar.addOrbSize,
            height: FloatingTabBar.addOrbSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: palette.orb,
              boxShadow: [BoxShadow(color: palette.orbShadow, blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: const Icon(CupertinoIcons.add, size: 22, color: AppPalette.onOrb),
          )
        : SizedBox(
            key: ValueKey(selected),
            height: FloatingTabBar.addOrbSize,
            child: Icon(selected ? tab.activeIcon : tab.icon, size: 24, color: color),
          );

    return Semantics(
      button: true,
      selected: selected,
      label: adding ? tab.addLabel : tab.label,
      hint: adding ? 'Adds a new habit' : null,
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: icon,
              ),
              const SizedBox(height: 2),
              // Shrinks rather than being cut off in a narrow slot
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  adding ? tab.addLabel! : tab.label,
                  maxLines: 1,
                  style:
                      TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: color),
                ),
              ),
            ],
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

/// Whether the floating bar has faded away (on Inspire, after a few seconds
/// untouched), so a page can let its own controls go quiet with it.
class TabBarFade extends InheritedWidget {
  final bool faded;

  const TabBarFade({super.key, required this.faded, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TabBarFade>()?.faded ?? false;

  @override
  bool updateShouldNotify(TabBarFade oldWidget) => oldWidget.faded != faded;
}
