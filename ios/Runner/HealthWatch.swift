import Flutter
import HealthKit
import UIKit
import os

/// Tells the app when Apple Health changes what a linked habit reads:
/// steps as they're counted, or another device's arriving through iCloud.
/// With the app open, Dart reads Health again ("changed" on
/// `momentum/health_watch`, HealthLive); in the background, Health wakes
/// the app (background delivery) and BackgroundRun does the work
/// ("health"), so reminders stop and widgets follow.
///
/// Dart says what to watch ("watch", HealthMetric names); the list is kept
/// so the queries start at launch, before Flutter, as iOS asks for
/// background delivery.
enum HealthWatch {
  private static let store = HKHealthStore()
  private static let key = "momentum.healthWatch"
  private static let log = Logger(subsystem: "com.paulblake.momentum", category: "health")

  private static var queries: [HKObserverQuery] = []
  private static var channel: FlutterMethodChannel?
  private static var lastRun: Date?

  /// Background runs closer together than this are skipped (Health writes
  /// in bursts; steps come at most hourly anyway).
  private static let gap: TimeInterval = 5 * 60

  private static func trace(_ message: String) {
    log.notice("\(message, privacy: .public)")
    if _isDebugAssertConfiguration() { NSLog("HealthWatch: %@", message) }
  }

  /// The app's engine is up.
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "momentum/health_watch", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "watch" else { return result(FlutterMethodNotImplemented) }
      let metrics = (call.arguments as? [String]) ?? []
      let before = saved
      if Set(metrics) != Set(before) {
        UserDefaults.standard.set(metrics, forKey: key)
        start(metrics, dropping: before)
      }
      result(nil)
    }
  }

  /// At launch: watches what the app last asked for.
  static func startAtLaunch() {
    start(saved, dropping: [])
  }

  private static var saved: [String] {
    UserDefaults.standard.stringArray(forKey: key) ?? []
  }

  private static func types(_ metric: String) -> [HKSampleType] {
    switch metric {
    case "steps": return [HKQuantityType(.stepCount)]
    case "exerciseMinutes": return [HKQuantityType(.appleExerciseTime), HKObjectType.workoutType()]
    case "workouts": return [HKObjectType.workoutType()]
    case "sleepHours": return [HKCategoryType(.sleepAnalysis)]
    case "mindfulMinutes": return [HKCategoryType(.mindfulSession)]
    case "water": return [HKQuantityType(.dietaryWater)]
    default: return []
    }
  }

  /// Watches [metrics], no longer waking for what only [dropping] read.
  private static func start(_ metrics: [String], dropping: [String]) {
    guard HKHealthStore.isHealthDataAvailable() else { return }
    queries.forEach { store.stop($0) }
    queries = []
    var watched = Set<HKSampleType>()
    for type in metrics.flatMap(types) where watched.insert(type).inserted {
      let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
        guard error == nil else {
          completion()
          return
        }
        DispatchQueue.main.async { heard(completion) }
      }
      store.execute(query)
      queries.append(query)
    }
    // Background delivery needs its entitlement (builds signed without it
    // just don't wake); steps can't come more often than hourly
    for type in Set(dropping.flatMap(types)).subtracting(watched) {
      store.disableBackgroundDelivery(for: type) { _, _ in }
    }
    for type in watched {
      let frequency: HKUpdateFrequency = type == HKQuantityType(.stepCount) ? .hourly : .immediate
      store.enableBackgroundDelivery(for: type, frequency: frequency) { _, error in
        if let error { trace("No background delivery: \(error.localizedDescription)") }
      }
    }
    trace("Watching \(watched.count) kinds of data")
  }

  /// Health changed: the app reads it again if it's open, or wakes for it.
  private static func heard(_ completion: @escaping () -> Void) {
    guard UIApplication.shared.applicationState == .background else {
      // Open, or opening (it reads Health as it loads)
      channel?.invokeMethod("changed", arguments: nil)
      return completion()
    }
    if let last = lastRun, Date().timeIntervalSince(last) < gap {
      return completion()
    }
    lastRun = Date()
    trace("Health changed in the background")
    BackgroundRun.run("health") { _ in completion() }
  }
}
