import 'package:flutter/widgets.dart';

/// What a tour can point at. A screen marks each with a [TourAnchor]; for
/// things there are several of (a habit's card), the tag says which.
enum TourAnchorId {
  // The tab bar
  tabBar,
  addHabit,
  tabCalendar,
  tabInsights,
  tabInspire,
  tabSettings,
  // Habits
  overallMomentum,
  habitCard,
  habitPlus,
  habitRing,
  habitTwoMinute,
  holdUndo,
  // The habit page
  detailRing,
  detailWeek,
  detailFreeze,
  detailMomentum,
  detailHeatmap,
  detailEdit,
  // Calendar
  calendarGrid,
  calendarDayHabit,
  // Insights
  insightsMomentum,
  insightsHeatmap,
  insightsAchievements,
  // Inspire
  inspireQuote,
  inspireActions,
  inspireSearch,
  // The editor
  storySentence,
  storyHardDay,
  editorStyleSwitch,
  // Settings
  settingsHelp,
  settingsFreezes,
  settingsNotifications,
}

/// Marks [child] as something a tour can point at. Free when no tour runs:
/// it only registers its key with the nearest [TourAnchorScope].
class TourAnchor extends StatefulWidget {
  final TourAnchorId id;

  /// Which one, where there are several ([TourAnchorId.habitCard]: the
  /// habit's id).
  final String? tag;
  final Widget child;

  const TourAnchor({super.key, required this.id, this.tag, required this.child});

  @override
  State<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends State<TourAnchor> {
  final _key = GlobalKey();
  TourAnchors? _anchors;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final anchors = TourAnchorScope.maybeOf(context);
    if (anchors != _anchors) {
      _anchors?._remove(this);
      _anchors = anchors?.._add(this);
    }
  }

  @override
  void dispose() {
    _anchors?._remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}

/// The [TourAnchor]s registered below a [TourAnchorScope], found by id: the
/// app has one, and each How-to picture its own.
class TourAnchors {
  final _anchors = <_TourAnchorState>{};

  void _add(_TourAnchorState anchor) => _anchors.add(anchor);
  void _remove(_TourAnchorState anchor) => _anchors.remove(anchor);

  /// The context of the visible [id] (with [tag], if given): built, in a
  /// tab that's showing, on the page on top. Null when there's none.
  BuildContext? find(TourAnchorId id, {String? tag}) {
    for (final anchor in _anchors) {
      if (anchor.widget.id != id || (tag != null && anchor.widget.tag != tag)) continue;
      final context = anchor._key.currentContext;
      if (context == null || !context.mounted) continue;
      if (!TickerMode.valuesOf(context).enabled) continue;
      if (ModalRoute.of(context)?.isCurrent == false) continue;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      return context;
    }
    return null;
  }

  /// Where [id] is on screen, in global coordinates, or null.
  Rect? rectOf(TourAnchorId id, {String? tag}) {
    final context = find(id, tag: tag);
    final box = context?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Every anchor registered now, for tests.
  @visibleForTesting
  List<(TourAnchorId, String?)> get registered => [for (final a in _anchors) (a.widget.id, a.widget.tag)];
}

/// Where [TourAnchor]s below it register ([anchors]).
class TourAnchorScope extends InheritedWidget {
  final TourAnchors anchors;

  const TourAnchorScope({super.key, required this.anchors, required super.child});

  static TourAnchors? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<TourAnchorScope>()?.anchors;

  @override
  bool updateShouldNotify(TourAnchorScope oldWidget) => oldWidget.anchors != anchors;
}
