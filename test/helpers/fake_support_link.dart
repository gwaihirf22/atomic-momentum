import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/support_link.dart';

/// "Buy me a coffee" without a browser: [available] decides whether Settings
/// shows it, and [opened] counts taps.
class FakeSupportLink implements SupportLink {
  bool available;
  bool opens;
  int opened = 0;

  FakeSupportLink({this.available = true, this.opens = true});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> open() async {
    opened++;
    return opens;
  }

  /// Puts a fake in place of the real one (after initializeDependencies).
  static FakeSupportLink install({bool available = true, bool opens = true}) {
    final fake = FakeSupportLink(available: available, opens: opens);
    if (sl.isRegistered<SupportLink>()) sl.unregister<SupportLink>();
    sl.registerSingleton<SupportLink>(fake);
    return fake;
  }
}
