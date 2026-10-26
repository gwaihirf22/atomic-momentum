import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  /// Where the platform doesn't say (Android, tests), a window this wide on
  /// its short side counts as a tablet's: the smallest iPad (mini) is 744
  /// points; the iPhone Duo, unfolded, is 669 and stays a phone.
  static const tabletFrom = 700.0;

  /// Whether the device is a tablet: an iPad, as iOS says ([DeviceKind]),
  /// so an iPad in a narrow Split View is still one and a big iPhone never
  /// is; elsewhere, from the window's short side.
  static bool isTablet(BuildContext context) =>
      DeviceKind.tablet ?? MediaQuery.sizeOf(context).shortestSide >= tabletFrom;
}

/// What kind of device this is, as the platform says it (iOS: an iPad or
/// not), asked once at launch ([load]); null where it can't say (Android,
/// tests).
abstract final class DeviceKind {
  static const _channel = MethodChannel('momentum/device');

  static bool? tablet;

  static Future<void> load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      tablet = await _channel.invokeMethod<bool>('isTablet');
    } on MissingPluginException {
      tablet = null;
    } on PlatformException {
      tablet = null;
    }
  }
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

/// [child] (a list that fills the height) no wider than [maxWidth], centred
/// at the top: whole pages such as Arrange and How to on an iPad.
class ReadableColumn extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ReadableColumn({super.key, this.maxWidth = AppLayout.readableMax, required this.child});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
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
