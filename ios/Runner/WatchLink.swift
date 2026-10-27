import Foundation
import UIKit
import WatchConnectivity
import os

/// The phone's side of the Apple Watch app (docs/design/watch.md): hands
/// the watch the same snapshot the widgets draw, and takes the watch's taps
/// into the widgets' queue, so the app logs them as a card's + would.
///
/// The latest snapshot goes as the application context (the newest replaces
/// the last, delivered when the watch wakes); the watch's logs come as user
/// info (guaranteed, in order, even when the phone was away), which iOS hands
/// over by launching the app in the background if it isn't running.
final class WatchLink: NSObject, WCSessionDelegate {
  static let shared = WatchLink()
  private static let log = Logger(subsystem: "com.paulblake.momentum", category: "watch")

  /// The snapshot not yet handed over (main thread).
  private var latest: String?

  /// Starts the session; in didFinishLaunching, so a log the watch sent is
  /// taken even when that's what launched the app.
  static func start() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = shared
    WCSession.default.activate()
  }

  /// The app wrote a new snapshot (WidgetChannel's or BackgroundWidgets'
  /// save): hands it to the watch.
  static func send(_ json: String) {
    guard WCSession.isSupported() else { return }
    onMain {
      shared.latest = json
      shared.push()
    }
  }

  private func push() {
    let session = WCSession.default
    // Not isWatchAppInstalled as well: it can lag behind an install (and
    // stays false for one made with simctl); without the app this just fails
    guard session.activationState == .activated, session.isPaired,
          let json = latest ?? WidgetStore.snapshotJSON()
    else { return }
    do {
      try session.updateApplicationContext(["snapshot": json])
      latest = nil
    } catch {
      Self.log.notice("Snapshot not sent to the watch: \(error.localizedDescription, privacy: .public)")
    }
  }

  func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
    Self.onMain { self.push() }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  /// Paired with another watch: starts again for it.
  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  /// The watch app was just installed (or the watch paired): it gets the
  /// snapshot at once.
  func sessionWatchStateDidChange(_ session: WCSession) {
    Self.onMain { self.push() }
  }

  /// A tap on the watch sent as a message (the phone reachable).
  func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    take(message)
    replyHandler(["ok": true])
  }

  /// A tap on the watch queued while the phone was away (or a message that
  /// failed).
  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    take(userInfo)
  }

  /// Ids of the watch's logs already taken, newest last (a log can come both
  /// as a message and queued).
  private static let seenKey = "watch_logs_seen_v1"

  /// Takes the watch's log once (by its id).
  private func take(_ payload: [String: Any]) {
    guard let log = payload["log"] as? [String: String], let id = log["id"] else { return }
    Task { @MainActor in
      let defaults = WidgetStore.defaults
      var seen = defaults?.stringArray(forKey: Self.seenKey) ?? []
      guard !seen.contains(id) else { return }
      seen.append(id)
      defaults?.set(Array(seen.suffix(200)), forKey: Self.seenKey)
      await Self.deliver(log)
    }
  }

  /// Queues [log] where the widgets queue theirs, then has the app log it
  /// if it's running, or a background engine if not (the watch's taps, and
  /// a reminder's Log button).
  @MainActor
  static func deliver(_ log: [String: String]) async {
    WidgetStore.queue(log)
    let task = UIApplication.shared.beginBackgroundTask(withName: "Log")
    defer {
      if task != .invalid { UIApplication.shared.endBackgroundTask(task) }
    }
    if BackgroundRun.appIsRunning, let logsWaiting = AppHook.logsWaiting {
      await logsWaiting()
    } else if UIApplication.shared.applicationState == .background {
      await withCheckedContinuation { done in BackgroundRun.run("watch") { _ in done.resume() } }
    }
    // Else opening on screen: the app takes the queue as it loads (a
    // second, background engine beside it held the launch)
  }

  private static func onMain(_ body: @escaping () -> Void) {
    if Thread.isMainThread {
      body()
    } else {
      DispatchQueue.main.async(execute: body)
    }
  }
}
