import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/sync/sync_log.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../presentation/layout/app_layout.dart';
import '../presentation/widgets/large_title_scaffold.dart';

/// What sync did on this device, newest first, with Copy (Settings →
/// Momentum Plus, builds with Developer tools only).
class SyncLogScreen extends StatelessWidget {
  final SyncLog log;

  const SyncLogScreen({super.key, required this.log});

  static Future<void> open(BuildContext context, SyncLog log) =>
      Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => SyncLogScreen(log: log)));

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: log.text));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(key: Key('syncLogCopied'), content: Text('Copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final entries = log.entries.reversed.toList();
    return LargeTitleScaffold(
      title: 'Sync log',
      backgroundColor: palette.background,
      maxContentWidth: AppLayout.readableMax,
      header: const LargeTitleHeader(title: 'Sync log'),
      trailing: CupertinoButton(
        key: const Key('syncLogCopy'),
        padding: EdgeInsets.zero,
        onPressed: entries.isEmpty ? null : () => _copy(context),
        child: const Text('Copy'),
      ),
      slivers: [
        if (entries.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppStyle.screenPadding),
              child: Text('Nothing yet.', style: TextStyle(color: palette.textSecondary)),
            ),
          )
        else
          SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 6, AppStyle.screenPadding, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(SyncLog.stampOf(entries[i].at),
                      style: TextStyle(color: palette.textSecondary, fontSize: 13, fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ])),
                  Text(entries[i].text, style: TextStyle(color: palette.text, fontSize: 15)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
