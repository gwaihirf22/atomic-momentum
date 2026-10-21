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

  /// The developer's tip page ("Buy me a coffee" in Settings, US only; see
  /// SupportLink), shared with the developer's other apps. Empty would hide
  /// the row.
  static const coffee = 'https://buymeacoffee.com/paulblake';

  /// The privacy policy (Settings → About, and the App Store listing). Its
  /// text is the website's pages/momentum/privacy.js; docs/store has a copy.
  static const privacy = 'https://paul-blake.com/momentum/privacy';

  /// Help and the support address (Settings → About, the App Store's
  /// Support URL).
  static const support = 'https://paul-blake.com/momentum/support';

  static const supportEmail = 'momentum@paul-blake.com';

  /// Who makes Momentum (Settings → About, the listing's copyright). A brand,
  /// not the App Store seller: an individual account shows Paul's legal name.
  static const maker = 'Blake Built';

  static const copyright = '© 2026 $maker';
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
