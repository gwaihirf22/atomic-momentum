import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../core/feedback/haptics.dart';
import '../../core/theme/app_palette.dart';

enum SyncNowPhase { idle, syncing, synced, failed }

/// What a Sync now button shows after a tap: a spinner while it runs (at
/// least [least], so a quick sync is still seen), then "Synced" or
/// "Couldn't sync" for [shown], then back to the usual.
class SyncNowFeedback extends ChangeNotifier {
  static const least = Duration(milliseconds: 800);
  static const shown = Duration(seconds: 2);

  SyncNowPhase _phase = SyncNowPhase.idle;
  Timer? _back;
  bool _disposed = false;

  SyncNowPhase get phase => _phase;
  bool get isIdle => _phase == SyncNowPhase.idle;
  bool get isSyncing => _phase == SyncNowPhase.syncing;

  /// Runs [work], which says whether it worked.
  Future<void> run(Future<bool> Function() work) async {
    if (isSyncing) return;
    _back?.cancel();
    _set(SyncNowPhase.syncing);
    var ok = false;
    try {
      final results = await Future.wait([work(), Future<bool>.delayed(least, () => true)]);
      ok = results.first;
    } catch (_) {
      ok = false;
    }
    if (_disposed) return;
    _set(ok ? SyncNowPhase.synced : SyncNowPhase.failed);
    if (ok) Haptics.selection();
    _back = Timer(shown, () => _set(SyncNowPhase.idle));
  }

  void _set(SyncNowPhase phase) {
    if (_disposed) return;
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _back?.cancel();
    super.dispose();
  }
}

/// The spinner, "Synced" or "Couldn't sync" beside a Sync now row; nothing
/// while idle. [compact] leaves out the words (beside a habit's Health line).
class SyncNowMark extends StatelessWidget {
  final SyncNowPhase phase;
  final bool compact;

  const SyncNowMark(this.phase, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    Widget marked(IconData icon, Color color, String words) => Semantics(
          liveRegion: true,
          label: words,
          child: ExcludeSemantics(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: color),
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(words, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        );
    return switch (phase) {
      SyncNowPhase.idle => const SizedBox.shrink(),
      SyncNowPhase.syncing => const CupertinoActivityIndicator(key: Key('syncNowSpinner'), radius: 9),
      SyncNowPhase.synced => KeyedSubtree(
          key: const Key('syncNowDone'),
          child: marked(CupertinoIcons.checkmark_circle_fill, palette.good, 'Synced'),
        ),
      SyncNowPhase.failed => KeyedSubtree(
          key: const Key('syncNowFailed'),
          child: marked(CupertinoIcons.exclamationmark_circle_fill, palette.warning, "Couldn't sync"),
        ),
    };
  }
}
