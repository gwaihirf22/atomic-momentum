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
  categoryRings,
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
  // Arrange
  arrangeSwitch,
  arrangeCategory,
  arrangeHabit,
  arrangeAddCategory,
  // Settings
  settingsHelp,
  settingsFreezes,
  settingsNotifications;

  /// The key a screen already gives this widget, for anchors found by key
  /// rather than wrapped in a [TourAnchor] ([tag] completes keys with an id
  /// in them). Null for those that are wrapped.
  String? keyFor(String? tag) => switch (this) {
        calendarGrid => 'calendarGrid',
        calendarDayHabit => 'dayHabit_$tag',
        insightsMomentum => 'insightsMomentum',
        insightsHeatmap => 'insightsDays',
        insightsAchievements => 'insightsAchievements',
        inspireQuote => 'inspireQuoteText',
        inspireActions => 'inspireActionsFade',
        inspireSearch => 'inspireSearch',
        storySentence => 'storySentence',
        storyHardDay => 'storyHardDay',
        editorStyleSwitch => 'switchHabitStyle',
        arrangeSwitch => 'groupByCategorySwitch',
        arrangeAddCategory => 'addCategory',
        settingsHelp => 'openTours',
        settingsFreezes => 'freezeBankTile',
        settingsNotifications => 'defaultReminderTime',
        detailRing => 'detailRing',
        detailFreeze => 'detailFreeze',
        detailMomentum => 'detailMomentum',
        detailHeatmap => 'detailHeatmap',
        detailEdit => 'detailEdit',
        _ => null,
      };
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
  /// Whether hidden tabs are told apart by their tickers being off (the
  /// app's); a still picture has every ticker off, and only its own tab.
  final bool tickersShowHidden;

  TourAnchors({this.tickersShowHidden = true});

  final _anchors = <_TourAnchorState>{};

  /// Where to search for anchors found by key (the scope's own context).
  BuildContext? _root;

  /// The last widget found by key, kept while it's mounted, so following it
  /// every frame doesn't search the whole tree.
  final _byKey = <(TourAnchorId, String?), Element>{};

  void _add(_TourAnchorState anchor) => _anchors.add(anchor);
  void _remove(_TourAnchorState anchor) => _anchors.remove(anchor);

  /// The context of the visible [id] (with [tag], if given): built, in a
  /// tab that's showing, on the page on top. Null when there's none.
  BuildContext? find(TourAnchorId id, {String? tag}) {
    for (final anchor in _anchors) {
      if (anchor.widget.id != id || (tag != null && anchor.widget.tag != tag)) continue;
      final context = anchor._key.currentContext;
      if (context != null && _shows(context, tickersShowHidden)) return context;
    }
    final key = id.keyFor(tag);
    if (key == null) return null;
    final cached = _byKey[(id, tag)];
    if (cached != null && cached.mounted && cached.widget.key == ValueKey(key) && _shows(cached, tickersShowHidden)) {
      return cached;
    }
    _byKey.remove((id, tag));
    final found = _search(key);
    if (found != null) _byKey[(id, tag)] = found;
    return found;
  }

  /// Built, in a tab that's showing, on the page on top, laid out.
  static bool _shows(BuildContext context, bool tickersShowHidden) {
    if (!context.mounted || (tickersShowHidden && !TickerMode.valuesOf(context).enabled)) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final box = context.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize;
  }

  /// The first showing widget keyed [key] below the scope, skipping what's
  /// kept offstage (tabs not showing).
  Element? _search(String key) {
    final root = _root;
    if (root == null || !root.mounted) return null;
    final want = ValueKey(key);
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) return;
      if (widget.key == want && _shows(element, tickersShowHidden)) {
        found = element;
        return;
      }
      element.visitChildElements(visit);
    }

    (root as Element).visitChildElements(visit);
    return found;
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

  TourAnchorScope({super.key, required this.anchors, required Widget child})
      : super(child: _Root(anchors: anchors, child: child));

  static TourAnchors? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<TourAnchorScope>()?.anchors;

  @override
  bool updateShouldNotify(TourAnchorScope oldWidget) => oldWidget.anchors != anchors;
}

/// Tells [anchors] where its scope's tree starts, for anchors found by key.
class _Root extends StatelessWidget {
  final TourAnchors anchors;
  final Widget child;
  const _Root({required this.anchors, required this.child});

  @override
  Widget build(BuildContext context) {
    anchors._root = context;
    return child;
  }
}
