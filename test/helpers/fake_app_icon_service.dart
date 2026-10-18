import 'package:flutter/foundation.dart';
import 'package:atomic_momentum/core/branding/app_icons.dart';
import 'package:atomic_momentum/core/injection/injection_container.dart';
import 'package:atomic_momentum/core/services/app_icon_service.dart';

/// An app icon that changes without a phone; [failWith] makes the next
/// change fail.
class FakeAppIconService implements AppIconService {
  @override
  final TargetPlatform platform;
  @override
  final bool isSupported;
  AppIconChoice icon;
  String? failWith;
  final changes = <AppIconChoice>[];

  FakeAppIconService({this.platform = TargetPlatform.iOS, this.isSupported = true, AppIconChoice? icon})
      : icon = icon ?? AppIcons.defaultFor(platform);

  @override
  Future<AppIconChoice> current() async => icon;

  @override
  Future<void> set(AppIconChoice choice) async {
    final failure = failWith;
    if (failure != null) {
      failWith = null;
      throw AppIconException(failure);
    }
    changes.add(choice);
    icon = choice;
  }

  /// Puts a fake in place of the real one (after initializeDependencies).
  static FakeAppIconService install({TargetPlatform platform = TargetPlatform.iOS, bool isSupported = true}) {
    final fake = FakeAppIconService(platform: platform, isSupported: isSupported);
    if (sl.isRegistered<AppIconService>()) sl.unregister<AppIconService>();
    sl.registerSingleton<AppIconService>(fake);
    return fake;
  }
}
