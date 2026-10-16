import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/main.dart';

void main() {
  setUp(() async {
    await resetDependencies();
    SharedPreferences.setMockInitialValues({});
    await initializeDependencies(seedDefaultHabit: false);
  });

  tearDown(() async {
    await resetDependencies();
  });

  testWidgets('app loads and shows the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();

    expect(find.text('Habits'), findsWidgets);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('tab navigation works', (WidgetTester tester) async {
    await tester.pumpWidget(const MomentumApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Habit Calendar'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(find.text('Habits').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.add), findsWidgets);
  });
}
