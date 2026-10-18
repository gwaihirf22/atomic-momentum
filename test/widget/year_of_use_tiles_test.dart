import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomic_momentum/core/dev/year_persona.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/presentation/dev/year_of_use_tiles.dart';
import 'package:atomic_momentum/presentation/providers/habit_provider.dart';
import 'package:atomic_momentum/presentation/providers/quote_provider.dart';

/// Settings → Developer: loading a year shows it's working (the year is
/// built off the main thread), and "Put my habits back" restores them.
void main() {
  late HabitProvider habits;

  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
    habits = get<HabitProvider>();
    await habits.loadHabits();
  });

  tearDown(resetDependencies);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<QuoteProvider>.value(value: get<QuoteProvider>()),
      ],
      child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => ListView(children: yearOfUseTiles(context))))),
    ));
  }

  /// Real time for the isolate, a little at a time, until [done].
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 150 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }
  }

  testWidgets('loads a year with a spinner, and puts the habits back', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('loadYearOfUse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loadYearConfirm')));
    await tester.pump();
    expect(find.byKey(const Key('loadingYear')), findsOneWidget);

    await waitFor(tester, () => find.text('Loaded a year of use').evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('loadingYear')), findsNothing);
    expect(habits.habits.map((h) => h.name), contains(YearPersona.water));

    await tester.tap(find.byKey(const Key('restoreMyHabits')));
    await waitFor(tester, () => find.text('Your habits are back').evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    expect(habits.habits, isEmpty);
  });

  testWidgets('with nothing loaded, there is nothing to put back', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('restoreMyHabits')));
    await tester.pump();
    expect(find.textContaining('Nothing to put back'), findsOneWidget);
  });
}
