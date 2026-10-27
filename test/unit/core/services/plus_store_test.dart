import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:atomic_momentum/core/demo/memory_prefs.dart';
import 'package:atomic_momentum/core/services/plus_store.dart';

/// The store as Apple's StoreKit would behave: products, purchases arriving
/// on the stream, completions and restores.
class FakePurchaseApi implements PurchaseApi {
  final _stream = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = true;
  final completed = <String>[];
  int restores = 0;

  /// What a restore finds (delivered on the stream).
  List<String> owned = [];

  /// How the next purchase goes, delivered on the stream.
  PurchaseStatus next = PurchaseStatus.purchased;

  void deliver(String id, PurchaseStatus status, {bool needsCompleting = true, String? error}) {
    final purchase = PurchaseDetails(
      productID: id,
      purchaseID: '1',
      verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: '', source: 'test'),
      transactionDate: null,
      status: status,
    )
      ..pendingCompletePurchase = needsCompleting
      ..error = error == null ? null : IAPError(source: 'test', code: 'e', message: error);
    _stream.add([purchase]);
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _stream.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async => ProductDetailsResponse(
        productDetails: [
          for (final (id, price, raw) in [
            (PlusProducts.tipLarge, r'$4.99', 4.99),
            (PlusProducts.plus, r'$1.99', 1.99),
            (PlusProducts.tipSmall, r'$0.99', 0.99),
            (PlusProducts.tipMedium, r'$2.99', 2.99),
          ])
            if (ids.contains(id))
              ProductDetails(id: id, title: id, description: '', price: price, rawPrice: raw, currencyCode: 'USD'),
        ],
        notFoundIDs: const [],
      );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    scheduleMicrotask(() => deliver(purchaseParam.productDetails.id, next, needsCompleting: next != PurchaseStatus.pending));
    return true;
  }

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) => buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async => completed.add(purchase.productID);

  @override
  Future<void> restorePurchases() async {
    restores++;
    for (final id in owned) {
      scheduleMicrotask(() => deliver(id, PurchaseStatus.restored));
    }
  }
}

void main() {
  late MemoryPrefs prefs;
  late FakePurchaseApi api;
  late PlatformPlusStore store;

  PlatformPlusStore make() => PlatformPlusStore(prefs: prefs, api: api, supported: true)..start();

  setUp(() {
    prefs = MemoryPrefs();
    api = FakePurchaseApi();
    store = make();
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  Future<PlusOffer> offer(String id) async => (await store.offers()).firstWhere((o) => o.id == id);

  test('offers Plus first, then the tips from the smallest, at the store\'s prices', () async {
    final offers = await store.offers();
    expect(offers.map((o) => o.id), [PlusProducts.plus, ...PlusProducts.tips]);
    expect(offers.first.price, r'$1.99');
    expect(offers.first.kind, OfferKind.plus);
    api.available = false;
    expect(await store.offers(), isEmpty);
  });

  test('buying Plus unlocks it, completes the purchase, and is remembered', () async {
    expect(store.unlocked, isFalse);
    expect(await store.buy(await offer(PlusProducts.plus)), PurchaseOutcome.bought);
    await settle();
    expect(store.unlocked, isTrue);
    expect(api.completed, [PlusProducts.plus]);
    // After a restart, before the store says anything
    expect(PlatformPlusStore(prefs: prefs, api: FakePurchaseApi(), supported: true).unlocked, isTrue);
  });

  test('a tip is a thank-you: completed, and never unlocks Plus', () async {
    expect(await store.buy(await offer(PlusProducts.tipMedium)), PurchaseOutcome.bought);
    await settle();
    expect(store.unlocked, isFalse);
    expect(api.completed, [PlusProducts.tipMedium]);
  });

  test('cancelled, pending (Ask to Buy) and failed purchases don\'t unlock', () async {
    api.next = PurchaseStatus.canceled;
    expect((await store.buy(await offer(PlusProducts.plus))).result, PurchaseResult.cancelled);
    api.next = PurchaseStatus.pending;
    expect((await store.buy(await offer(PlusProducts.plus))).result, PurchaseResult.pending);
    api.next = PurchaseStatus.error;
    api.deliver(PlusProducts.plus, PurchaseStatus.error, error: 'Payment declined');
    await settle();
    expect(store.unlocked, isFalse);

    // An approved Ask to Buy arrives later, on its own
    api.deliver(PlusProducts.plus, PurchaseStatus.purchased);
    await settle();
    expect(store.unlocked, isTrue);
  });

  test('a failure says why, in the store\'s words', () async {
    final plus = await offer(PlusProducts.plus);
    final buying = store.buy(plus);
    api.next = PurchaseStatus.error;
    // The fake delivers `next` as it was when buy was called (purchased); deliver an error first
    api.deliver(PlusProducts.plus, PurchaseStatus.error, error: 'Payment declined');
    final outcome = await buying;
    expect(outcome.result, PurchaseResult.failed);
    expect(outcome.message, 'Payment declined');
  });

  test('a purchase waiting from last time is completed at launch, and Plus bought elsewhere is found quietly', () async {
    final fresh = MemoryPrefs();
    final restored = FakePurchaseApi()..owned = [PlusProducts.plus];
    final store = PlatformPlusStore(prefs: fresh, api: restored, supported: true)..start();
    expect(restored.restores, 1, reason: 'a quiet look at launch');
    await settle();
    expect(store.unlocked, isTrue);
    expect(restored.completed, [PlusProducts.plus]);
  });

  test('Restore Purchases unlocks when the store has Plus, and not when it doesn\'t', () async {
    expect(await store.restore(), isFalse);
    api.owned = [PlusProducts.plus];
    expect(await store.restore(), isTrue);
  });

  test('unsupported (Android): nothing for sale, nothing started', () async {
    final android = PlatformPlusStore(prefs: MemoryPrefs(), api: api, supported: false)..start();
    expect(android.isSupported, isFalse);
    expect(await android.offers(), isEmpty);
  });

  test('a store that isn\'t there (no plugin) gives no offers rather than failing', () async {
    final missing = _MissingApi();
    final store = PlatformPlusStore(prefs: MemoryPrefs(), api: missing, supported: true)..start();
    expect(await store.offers(), isEmpty);
    expect(await store.restore(), isFalse);
  });
}

class _MissingApi extends FakePurchaseApi {
  @override
  Future<bool> isAvailable() => Future.error(MissingPluginException());
  @override
  Future<void> restorePurchases() => Future.error(MissingPluginException());
}
