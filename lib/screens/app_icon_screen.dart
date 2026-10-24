import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/branding/app_icons.dart';
import '../core/feedback/haptics.dart';
import '../core/injection/injection_container.dart';
import '../core/services/app_icon_service.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../presentation/widgets/adaptive.dart';

/// Settings → App icon: the icons on offer, the current one checked.
class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  final _service = get<AppIconService>();
  AppIconChoice? _current;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service.current().then((icon) {
      if (mounted) setState(() => _current = icon);
    });
  }

  Future<void> _choose(AppIconChoice icon) async {
    if (_busy || icon == _current) return;
    setState(() => _busy = true);
    try {
      await _service.set(icon);
      if (!mounted) return;
      Haptics.selection();
      setState(() => _current = icon);
    } on AppIconException catch (e) {
      if (!mounted) return;
      await showAdaptiveAlert<void>(
        context,
        title: 'Couldn\'t change the icon',
        message: e.message,
        actions: const [AdaptiveAction(label: 'OK', value: null, isDefault: true)],
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final platform = _service.platform;
    final icons = AppIcons.offeredOn(platform);
    final footer = platform == TargetPlatform.android
        ? 'Your new icon appears after you leave Momentum.'
        // Since iOS 18.1, Notification Center keeps the old icon until a restart
        // (an iOS bug, developer.apple.com/forums/thread/780074): nothing an app can refresh
        : 'Match system switches between light and dark with your phone, on iOS 18 and later. '
            'Notifications may show the old icon until you restart your iPhone.';

    return Scaffold(
      backgroundColor: palette.background,
      appBar: isCupertino(context)
          ? CupertinoNavigationBar(backgroundColor: palette.background, middle: const Text('App icon'))
          : AppBar(title: const Text('App icon')) as PreferredSizeWidget,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 20,
              children: [
                for (final icon in icons)
                  AppIconTile(
                    key: Key('appIcon_${icon.id}'),
                    icon: icon,
                    selected: icon == _current,
                    onTap: () => _choose(icon),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              footer,
              key: const Key('appIconFooter'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// An icon's picture with its name under it; a ring and a check when chosen.
class AppIconTile extends StatelessWidget {
  static const size = 84.0;

  final AppIconChoice icon;
  final bool selected;
  final VoidCallback onTap;

  const AppIconTile({super.key, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final radius = BorderRadius.circular(size * 0.225);
    return Semantics(
      button: true,
      selected: selected,
      label: icon.label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: size + 24,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(size * 0.225 + 4),
                      border: Border.all(color: selected ? palette.accent : Colors.transparent, width: 3),
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: SizedBox.square(dimension: size, child: _Picture(icon)),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        key: const Key('appIconCheck'),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.background, width: 2),
                        ),
                        child: Icon(CupertinoIcons.checkmark, size: 14, color: palette.onAccent),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                icon.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: palette.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The preview; one following the system is split corner to corner, light
/// above and dark below.
class _Picture extends StatelessWidget {
  final AppIconChoice icon;

  const _Picture(this.icon);

  @override
  Widget build(BuildContext context) {
    final light = Image.asset(icon.preview, fit: BoxFit.cover);
    final dark = icon.darkPreview;
    if (!icon.followsSystem || dark == null) return light;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(dark, fit: BoxFit.cover),
        ClipPath(clipper: const _UpperLeftHalf(), child: light),
      ],
    );
  }
}

class _UpperLeftHalf extends CustomClipper<Path> {
  const _UpperLeftHalf();

  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_UpperLeftHalf oldClipper) => false;
}
