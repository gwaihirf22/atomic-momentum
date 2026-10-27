import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/feedback/haptics.dart';
import '../core/injection/injection_container.dart';
import '../core/services/plus_store.dart';
import '../core/services/support_link.dart';
import '../core/sync/sync_service.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/habit_color.dart';
import '../presentation/layout/app_layout.dart';
import '../presentation/widgets/adaptive.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/orb_button.dart';
import '../presentation/widgets/settings_list.dart';

/// Momentum Plus: what it is now and what's coming, buying it, Restore
/// Purchases, and (once it's yours, outside the US) tips. Opened from
/// Settings, the Sync switch and Say thanks.
class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => const PlusScreen()));

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  final PlusStore _store = get<PlusStore>();
  late Future<List<PlusOffer>> _offers = _store.offers();

  /// Tips show outside the US, where "Buy Paul a coffee" doesn't.
  bool _tipsHere = false;

  /// The product being bought (its button shows busy).
  String? _buying;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    if (sl.isRegistered<SupportLink>()) {
      get<SupportLink>().isAvailable().then((us) {
        if (mounted && !us) setState(() => _tipsHere = true);
      });
    }
  }

  Future<void> _buy(PlusOffer? offer) async {
    if (offer == null) {
      await _alert("Can't reach the App Store", 'Check your connection and try again.');
      setState(() => _offers = _store.offers());
      return;
    }
    setState(() => _buying = offer.id);
    final outcome = await _store.buy(offer);
    if (!mounted) return;
    setState(() => _buying = null);
    switch (outcome.result) {
      case PurchaseResult.bought:
        Haptics.allDone();
        if (offer.kind == OfferKind.tip) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(key: Key('tipThanks'), content: Text('Thank you! That means a lot.')),
          );
        }
      case PurchaseResult.pending:
        await _alert('Waiting for approval',
            'Someone in your family needs to approve it. It comes through as soon as they do.');
      case PurchaseResult.cancelled:
        break;
      case PurchaseResult.failed:
        await _alert("Couldn't complete the purchase", outcome.message ?? 'Try again in a moment.');
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final found = await _store.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (found) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(key: Key('plusRestored'), content: Text('Momentum Plus restored. Welcome back!')),
      );
    } else {
      await _alert('Nothing to restore', "This Apple Account hasn't bought Momentum Plus yet.");
    }
  }

  Future<void> _turnOnSync() async {
    final sync = get<SyncService>();
    final navigator = Navigator.of(context);
    await sync.turnOn();
    if (mounted && sync.isOn) navigator.pop();
  }

  Future<void> _alert(String title, String message) => showAdaptiveAlert<void>(
        context,
        title: title,
        message: message,
        actions: const [AdaptiveAction(label: 'OK', value: null, isDefault: true)],
      );

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => LargeTitleScaffold(
        title: 'Momentum Plus',
        backgroundColor: palette.background,
        maxContentWidth: AppLayout.readableMax,
        header: const LargeTitleHeader(title: 'Momentum Plus', titleKey: Key('plusTitle')),
        slivers: [
          SliverToBoxAdapter(
            child: FutureBuilder<List<PlusOffer>>(
              future: _offers,
              builder: (context, snapshot) {
                final offers = snapshot.data ?? const <PlusOffer>[];
                final plus = offers.where((o) => o.kind == OfferKind.plus).firstOrNull;
                final tips = offers.where((o) => o.kind == OfferKind.tip).toList();
                return _content(context, palette, plus: plus, tips: tips, loaded: snapshot.hasData);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, AppPalette palette,
      {required PlusOffer? plus, required List<PlusOffer> tips, required bool loaded}) {
    final owned = _store.unlocked;
    final syncOn = sl.isRegistered<SyncService>() && get<SyncService>().isOn;
    Widget text(String s, {double size = 16, FontWeight weight = FontWeight.w400, Color? color, Key? key}) => Text(
          s,
          key: key,
          style: TextStyle(fontSize: size, height: 1.4, fontWeight: weight, color: color ?? palette.text),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 0, AppStyle.screenPadding, 4),
        child: owned
            ? text('Plus is yours. Thank you!', size: 18, weight: FontWeight.w700, key: const Key('plusOwned'))
            : text('One purchase, yours for good, shared with your family.', color: palette.textSecondary),
      ),
      SettingsSection(
        header: 'Now',
        children: [
          for (final (icon, color, title, subtitle) in [
            (CupertinoIcons.cloud_fill, HabitColor.blue, 'Sync with iCloud',
                'Your habits on your iPhone and iPad, kept in your own iCloud'),
            (CupertinoIcons.sparkles, HabitColor.amber, 'A year in review', 'Your year so far, on Insights'),
            (CupertinoIcons.heart_fill, HabitColor.red, 'Health insights', 'How sleep and steps shape your habits'),
            (CupertinoIcons.mic_fill, HabitColor.purple, 'Siri and Shortcuts', 'Log a habit without opening the app'),
          ])
            SettingsTile(icon: icon, iconColor: color.color, title: title, subtitle: subtitle),
        ],
      ),
      SettingsSection(
        header: 'Coming next',
        footer: "Nothing that's free today will ever cost money. Buy once, get everything that comes.",
        children: [
          for (final (icon, color, title, subtitle) in [
            (CupertinoIcons.time, HabitColor.orange, 'Apple Watch', 'Log and see your rings from your wrist'),
            (CupertinoIcons.paintbrush_fill, HabitColor.pink, 'New icons and themes', 'More ways to make it yours'),
          ])
            SettingsTile(icon: icon, iconColor: color.color, title: title, subtitle: subtitle),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppStyle.screenPadding, 8, AppStyle.screenPadding, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!owned) ...[
            OrbButton(
              key: const Key('plusBuy'),
              // The price once the store says; never "…"
              label: plus == null ? 'Get Plus' : 'Get Plus · ${plus.price}',
              busy: _buying == PlusProducts.plus || !loaded,
              onPressed: () => _buy(plus),
            ),
            const SizedBox(height: 4),
            CupertinoButton(
              key: const Key('plusRestore'),
              onPressed: _restoring ? null : _restore,
              child: const Text('Restore Purchases'),
            ),
            text('One-time purchase, paid through your Apple Account. Shared with your family through Family Sharing.',
                size: 13, color: palette.textSecondary),
          ] else if (!syncOn && sl.isRegistered<SyncService>())
            OrbButton(key: const Key('plusTurnOnSync'), label: 'Turn on sync', onPressed: _turnOnSync),
        ]),
      ),
      if (owned && _tipsHere && tips.isNotEmpty)
        SettingsSection(
          header: 'Want to give more?',
          footer: 'Tips are a thank-you, nothing more. Momentum stays free.',
          children: [
            for (final tip in tips)
              SettingsTile(
                tileKey: Key('plusTip_${tip.id.split('.').last}'),
                icon: CupertinoIcons.gift_fill,
                iconColor: HabitColor.brown.color,
                title: 'Leave a ${tip.price} tip',
                onTap: _buying == null ? () => _buy(tip) : null,
              ),
          ],
        ),
      const SizedBox(height: 24),
    ]);
  }
}
