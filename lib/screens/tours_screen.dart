import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_style.dart';
import '../domain/entities/habit_color.dart';
import '../presentation/tour/tour_controller.dart';
import '../presentation/widgets/adaptive.dart';
import '../presentation/widgets/settings_list.dart';

/// Settings → Help → Tours: each tour, to take again, and "Show tours
/// again" for all of them to come back on their next visit.
class ToursScreen extends StatelessWidget {
  const ToursScreen({super.key});

  Future<void> _showAgain(BuildContext context) async {
    final yes = await showAdaptiveAlert<bool>(
      context,
      title: 'Show tours again?',
      message: 'Each tour comes back the next time you open its tab.',
      actions: const [
        AdaptiveAction(label: 'Cancel', value: false),
        AdaptiveAction(key: Key('toursShowAgainYes'), label: 'Show again', value: true, isDefault: true),
      ],
    );
    if (yes != true || !context.mounted) return;
    await context.read<TourController>().showAgain();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tours will show again as you visit each tab')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final tours = context.read<TourController>();
    return Scaffold(
      backgroundColor: palette.background,
      appBar: isCupertino(context)
          ? CupertinoNavigationBar(backgroundColor: palette.background, middle: const Text('Tours'))
          : AppBar(title: const Text('Tours')) as PreferredSizeWidget,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            SettingsSection(
              footer: 'Tours show the app on example habits. Yours are never changed.',
              children: [
                for (final tour in tours.tours.values)
                  SettingsTile(
                    tileKey: Key('playTour_${tour.id.name}'),
                    icon: CupertinoIcons.play_fill,
                    iconColor: HabitColor.orange.color,
                    title: tour.title,
                    subtitle: tour.summary.isEmpty ? null : tour.summary,
                    onTap: () => tours.start(tour.id),
                  ),
              ],
            ),
            SettingsSection(
              children: [
                SettingsTile(
                  tileKey: const Key('toursShowAgain'),
                  icon: CupertinoIcons.arrow_counterclockwise,
                  iconColor: HabitColor.blueGrey.color,
                  title: 'Show tours again',
                  showChevron: false,
                  onTap: () => _showAgain(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
