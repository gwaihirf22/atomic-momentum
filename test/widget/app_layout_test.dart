import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atomic_momentum/presentation/layout/app_layout.dart';

void main() {
  test('tiers follow the window\'s width', () {
    expect(AppLayout.tierFor(375), LayoutTier.compact);
    expect(AppLayout.tierFor(507), LayoutTier.compact, reason: 'half an iPad in Split View');
    expect(AppLayout.tierFor(744), LayoutTier.regular, reason: 'iPad mini upright');
    expect(AppLayout.tierFor(834), LayoutTier.regular, reason: 'iPad Pro 11" upright');
    expect(AppLayout.tierFor(1032), LayoutTier.regular, reason: 'iPad Pro 13" upright');
    expect(AppLayout.tierFor(1194), LayoutTier.wide, reason: 'iPad Pro 11" sideways');
    expect(AppLayout.tierFor(1376), LayoutTier.wide);
    expect(LayoutTier.compact.hasSidebar, isFalse);
    expect(LayoutTier.regular.hasSidebar, isTrue);
  });

  test('cards go in columns of at least 400', () {
    expect(AppLayout.columnsFor(390), 1);
    expect(AppLayout.columnsFor(799), 1);
    expect(AppLayout.columnsFor(834), 2);
    expect(AppLayout.columnsFor(1376), 3);
    expect(AppLayout.columnsFor(3000), 3);
  });

  Future<Map<String, String>> wordsAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Map<String, String> words;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      words = {
        'device': DeviceWords.device(context),
        'this': DeviceWords.thisDevice(context),
        'apple': DeviceWords.appleDevice(context),
      };
      return const SizedBox();
    })));
    return words;
  }

  testWidgets('a phone is "this phone", an iPad "this iPad", either way up', (tester) async {
    expect(await wordsAt(tester, const Size(390, 844)), {'device': 'phone', 'this': 'this phone', 'apple': 'iPhone'});
    expect(await wordsAt(tester, const Size(844, 390)), {'device': 'phone', 'this': 'this phone', 'apple': 'iPhone'});
    expect(await wordsAt(tester, const Size(834, 1194)), {'device': 'iPad', 'this': 'this iPad', 'apple': 'iPad'});
    expect(await wordsAt(tester, const Size(1194, 834)), {'device': 'iPad', 'this': 'this iPad', 'apple': 'iPad'});
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('an Android tablet is "this tablet"', (tester) async {
    expect((await wordsAt(tester, const Size(1280, 800)))['this'], 'this tablet');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('readable width centres content wider than the cap, and leaves phones alone', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ReadableWidth(child: SizedBox(key: Key('content'), height: 10, width: double.infinity))));
    expect(tester.getSize(find.byKey(const Key('content'))).width, AppLayout.readableMax);
    expect(tester.getCenter(find.byKey(const Key('content'))).dx, 1194 / 2);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('content'))).width, 390);
  });
}
