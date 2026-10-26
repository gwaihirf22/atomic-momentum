import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_palette.dart';

/// Which side of the spotlight the bubble prefers.
enum BubbleSide { auto, above, below }

/// A tour's spotlight: the screen dimmed with [AppPalette.scrim] except for a
/// rounded hole around [target], and a speech [bubble] beside it with an
/// arrow pointing in. With no target the bubble sits in the middle, arrowless.
///
/// Touches never reach the app, except inside the hole when [passThrough]
/// (a "try it" step); [onTapHole] hears taps there otherwise.
class TourSpotlight extends StatefulWidget {
  /// What to light up, in global coordinates; null for none.
  final Rect? target;
  final Widget bubble;
  final BubbleSide side;

  /// A "try it" step: the ring pulses gently and touches in the hole pass
  /// through to the app.
  final bool tryIt;
  final bool passThrough;
  final VoidCallback? onTapHole;

  /// What covers the bottom of the screen (the floating tab bar), which the
  /// bubble keeps clear of.
  final double bottomCovered;

  const TourSpotlight({
    super.key,
    required this.target,
    required this.bubble,
    this.side = BubbleSide.auto,
    this.tryIt = false,
    this.passThrough = false,
    this.onTapHole,
    this.bottomCovered = 0,
  });

  /// Room left around the target, and the hole's corners.
  static const padding = 6.0;
  static const radius = 14.0;

  /// The gap between the hole and the bubble's arrow tip.
  static const gap = 6.0;

  /// The hole drawn around [target].
  static RRect holeFor(Rect target) =>
      RRect.fromRectAndRadius(target.inflate(padding), const Radius.circular(radius));

  @override
  State<TourSpotlight> createState() => _TourSpotlightState();
}

class _TourSpotlightState extends State<TourSpotlight> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(TourSpotlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final pulse = widget.tryIt && widget.target != null && !MediaQuery.disableAnimationsOf(context);
    if (pulse && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!pulse && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final target = widget.target;
    final hole = target == null ? null : TourSpotlight.holeFor(target);
    final media = MediaQuery.of(context);
    return Stack(children: [
      Positioned.fill(
        child: _TourBarrier(
          hole: hole,
          passThrough: widget.passThrough,
          onTapHole: widget.onTapHole,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => CustomPaint(
              painter: CutoutPainter(
                hole: hole,
                scrim: palette.scrim,
                ring: palette.accent,
                pulse: widget.tryIt ? _pulse.value : null,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: _Callout(
          hole: hole?.outerRect,
          side: widget.side,
          top: media.padding.top + 8,
          bottom: math.max(media.padding.bottom, widget.bottomCovered) + 8,
          arrowColor: palette.surface,
          child: widget.bubble,
        ),
      ),
    ]);
  }
}

/// The dim with a rounded hole, its accent ring, and on "try it" steps a
/// second ring breathing outwards ([pulse] 0 to 1).
class CutoutPainter extends CustomPainter {
  final RRect? hole;
  final Color scrim;
  final Color ring;
  final double? pulse;

  const CutoutPainter({required this.hole, required this.scrim, required this.ring, this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final hole = this.hole;
    if (hole == null) {
      canvas.drawRect(screen, Paint()..color = scrim);
      return;
    }
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(screen)
      ..addRRect(hole);
    canvas.drawPath(dim, Paint()..color = scrim);
    canvas.drawRRect(
      hole,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final t = pulse;
    if (t != null && t > 0) {
      canvas.drawRRect(
        hole.inflate(10 * t),
        Paint()
          ..color = ring.withValues(alpha: 0.6 * (1 - t))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(CutoutPainter old) =>
      old.hole != hole || old.scrim != scrim || old.ring != ring || old.pulse != pulse;
}

/// Puts the bubble on the side of the hole with room for it (preferring
/// [side]) and paints its arrow at the hole's middle, clear of the bubble's
/// corners. With too little room either side, or no hole, the bubble sits in
/// the middle of the space, arrowless.
class _Callout extends SingleChildRenderObjectWidget {
  final Rect? hole;
  final BubbleSide side;
  final double top;
  final double bottom;
  final Color arrowColor;

  const _Callout({
    required this.hole,
    required this.side,
    required this.top,
    required this.bottom,
    required this.arrowColor,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderCallout(hole: hole, side: side, top: top, bottom: bottom, arrowColor: arrowColor);

  @override
  void updateRenderObject(BuildContext context, RenderCallout renderObject) {
    renderObject
      ..hole = hole
      ..side = side
      ..top = top
      ..bottom = bottom
      ..arrowColor = arrowColor;
  }
}

/// Where a tour's bubble goes: see [_Callout]. Exposes where it went, for
/// tests.
class RenderCallout extends RenderShiftedBox {
  RenderCallout({
    required Rect? hole,
    required BubbleSide side,
    required double top,
    required double bottom,
    required Color arrowColor,
  })  : _hole = hole,
        _side = side,
        _top = top,
        _bottom = bottom,
        _arrowColor = arrowColor,
        super(null);

  static const arrowSize = Size(20, 10);
  static const margin = 16.0;
  static const maxWidth = 340.0;

  Rect? _hole;
  set hole(Rect? value) {
    if (value == _hole) return;
    _hole = value;
    markNeedsLayout();
  }

  BubbleSide _side;
  set side(BubbleSide value) {
    if (value == _side) return;
    _side = value;
    markNeedsLayout();
  }

  double _top;
  set top(double value) {
    if (value == _top) return;
    _top = value;
    markNeedsLayout();
  }

  double _bottom;
  set bottom(double value) {
    if (value == _bottom) return;
    _bottom = value;
    markNeedsLayout();
  }

  Color _arrowColor;
  set arrowColor(Color value) {
    if (value == _arrowColor) return;
    _arrowColor = value;
    markNeedsPaint();
  }

  /// Where the arrow's base starts (its left end), and whether it points up
  /// at a hole above the bubble; null with no arrow.
  Offset? arrowAt;
  bool arrowUp = true;

  /// The arrow points sideways at a hole beside the bubble (a tall target,
  /// such as the iPad's sidebar): left when [arrowLeft], else right.
  bool arrowSideways = false;
  bool arrowLeft = true;

  /// Where the bubble ended up, in this box.
  Rect get bubbleRect => (child!.parentData! as BoxParentData).offset & child!.size;

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    final data = child.parentData! as BoxParentData;
    final width = math.min(size.width - 2 * margin, maxWidth);
    final regionTop = _top;
    final regionBottom = size.height - _bottom;
    final hole = _hole;
    arrowAt = null;
    arrowSideways = false;

    final region = math.max(0.0, regionBottom - regionTop);
    // Its full height first: every word shows, wherever it goes
    child.layout(BoxConstraints(minWidth: width, maxWidth: width, maxHeight: region), parentUsesSize: true);
    final height = child.size.height;
    if (hole == null) {
      data.offset = Offset((size.width - width) / 2, regionTop + (region - height) / 2);
      return;
    }
    final above = hole.top - TourSpotlight.gap - arrowSize.height - regionTop;
    final below = regionBottom - (hole.bottom + TourSpotlight.gap + arrowSize.height);
    final fitsBelow = height <= below, fitsAbove = height <= above;
    if (!fitsBelow && !fitsAbove) {
      // A tall target with room at its side (the iPad's sidebar): beside it,
      // level with its middle, the arrow pointing across
      final rightRoom = size.width - margin - (hole.right + TourSpotlight.gap + arrowSize.height);
      final leftRoom = hole.left - TourSpotlight.gap - arrowSize.height - margin;
      if (rightRoom >= width || leftRoom >= width) {
        final toRight = rightRoom >= width;
        final top = (hole.center.dy - height / 2).clamp(regionTop, math.max(regionTop, regionBottom - height)).toDouble();
        final left = toRight
            ? hole.right + TourSpotlight.gap + arrowSize.height
            : hole.left - TourSpotlight.gap - arrowSize.height - width;
        data.offset = Offset(left, top);
        final arrowY = hole.center.dy.clamp(top + 18.0 + arrowSize.width / 2, top + height - 18.0 - arrowSize.width / 2).toDouble() -
            arrowSize.width / 2;
        arrowAt = Offset(toRight ? hole.right + TourSpotlight.gap : left + width, arrowY);
        arrowSideways = true;
        arrowLeft = toRight;
        return;
      }
      // No room beside a big target either: over its edge, on the roomier
      // side, arrowless, rather than hiding words
      final left = (hole.center.dx - width / 2).clamp(margin, size.width - margin - width);
      data.offset = Offset(left, below >= above ? regionBottom - height : regionTop);
      return;
    }
    final preferBelow = switch (_side) {
      BubbleSide.below => true,
      BubbleSide.above => false,
      BubbleSide.auto => hole.center.dy < (regionTop + regionBottom) / 2,
    };
    // The preferred side if it fits, else the other
    final goBelow = preferBelow ? fitsBelow : !fitsAbove;

    final left = (hole.center.dx - width / 2).clamp(margin, size.width - margin - width);
    final corner = 18.0 + arrowSize.width / 2;
    final arrowX = hole.center.dx.clamp(left + corner, left + width - corner) - arrowSize.width / 2;
    if (goBelow) {
      final arrowY = hole.bottom + TourSpotlight.gap;
      data.offset = Offset(left, arrowY + arrowSize.height);
      arrowAt = Offset(arrowX, arrowY);
      arrowUp = true;
    } else {
      final y = hole.top - TourSpotlight.gap - arrowSize.height - height;
      data.offset = Offset(left, y);
      arrowAt = Offset(arrowX, y + height);
      arrowUp = false;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final at = arrowAt;
    if (at != null) {
      final o = offset + at;
      final w = arrowSize.width, h = arrowSize.height;
      // Overlaps the bubble by a pixel so no seam shows
      final path = arrowSideways
          ? (arrowLeft
              ? (Path()
                ..moveTo(o.dx + h + 1, o.dy)
                ..lineTo(o.dx, o.dy + w / 2)
                ..lineTo(o.dx + h + 1, o.dy + w))
              : (Path()
                ..moveTo(o.dx - 1, o.dy)
                ..lineTo(o.dx + h, o.dy + w / 2)
                ..lineTo(o.dx - 1, o.dy + w)))
          : arrowUp
          ? (Path()
            ..moveTo(o.dx, o.dy + h + 1)
            ..lineTo(o.dx + w / 2, o.dy)
            ..lineTo(o.dx + w, o.dy + h + 1))
          : (Path()
            ..moveTo(o.dx, o.dy - 1)
            ..lineTo(o.dx + w / 2, o.dy + h)
            ..lineTo(o.dx + w, o.dy - 1));
      context.canvas.drawPath(path..close(), Paint()..color = _arrowColor);
    }
    super.paint(context, offset);
  }

  @override
  bool hitTestSelf(Offset position) => false;
}

/// Absorbs every touch, except inside [hole] when [passThrough]; taps in the
/// hole otherwise go to [onTapHole].
class _TourBarrier extends SingleChildRenderObjectWidget {
  final RRect? hole;
  final bool passThrough;
  final VoidCallback? onTapHole;

  const _TourBarrier({required this.hole, required this.passThrough, this.onTapHole, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTourBarrier(hole: hole, passThrough: passThrough, onTapHole: onTapHole);

  @override
  void updateRenderObject(BuildContext context, _RenderTourBarrier renderObject) {
    renderObject
      ..hole = hole
      ..passThrough = passThrough
      ..onTapHole = onTapHole;
  }
}

class _RenderTourBarrier extends RenderProxyBox {
  RRect? hole;
  bool passThrough;
  VoidCallback? onTapHole;
  Offset? _down;

  _RenderTourBarrier({required this.hole, required this.passThrough, this.onTapHole});

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final inHole = hole?.contains(localToGlobal(position)) ?? false;
    if (inHole && passThrough) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    final hole = this.hole;
    if (hole == null || onTapHole == null) return;
    if (event is PointerDownEvent) {
      _down = event.position;
    } else if (event is PointerUpEvent) {
      final down = _down;
      _down = null;
      if (down != null && hole.contains(down) && hole.contains(event.position)) onTapHole!();
    } else if (event is PointerCancelEvent) {
      _down = null;
    }
  }
}
