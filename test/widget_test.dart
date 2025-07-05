// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atomic_momentum/core/theme/ios_theme.dart';
import 'package:atomic_momentum/screens/ios_main_navigation.dart';

void main() {
  Widget createTestApp() {
    return CupertinoApp(
      title: 'Atomic Momentum Test',
      debugShowCheckedModeBanner: false,
      theme: IOSTheme.getTheme(Brightness.light),
      home: const IOSMainNavigation(),
    );
  }

  testWidgets('iOS app loads and shows home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(createTestApp());

    // Wait for the app to load
    await tester.pumpAndSettle();

    // Verify that our app title appears in the navigation bar
    expect(find.text('Habits'), findsOneWidget);

    // Verify that the add button exists in navigation bar
    expect(find.byIcon(CupertinoIcons.add), findsOneWidget);

    // Verify that the tab bar exists with correct tabs
    expect(find.text('Habits'), findsWidgets);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
  
  testWidgets('iOS tab navigation works correctly', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Tap on Calendar tab
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    // Tap on Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Tap back to Habits tab
    await tester.tap(find.text('Habits'));
    await tester.pumpAndSettle();
  });
}
