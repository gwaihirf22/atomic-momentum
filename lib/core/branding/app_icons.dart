import 'package:flutter/foundation.dart';

/// An app icon offered in Settings → App icon.
///
/// Adding one: a source picture in assets/branding, a line in
/// tool/make_app_icons.py (run it), an entry here, an `<activity-alias>` in
/// AndroidManifest.xml, and its iOS name in the build setting
/// ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES. app_icons_test checks they
/// agree.
@immutable
class AppIconChoice {
  final String id;
  final String label;

  /// The iOS icon set; null is the primary icon (AppIcon).
  final String? iosName;

  /// The Android launcher alias; null when Android can't offer it.
  final String? androidAlias;

  /// The picture shown in Settings (for [followsSystem], the light one).
  final String preview;

  /// Light in light mode, dark in dark mode (iOS 18 and later); [darkPreview]
  /// is its other half.
  final bool followsSystem;
  final String? darkPreview;

  const AppIconChoice({
    required this.id,
    required this.label,
    required this.iosName,
    required this.androidAlias,
    required this.preview,
    this.followsSystem = false,
    this.darkPreview,
  });

  bool offeredOn(TargetPlatform platform) => switch (platform) {
        TargetPlatform.iOS => true,
        TargetPlatform.android => androidAlias != null,
        _ => false,
      };

  @override
  String toString() => 'AppIconChoice($id)';
}

class AppIcons {
  const AppIcons._();

  static const _previews = 'assets/branding/icons';

  static const system = AppIconChoice(
    id: 'system',
    label: 'Match system',
    iosName: null,
    androidAlias: null,
    preview: '$_previews/light.png',
    followsSystem: true,
    darkPreview: '$_previews/charged.png',
  );

  static const charged = AppIconChoice(
    id: 'charged',
    label: 'Charged',
    iosName: 'AppIcon-Charged',
    androidAlias: 'IconCharged',
    preview: '$_previews/charged.png',
  );

  static const light = AppIconChoice(
    id: 'light',
    label: 'Light',
    iosName: 'AppIcon-Light',
    androidAlias: 'IconLight',
    preview: '$_previews/light.png',
  );

  static const all = [system, charged, light];

  static List<AppIconChoice> offeredOn(TargetPlatform platform) =>
      all.where((icon) => icon.offeredOn(platform)).toList();

  /// What a new install shows: matching the system where it can (iOS),
  /// otherwise Light (Android takes Charged instead when it's first opened
  /// in dark mode, see MainActivity.kt).
  static AppIconChoice defaultFor(TargetPlatform platform) =>
      platform == TargetPlatform.iOS ? system : light;

  /// The choice for what the platform reports showing: an iOS icon name
  /// (null for the primary) or an Android alias.
  static AppIconChoice fromPlatform(TargetPlatform platform, String? name) {
    for (final icon in offeredOn(platform)) {
      final iconName = platform == TargetPlatform.iOS ? icon.iosName : icon.androidAlias;
      if (iconName == name) return icon;
    }
    return defaultFor(platform);
  }
}
