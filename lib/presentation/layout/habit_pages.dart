import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:provider/provider.dart';

import '../../core/theme/app_palette.dart';
import '../../screens/habit_detail_screen.dart';
import '../providers/habit_provider.dart';
import 'app_layout.dart';

/// The habit a detail pane shows beside its list (a wide window), and the
/// day it opened on.
class HabitSelection extends ChangeNotifier {
  String? _habitId;
  DateTime? _day;

  /// Bumped on each choice, so choosing the same habit again opens it afresh.
  int _version = 0;

  String? get habitId => _habitId;
  DateTime? get day => _day;
  int get version => _version;

  void select(String habitId, {DateTime? day}) {
    _habitId = habitId;
    _day = day;
    _version++;
    notifyListeners();
  }

  void clear() {
    if (_habitId == null) return;
    _habitId = null;
    _day = null;
    _version++;
    notifyListeners();
  }
}

/// Lets screens in a tab find the detail pane beside them, if there is one.
class DetailPaneScope extends InheritedNotifier<HabitSelection> {
  const DetailPaneScope({super.key, required HabitSelection selection, required super.child})
      : super(notifier: selection);

  static HabitSelection? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DetailPaneScope>()?.notifier;
}

/// Opening a habit's page: beside the list in a wide window (iPad
/// landscape), otherwise pushed in the tab as on a phone.
abstract final class HabitPages {
  static void open(BuildContext context, String habitId, {DateTime? day}) {
    final pane = DetailPaneScope.maybeOf(context);
    if (pane != null) {
      pane.select(habitId, day: day);
      return;
    }
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => HabitDetailScreen(habitId: habitId, day: day)));
  }

  /// Whether [habitId] is the one showing beside the list (its card is
  /// highlighted).
  static bool isSelected(BuildContext context, String habitId) => DetailPaneScope.maybeOf(context)?.habitId == habitId;

  /// Shows [habitId] beside the list if there's a pane (a notification
  /// tap); false when there isn't.
  static bool selectIfPane(BuildContext context, String habitId) {
    final pane = DetailPaneScope.maybeOf(context);
    pane?.select(habitId);
    return pane != null;
  }
}

/// A list with the selected habit's page beside it: the tab's own navigator
/// on the left, the page (in a navigator of its own, so what it opens stays
/// in the pane) on the right.
class HabitSplitView extends StatelessWidget {
  final HabitSelection selection;
  final Widget list;

  /// Shown while nothing is selected.
  final Widget placeholder;

  const HabitSplitView({super.key, required this.selection, required this.list, required this.placeholder});

  /// How wide the list is, given the room for both.
  static double listWidth(double width) => (width * 0.45).clamp(360.0, 520.0);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: listWidth(constraints.maxWidth), child: list),
          Container(width: 0.5, color: palette.separator),
          Expanded(
            child: ListenableBuilder(
              listenable: selection,
              builder: (context, _) {
                final id = selection.habitId;
                // A habit deleted (or gone with a sync) leaves the pane empty
                final exists = id != null && context.watch<HabitProvider>().getHabitById(id) != null;
                if (!exists) return placeholder;
                return Navigator(
                  key: ValueKey(('pane', selection.version)),
                  onGenerateRoute: (_) => CupertinoPageRoute<void>(
                    builder: (_) => HabitDetailScreen(key: Key('paneHabit_$id'), habitId: id, day: selection.day),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

/// The empty detail pane: a quiet nudge to pick a habit.
class PickAHabit extends StatelessWidget {
  const PickAHabit({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ColoredBox(
      key: const Key('pickAHabit'),
      color: palette.background,
      // Not under a page's scaffold: the app's own text style, explicitly
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
        child: Center(
        child: ReadableWidth(
          maxWidth: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(CupertinoIcons.hand_point_left, size: 40, color: palette.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Pick a habit',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: palette.text),
            ),
            const SizedBox(height: 6),
            Text(
              'Its streak, momentum, notes and every day so far show here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.35, color: palette.textSecondary),
            ),
          ]),
        ),
      ),
      ),
    );
  }
}
