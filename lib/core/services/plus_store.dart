import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dev/dev_tools.dart';
import '../logging/log.dart';

/// What can be bought (docs/design/plus-purchase.md): Momentum Plus, once,
/// and tips, as often as anyone likes. Tips are a thank-you and never
/// unlock Plus.
abstract final class PlusProducts {
  static const plus = 'com.paulblake.momentum.plus';
  static const tipSmall = 'com.paulblake.momentum.tip.small';
  static const tipMedium = 'com.paulblake.momentum.tip.medium';
  static const tipLarge = 'com.paulblake.momentum.tip.large';

  static const tips = [tipSmall, tipMedium, tipLarge];
  static const all = {plus, ...tips};
}

enum OfferKind { plus, tip }

/// Something to buy, with its price as the App Store shows it ("$1.99").
class PlusOffer {
  final String id;
  final OfferKind kind;
  final String price;

  /// The store's own description, to buy it with (null in tests).
  final ProductDetails? details;

  const PlusOffer({required this.id, required this.kind, required this.price, this.details});
}

enum PurchaseResult { bought, cancelled, pending, failed }

/// How a purchase went; [message] says why it failed, in the store's words.
class PurchaseOutcome {
  final PurchaseResult result;
  final String? message;

  const PurchaseOutcome(this.result, [this.message]);

  static const bought = PurchaseOutcome(PurchaseResult.bought);
  static const cancelled = PurchaseOutcome(PurchaseResult.cancelled);
  static const pending = PurchaseOutcome(PurchaseResult.pending);
}

/// Momentum Plus and tips: whether Plus is unlocked, what's for sale, and
/// buying and restoring. Tests use FakePlusStore.
abstract class PlusStore extends ChangeNotifier {
  /// Where Plus is sold: iPhone and iPad (and anywhere with Developer
  /// tools, to try it). Hidden on Android until Google Drive sync exists.
  bool get isSupported;

  bool get unlocked;

  /// Plus and the tips, priced by the store; empty when it can't be reached.
  Future<List<PlusOffer>> offers();

  Future<PurchaseOutcome> buy(PlusOffer offer);

  /// Restore Purchases: true if Plus is unlocked afterwards.
  Future<bool> restore();

  /// Developer tools: "Pretend Plus is bought".
  bool get pretending;
  Future<void> setPretending(bool on);
}

/// The store calls [PlatformPlusStore] makes: Apple's (or Google's) through
/// `in_app_purchase`, or a fake in tests.
abstract class PurchaseApi {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<bool> buyConsumable({required PurchaseParam purchaseParam});
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<void> restorePurchases();
}

class _InAppPurchaseApi implements PurchaseApi {
  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;
  @override
  Future<bool> isAvailable() => _iap.isAvailable();
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) => _iap.queryProductDetails(ids);
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _iap.buyNonConsumable(purchaseParam: purchaseParam);
  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) => _iap.buyConsumable(purchaseParam: purchaseParam);
  @override
  Future<void> completePurchase(PurchaseDetails purchase) => _iap.completePurchase(purchase);
  @override
  Future<void> restorePurchases() => _iap.restorePurchases();
}

/// [PlusStore] through Apple's StoreKit 2 (`in_app_purchase`). Started from
/// `main()`, so purchases waiting from last time are finished and Plus
/// bought on another device of the same Apple ID is found quietly.
class PlatformPlusStore extends PlusStore {
  static const unlockedKey = 'plus_v1';
  static const pretendKey = 'plus_dev_v1';

  final SharedPreferences _prefs;
  final PurchaseApi _api;
  final bool _supported;

  PlatformPlusStore({required SharedPreferences prefs, PurchaseApi? api, bool? supported})
      : _prefs = prefs,
        _api = api ?? _InAppPurchaseApi(),
        _supported = supported ?? (DevTools.enabled || (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS));

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Purchases being made, by product: their outcome once the store says.
  final _waiting = <String, Completer<PurchaseOutcome>>{};

  @override
  bool get isSupported => _supported;

  @override
  bool get unlocked => _prefs.containsKey(unlockedKey) || pretending;

  @override
  bool get pretending => DevTools.enabled && (_prefs.getBool(pretendKey) ?? false);

  @override
  Future<void> setPretending(bool on) async {
    await _prefs.setBool(pretendKey, on);
    notifyListeners();
  }

  /// Hears the store from launch, and looks quietly for Plus bought
  /// elsewhere (StoreKit 2's current entitlements: no sign-in prompt).
  void start() {
    if (!_supported || _subscription != null) return;
    try {
      _subscription = _api.purchaseStream.listen(_heard, onError: (Object e) => logWarning('Purchases: $e'));
    } on MissingPluginException {
      return;
    }
    if (!unlocked) {
      _api.restorePurchases().catchError((Object e) => logWarning('Purchases: quiet restore failed: $e'));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_prefs.containsKey(unlockedKey)) return;
    await _prefs.setString(unlockedKey, clock.now().toUtc().toIso8601String());
    notifyListeners();
  }

  Future<void> _heard(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final waiting = _waiting[purchase.productID];
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Ask to Buy: it may come through later, on this stream
          if (waiting != null && !waiting.isCompleted) waiting.complete(PurchaseOutcome.pending);
          continue;
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          if (purchase.productID == PlusProducts.plus) await _unlock();
          if (waiting != null && !waiting.isCompleted) waiting.complete(PurchaseOutcome.bought);
        case PurchaseStatus.canceled:
          if (waiting != null && !waiting.isCompleted) waiting.complete(PurchaseOutcome.cancelled);
        case PurchaseStatus.error:
          if (waiting != null && !waiting.isCompleted) {
            waiting.complete(PurchaseOutcome(PurchaseResult.failed, purchase.error?.message));
          }
      }
      _waiting.remove(purchase.productID);
      if (purchase.pendingCompletePurchase) {
        try {
          await _api.completePurchase(purchase);
        } catch (e) {
          logWarning('Purchases: completing ${purchase.productID} failed: $e');
        }
      }
    }
  }

  @override
  Future<List<PlusOffer>> offers() async {
    if (!_supported) return const [];
    try {
      // A store that doesn't answer is a store that can't be reached
      if (!await _api.isAvailable().timeout(lookupTimeout)) return const [];
      final response = await _api.queryProductDetails(PlusProducts.all).timeout(lookupTimeout);
      final offers = [
        for (final details in response.productDetails)
          PlusOffer(
            id: details.id,
            kind: details.id == PlusProducts.plus ? OfferKind.plus : OfferKind.tip,
            price: details.price,
            details: details,
          ),
      ];
      // Plus first, then the tips from smallest
      offers.sort((a, b) {
        if (a.kind != b.kind) return a.kind == OfferKind.plus ? -1 : 1;
        return PlusProducts.tips.indexOf(a.id).compareTo(PlusProducts.tips.indexOf(b.id));
      });
      return offers;
    } on MissingPluginException {
      return const [];
    } on TimeoutException {
      logWarning('Purchases: the store took too long');
      return const [];
    } on PlatformException catch (e) {
      logWarning('Purchases: products unavailable: $e');
      return const [];
    }
  }

  /// How long the store has to say what's for sale.
  static const lookupTimeout = Duration(seconds: 8);

  @override
  Future<PurchaseOutcome> buy(PlusOffer offer) async {
    final details = offer.details;
    if (details == null) return const PurchaseOutcome(PurchaseResult.failed, "That isn't for sale right now.");
    final waiting = _waiting[offer.id] = Completer<PurchaseOutcome>();
    try {
      final param = PurchaseParam(productDetails: details);
      offer.kind == OfferKind.plus
          ? await _api.buyNonConsumable(purchaseParam: param)
          : await _api.buyConsumable(purchaseParam: param);
    } on PlatformException catch (e) {
      _waiting.remove(offer.id);
      return PurchaseOutcome(PurchaseResult.failed, e.message);
    }
    return waiting.future;
  }

  @override
  Future<bool> restore() async {
    try {
      await _api.restorePurchases();
    } on PlatformException catch (e) {
      logWarning('Purchases: restore failed: $e');
    } on MissingPluginException {
      return unlocked;
    }
    // What was found arrives on the stream just after
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return unlocked;
  }
}
