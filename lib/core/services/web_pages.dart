import 'package:url_launcher/url_launcher.dart';

/// Opens the app's own web pages (the privacy policy, support) in the
/// browser. Tests use a fake.
abstract class WebPages {
  /// Opens [url]; false if it couldn't.
  Future<bool> open(String url);
}

class PlatformWebPages implements WebPages {
  const PlatformWebPages();

  @override
  Future<bool> open(String url) async {
    try {
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
