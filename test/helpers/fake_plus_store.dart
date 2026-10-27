import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/plus_store.dart';

/// [PlusStore] for widget tests: Plus and the tips at US prices, and each
/// purchase going however [next] says.
class FakePlusStore extends PlusStore {
  @override
  bool isSupported;

  bool _unlocked;
  bool _pretending = false;

  /// How the next purchase goes.
  PurchaseOutcome next = PurchaseOutcome.bought;

  /// Whether the store can be reached (no offers when it can't).
  bool reachable = true;

  /// Restore Purchases finds Plus.
  bool restoreFinds = false;

  final bought = <String>[];
  int restores = 0;

  FakePlusStore({this.isSupported = true, bool unlocked = false}) : _unlocked = unlocked;

  static FakePlusStore install({bool isSupported = true, bool unlocked = false}) {
    final fake = FakePlusStore(isSupported: isSupported, unlocked: unlocked);
    if (sl.isRegistered<PlusStore>()) sl.unregister<PlusStore>();
    sl.registerSingleton<PlusStore>(fake);
    return fake;
  }

  @override
  bool get unlocked => _unlocked || _pretending;

  set unlocked(bool value) {
    _unlocked = value;
    notifyListeners();
  }

  @override
  bool get pretending => _pretending;

  @override
  Future<void> setPretending(bool on) async {
    _pretending = on;
    notifyListeners();
  }

  static const plusOffer = PlusOffer(id: PlusProducts.plus, kind: OfferKind.plus, price: r'$1.99');
  static const tipOffers = [
    PlusOffer(id: PlusProducts.tipSmall, kind: OfferKind.tip, price: r'$0.99'),
    PlusOffer(id: PlusProducts.tipMedium, kind: OfferKind.tip, price: r'$2.99'),
    PlusOffer(id: PlusProducts.tipLarge, kind: OfferKind.tip, price: r'$4.99'),
  ];

  @override
  Future<List<PlusOffer>> offers() async => reachable && isSupported ? const [plusOffer, ...tipOffers] : const [];

  @override
  Future<PurchaseOutcome> buy(PlusOffer offer) async {
    final outcome = next;
    if (outcome.result == PurchaseResult.bought) {
      bought.add(offer.id);
      if (offer.kind == OfferKind.plus) unlocked = true;
    }
    return outcome;
  }

  @override
  Future<bool> restore() async {
    restores++;
    if (restoreFinds) unlocked = true;
    return unlocked;
  }
}
