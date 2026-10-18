import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/sharer.dart';

/// Records what would have gone to the share sheet.
class FakeSharer implements Sharer {
  final shared = <({Uint8List png, String name, String? text})>[];

  @override
  Future<void> shareImage(Uint8List png, {required String name, String? text, Rect? origin}) async {
    shared.add((png: png, name: name, text: text));
  }

  /// Puts a fake in place of the real share sheet (after initializeDependencies).
  static FakeSharer install() {
    final fake = FakeSharer();
    if (sl.isRegistered<Sharer>()) sl.unregister<Sharer>();
    sl.registerSingleton<Sharer>(fake);
    return fake;
  }
}

/// A PNG's width and height, from its header.
(int, int) pngSize(Uint8List png) {
  int read(int at) => (png[at] << 24) | (png[at + 1] << 16) | (png[at + 2] << 8) | png[at + 3];
  return (read(16), read(20));
}
