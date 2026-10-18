import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A sideways drag that moves between the main tabs. It only takes clearly
/// sideways swipes (twice as much across as up or down), so a slightly
/// diagonal scroll still scrolls. Anything inside that takes sideways drags
/// of its own (habit cards, the rings pager, the Calendar grid, switches)
/// wins over it, as the innermost drag always does.
class TabSwipeRecognizer extends HorizontalDragGestureRecognizer {
  TabSwipeRecognizer({super.debugOwner});

  /// How far each pointer has moved since it went down, both ways.
  final _moved = <int, Offset>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _moved[event.pointer] = Offset.zero;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) _moved[event.pointer] = (_moved[event.pointer] ?? Offset.zero) + event.delta;
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    if (!super.hasSufficientGlobalDistanceToAccept(pointerDeviceKind, deviceTouchSlop)) return false;
    final total = _moved.values.fold(Offset.zero, (sum, moved) => sum + moved);
    return total.dx.abs() > 2 * total.dy.abs();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _moved.clear();
    super.didStopTrackingLastPointer(pointer);
  }
}

/// Keeps a sideways swipe on [child] (a habit) from moving to another tab:
/// it claims the drag and does nothing with it.
class TabSwipeBlocker extends StatelessWidget {
  final Widget child;

  const TabSwipeBlocker({super.key, required this.child});

  @override
  Widget build(BuildContext context) => RawGestureDetector(
        excludeFromSemantics: true,
        gestures: {
          HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
            HorizontalDragGestureRecognizer.new,
            (recognizer) => recognizer.onStart = (_) {},
          ),
        },
        child: child,
      );
}
