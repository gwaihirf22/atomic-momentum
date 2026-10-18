import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../branding/app_icons.dart';

/// Couldn't change the app icon.
class AppIconException implements Exception {
  final String message;

  const AppIconException(this.message);

  @override
  String toString() => 'AppIconException: $message';
}

/// Which app icon shows on the home screen, and switching it. The phone keeps
/// the choice (nothing is saved in the app), so this always says what's
/// really there. Tests use a fake.
abstract class AppIconService {
  TargetPlatform get platform;

  /// Icons change on iPhone and Android only (not web or Mac).
  bool get isSupported;

  Future<AppIconChoice> current();

  /// Throws [AppIconException] when the phone refuses. On Android the icon
  /// changes once the app leaves the screen.
  Future<void> set(AppIconChoice icon);
}

/// Talks to AppDelegate.swift (iOS) and MainActivity.kt (Android).
class PlatformAppIconService implements AppIconService {
  static const _channel = MethodChannel('momentum/app_icon');

  const PlatformAppIconService();

  @override
  TargetPlatform get platform => defaultTargetPlatform;

  @override
  bool get isSupported => !kIsWeb && (platform == TargetPlatform.iOS || platform == TargetPlatform.android);

  @override
  Future<AppIconChoice> current() async {
    if (!isSupported) return AppIcons.defaultFor(platform);
    try {
      return AppIcons.fromPlatform(platform, await _channel.invokeMethod<String>('current'));
    } on MissingPluginException {
      return AppIcons.defaultFor(platform);
    } on PlatformException {
      return AppIcons.defaultFor(platform);
    }
  }

  @override
  Future<void> set(AppIconChoice icon) async {
    if (!icon.offeredOn(platform)) throw AppIconException('${icon.label} isn\'t offered here');
    try {
      await _channel.invokeMethod<void>('set', platform == TargetPlatform.iOS ? icon.iosName : icon.androidAlias);
    } on PlatformException catch (e) {
      throw AppIconException(e.message ?? e.code);
    } on MissingPluginException catch (e) {
      throw AppIconException(e.message ?? 'Not available');
    }
  }
}
