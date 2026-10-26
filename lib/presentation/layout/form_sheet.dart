import 'package:flutter/cupertino.dart';

import '../../core/theme/app_palette.dart';
import 'app_layout.dart';

/// How the habit editor (and pages like it) open: full screen on a phone,
/// and on an iPad as a form sheet, a card centred over the dimmed app, the
/// way iPad apps present a form.
abstract final class FormSheet {
  /// The sheet's size on an iPad, at most (it shrinks to fit a smaller window).
  static const maxSize = Size(620, 860);

  static Route<T> route<T>(BuildContext context, WidgetBuilder builder, {bool fullscreenDialog = false}) {
    if (!AppLayout.of(context).hasSidebar) {
      return CupertinoPageRoute<T>(fullscreenDialog: fullscreenDialog, builder: builder);
    }
    return _FormSheetRoute<T>(builder: builder, barrierColor: AppPalette.of(context).scrim);
  }
}

class _FormSheetRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  _FormSheetRoute({required this.builder, required Color barrierColor}) : _barrierColor = barrierColor;

  final Color _barrierColor;

  @override
  Color? get barrierColor => _barrierColor;

  // A form with unsaved changes asks before closing: never by a stray tap
  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final padding = MediaQuery.paddingOf(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: FormSheet.maxSize.width, maxHeight: FormSheet.maxSize.height),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: LayoutBuilder(
                // The page inside sees the sheet as its whole screen
                builder: (context, constraints) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: constraints.biggest,
                    padding: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                    viewInsets: MediaQuery.viewInsetsOf(context).copyWith(
                      bottom: (MediaQuery.viewInsetsOf(context).bottom - padding.bottom).clamp(0, double.infinity),
                    ),
                  ),
                  child: Builder(builder: builder),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
