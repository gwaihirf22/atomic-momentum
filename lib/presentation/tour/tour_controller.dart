import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/shared_preferences_datasource.dart';

import '../../screens/habit_detail_screen.dart';
import '../../screens/ios_main_navigation.dart';
import '../widgets/habit_card.dart';
import 'tour.dart';
import 'tour_anchor.dart';
import 'tour_events.dart';
import 'world_scope.dart';

/// How a launch begins: a new install takes the Habits tour, someone who
/// had habits before tours existed is offered it once, everyone else
/// nothing (tours then come on each tab's first visit).
enum TourStart {
  firstRun,
  offer,
  none;

  /// Decided from what's stored: tours never started, with or without
  /// habits. A launch from a notification tap goes straight to the habit.
  static TourStart of(SharedPreferences prefs, {bool fromNotification = false}) {
    if (fromNotification || prefs.containsKey(TourStore.key)) return none;
    final habits = prefs.getString(SharedPreferencesDataSource.habitsKey);
    final hasHabits = habits != null && habits.trim() != '[]' && habits.trim().isNotEmpty;
    return hasHabits ? offer : firstRun;
  }
}

/// Which tours have been seen: the one key tours write to the person's own
/// storage.
class TourStore {
  static const key = 'tours_seen_v1';

  final SharedPreferences _prefs;
  TourStore(this._prefs);

  /// Whether the person has been offered tours at all (a new install, or
  /// one updated from before tours, hasn't).
  bool get started => _prefs.containsKey(key);

  Set<TourId> get seen => {
        for (final name in _prefs.getStringList(key) ?? const <String>[])
          if (TourId.values.where((t) => t.name == name).firstOrNull case final id?) id,
      };

  Future<void> markSeen(TourId id) => _prefs.setStringList(key, ({...seen, id}.map((t) => t.name).toList()..sort()));

  /// Starts the store with nothing seen (the offer to take them was made).
  Future<void> start() async {
    if (!started) await _prefs.setStringList(key, const []);
  }

  /// "Show tours again".
  Future<void> reset() => _prefs.setStringList(key, const []);
}

/// Runs one tour at a time: switches to its world and tab, makes each step
/// ready (pages opened, its target brought into view), listens for the thing
/// a step waits for, and puts the person back where they were at the end.
class TourController extends ChangeNotifier {
  final WorldController worlds;
  final TourStore? store;

  /// Every tour, by id (tests pass their own).
  final Map<TourId, Tour> tours;

  /// Where tour steps' targets register.
  final TourAnchors anchors;

  /// Called when a tour ends, finished or skipped (the first run asks for
  /// notification permission then).
  void Function(TourId id, {required bool finished})? onEnd;

  TourController({required this.worlds, required this.tours, required this.anchors, this.store});

  Tour? _tour;
  int _step = 0;
  bool _ready = false;
  StreamSubscription<TourEvent>? _events;

  Tour? get tour => _tour;
  int get stepIndex => _step;
  TourStep? get step => _tour?.steps[_step];
  bool get isRunning => _tour != null;

  /// The current step is ready to show (its moves done, its target placed).
  bool get isReady => _ready;

  /// The habit id the step is about, in the world showing.
  String? get stepHabitId {
    final name = step?.habit;
    final demo = worlds.world.demo;
    if (name == null || demo == null) return null;
    return demo.habits.habits.where((h) => h.name == name).firstOrNull?.id;
  }

  bool _offering = false;

  /// "New: short tours" is showing (to people who had habits before tours).
  bool get isOffering => _offering;

  /// Offers the Habits tour, once: whatever the answer, it isn't offered
  /// again.
  Future<void> offer() async {
    if (isRunning || _offering) return;
    _offering = true;
    notifyListeners();
    await store?.start();
  }

  /// "Start".
  Future<void> acceptOffer() async {
    _offering = false;
    notifyListeners();
    await start(TourId.habits);
  }

  /// "Not now": the Habits tour counts as seen, so the other tabs' tours
  /// still come on their first visit.
  Future<void> declineOffer() async {
    _offering = false;
    notifyListeners();
    await store?.markSeen(TourId.habits);
  }

  /// "Show tours again": each comes back on its next visit.
  Future<void> showAgain() async => store?.reset();

  Future<void> start(TourId id) async {
    final tour = tours[id];
    if (tour == null || isRunning) return;
    _tour = tour;
    _step = 0;
    _ready = false;
    notifyListeners();
    if (tour.world == TourWorld.example) {
      await worlds.enterDemo(tab: tour.tab);
    } else {
      worlds.world.nav.show(tour.tab);
    }
    _events = TourEvents.stream.listen(_heard);
    await _prepare();
  }

  void _heard(TourEvent event) {
    final wait = step?.wait;
    if (_ready && wait != null && wait.matches(event, stepHabitId)) next();
  }

  /// Moves on; after the last step, ends the tour.
  Future<void> next() async {
    final tour = _tour;
    if (tour == null) return;
    if (_step + 1 >= tour.steps.length) return _end(finished: true);
    _step++;
    _ready = false;
    notifyListeners();
    await _prepare();
  }

  Future<void> back() async {
    if (_tour == null || _step == 0) return;
    _step--;
    _ready = false;
    notifyListeners();
    await _prepare();
  }

  Future<void> skip() => _end(finished: false);

  Future<void> _end({required bool finished}) async {
    final tour = _tour;
    if (tour == null) return;
    // Gone at once; the bookkeeping follows
    final events = _events;
    _events = null;
    _tour = null;
    _ready = false;
    if (worlds.world.isDemo) worlds.exitDemo();
    notifyListeners();
    onEnd?.call(tour.id, finished: finished);
    unawaited(events?.cancel());
    await store?.markSeen(tour.id);
  }

  /// Does the step's moves, then waits for its target to be built and on
  /// screen (scrolling to it), a frame at a time.
  Future<void> _prepare() async {
    final step = this.step;
    if (step == null) return;
    for (final move in step.before) {
      await _frame();
      final nav = worlds.world.nav;
      switch (move) {
        case ShowTab(:final tab):
          nav.show(tab);
        case BackToTabs():
          nav.popAllToRoot();
        case OpenHabitPage(:final habit):
          final demo = worlds.world.demo;
          final id = demo?.habits.habits.where((h) => h.name == habit).firstOrNull?.id;
          final navigator = nav.navigatorOf(nav.current.value);
          if (id != null && navigator != null) {
            unawaited(navigator.push(CupertinoPageRoute<void>(builder: (_) => HabitDetailScreen(habitId: id))));
          }
        case CloseSwipes():
          HabitCard.closeSwipes();
        case ToOwnHabits():
          worlds.exitDemo(tab: AppTab.habits);
      }
    }
    final anchor = step.anchor;
    if (anchor != null) await _reveal(anchor, step);
    if (!identical(this.step, step)) return;
    _ready = true;
    notifyListeners();
  }

  /// Brings the step's target into view: waits for it to be built (pages
  /// slide in, tabs build on first show), scrolling down the page to find
  /// one not built yet, then scrolls it to a third of the way down.
  Future<void> _reveal(TourAnchorId anchor, TourStep step) async {
    for (var tries = 0; tries < 40; tries++) {
      await _frame();
      if (!identical(this.step, step)) return;
      final context = anchors.find(anchor, tag: stepHabitId == null ? null : _tagFor(anchor));
      if (context != null) {
        if (!context.mounted) continue;
        final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
        await Scrollable.ensureVisible(
          context,
          alignment: 0.3,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
        return;
      }
      // Not built yet: further down a lazily built page, perhaps
      if (tries > 3) _scrollDown();
    }
    debugPrint('Tour: no ${anchor.name} for step "${step.text}"');
  }

  /// Anchors there are several of carry the habit's id.
  String? _tagFor(TourAnchorId anchor) => switch (anchor) {
        TourAnchorId.habitCard ||
        TourAnchorId.habitPlus ||
        TourAnchorId.habitRing ||
        TourAnchorId.habitTwoMinute ||
        TourAnchorId.holdUndo ||
        TourAnchorId.calendarDayHabit =>
          stepHabitId,
        _ => null,
      };

  /// Scrolls the page showing in the current tab a screen further.
  void _scrollDown() {
    final navigator = worlds.world.nav.navigatorOf(worlds.world.nav.current.value);
    ScrollableState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (state.widget.axis == Axis.vertical) {
          found = state;
          return;
        }
      }
      element.visitChildElements(visit);
    }

    final context = navigator?.context;
    if (context is Element) context.visitChildElements(visit);
    final position = found?.position;
    if (position == null || position.pixels >= position.maxScrollExtent) return;
    position.jumpTo((position.pixels + position.viewportDimension * 0.8).clamp(0, position.maxScrollExtent));
  }

  Future<void> _frame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    WidgetsBinding.instance.ensureVisualUpdate();
    return completer.future;
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }
}
