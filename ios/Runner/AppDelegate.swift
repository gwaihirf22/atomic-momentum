import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: lets notifications show while the app is open
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    // Sync and Health while the app isn't on screen (BackgroundRun in CloudSync.swift)
    CloudSync.shared.startIfOn()
    BackgroundRun.registerRefresh()
    BackgroundRun.testAtLaunch()
    // Before launch ends, as iOS asks for Health's background delivery
    HealthWatch.startAtLaunch()
    NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
    ) { _ in BackgroundRun.scheduleRefresh() }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// iCloud's pushes when another device changed something (and test ones
  /// carrying `momentum`); any other goes to the plugins.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    guard let reason = BackgroundRun.reason(forPush: userInfo) else {
      return super.application(
        application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }
    BackgroundRun.push(reason) { changed in completionHandler(changed ? .newData : .noData) }
  }

  /// The app runs on the scene lifecycle (iOS 27 won't launch apps without
  /// it; Info.plist's UIApplicationSceneManifest), so Flutter makes the
  /// engine with the first scene and plugins and channels register here.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    AppIconChannel.register(messenger: messenger)
    StorefrontChannel.register(messenger: messenger)
    WidgetChannel.register(messenger: messenger)
    SyncChannel.register(messenger: messenger)
    HealthWatch.register(messenger: messenger)
    BackgroundRun.registerApp(engine: engineBridge.pluginRegistry as? FlutterEngine, messenger: messenger)
    DeviceChannel.register(messenger: messenger)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WidgetLinks") {
      WidgetLinks.register(with: registrar)
    }
  }
}

/// A home screen widget tapped outside its buttons (momentum://habit/<id>,
/// momentum://inspire): links that launched the app, or came while it ran.
/// With scenes these arrive through the scene, which Flutter passes on to
/// plugins that ask; this is ours.
class WidgetLinks: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.addSceneDelegate(WidgetLinks())
  }

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    for context in connectionOptions?.urlContexts ?? [] {
      _ = WidgetChannel.open(context.url)
    }
    // Leaves the connection to Flutter
    return false
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
    for context in URLContexts where WidgetChannel.open(context.url) {
      handled = true
    }
    return handled
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

  /// Where a widget that opened the app leads ("habit/<id>", "inspire"),
  /// kept until Flutter is listening.
  private static var opened: String?

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
        // Siri learns the habits' names for "Log water in Momentum"
        if #available(iOS 17.0, *) { MomentumShortcuts.updateAppShortcutParameters() }
        result(nil)
      case "takeLogs":
        result(WidgetStore.takeLogs())
      case "applied":
        resumeAll()
        result(nil)
      case "takeOpened":
        result(opened)
        opened = nil
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

  /// Handles momentum:// links from widgets (habit/<id>, inspire, insights,
  /// habits); false for any other link.
  static func open(_ url: URL) -> Bool {
    guard url.scheme == "momentum", let host = url.host else { return false }
    let route = ([host] + url.pathComponents.dropFirst()).joined(separator: "/")
    opened = route
    channel?.invokeMethod("open", arguments: route) { reply in
      // Flutter went there (it answers nil); otherwise it asks at launch
      if reply == nil { opened = nil }
    }
    return true
  }
}

/// `momentum/device`: whether this is an iPad. Dart can't tell a big iPhone
/// (the Duo, unfolded) from an iPad by its size alone.
enum DeviceChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "momentum/device", binaryMessenger: messenger).setMethodCallHandler { call, result in
      switch call.method {
      case "isTablet": result(UIDevice.current.userInterfaceIdiom == .pad)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
}
