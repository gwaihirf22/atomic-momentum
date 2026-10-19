import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/dev/year_of_use.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/dev/tour_style_preview.dart';
import 'package:atomic_momentum/presentation/providers/theme_provider.dart';
import 'package:atomic_momentum/screens/ios_main_navigation.dart';

/// Screenshots of the tours' look on a real screen, for review: each step of
/// the tour style preview over a year of example habits, in Light, Sepia and
/// Charged, at the default text size and iOS's largest standard one (135%).
/// Storage is in memory; the device's own habits are never touched.
///
/// Run with tool/tour_screens.sh "<simulator or emulator>"; the pictures land
/// in build/tour_screens/<device>/.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the tour style, step by step, in every theme and text size', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.runAsync(() => YearOfUse.load(prefs, DateTime.now()));
    await initializeDependencies(seedDefaultHabit: false);
    await tester.pumpWidget(const MomentumApp());
    await _wait(tester, 2000);
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();

    final context = tester.element(find.byType(IOSMainNavigation));
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    for (final appearance in [Appearance.dark, Appearance.light, Appearance.sepia]) {
      for (final scale in [1.0, 1.35]) {
        await theme.setAppearance(appearance);
        binding.platformDispatcher.textScaleFactorTestValue = scale;
        await _wait(tester, 600);
        for (var step = 0; step < TourStylePreview.steps.length; step++) {
          TourStylePreview.show(context, at: step);
          await _wait(tester, 900);
          await binding.takeScreenshot('${appearance.name}_${(scale * 100).round()}_step${step + 1}');
        }
        TourStylePreview.close();
      }
    }
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// Lets frames run for [ms] (the spotlight's pulse never settles).
Future<void> _wait(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
