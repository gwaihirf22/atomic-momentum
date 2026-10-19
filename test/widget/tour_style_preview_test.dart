import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/main.dart';
import 'package:atomic_momentum/presentation/dev/tour_style_preview.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/tour/spotlight.dart';
import 'package:atomic_momentum/screens/ios_main_navigation.dart';

void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(() async {
    TourStylePreview.close();
    await resetDependencies();
  });

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the tour style preview lights up each target over the real Habits screen, and changes nothing',
      (tester) async {
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(IOSMainNavigation));
    final habits = Provider.of<HabitProvider>(context, listen: false);
    await habits.addSampleHabits();
    for (final h in habits.habits) {
      await habits.updateProgressForDate(h.id, DateTime.now().subtract(const Duration(days: 1)), 1);
    }
    await tester.pumpAndSettle();
    final before = jsonEncode([for (final h in habits.habits) h.history.map((k, v) => MapEntry('$k', v))]);

    TourStylePreview.show(context);
    await frames(tester);
    for (var step = 0; step < TourStylePreview.steps.length; step++) {
      expect(TourStylePreview.step.value, step);
      final spotlight = tester.widget<TourSpotlight>(find.byType(TourSpotlight));
      // Every step but the offer finds its target on screen
      expect(spotlight.target != null, step != TourStylePreview.steps.length - 1, reason: 'step ${step + 1}');
      expect(tester.takeException(), isNull);
      if (spotlight.tryIt) {
        // Taps in the hole move it on, and never reach the + underneath
        await tester.tapAt(spotlight.target!.center);
      } else {
        await tester.tap(find.text(step == TourStylePreview.steps.length - 1 ? 'Start' : TourStylePreview.steps[step].next));
      }
      await frames(tester);
    }
    expect(TourStylePreview.isShowing, isFalse);
    expect(find.byType(TourSpotlight), findsNothing);
    expect(jsonEncode([for (final h in habits.habits) h.history.map((k, v) => MapEntry('$k', v))]), before);
  });
}
