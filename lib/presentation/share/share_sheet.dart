import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../core/injection/injection_container.dart';
import '../../core/services/sharer.dart';
import '../../core/theme/app_palette.dart';
import '../widgets/large_title_scaffold.dart';
import '../widgets/orb_button.dart';
import 'share_cards.dart';

/// Builds the card for a style, with or without the habit's name.
typedef ShareCardBuilder = Widget Function(ShareLook look, bool hideName);

/// Shows the share preview: the card, a choice of style, "Hide habit name"
/// (when there's one to hide), and Share…, which hands a 1080 × 1350 picture
/// to the phone's share sheet.
Future<void> showShareSheet(
  BuildContext context, {
  required ShareCardBuilder card,
  required String fileName,
  List<ShareStyle> styles = ShareStyle.values,
  bool canHideName = false,
  bool hideNameByDefault = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).surface,
    builder: (context) => ShareSheet(
      card: card,
      fileName: fileName,
      styles: styles,
      canHideName: canHideName,
      hideNameByDefault: hideNameByDefault,
    ),
  );
}

class ShareSheet extends StatefulWidget {
  final ShareCardBuilder card;
  final String fileName;
  final List<ShareStyle> styles;
  final bool canHideName;
  final bool hideNameByDefault;

  const ShareSheet({
    super.key,
    required this.card,
    required this.fileName,
    required this.styles,
    this.canHideName = false,
    this.hideNameByDefault = false,
  });

  @override
  State<ShareSheet> createState() => ShareSheetState();
}

class ShareSheetState extends State<ShareSheet> {
  final _card = GlobalKey();
  final _button = GlobalKey();
  late ShareStyle _style = widget.styles.first;
  late bool _hideName = widget.canHideName && widget.hideNameByDefault;
  bool _busy = false;

  /// The card as a PNG, 1080 pixels wide.
  Future<Uint8List?> render() async {
    final boundary = _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 1080 / ShareCardFrame.size.width);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final png = await render();
      if (png == null || !mounted) return;
      final box = _button.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      await get<Sharer>().shareImage(png, name: widget.fileName, text: AppLinks.shareText, origin: origin);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text("Couldn't share that. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('shareSheet'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            header: true,
            child: Text(
              'Share',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: LargeTitleHeader.fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth < 264 ? constraints.maxWidth : 264.0;
              return Container(
                width: width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width / 12),
                  boxShadow: [BoxShadow(color: palette.barShadow, blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: FittedBox(
                  child: RepaintBoundary(key: _card, child: widget.card(ShareLook.of(_style), _hideName)),
                ),
              );
            }),
          ),
          if (widget.styles.length > 1) ...[
            const SizedBox(height: 18),
            Semantics(
              label: 'Card style',
              child: Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
                for (final style in widget.styles)
                  Semantics(
                    button: true,
                    inMutuallyExclusiveGroup: true,
                    selected: style == _style,
                    label: style.label,
                    excludeSemantics: true,
                    onTap: () => setState(() => _style = style),
                    child: GestureDetector(
                      key: Key('shareStyle_${style.name}'),
                      onTap: () => setState(() => _style = style),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: shareSwatch(style).copyWith(
                          border: Border.all(
                            color: style == _style ? palette.text : palette.track,
                            width: style == _style ? 3 : 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ],
          if (widget.canHideName) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: palette.raised, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SwitchListTile.adaptive(
                key: const Key('shareHideName'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Hide habit name'),
                subtitle: const Text('For the habits you keep to yourself'),
                value: _hideName,
                onChanged: (value) => setState(() => _hideName = value),
              ),
            ),
          ],
          const SizedBox(height: 18),
          OrbButton(
            key: _button,
            label: 'Share…',
            busy: _busy,
            onPressed: _busy ? null : _share,
          ),
          const SizedBox(height: 8),
          Text(
            AppLinks.hasStore
                ? "Opens your phone's share sheet: Messages, WhatsApp, Telegram, Instagram and more. "
                    'A link to get Momentum goes with it.'
                : "Opens your phone's share sheet: Messages, WhatsApp, Telegram, Instagram and more.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ]),
      ),
    );
  }
}

/// A share icon for a card's heading.
class ShareIconButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const ShareIconButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(CupertinoIcons.share, size: 20, color: AppPalette.of(context).textSecondary),
          ),
        ),
      );
}
