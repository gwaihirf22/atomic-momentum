import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_style.dart';

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

  const LargeTitleScaffold({
    super.key,
    required this.title,
    required this.header,
    this.trailing,
    required this.slivers,
    required this.backgroundColor,
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
    final separator = CupertinoDynamicColor.resolve(CupertinoColors.separator, context);
    // Material Scaffold hosts SnackBars; Cupertino scaffolds can't show them
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: CupertinoPageScaffold(
        backgroundColor: widget.backgroundColor,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: widget.backgroundColor,
          border: _collapsed ? Border(bottom: BorderSide(color: separator, width: 0.5)) : null,
          middle: AnimatedOpacity(
            key: const Key('collapsedTitle'),
            opacity: _collapsed ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Text(widget.title),
          ),
          trailing: widget.trailing,
        ),
        child: SafeArea(
          child: CustomScrollView(
            controller: _controller,
            slivers: [
              SliverToBoxAdapter(child: widget.header),
              ...widget.slivers,
            ],
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

  @override
  Widget build(BuildContext context) {
    final label = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
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
                  child: Text(
                    title,
                    key: titleKey,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 32,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: label,
                    ),
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
