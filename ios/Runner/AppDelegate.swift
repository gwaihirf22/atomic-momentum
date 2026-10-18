import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: lets notifications show while the app is open
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "AppIcon") {
      AppIconChannel.register(messenger: registrar.messenger())
    }
    if let registrar = self.registrar(forPlugin: "Storefront") {
      StorefrontChannel.register(messenger: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Settings → App icon: which icon set is showing, and switching it. nil is
/// the primary icon (AppIcon), the others are listed in the build setting
/// ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
enum AppIconChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "momentum/app_icon", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let app = UIApplication.shared
      switch call.method {
      case "current":
        result(app.alternateIconName)
      case "set":
        let name = call.arguments as? String
        guard name != app.alternateIconName else { return result(nil) }
        app.setAlternateIconName(name) { error in
          if let error = error {
            result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// The App Store's country for this Apple ID ("USA"), or nil when unknown.
/// Settings offers "Buy me a coffee" (an outside link) only in the US, where
/// Apple allows it (guideline 3.1.1(a)).
enum StorefrontChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "momentum/storefront", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "country" else { return result(FlutterMethodNotImplemented) }
      Task { @MainActor in
        result(await Storefront.current?.countryCode)
      }
    }
  }
}
