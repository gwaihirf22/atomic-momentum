import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/demo/memory_prefs.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/presentation/plus/plus_mention.dart';
import 'package:atomic_momentum/screens/plus_screen.dart';

import '../helpers/fake_plus_store.dart';

/// The one gentle mention of Momentum Plus, at the end of a week in review.
void main() {
  final week1 = DateTime(2026, 10, 19);
  final week2 = DateTime(2026, 10, 26);
  final week3 = DateTime(2026, 11, 2);

  group('when it shows', () {
    test('from the second week looked at, once ever', () {
      final prefs = MemoryPrefs();
      final plus = FakePlusStore();
      expect(PlusMention.decide(prefs, plus, week1, tablet: false), isFalse, reason: 'the first week');
      expect(PlusMention.decide(prefs, plus, week1, tablet: false), isFalse, reason: 'the same week again');
      expect(PlusMention.decide(prefs, plus, week2, tablet: false), isTrue);
      expect(PlusMention.decide(prefs, plus, week3, tablet: false), isFalse, reason: 'once ever');
    });

    test('never with Plus, on an iPad, or where Plus isn\'t sold', () {
      for (final (plus, tablet) in [
        (FakePlusStore(unlocked: true), false),
        (FakePlusStore(), true),
        (FakePlusStore(isSupported: false), false),
        (null, false),
      ]) {
        final prefs = MemoryPrefs();
        PlusMention.decide(prefs, plus, week1, tablet: tablet);
        expect(PlusMention.decide(prefs, plus, week2, tablet: tablet), isFalse);
      }
    });
  });

  group('the card', () {
    setUp(() async {
      await resetDependencies();
      SharedPreferences.setMockInitialValues({
        PlusMention.weeksKey: ['2026-10-19'],
      });
      await initializeDependencies(seedDefaultHabit: false);
      FakePlusStore.install();
    });

    tearDown(resetDependencies);

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlusMention(week: week2))));
      await tester.pumpAndSettle();
    }

    testWidgets('opens the Plus page, and can be closed', (tester) async {
      await pump(tester);
      expect(find.text('Using an iPad too?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('plusMentionOpen')));
      await tester.pumpAndSettle();
      expect(find.byType(PlusScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(PlusScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('plusMentionClose')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plusMention')), findsNothing);
    });

    testWidgets('isn\'t there the next time', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('plusMention')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlusMention(week: week3))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plusMention')), findsNothing);
    });
  });
}
