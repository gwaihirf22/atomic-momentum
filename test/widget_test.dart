// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:workspace/main.dart';

void main() {
  testWidgets('App loads and shows home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MomentumApp());

    // Wait for the app to load
    await tester.pumpAndSettle();

    // Verify that our app title appears.
    expect(find.text('Momentum'), findsOneWidget);

    // Verify that the floating action button exists
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
