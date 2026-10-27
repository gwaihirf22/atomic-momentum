import Foundation
import WidgetKit

// Shared by the app (Runner), the widget extension and the Apple Watch app
// and its complications: each reads and writes its own device's App Group,
// where the app leaves a snapshot to draw and the widgets leave the taps made
// on their + for the app to log (the watch sends its taps to the phone, which
// queues them here).

/// The App Group's keys and the reads and writes on them. Main thread only.
enum WidgetStore {
  static let appGroup = "group.com.paulblake.momentum"

  /// The JSON the app writes (lib/presentation/home_widgets/widget_snapshot.dart).
  static let snapshotKey = "widget_snapshot_v1"

  /// Taps waiting for the app: [{"id", "habit", "day": "2026-10-18"}], and
  /// from the watch "kind": "set" with "amount", or "kind": "twoMinute"
  /// (every value a string; lib/core/services/home_widget_bridge.dart).
  static let logsKey = "widget_logs_v1"

  static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

  static func snapshotJSON() -> String? { defaults?.string(forKey: snapshotKey) }

  /// Stores the app's snapshot and redraws every widget.
  static func saveSnapshot(_ json: String) {
    defaults?.set(json, forKey: snapshotKey)
    reloadAll()
  }

  /// Redraws every widget, and on iOS 18 the "Log a habit" controls.
  static func reloadAll() {
    WidgetCenter.shared.reloadAllTimelines()
    #if os(iOS)
    if #available(iOS 18.0, *) { ControlCenter.shared.reloadAllControls() }
    #endif
  }

  /// Queues a + tapped on [habitId]'s widget.
  static func queueLog(habitId: String, at now: Date) {
    queue(newLog(habitId: habitId, at: now))
  }

  /// A log for the app: one step by default, or [kind] "set" (with
  /// [amount]) or "twoMinute".
  static func newLog(habitId: String, at now: Date, kind: String? = nil, amount: Int? = nil) -> [String: String] {
    var log = ["id": UUID().uuidString, "habit": habitId, "day": dayString(now)]
    if let kind { log["kind"] = kind }
    if let amount { log["amount"] = String(amount) }
    return log
  }

  /// Adds [log] to the queue the app takes (a widget's, or one the watch sent).
  static func queue(_ log: [String: String]) {
    var logs = defaults?.array(forKey: logsKey) as? [[String: String]] ?? []
    logs.append(log)
    defaults?.set(logs, forKey: logsKey)
  }

  /// Every queued tap, oldest first; the queue is emptied.
  static func takeLogs() -> [[String: String]] {
    let logs = defaults?.array(forKey: logsKey) as? [[String: String]] ?? []
    defaults?.removeObject(forKey: logsKey)
    return logs
  }

  /// Shows a + at once: the habit one step further in the snapshot, until
  /// the app logs it and writes the real one. Same steps as the app's
  /// StepSize.up.
  static func showStep(habitId: String, at now: Date) {
    change(habitId: habitId, at: now) { progress, target, step in
      progress < target ? stepUp(progress, step: step, target: target) : nil
    }
  }

  /// Shows the watch's Crown at once: the period's amount set to [amount].
  static func showSet(habitId: String, amount: Int, at now: Date) {
    change(habitId: habitId, at: now) { progress, _, _ in amount == progress ? nil : max(0, amount) }
  }

  /// Shows the watch's "2 min" at once: the period kept with it.
  static func showTwoMinute(habitId: String, at now: Date) {
    edit(habitId: habitId, at: now) { habit, _ in
      guard var two = habit["twoMinute"] as? [String: Bool], two["can"] == true else { return false }
      two["done"] = true
      habit["twoMinute"] = two
      return true
    }
  }

  /// Sets a habit's progress in the stored snapshot to what [next] says
  /// (nil: leave it), with its text, done and next step to match.
  private static func change(habitId: String, at now: Date, next: (_ progress: Int, _ target: Int, _ step: Int) -> Int?) {
    edit(habitId: habitId, at: now) { habit, today in
      guard let target = habit["target"] as? Int, let step = habit["step"] as? Int, step > 0 else { return false }
      let progress = habit["progress"] as? Int ?? 0
      guard let value = next(progress, target, step) else { return false }
      let units = (habit["units"] as? String).map { $0.isEmpty ? "" : " \($0)" } ?? ""
      let wasDone = habit["done"] as? Bool == true
      habit["progress"] = value
      habit["done"] = value >= target
      habit["text"] = "\(value) of \(target)\(units)"
      habit["next"] = value < target ? stepUp(value, step: step, target: target) : NSNull()
      if habit["due"] as? Bool == true, (value >= target) != wasDone {
        let done = (today["done"] ?? 0) + (value >= target ? 1 : -1)
        today["done"] = min(max(done, 0), today["due"] ?? 0)
      }
      return true
    }
  }

  /// Edits one habit of the stored snapshot (and today's count) in place.
  private static func edit(habitId: String, at now: Date, _ body: (inout [String: Any], inout [String: Int]) -> Bool) {
    guard let json = snapshotJSON(), let data = json.data(using: .utf8),
          var snapshot = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          var habits = snapshot["habits"] as? [[String: Any]],
          let index = habits.firstIndex(where: { $0["id"] as? String == habitId })
    else { return }
    var habit = habits[index]
    // A new period since the app last wrote: it starts from nothing
    if let ends = (habit["periodEnds"] as? String).flatMap(parseLocal), ends <= now {
      habit["progress"] = 0
      habit["done"] = false
      habit["periodEnds"] = NSNull()
      if habit["twoMinute"] is [String: Bool] { habit["twoMinute"] = ["can": true, "done": false] }
    }
    var today = snapshot["today"] as? [String: Int] ?? [:]
    guard body(&habit, &today) else { return }
    habits[index] = habit
    snapshot["habits"] = habits
    if !today.isEmpty { snapshot["today"] = today }
    if let out = try? JSONSerialization.data(withJSONObject: snapshot), let string = String(data: out, encoding: .utf8) {
      defaults?.set(string, forKey: snapshotKey)
    }
  }

  /// The app's StepSize.up: to the next whole step, never past the target.
  static func stepUp(_ value: Int, step: Int, target: Int) -> Int {
    let next = (value / step + 1) * step
    return value < target && next > target ? target : next
  }

  private static let localFormat: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return f
  }()

  private static let dayFormat: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  /// "2026-10-19T00:00:00" in the phone's time zone, as the app writes it.
  static func parseLocal(_ string: String) -> Date? {
    localFormat.timeZone = .current
    return localFormat.date(from: string)
  }

  static func dayString(_ date: Date) -> String {
    dayFormat.timeZone = .current
    return dayFormat.string(from: date)
  }
}

#if os(iOS)
/// Set by the app (AppDelegate) so a widget's tap, run in the app's process,
/// can have the app log it at once. Nil in the widget extension.
enum AppHook {
  @MainActor static var logsWaiting: (() async -> Void)?
}
#endif
