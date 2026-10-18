import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_momentum/core/branding/app_icons.dart';

void main() {
  group('the icons on offer', () {
    test('have different ids and names', () {
      expect(AppIcons.all.map((i) => i.id).toSet(), hasLength(AppIcons.all.length));
      expect(AppIcons.all.map((i) => i.label).toSet(), hasLength(AppIcons.all.length));
      final iosNames = AppIcons.all.map((i) => i.iosName).toList();
      expect(iosNames.toSet(), hasLength(iosNames.length));
      final aliases = AppIcons.all.map((i) => i.androidAlias).whereType<String>().toList();
      expect(aliases.toSet(), hasLength(aliases.length));
    });

    test('one follows the system: the primary iOS icon, not on Android', () {
      final following = AppIcons.all.where((i) => i.followsSystem).toList();
      expect(following, [AppIcons.system]);
      expect(AppIcons.system.iosName, isNull);
      expect(AppIcons.system.darkPreview, isNotNull);
      expect(AppIcons.offeredOn(TargetPlatform.android), isNot(contains(AppIcons.system)));
    });

    test('a new install matches the system on iOS and is Charged on Android', () {
      expect(AppIcons.defaultFor(TargetPlatform.iOS), AppIcons.system);
      expect(AppIcons.defaultFor(TargetPlatform.android), AppIcons.charged);
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        expect(AppIcons.offeredOn(platform), contains(AppIcons.defaultFor(platform)));
      }
    });

    test('none are offered on web or Mac', () {
      expect(AppIcons.offeredOn(TargetPlatform.macOS), isEmpty);
    });

    test('what the phone reports maps back to a choice', () {
      expect(AppIcons.fromPlatform(TargetPlatform.iOS, null), AppIcons.system);
      expect(AppIcons.fromPlatform(TargetPlatform.iOS, 'AppIcon-Light'), AppIcons.light);
      expect(AppIcons.fromPlatform(TargetPlatform.android, 'IconCharged'), AppIcons.charged);
      expect(AppIcons.fromPlatform(TargetPlatform.android, 'IconLight'), AppIcons.light);
      // An icon from a newer or older version falls back to the default
      expect(AppIcons.fromPlatform(TargetPlatform.iOS, 'AppIcon-Gone'), AppIcons.system);
      expect(AppIcons.fromPlatform(TargetPlatform.android, null), AppIcons.charged);
    });
  });

  // tool/make_app_icons.py, the Xcode project and the Android manifest must
  // agree with AppIcons, or picking an icon fails on the phone
  group('each icon exists on the phones', () {
    final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    const res = 'android/app/src/main/res';
    final colours = File('$res/values/ic_launcher_colors.xml').readAsStringSync();

    test('iOS: an icon set with a light and a dark picture, listed in the build settings', () {
      final listed = RegExp(r'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "([^"]*)";')
          .allMatches(pbxproj)
          .map((m) => m.group(1)!.split(' ').toSet())
          .toList();
      expect(listed, hasLength(3), reason: 'Debug, Release and Profile');
      final alternates = AppIcons.all.map((i) => i.iosName).whereType<String>().toSet();
      for (final names in listed) {
        expect(names, alternates);
      }
      for (final name in ['AppIcon', ...alternates]) {
        final folder = 'ios/Runner/Assets.xcassets/$name.appiconset';
        final contents = jsonDecode(File('$folder/Contents.json').readAsStringSync()) as Map<String, dynamic>;
        final images = (contents['images'] as List).cast<Map<String, dynamic>>();
        expect(images.where((i) => i['appearances'] == null), hasLength(1), reason: name);
        expect(images.where((i) => i['appearances'] != null), hasLength(1), reason: '$name in dark mode');
        for (final image in images) {
          expect(File('$folder/${image['filename']}').existsSync(), isTrue, reason: '$name: ${image['filename']}');
        }
      }
    });

    test('Android: a launcher alias with its adaptive icon, only the default enabled', () {
      final aliases = RegExp(r'<activity-alias\s+([^>]*)>').allMatches(manifest).map((m) => m.group(1)!).toList();
      for (final icon in AppIcons.offeredOn(TargetPlatform.android)) {
        final alias = aliases.singleWhere((a) => a.contains('android:name=".${icon.androidAlias}"'),
            orElse: () => fail('no <activity-alias> for ${icon.androidAlias}'));
        final enabled = icon == AppIcons.defaultFor(TargetPlatform.android);
        expect(alias, contains('android:enabled="$enabled"'), reason: icon.id);
        final mipmap = RegExp(r'android:icon="@mipmap/(\w+)"').firstMatch(alias)!.group(1);
        for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
          for (final file in ['$mipmap.png', '${mipmap}_foreground.png', '${mipmap}_monochrome.png']) {
            expect(File('$res/mipmap-$density/$file').existsSync(), isTrue, reason: '$file at $density');
          }
        }
        // Adaptive, so each launcher masks it to its own shape
        final adaptive = File('$res/mipmap-anydpi-v26/$mipmap.xml').readAsStringSync();
        expect(adaptive, contains('@mipmap/${mipmap}_foreground'));
        expect(adaptive, contains('@mipmap/${mipmap}_monochrome'));
        expect(adaptive, contains('@color/${mipmap}_background'));
        expect(colours, contains('name="${mipmap}_background"'));
      }
      final iconAliases = aliases.where((a) => a.contains('android:name=".Icon')).toList();
      expect(iconAliases, hasLength(AppIcons.offeredOn(TargetPlatform.android).length),
          reason: 'every launcher alias is in AppIcons');
    });

    test('previews are bundled', () {
      expect(pubspec, contains('- assets/branding/icons/'));
      for (final icon in AppIcons.all) {
        for (final preview in [icon.preview, icon.darkPreview].whereType<String>()) {
          expect(preview, startsWith('assets/branding/icons/'));
          expect(File(preview).existsSync(), isTrue, reason: preview);
        }
      }
    });
  });
}
