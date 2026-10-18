import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:share_plus/share_plus.dart';

/// Where Momentum can be got. Empty until it's on the App Store: then share
/// cards say "on the App Store" and shares carry the link.
class AppLinks {
  const AppLinks._();

  static const store = '';

  static bool get hasStore => store.isNotEmpty;

  /// Sent along with a shared picture (null before launch: the card itself
  /// carries the name).
  static String? get shareText => hasStore ? 'Made with Momentum: $store' : null;
}

/// Hands a picture to the phone's share sheet (Messages, WhatsApp, Telegram,
/// Instagram…). Tests use a fake.
abstract class Sharer {
  /// [origin] is where the share sheet points from on iPad.
  Future<void> shareImage(Uint8List png, {required String name, String? text, Rect? origin});
}

class SystemSharer implements Sharer {
  const SystemSharer();

  @override
  Future<void> shareImage(Uint8List png, {required String name, String? text, Rect? origin}) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(png, mimeType: 'image/png', name: name)],
      fileNameOverrides: [name],
      text: text,
      sharePositionOrigin: origin,
    ));
  }
}
