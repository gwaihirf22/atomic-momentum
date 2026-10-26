import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// How much room the app has, from the window's width (never the device):
/// an iPad in a narrow Split View gets the phone layout, and the layout
/// changes live as the window is resized.
enum LayoutTier {
  /// Phones, and narrow iPad windows: the floating tab bar, pages push.
  compact,

  /// iPad portrait, or half a screen: a sidebar and one content pane.
  regular,

  /// iPad landscape, a 13-inch iPad upright: a sidebar, a list and a
  /// habit's page side by side.
  wide;

  bool get hasSidebar => this != compact;
  bool get isWide => this == wide;
}

abstract final class AppLayout {
  /// From this width the app has a sidebar (iPad portrait is 744–1032).
  static const regularFrom = 700.0;

  /// From this width a list and a habit's page sit side by side.
  static const wideFrom = 1100.0;

  /// The most text-heavy content (settings, a habit's page, editors) spreads
  /// to; wider, it's centred.
  static const readableMax = 680.0;

  /// The narrowest a card in a grid of cards gets (Insights).
  static const cardMin = 400.0;

  static LayoutTier tierFor(double width) => width >= wideFrom
      ? LayoutTier.wide
      : width >= regularFrom
          ? LayoutTier.regular
          : LayoutTier.compact;

  static LayoutTier of(BuildContext context) => tierFor(MediaQuery.sizeOf(context).width);

  /// How many cards fit across [width], at least [cardMin] each (1 to 3).
  static int columnsFor(double width) => math.max(1, math.min(3, (width / cardMin).floor()));

  /// Whether the device is a tablet (an iPad), from the shorter side of the
  /// window: phones are under 600 points either way round.
  static bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= 600;
}

/// [child] no wider than [maxWidth], centred in whatever room there is.
/// Phones are narrower than the cap, so nothing changes there.
class ReadableWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ReadableWidth({super.key, this.maxWidth = AppLayout.readableMax, required this.child});

  @override
  Widget build(BuildContext context) => Center(
        heightFactor: 1,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

/// What to call the device in the app's words: "this phone" on a phone,
/// "this iPad" or "this tablet" on a tablet.
abstract final class DeviceWords {
  static bool get _apple => defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

  /// "phone", "iPad" or "tablet".
  static String device(BuildContext context) =>
      AppLayout.isTablet(context) ? (_apple ? 'iPad' : 'tablet') : 'phone';

  /// "this phone", "this iPad" or "this tablet".
  static String thisDevice(BuildContext context) => 'this ${device(context)}';

  /// "iPhone" or "iPad", for Apple's own names (restarting it, its settings).
  static String appleDevice(BuildContext context) => AppLayout.isTablet(context) ? 'iPad' : 'iPhone';
}
