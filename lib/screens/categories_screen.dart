import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;
import '../core/theme/app_palette.dart';
import 'package:provider/provider.dart';
import '../domain/entities/category.dart';
import '../domain/entities/habit.dart';
import '../presentation/providers/category_provider.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/widgets/category_editor_sheet.dart';
import '../presentation/widgets/category_icons.dart';
import '../presentation/widgets/adaptive.dart';
import 'package:flutter/cupertino.dart';
import '../core/theme/app_style.dart';
import '../core/feedback/haptics.dart';
import '../domain/entities/habit_color.dart';
import '../presentation/widgets/habit_icons.dart';
import '../presentation/widgets/settings_list.dart';
import '../presentation/tour/tour.dart';
import '../presentation/tour/tour_anchor.dart';
import '../presentation/tour/tour_controller.dart';
import '../presentation/tour/world_scope.dart';

/// Arrange (holding a category or a habit's card on Habits, or Settings): the order of
/// categories and habits, and managing categories (add, edit, delete,
/// restore). With "Group by category" on, habits follow their category's
/// place and move within it; off, they go in any order.
class CategoriesScreen extends StatefulWidget {
  /// A habit held on the Habits screen: scrolled to and briefly tinted.
  final String? showHabitId;

  const CategoriesScreen({Key? key, this.showHabitId}) : super(key: key);

  /// Holding a category, or a habit (its card on Habits, its row on
  /// Calendar): Arrange, at that habit. Not during a tour, whose steps
  /// never hold these.
  static void open(BuildContext context, {String? habitId}) {
    if (TourController.maybeOf(context)?.isRunning ?? false) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => CategoriesScreen(showHabitId: habitId)));
  }

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String? get showHabitId => widget.showHabitId;

  @override
  void initState() {
    super.initState();
    // The first visit with habits to arrange brings its tour
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !WorldScope.isDemo(context) && context.read<HabitProvider>().habits.isNotEmpty) {
        TourController.maybeOf(context)?.firstVisit(TourId.arrange);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final habitProvider = context.watch<HabitProvider>();
    final habits = habitProvider.habits;
    final categories = categoryProvider.categories;
    final grouped = habitProvider.groupByCategory;
    final atLimit = categories.length >= Category.maxCount;
    final palette = AppPalette.of(context);

    final addButton = IconButton(
      key: const Key('addCategory'),
      icon: Icon(isCupertino(context) ? CupertinoIcons.add : Icons.add),
      tooltip: atLimit ? 'You can have up to ${Category.maxCount} categories' : 'Add category',
      onPressed: atLimit ? null : () => showCategoryEditorSheet(context),
    );

    return Scaffold(
      backgroundColor: palette.background,
      appBar: isCupertino(context)
          ? CupertinoNavigationBar(
              backgroundColor: palette.background,
              middle: const Text('Arrange'),
              trailing: addButton,
            )
          : AppBar(title: const Text('Arrange'), actions: [addButton]) as PreferredSizeWidget,
      body: CustomScrollView(
        // Every row built, so the habit asked for can be scrolled to
        cacheExtent: 4000,
        slivers: [
          SliverToBoxAdapter(
            child: SettingsSection(
              footer: grouped
                  ? "Habits follow their category's place. Drag a category to move its habits with it; habits move within their category."
                  : 'Habits go in any order, whatever their category.',
              children: [
                SettingsSwitchTile(
                  tileKey: const Key('groupByCategorySwitch'),
                  icon: CupertinoIcons.square_stack_3d_up_fill,
                  iconColor: HabitColor.indigo.color,
                  title: 'Group by category',
                  value: grouped,
                  onChanged: (on) => habitProvider.setGroupByCategory(on),
                ),
              ],
            ),
          ),
          if (grouped)
            _GroupedList(categories: categories, habits: habits, showHabitId: showHabitId)
          else ...[
            const SliverToBoxAdapter(child: SectionHeader('Categories')),
            _CategoryList(categories: categories, habits: habits),
            const SliverToBoxAdapter(child: SectionHeader('Habits')),
            _HabitList(habits: habits, showHabitId: showHabitId),
          ],
          SliverToBoxAdapter(child: _Footer(atLimit: atLimit, habits: habits)),
        ],
      ),
    );
  }
}

Future<void> _moveCategory(BuildContext context, int oldIndex, int newIndex) async {
  final provider = context.read<CategoryProvider>();
  if (!await provider.reorder(oldIndex, newIndex) && context.mounted) {
    _showMessage(context, provider.error ?? 'Could not reorder categories');
  }
}

/// Grouped: each category followed by its habits (those in a deleted or
/// unknown category last, under Uncategorized). Categories drag with their
/// habits; habits drag within their category.
class _GroupedList extends StatefulWidget {
  final List<Category> categories;
  final List<Habit> habits;
  final String? showHabitId;

  const _GroupedList({required this.categories, required this.habits, this.showHabitId});

  @override
  State<_GroupedList> createState() => _GroupedListState();
}

class _GroupedListState extends State<_GroupedList> {
  /// The category being dragged. While one moves, every category's habits
  /// fold into its header: it's lifted with its habits, and lands between
  /// categories, never among another's habits.
  String? _moving;

  /// Room left above the list for the habits folded above the dragged
  /// category, so it stays under the finger while the others gather round.
  double _gather = 0;

  /// The category of the habit being dragged: the habit can't leave it,
  /// and everything else dims.
  String? _within;
  _WithinCategory? _boundary;

  /// Each habit row's, to measure what folds and where a category's habits are.
  final _rowKeys = <String, GlobalKey>{};

  List<Category> get categories => widget.categories;
  List<Habit> get habits => widget.habits;

  void _lift(List<_Row> rows, int index) {
    var above = 0.0;
    for (final row in rows.take(index)) {
      if (row.habit case final habit?) above += _rowKeys[habit.id]?.currentContext?.size?.height ?? 0;
    }
    setState(() {
      _moving = rows[index].groupId;
      _gather = above;
    });
  }

  /// A habit picked up: it may go anywhere among its category's habits.
  void _hold(List<_Row> rows, int index) {
    double? top, bottom;
    for (final row in rows) {
      if (row.habit == null || row.groupId != rows[index].groupId) continue;
      final box = _rowKeys[row.habit!.id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final at = box.localToGlobal(Offset.zero).dy;
      top ??= at;
      bottom = at + box.size.height;
    }
    setState(() {
      _within = rows[index].groupId;
      _boundary = top == null
          ? null
          : _WithinCategory(top: top, bottom: bottom!, scroll: Scrollable.maybeOf(context)?.position);
    });
  }

  void _letGo() {
    if (!mounted || _within == null) return;
    setState(() {
      _within = null;
      _boundary = null;
    });
  }

  void _fold(String? categoryId) {
    if (!mounted || _moving == categoryId) return;
    setState(() {
      _moving = categoryId;
      if (categoryId == null) _gather = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = {for (final c in categories) c.id};
    final rows = <_Row>[
      for (final category in categories) ...[
        _Row.category(category),
        for (final habit in habits)
          if (habit.categoryId == category.id) _Row.habit(habit, category.id),
      ],
    ];
    final lost = [for (final h in habits) if (!active.contains(h.categoryId)) h];
    if (lost.isNotEmpty) {
      rows.add(_Row.category(Category.uncategorized, fixed: true));
      rows.addAll([for (final h in lost) _Row.habit(h, Category.uncategorizedId)]);
    }

    final list = SliverReorderableList(
      itemCount: rows.length,
      proxyDecorator: (child, i, animation) => _Lifted(
        animation: animation,
        // A category with habits is lifted as a little stack of them
        stacked: rows[i].category == null ? 0 : _countHabits(habits, rows[i].groupId!).clamp(0, 2),
        child: child,
      ),
      // Asked for right after onReorderStart
      dragBoundaryProvider: (_) => _boundary,
      onReorderStart: (i) {
        Haptics.selection();
        rows[i].category != null ? _lift(rows, i) : _hold(rows, i);
      },
      // Put back where it was: unfold now (a move unfolds once it's made)
      onReorderEnd: (at) {
        _letGo();
        final from = rows.indexWhere((r) => r.category != null && r.groupId == _moving);
        if (at == from || at == from + 1) _fold(null);
      },
      onReorderItem: (from, to) {
        _drop(context, rows, from, to);
        _fold(null);
      },
      itemBuilder: (context, i) {
        final row = rows[i];
        final category = row.category;
        if (category != null) {
          final index = categories.indexOf(category);
          return _Dim(
            key: Key('categoryRow_${category.id}'),
            dimmed: _within != null && category.id != _within,
            child: _anchored(i == 0 ? TourAnchorId.arrangeCategory : null, _CategoryRow(
              category: category,
              index: i,
              habitCount: _countHabits(habits, category.id),
              draggable: !row.fixed,
              onMove: row.fixed
                  ? null
                  : (by) => _moveCategory(context, index, by < 0 ? index + by : index + by + 1),
              canMoveUp: !row.fixed && index > 0,
              canMoveDown: !row.fixed && index < categories.length - 1,
              onDragCancel: () => _fold(null),
            )),
          );
        }
        final habit = row.habit!;
        final group = [for (final r in rows) if (r.habit != null && r.groupId == row.groupId) r.habit!];
        final at = group.indexOf(habit);
        return _Fold(
          key: Key('arrangeHabit_${habit.id}'),
          folded: _moving != null,
          child: _Dim(
            dimmed: _within != null && row.groupId != _within,
            child: _anchored(rows.indexWhere((r) => r.habit != null) == i ? TourAnchorId.arrangeHabit : null, _HabitRow(
              key: _rowKeys.putIfAbsent(habit.id, GlobalKey.new),
              habit: habit,
              index: i,
              indented: true,
              flash: habit.id == widget.showHabitId,
              canMoveUp: at > 0,
              canMoveDown: at < group.length - 1,
              onMove: (by) => _moveWithin(context, habit, group[at + by]),
              onDragCancel: _letGo,
            )),
          ),
        );
      },
    );
    return SliverMainAxisGroup(
      slivers: [
        // Grows as the habits above fold, by just as much
        SliverToBoxAdapter(
          child: AnimatedContainer(duration: _foldDuration(context), curve: _foldCurve, height: _gather),
        ),
        list,
      ],
    );
  }

  /// A drop at [at] (counted without the row moved): a category moves
  /// (its habits follow on the Habits screen); a habit moves within its
  /// category, or back where it was.
  void _drop(BuildContext context, List<_Row> rows, int from, int at) {
    final moved = rows[from];
    final rest = [...rows]..removeAt(from);
    at = at.clamp(0, rest.length);
    final category = moved.category;
    if (category != null) {
      if (moved.fixed) return;
      final oldIndex = categories.indexOf(category);
      final newIndex = rest.take(at).where((r) => r.category != null && !r.fixed).length;
      if (newIndex != oldIndex) _moveCategory(context, oldIndex, newIndex > oldIndex ? newIndex + 1 : newIndex);
      return;
    }
    final habit = moved.habit!;
    // The category it landed in: the nearest header above the drop
    final header = rest.take(at).lastWhere((r) => r.category != null, orElse: () => const _Row.none());
    if (header.groupId != moved.groupId) {
      Haptics.selection();
      _showMessage(context, 'Habits move within their category. To change one\'s category, edit it.');
      return;
    }
    final provider = context.read<HabitProvider>();
    final others = [for (final h in provider.habits) if (h.id != habit.id) h.id];
    final following = at < rest.length ? rest[at] : null;
    if (following?.habit case final next? when following!.groupId == moved.groupId) {
      provider.moveHabit(habit.id, others.indexOf(next.id));
      return;
    }
    // The last of its category
    final group = [
      for (final r in rest)
        if (r.habit != null && r.groupId == moved.groupId) r.habit!.id,
    ];
    if (group.isEmpty) return;
    provider.moveHabit(habit.id, others.indexOf(group.last) + 1);
  }

  void _moveWithin(BuildContext context, Habit habit, Habit neighbour) {
    final provider = context.read<HabitProvider>();
    final ids = [for (final h in provider.habits) h.id];
    provider.moveHabit(habit.id, ids.indexOf(neighbour.id));
  }
}

/// Not grouped: the categories, in their own order.
class _CategoryList extends StatelessWidget {
  final List<Category> categories;
  final List<Habit> habits;

  const _CategoryList({required this.categories, required this.habits});

  @override
  Widget build(BuildContext context) {
    return SliverReorderableList(
      itemCount: categories.length,
      proxyDecorator: (child, _, animation) => _Lifted(animation: animation, child: child),
      onReorderStart: (_) => Haptics.selection(),
      onReorderItem: (from, to) => _moveCategory(context, from, to > from ? to + 1 : to),
      itemBuilder: (context, i) => _CategoryRow(
        key: Key('categoryRow_${categories[i].id}'),
        anchor: i == 0 ? TourAnchorId.arrangeCategory : null,
        category: categories[i],
        index: i,
        habitCount: _countHabits(habits, categories[i].id),
        canMoveUp: i > 0,
        canMoveDown: i < categories.length - 1,
        onMove: (by) => _moveCategory(context, i, by < 0 ? i + by : i + by + 1),
      ),
    );
  }
}

/// Not grouped: every habit, in any order.
class _HabitList extends StatelessWidget {
  final List<Habit> habits;
  final String? showHabitId;

  const _HabitList({required this.habits, this.showHabitId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<HabitProvider>();
    return SliverReorderableList(
      itemCount: habits.length,
      proxyDecorator: (child, _, animation) => _Lifted(animation: animation, child: child),
      onReorderStart: (_) => Haptics.selection(),
      onReorderItem: (from, to) => provider.moveHabit(habits[from].id, to),
      itemBuilder: (context, i) => _HabitRow(
        key: Key('arrangeHabit_${habits[i].id}'),
        anchor: i == 0 ? TourAnchorId.arrangeHabit : null,
        habit: habits[i],
        index: i,
        flash: habits[i].id == showHabitId,
        canMoveUp: i > 0,
        canMoveDown: i < habits.length - 1,
        onMove: (by) => provider.moveHabit(habits[i].id, i + by),
      ),
    );
  }
}

/// A row of the grouped list: a category's header, or one of its habits.
class _Row {
  final Category? category;
  final Habit? habit;

  /// The category a habit row belongs to (Uncategorized for a lost one).
  final String? groupId;

  /// Uncategorized's header: shown, never dragged.
  final bool fixed;

  _Row.category(Category this.category, {this.fixed = false})
      : habit = null,
        groupId = category.id;
  _Row.habit(Habit this.habit, String this.groupId)
      : category = null,
        fixed = false;
  const _Row.none()
      : category = null,
        habit = null,
        groupId = null,
        fixed = false;
}

/// The handle a row drags by, with what VoiceOver says.
class _Handle extends StatelessWidget {
  final int index;
  final String label;
  final Key handleKey;

  /// A drag the system took away (a call, Control Center): no drop comes.
  final VoidCallback? onCancel;

  const _Handle({required this.index, required this.label, required this.handleKey, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: Listener(
        onPointerCancel: onCancel == null ? null : (_) => onCancel!(),
        child: SizedBox(
          key: handleKey,
          width: 44,
          height: 44,
          child: Semantics(
            label: label,
            child: Icon(
              isCupertino(context) ? CupertinoIcons.line_horizontal_3 : Icons.drag_handle,
              color: AppPalette.of(context).textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps a dragged habit among its category's habits: it stops at the
/// category's first and last, with a tick as it meets the edge. Where they
/// were at pick-up, moved along as the list scrolls.
class _WithinCategory extends DragBoundaryDelegate<Rect> {
  final double top;
  final double bottom;
  final ScrollPosition? scroll;
  final double _startPixels;
  bool _atEdge = false;

  _WithinCategory({required this.top, required this.bottom, this.scroll}) : _startPixels = scroll?.pixels ?? 0;

  double get _shift => _startPixels - (scroll?.pixels ?? _startPixels);

  @override
  bool isWithinBoundary(Rect dragged) => dragged.top >= top + _shift && dragged.bottom <= bottom + _shift;

  @override
  Rect nearestPositionWithinBoundary(Rect dragged) {
    final min = top + _shift;
    final max = math.max(min, bottom + _shift - dragged.height);
    final y = dragged.top.clamp(min, max);
    final atEdge = y != dragged.top;
    if (atEdge && !_atEdge) Haptics.selection();
    _atEdge = atEdge;
    return Rect.fromLTWH(dragged.left, y, dragged.width, dragged.height);
  }
}

/// The habit held on the Habits screen: scrolled into view, tinted in its
/// colour, fading to the list's.
class _Flash extends StatefulWidget {
  final Color from;
  final Color to;
  final Widget Function(Color color) builder;

  const _Flash({required this.from, required this.to, required this.builder});

  @override
  State<_Flash> createState() => _FlashState();
}

class _FlashState extends State<_Flash> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Scrollable.ensureVisible(context, alignment: 0.4, duration: _foldDuration(context) * 2, curve: _foldCurve);
      }
    });
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: 1800),
        curve: Curves.easeIn,
        builder: (context, t, _) => widget.builder(Color.lerp(widget.to, widget.from, t)!),
      );
}

/// Rows outside a dragged habit's category, faded back.
class _Dim extends StatelessWidget {
  final bool dimmed;
  final Widget child;

  const _Dim({Key? key, required this.dimmed, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      AnimatedOpacity(opacity: dimmed ? 0.35 : 1, duration: _foldDuration(context), child: child);
}

const _foldCurve = Curves.easeOutCubic;

Duration _foldDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220);

/// A habit row folded away under its category's header while a category
/// is dragged.
class _Fold extends StatelessWidget {
  final bool folded;
  final Widget child;

  const _Fold({Key? key, required this.folded, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final duration = _foldDuration(context);
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: folded ? 0 : 1,
        duration: duration,
        curve: _foldCurve,
        child: AnimatedOpacity(
          opacity: folded ? 0 : 1,
          duration: duration,
          child: IgnorePointer(ignoring: folded, child: ExcludeSemantics(excluding: folded, child: child)),
        ),
      ),
    );
  }
}

/// A row being dragged: raised off the list on a shadow, and for a category
/// with habits, the edges of [stacked] more rows under it: its habits, coming
/// along.
class _Lifted extends StatelessWidget {
  final Animation<double> animation;
  final int stacked;
  final Widget child;

  const _Lifted({required this.animation, this.stacked = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final radius = BorderRadius.circular(AppStyle.cardRadius);
    return AnimatedBuilder(
      animation: animation,
      child: ClipRRect(borderRadius: radius, child: child),
      builder: (context, child) {
        final t = Curves.easeOut.transform(animation.value);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = stacked; i >= 1; i--)
              Positioned.fill(
                left: 10.0 * i,
                right: 10.0 * i,
                bottom: -6.0 * i * t,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: radius,
                    border: Border.all(color: palette.separator),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: radius,
                boxShadow: [BoxShadow(color: palette.barShadow, blurRadius: 24 * t, offset: Offset(0, 8 * t))],
              ),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

/// VoiceOver's way to reorder without dragging.
Map<CustomSemanticsAction, VoidCallback> _moveActions({
  required bool up,
  required bool down,
  required void Function(int by)? onMove,
}) =>
    {
      if (up && onMove != null) const CustomSemanticsAction(label: 'Move up'): () => onMove(-1),
      if (down && onMove != null) const CustomSemanticsAction(label: 'Move down'): () => onMove(1),
    };

class _HabitRow extends StatelessWidget {
  final Habit habit;
  final int index;
  final bool indented;

  /// The habit held on the Habits screen.
  final bool flash;

  /// What a tour points at here, if anything.
  final TourAnchorId? anchor;
  final bool canMoveUp;
  final bool canMoveDown;
  final void Function(int by) onMove;
  final VoidCallback? onDragCancel;

  const _HabitRow({
    Key? key,
    required this.habit,
    required this.index,
    this.indented = false,
    this.flash = false,
    this.anchor,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
    this.onDragCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final category = context.read<CategoryProvider>().resolve(habit.categoryId);
    if (!flash) return _anchored(anchor, _row(context, category, palette.background));
    return _anchored(
      anchor,
      _Flash(
        from: palette.tint(palette.habitColor(habit.color.color), alpha: 0.22),
        to: palette.background,
        builder: (color) => _row(context, category, color),
      ),
    );
  }

  Widget _row(BuildContext context, Category category, Color color) {
    final palette = AppPalette.of(context);
    return Semantics(
      customSemanticsActions: _moveActions(up: canMoveUp, down: canMoveDown, onMove: onMove),
      child: Material(
        color: color,
        child: ListTile(
          contentPadding: EdgeInsets.only(left: indented ? 40 : 16, right: 8),
          leading: Icon(habitIcon(habit, category), color: palette.habitColor(habit.color.color), size: 22),
          title: Text(habit.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: _Handle(
            index: index,
            label: 'Reorder ${habit.name}',
            handleKey: Key('habitDragHandle_${habit.id}'),
            onCancel: onDragCancel,
          ),
        ),
      ),
    );
  }
}

int _countHabits(List<Habit> habits, String categoryId) =>
    habits.where((h) => h.categoryId == categoryId).length;

String _habitCountText(int count) =>
    count == 0 ? 'No habits' : '$count ${count == 1 ? 'habit' : 'habits'}';

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _CategoryIcon extends StatelessWidget {
  final Category category;

  const _CategoryIcon(this.category);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: palette.tint(category.color, alpha: 0.18), shape: BoxShape.circle),
      child: Icon(category.icon, size: 20, color: palette.habitColor(category.color)),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;
  final int index;
  final int habitCount;

  /// Uncategorized's header can't be dragged or edited.
  final bool draggable;
  final bool canMoveUp;
  final bool canMoveDown;
  final void Function(int by)? onMove;
  final VoidCallback? onDragCancel;

  /// What a tour points at here, if anything.
  final TourAnchorId? anchor;

  const _CategoryRow({
    Key? key,
    required this.category,
    required this.index,
    required this.habitCount,
    this.draggable = true,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.onMove,
    this.onDragCancel,
    this.anchor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _anchored(anchor, Semantics(
      customSemanticsActions: _moveActions(up: canMoveUp, down: canMoveDown, onMove: onMove),
      child: Material(
        color: AppPalette.of(context).background,
        child: ListTile(
          leading: _CategoryIcon(category),
          title: Text(category.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(_habitCountText(habitCount)),
          onTap: draggable ? () => showCategoryEditorSheet(context, existing: category) : null,
          trailing: draggable
              ? _Handle(
                  index: index,
                  label: 'Reorder ${category.name}',
                  handleKey: Key('dragHandle_${category.id}'),
                  onCancel: onDragCancel,
                )
              : null,
        ),
      ),
    ));
  }
}

/// [child], marked for a tour when [id] is given.
Widget _anchored(TourAnchorId? id, Widget child) => id == null ? child : TourAnchor(id: id, child: child);

/// Limit note and the Recently Deleted section, below the reorderable list.
class _Footer extends StatelessWidget {
  final bool atLimit;
  final List<Habit> habits;

  const _Footer({required this.atLimit, required this.habits});

  @override
  Widget build(BuildContext context) {
    final deleted = context.watch<CategoryProvider>().deletedCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (atLimit)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'You can have up to ${Category.maxCount} categories.',
              style: TextStyle(color: secondaryLabel(context)),
            ),
          ),
        if (deleted.isNotEmpty) ...[
          const SectionHeader('Recently Deleted'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Habits in a deleted category are kept and shown as Uncategorized.',
              style: TextStyle(color: secondaryLabel(context)),
            ),
          ),
          for (final category in deleted)
            _DeletedRow(
              key: Key('deletedRow_${category.id}'),
              category: category,
              habitCount: _countHabits(habits, category.id),
            ),
        ],
      ],
    );
  }
}

class _DeletedRow extends StatelessWidget {
  final Category category;
  final int habitCount;

  const _DeletedRow({Key? key, required this.category, required this.habitCount}) : super(key: key);

  Future<void> _restore(BuildContext context) async {
    final provider = context.read<CategoryProvider>();
    final restored = await provider.restore(category.id);
    if (!context.mounted) return;
    if (restored == null) {
      _showMessage(context, provider.error ?? 'Could not restore "${category.name}"');
    } else if (restored.name != category.name) {
      _showMessage(context, 'Restored as "${restored.name}"');
    }
  }

  Future<void> _moveHabits(BuildContext context) async {
    final categoryProvider = context.read<CategoryProvider>();
    final target = await chooseAdaptive<Category>(
      context,
      title: 'Move ${_habitCountText(habitCount).toLowerCase()} to…',
      options: [
        for (final c in categoryProvider.categories) AdaptiveOption(c, c.name, key: Key('moveTarget_${c.id}')),
      ],
    );
    if (target == null || !context.mounted) return;

    final moved = await categoryProvider.moveHabits(category.id, target.id);
    if (!context.mounted) return;
    if (moved == null) {
      _showMessage(context, categoryProvider.error ?? 'Could not move the habits');
      return;
    }
    await context.read<HabitProvider>().loadHabits();
    if (context.mounted) {
      _showMessage(context, 'Moved ${_habitCountText(moved).toLowerCase()} to ${target.name}');
    }
  }

  Future<void> _deletePermanently(BuildContext context) async {
    final confirmed = await confirmAdaptive(
      context,
      title: 'Permanently delete "${category.name}"?',
      message: 'This can\'t be undone.',
      confirmLabel: 'Delete Permanently',
      destructive: true,
      confirmKey: const Key('confirmDeletePermanently'),
    );
    if (!confirmed || !context.mounted) return;

    final provider = context.read<CategoryProvider>();
    if (!await provider.deletePermanently(category.id) && context.mounted) {
      _showMessage(context, provider.error ?? 'Could not delete "${category.name}"');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Opacity(opacity: 0.5, child: _CategoryIcon(category)),
      title: Text(category.name, style: TextStyle(color: secondaryLabel(context))),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(habitCount == 0
              ? 'No habits'
              : '${_habitCountText(habitCount)} · shown as Uncategorized'),
          // Wraps on narrow screens rather than overflowing
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: Key('restoreCategory_${category.id}'),
                onPressed: () => _restore(context),
                child: const Text('Restore'),
              ),
              if (habitCount > 0)
                TextButton(
                  key: Key('moveHabits_${category.id}'),
                  onPressed: () => _moveHabits(context),
                  child: const Text('Move habits to…'),
                )
              else
                TextButton(
                  key: Key('deletePermanently_${category.id}'),
                  onPressed: () => _deletePermanently(context),
                  style: TextButton.styleFrom(foregroundColor: AppPalette.of(context).danger),
                  child: const Text('Delete Permanently'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
