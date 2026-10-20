import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/web_pages.dart';

/// The app's web pages without a browser: [opened] lists what was opened.
class FakeWebPages implements WebPages {
  bool opens;
  final opened = <String>[];

  FakeWebPages({this.opens = true});

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return opens;
  }

  /// Puts a fake in place of the real one (after initializeDependencies).
  static FakeWebPages install({bool opens = true}) {
    final fake = FakeWebPages(opens: opens);
    if (sl.isRegistered<WebPages>()) sl.unregister<WebPages>();
    sl.registerSingleton<WebPages>(fake);
    return fake;
  }
}
