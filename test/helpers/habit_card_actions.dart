import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens Edit the way a person does now: swipe the habit's card left, then
/// tap Edit. (Tapping the card opens the habit's page.)
Future<void> swipeToEdit(WidgetTester tester, String habitId) async {
  await tester.drag(find.byKey(Key('habitCard_$habitId')), const Offset(-300, 0));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('editHabit_$habitId')));
  await tester.pumpAndSettle();
}
