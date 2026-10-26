import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/demo/demo_world.dart';
import '../core/injection/injection_container.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/habit_color.dart';
import '../presentation/howto/guides.dart';
import '../presentation/howto/phone_frame.dart';
import '../presentation/tour/world_scope.dart';
import '../presentation/widgets/settings_list.dart';
import '../presentation/layout/app_layout.dart';

/// Settings → Help → How to: the guides, each a page of pictures of the app.
/// The pictures show the example habits, built when the page opens.
class HowToScreen extends StatefulWidget {
  /// Where the example habits come from (tests build them in place).
  final Future<DemoSeed> Function(DateTime now)? seed;

  const HowToScreen({super.key, this.seed});

  @override
  State<HowToScreen> createState() => _HowToScreenState();
}

class _HowToScreenState extends State<HowToScreen> {
  AppWorld? _world;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seed = await (widget.seed ?? DemoSeed.forDay)(clock.now());
    final settings = sl.isRegistered<SharedPreferences>() ? get<SharedPreferences>() : null;
    final demo = await DemoWorld.create(seed, settingsFrom: settings);
    if (!mounted) {
      demo.dispose();
      return;
    }
    setState(() => _world = AppWorld.example(demo));
  }

  @override
  void dispose() {
    _world?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final world = _world;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: isCupertino(context)
          ? CupertinoNavigationBar(backgroundColor: palette.background, middle: const Text('How to'))
          : AppBar(title: const Text('How to')) as PreferredSizeWidget,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            SettingsSection(
              footer: 'Pictures show example habits, not your own.',
              children: [
                for (final guide in Guides.all)
                  SettingsTile(
                    tileKey: Key('guide_${guide.id}'),
                    icon: CupertinoIcons.book_fill,
                    iconColor: HabitColor.teal.color,
                    title: guide.title,
                    subtitle: guide.summary,
                    enabled: world != null,
                    onTap: world == null
                        ? null
                        : () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => GuideScreen(guide: guide, world: world))),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One guide: each card a live picture of the app and a sentence or two.
class GuideScreen extends StatelessWidget {
  final Guide guide;
  final AppWorld world;

  const GuideScreen({super.key, required this.guide, required this.world});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: isCupertino(context)
          ? CupertinoNavigationBar(backgroundColor: palette.background, middle: Text(guide.title))
          : AppBar(title: Text(guide.title)) as PreferredSizeWidget,
      body: SafeArea(
        child: ReadableColumn(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: guide.cards.length,
          itemBuilder: (context, i) {
            final card = guide.cards[i];
            return Padding(
              key: Key('guideCard_${guide.id}_$i'),
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: RepaintBoundary(child: PhonePicture(scene: card.scene, world: world)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(card.text, style: TextStyle(fontSize: 16, height: 1.4, color: palette.text)),
              ]),
            );
          },
        ),
        ),
      ),
    );
  }
}
