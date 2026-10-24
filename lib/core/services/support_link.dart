import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sharer.dart';

/// Settings → Say thanks → "Buy Paul a coffee": the developer's tip page, opened
/// in the browser. Momentum is free; this is the only way to give something.
///
/// Shown only in the United States. As of October 2026 both stores allow a
/// link to an outside payment page there (Apple guideline 3.1.1(a); Google
/// Play while its US court order stands) and forbid it elsewhere, where tips
/// would have to be in-app purchases. Hidden, too, without a page
/// ([AppLinks.coffee]). Tests use a fake.
abstract class SupportLink {
  /// Whether to offer the link here: a page exists and this is a US user.
  Future<bool> isAvailable();

  /// Opens the page in the browser; false if it couldn't.
  Future<bool> open();
}

class PlatformSupportLink implements SupportLink {
  static const _storefront = MethodChannel('momentum/storefront');

  final String url;

  /// The App Store's country for this Apple ID ("USA"), or null when unknown
  /// (a simulator without an account, or not an iPhone).
  final Future<String?> Function() storeCountry;

  /// The phone's region ("US"), used when the store's country isn't known.
  final String? Function() region;

  /// Whether the phone's region may stand in for the store's country: on
  /// Android, not on an iPhone. An iPhone's App Store always has a country;
  /// when it doesn't say, the link stays hidden, so it can never show on
  /// another country's storefront (App Review, 2026-10-23).
  final bool trustRegion;

  PlatformSupportLink({
    this.url = AppLinks.coffee,
    Future<String?> Function()? storeCountry,
    String? Function()? region,
    bool? trustRegion,
  })  : storeCountry = storeCountry ?? _appStoreCountry,
        region = region ?? (() => PlatformDispatcher.instance.locale.countryCode),
        trustRegion = trustRegion ?? (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS);

  static Future<String?> _appStoreCountry() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      return await _storefront.invokeMethod<String>('country');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (url.isEmpty) return false;
    // The store's own country decides; on Android the phone's region stands
    // in when it's unknown (Play's country needs its billing library)
    final store = await storeCountry();
    if (store != null) return store == 'USA';
    return trustRegion && region() == 'US';
  }

  @override
  Future<bool> open() async {
    if (url.isEmpty) return false;
    try {
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
