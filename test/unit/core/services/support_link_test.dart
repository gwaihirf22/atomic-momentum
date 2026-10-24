import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/services/sharer.dart';
import 'package:atomic_momentum/core/services/support_link.dart';

void main() {
  PlatformSupportLink link({String url = 'https://example.com/coffee', String? store, String? region, bool iPhone = false}) =>
      PlatformSupportLink(url: url, storeCountry: () async => store, region: () => region, trustRegion: !iPhone);

  group('"Buy Paul a coffee" shows', () {
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

    test("never on an iPhone whose App Store doesn't say its country, whatever the region", () async {
      expect(await link(region: 'US', iPhone: true).isAvailable(), isFalse);
      expect(await link(store: 'USA', region: 'GB', iPhone: true).isAvailable(), isTrue);
      expect(await link(store: 'GBR', region: 'US', iPhone: true).isAvailable(), isFalse);
    });

    test('never before there is a page', () async {
      expect(await link(url: '', store: 'USA').isAvailable(), isFalse);
      expect(await link(url: '').open(), isFalse);
    });
  });

  test("the row opens the developer's Buy Me a Coffee page, for US users", () async {
    expect(AppLinks.coffee, 'https://buymeacoffee.com/paulblake');
    expect(Uri.parse(AppLinks.coffee).scheme, 'https', reason: 'it opens in the browser');
    expect(await PlatformSupportLink(storeCountry: () async => 'USA').isAvailable(), isTrue);
    expect(await PlatformSupportLink(storeCountry: () async => 'GBR').isAvailable(), isFalse);
  });
}
