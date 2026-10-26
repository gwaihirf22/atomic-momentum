import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';
import 'floating_tab_bar.dart';

/// A main tab's page with an iOS-style large title: a big header at the top
/// of the scrolling content that hands over to a small centered title in the
/// navigation bar once it scrolls away.
///
/// Custom rather than CupertinoSliverNavigationBar so the header can hold
/// more than a title (a date line, the momentum ring, month controls) and
/// use the app's display font.
class LargeTitleScaffold extends StatefulWidget {
  /// Shown in the navigation bar once the header has scrolled off.
  final String title;

  /// The big header (usually a [LargeTitleHeader]).
  final Widget header;
  final Widget? trailing;
  final List<Widget> slivers;
  final Color backgroundColor;

  /// How the page scrolls (e.g. not at all while something inside is pinched).
  final ScrollPhysics? physics;

  /// The widest the page's content gets (iPad); wider, it's centred. Null:
  /// the whole width (Calendar's month beside its day).
  final double? maxContentWidth;

  const LargeTitleScaffold({
    super.key,
    required this.title,
    required this.header,
    this.trailing,
    required this.slivers,
    required this.backgroundColor,
    this.physics,
    this.maxContentWidth,
  });

  @override
  State<LargeTitleScaffold> createState() => _LargeTitleScaffoldState();
}

class _LargeTitleScaffoldState extends State<LargeTitleScaffold> {
  // About where the large title's text has scrolled under the bar
  static const _collapseOffset = 44.0;

  final _controller = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final collapsed = _controller.hasClients && _controller.offset > _collapseOffset;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final separator = AppPalette.of(context).separator;
    // Under the floating tab bar, the content scrolls on beneath it; this
    // space at the end lets the last item clear it, and SnackBars sit above it
    final tabBarInset = TabBarInset.of(context);
    // Material Scaffold hosts SnackBars; Cupertino scaffolds can't show them
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      extendBody: true,
      bottomNavigationBar: tabBarInset > 0 ? SizedBox(height: tabBarInset) : null,
      body: CupertinoPageScaffold(
        backgroundColor: widget.backgroundColor,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: widget.backgroundColor,
          // Sets the status bar icons for the theme (Sepia counts as light)
          brightness: AppPalette.of(context).brightness,
          border: _collapsed ? Border(bottom: BorderSide(color: separator, width: 0.5)) : null,
          middle: AnimatedOpacity(
            key: const Key('collapsedTitle'),
            opacity: _collapsed ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Text(widget.title),
          ),
          trailing: widget.trailing,
        ),
        // The page's rows (ListTiles, switches) draw their ink here, on the
        // page, rather than under its background
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            bottom: false,
            // Inside the Scaffold, the bottom padding includes the tab bar
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Centred within the cap, on wide windows
                final max = widget.maxContentWidth;
                final inset = max == null ? 0.0 : ((constraints.maxWidth - max) / 2).clamp(0.0, double.infinity);
                Widget fit(Widget sliver) => inset == 0
                    ? sliver
                    : SliverPadding(padding: EdgeInsets.symmetric(horizontal: inset), sliver: sliver);
                return CustomScrollView(
                controller: _controller,
                physics: widget.physics,
                slivers: [
                  fit(SliverToBoxAdapter(child: widget.header)),
                  for (final sliver in widget.slivers) fit(sliver),
                  // The home indicator, and the tab bar when there is one
                  SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
                ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The large title block: an optional small date-style line above a big
/// title in the display font, and an optional accessory on the right.
class LargeTitleHeader extends StatelessWidget {
  /// Display font for large titles.
  static const fontFamily = 'Sora';

  final String? eyebrow;
  final String title;
  final Widget? accessory;
  final Key? titleKey;

  const LargeTitleHeader({super.key, this.eyebrow, required this.title, this.accessory, this.titleKey});

  /// Title sizes to try, largest first: a longer title steps down so it fits
  /// in [maxTitleLines] lines, and wraps further only at the smallest size.
  static const titleSizes = [32.0, 28.0, 24.0];
  static const maxTitleLines = 2;

  /// The largest of [titleSizes] at which [title] fits in [maxTitleLines]
  /// lines of [width] (with the device's text size applied).
  static double fittingSize(
    BuildContext context,
    String title,
    TextStyle Function(double size) styleAt,
    double width,
  ) {
    for (final size in titleSizes) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: styleAt(size)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: maxTitleLines,
      )..layout(maxWidth: width);
      if (!painter.didExceedMaxLines) return size;
    }
    return titleSizes.last;
  }

  @override
  Widget build(BuildContext context) {
    final label = AppPalette.of(context).text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding + 4, 4, AppStyle.screenPadding, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Text(
                    eyebrow!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: secondaryLabel(context),
                    ),
                  ),
                Semantics(
                  header: true,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      TextStyle styleAt(double size) => TextStyle(
                            fontFamily: fontFamily,
                            fontSize: size,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                            color: label,
                          );
                      final size = fittingSize(context, title, styleAt, constraints.maxWidth);
                      return Text(
                        title,
                        key: titleKey,
                        // Wraps if it must: never cut off
                        style: styleAt(size),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (accessory != null) ...[const SizedBox(width: 12), accessory!],
        ],
      ),
    );
  }
}
