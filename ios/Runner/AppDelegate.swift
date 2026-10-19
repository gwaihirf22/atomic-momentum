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
    if let registrar = self.registrar(forPlugin: "Widgets") {
      WidgetChannel.register(messenger: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // A home screen widget tapped outside its + (momentum://habit/<id>)
  override func application(
    _ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if WidgetChannel.open(url) { return true }
    return super.application(app, open: url, options: options)
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

/// The home screen widgets (ios/MomentumWidgets): the app saves their
/// snapshot to the App Group, takes the taps queued on their + and logs them
/// (lib/presentation/home_widgets/home_widget_sync.dart), and opens the habit
/// a widget was tapped on.
enum WidgetChannel {
  private static var channel: FlutterMethodChannel?

  /// Widget taps waiting for the app to log them (the intent stays running,
  /// so iOS keeps the app awake, until the app says they're applied).
  private static var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

  /// A habit whose widget opened the app before Flutter was listening.
  private static var openedHabit: String?

  /// How long a tap waits for the app before leaving it queued for later.
  private static let wait: TimeInterval = 8

  @MainActor
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "momentum/widgets", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "save":
        if let json = call.arguments as? String { WidgetStore.saveSnapshot(json) }
        result(nil)
      case "takeLogs":
        result(WidgetStore.takeLogs())
      case "applied":
        resumeAll()
        result(nil)
      case "takeOpenedHabit":
        result(openedHabit)
        openedHabit = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    if #available(iOS 17.0, *) {
      AppHook.logsWaiting = { await logsWaiting() }
    }
  }

  /// A widget's tap is queued: has the app log it, and waits until it has
  /// (or gives up after a few seconds; the tap stays queued for next time).
  @MainActor
  private static func logsWaiting() async {
    let id = UUID()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      waiters[id] = continuation
      channel?.invokeMethod("logsWaiting", arguments: nil)
      DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
        waiters.removeValue(forKey: id)?.resume()
      }
    }
  }

  private static func resumeAll() {
    let waiting = waiters.values
    waiters.removeAll()
    waiting.forEach { $0.resume() }
  }

  /// Handles momentum://habit/<id>; false for any other link.
  static func open(_ url: URL) -> Bool {
    guard url.scheme == "momentum" else { return false }
    if url.host == "habit", let id = url.pathComponents.dropFirst().first {
      openedHabit = id
      channel?.invokeMethod("openHabit", arguments: id) { reply in
        // Flutter showed it (it answers nil); otherwise it asks at launch
        if reply == nil { openedHabit = nil }
      }
    }
    return true
  }
}
