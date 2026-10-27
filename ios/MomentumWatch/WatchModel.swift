import SwiftUI
import WatchConnectivity
import WatchKit

/// The watch's side (docs/design/watch.md): the phone's snapshot, as the
/// widgets get it, and taps sent back to the phone, which logs them as the
/// card's + would. A tap shows at once (the same arithmetic as a widget's
/// +), then the phone's next snapshot replaces the guess.
@MainActor
final class WatchModel: NSObject, ObservableObject {
  static let shared = WatchModel()

  @Published private(set) var snapshot: Snapshot?

  /// When the oldest tap not yet with the phone was made (nil: none).
  @Published private(set) var waitingSince: Date?

  /// A habit a complication was tapped on, to show.
  @Published var openHabit: String?

  /// Taps older than this not yet with the phone get a mark on Today.
  static let lateAfter: TimeInterval = 60 * 60

  func start() {
    reload()
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  /// Reads the stored snapshot again.
  func reload() {
    snapshot = Snapshot.load()
    let made = WCSession.isSupported()
      ? WCSession.default.outstandingUserInfoTransfers.compactMap { $0.userInfo["made"] as? Double }
      : []
    waitingSince = made.min().map(Date.init(timeIntervalSince1970:))
  }

  var plus: Bool { snapshot?.plus == true }

  /// The watch's +: one step toward the target.
  func step(_ habit: HabitInfo) {
    let now = Date()
    WidgetStore.showStep(habitId: habit.id, at: now)
    send(WidgetStore.newLog(habitId: habit.id, at: now))
    WKInterfaceDevice.current().play(habit.progress + habit.step >= habit.target ? .success : .click)
  }

  /// The Crown: the period's amount set to [amount].
  func set(_ habit: HabitInfo, to amount: Int) {
    let now = Date()
    WidgetStore.showSet(habitId: habit.id, amount: amount, at: now)
    send(WidgetStore.newLog(habitId: habit.id, at: now, kind: "set", amount: amount))
    if amount >= habit.target, habit.progress < habit.target { WKInterfaceDevice.current().play(.success) }
  }

  /// "2 min": the period kept with the two-minute version.
  func twoMinute(_ habit: HabitInfo) {
    let now = Date()
    WidgetStore.showTwoMinute(habitId: habit.id, at: now)
    send(WidgetStore.newLog(habitId: habit.id, at: now, kind: "twoMinute"))
    WKInterfaceDevice.current().play(.success)
  }

  /// Sends a log to the phone: as a message when it's reachable (at once,
  /// waking the iPhone app if it isn't running), else queued (guaranteed,
  /// delivered when it is). The phone takes a log's id once, so one sent both
  /// ways is logged once.
  private func send(_ log: [String: String]) {
    if WCSession.isSupported() {
      let session = WCSession.default
      let info: [String: Any] = ["log": log, "made": Date().timeIntervalSince1970]
      if session.activationState == .activated, session.isReachable {
        session.sendMessage(info, replyHandler: { _ in }, errorHandler: { _ in
          session.transferUserInfo(info)
          Task { @MainActor in self.reload() }
        })
      } else {
        session.transferUserInfo(info)
      }
    }
    WidgetStore.reloadAll()
    reload()
  }

  /// The phone's snapshot arrived: stored for the app and the complications.
  fileprivate func take(_ context: [String: Any]) {
    guard let json = context["snapshot"] as? String else { return }
    WidgetStore.saveSnapshot(json)
    reload()
  }
}

extension WatchModel: WCSessionDelegate {
  nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
    let context = session.receivedApplicationContext
    Task { @MainActor in
      if !context.isEmpty { self.take(context) }
    }
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
    Task { @MainActor in self.take(context) }
  }

  nonisolated func session(_ session: WCSession, didFinish transfer: WCSessionUserInfoTransfer, error: Error?) {
    Task { @MainActor in self.reload() }
  }
}

extension HabitInfo {
  /// The habit as Today shows it now (a new period starts from nothing).
  var now: HabitInfo { at(Date()) }

  /// Whether the watch's + is offered: not for a habit being broken (a stray
  /// tap would log a slip; slips are logged on the phone), frozen, or done.
  var canStep: Bool { !isBreak && frozen != true && next != nil }
}
