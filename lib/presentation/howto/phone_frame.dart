import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../screens/habit_detail_screen.dart';
import '../../screens/ios_main_navigation.dart';
import '../tour/tour_anchor.dart';
import '../tour/world_scope.dart';

/// One picture in How-to: the real app on a tab (and a habit's page, if
/// [habitPage] names one), on the example habits, with [highlight] ringed.
/// [height] says how much of the phone to show around it.
class HowToScene {
  final AppTab tab;

  /// An example habit whose page is open (by name).
  final String? habitPage;
  final TourAnchorId? highlight;

  /// Which one, by example habit name, for highlights there are several of.
  final String? habit;

  /// How much of the 844 pt tall phone to show, centred on [highlight]
  /// (from the top without one).
  final double height;

  /// What it shows, for VoiceOver.
  final String alt;

  const HowToScene({
    required this.tab,
    this.habitPage,
    this.highlight,
    this.habit,
    this.height = 420,
    required this.alt,
  });
}

/// A live, still picture of [scene]: the app itself, built at an iPhone's
/// size (390 × 844), scaled to fit the width, never touchable or animated,
/// in the reader's theme. Never stale: it's the app as it is.
class PhonePicture extends StatefulWidget {
  final HowToScene scene;

  /// The example world it shows (one per How-to visit).
  final AppWorld world;

  const PhonePicture({super.key, required this.scene, required this.world});

  static const size = Size(390, 844);

  @override
  State<PhonePicture> createState() => _PhonePictureState();
}

class _PhonePictureState extends State<PhonePicture> {
  final _anchors = TourAnchors(tickersShowHidden: false);
  final _frameKey = GlobalKey();

  /// Where the highlight is, in the phone's own coordinates.
  Rect? _ring;
  bool _settled = false;

  /// This picture's own world: its own navigator and tabs, on the shared
  /// example habits.
  late final AppWorld _world = AppWorld.example(widget.world.demo!, initialTab: widget.scene.tab);

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    await _frame();
    final page = widget.scene.habitPage;
    if (page != null) {
      final id = _world.demo!.habits.habits.where((h) => h.name == page).firstOrNull?.id;
      final navigator = _world.nav.navigatorOf(widget.scene.tab);
      if (id != null && navigator != null) {
        unawaited(navigator.push(PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => HabitDetailScreen(habitId: id),
          transitionDuration: Duration.zero,
        )));
      }
    }
    for (var i = 0; i < 6; i++) {
      await _frame();
    }
    // A highlight further down the page: scroll to it, then bring it to the
    // middle, as someone would before taking a screenshot
    for (var tries = 0; tries < 12 && mounted; tries++) {
      final context = _anchorContext();
      if (context != null && context.mounted) {
        // Its own list only (Scrollable.ensureVisible would scroll the guide
        // page around the picture too)
        final box = context.findRenderObject();
        final position = Scrollable.maybeOf(context)?.position;
        if (box != null && position != null) {
          await position.ensureVisible(box, alignment: 0.4);
          await _frame();
        }
        break;
      }
      if (widget.scene.highlight == null || !_scrollDown()) break;
      await _frame();
    }
    if (!mounted) return;
    setState(() {
      _ring = _find();
      _settled = true;
    });
  }

  BuildContext? _anchorContext() {
    final highlight = widget.scene.highlight;
    if (highlight == null) return null;
    final name = widget.scene.habit;
    final tag = name == null ? null : _world.demo!.habits.habits.where((h) => h.name == name).firstOrNull?.id;
    return _anchors.find(highlight, tag: tag);
  }

  /// Scrolls the picture's main list (its tallest vertical one) a screen
  /// further; false at the end.
  bool _scrollDown() {
    final root = _frameKey.currentContext;
    if (root is! Element) return false;
    ScrollableState? found;
    var tallest = 0.0;
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (state.widget.axis == Axis.vertical && state.position.hasViewportDimension) {
          final height = state.position.viewportDimension;
          if (height > tallest) {
            tallest = height;
            found = state;
          }
        }
      }
      element.visitChildElements(visit);
    }

    root.visitChildElements(visit);
    final position = found?.position;
    if (position == null || position.pixels >= position.maxScrollExtent) return false;
    position.jumpTo(math.min(position.pixels + position.viewportDimension * 0.8, position.maxScrollExtent));
    return true;
  }

  Rect? _find() {
    final context = _anchorContext();
    final box = context?.findRenderObject() as RenderBox?;
    final frame = _frameKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || frame == null) return null;
    return box.localToGlobal(Offset.zero, ancestor: frame) & box.size;
  }

  Future<void> _frame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    WidgetsBinding.instance.ensureVisualUpdate();
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final scene = widget.scene;
    const phone = PhonePicture.size;
    // Which slice of the phone to show: around the highlight, or the top
    final ring = _ring;
    final shown = math.min(scene.height, phone.height);
    final top = ring == null ? 0.0 : (ring.center.dy - shown / 2).clamp(0.0, phone.height - shown);

    final app = MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: phone,
        padding: const EdgeInsets.only(top: 47, bottom: 34),
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
        viewInsets: EdgeInsets.zero,
        textScaler: TextScaler.noScaling,
        disableAnimations: true,
        accessibleNavigation: false,
      ),
      child: WorldScope(
        world: _world,
        child: TourAnchorScope(
          anchors: _anchors,
          child: HeroControllerScope.none(
            child: Navigator(
              key: _world.navigatorKey,
              onGenerateRoute: (_) => PageRouteBuilder<void>(
                pageBuilder: (_, __, ___) => IOSMainNavigation(
                  demo: true,
                  initialTab: scene.tab,
                  controller: _world.nav,
                ),
                transitionDuration: Duration.zero,
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      image: true,
      label: scene.alt,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: palette.separator),
            borderRadius: BorderRadius.circular(16),
          ),
          child: AspectRatio(
            aspectRatio: phone.width / shown,
            child: FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: phone.width,
                height: shown,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: phone.height,
                    maxHeight: phone.height,
                    child: Transform.translate(
                      offset: Offset(0, -top),
                      child: SizedBox.fromSize(
                        key: _frameKey,
                        size: phone,
                        child: Stack(children: [
                          Positioned.fill(
                            child: ExcludeFocus(
                              child: IgnorePointer(child: TickerMode(enabled: false, child: app)),
                            ),
                          ),
                          if (ring != null)
                            Positioned.fromRect(
                              key: const Key('howToRing'),
                              rect: ring.inflate(6),
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: palette.accent, width: 3),
                                  ),
                                ),
                              ),
                            ),
                          if (!_settled) Positioned.fill(child: ColoredBox(color: palette.background)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
