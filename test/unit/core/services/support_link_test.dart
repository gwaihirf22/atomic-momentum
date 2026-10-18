import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/services/sharer.dart';
import 'package:atomic_momentum/core/services/support_link.dart';

void main() {
  PlatformSupportLink link({String url = 'https://example.com/coffee', String? store, String? region}) =>
      PlatformSupportLink(url: url, storeCountry: () async => store, region: () => region);

  group('"Buy me a coffee" shows', () {
    test('for a US App Store account', () async {
      expect(await link(store: 'USA', region: 'GB').isAvailable(), isTrue,
          reason: "the store's country decides, not the phone's region");
    });

    test('not for an account in another country, wherever the phone is set', () async {
      expect(await link(store: 'GBR', region: 'US').isAvailable(), isFalse);
      expect(await link(store: 'CAN').isAvailable(), isFalse);
    });

    test("by the phone's region when the store's country is unknown (Android)", () async {
      expect(await link(region: 'US').isAvailable(), isTrue);
      expect(await link(region: 'DE').isAvailable(), isFalse);
      expect(await link().isAvailable(), isFalse, reason: 'no region: not offered');
    });

    test('never before there is a page', () async {
      expect(await link(url: '', store: 'USA').isAvailable(), isFalse);
      expect(await link(url: '').open(), isFalse);
    });
  });

  test('there is no page yet, so the row stays hidden until AppLinks.coffee is set', () async {
    expect(AppLinks.coffee, isEmpty);
    expect(await PlatformSupportLink(storeCountry: () async => 'USA').isAvailable(), isFalse);
  });
}
