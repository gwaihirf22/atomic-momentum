import Foundation
import WidgetKit

// Shared by the app (Runner) and the widget extension: both read and write
// the App Group, where the app leaves a snapshot for the widgets to draw and
// the widgets leave the taps made on their + for the app to log.

/// The App Group's keys and the reads and writes on them. Main thread only.
enum WidgetStore {
  static let appGroup = "group.com.paulblake.momentum"

  /// The JSON the app writes (lib/presentation/home_widgets/widget_snapshot.dart).
  static let snapshotKey = "widget_snapshot_v1"

  /// Taps waiting for the app: [{"id", "habit", "day": "2026-10-18"}].
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
    if #available(iOS 18.0, *) { ControlCenter.shared.reloadAllControls() }
  }

  /// Queues a + tapped on [habitId]'s widget.
  static func queueLog(habitId: String, at now: Date) {
    var logs = defaults?.array(forKey: logsKey) as? [[String: String]] ?? []
    logs.append(["id": UUID().uuidString, "habit": habitId, "day": dayString(now)])
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
    guard let json = snapshotJSON(), let data = json.data(using: .utf8),
          var snapshot = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          var habits = snapshot["habits"] as? [[String: Any]],
          let index = habits.firstIndex(where: { $0["id"] as? String == habitId })
    else { return }
    var habit = habits[index]
    guard let target = habit["target"] as? Int, let step = habit["step"] as? Int, step > 0 else { return }
    var progress = habit["progress"] as? Int ?? 0
    // A new period since the app last wrote: it starts from nothing
    if let ends = (habit["periodEnds"] as? String).flatMap(parseLocal), ends <= now {
      progress = 0
      habit["periodEnds"] = NSNull()
    }
    guard progress < target else { return }
    let next = stepUp(progress, step: step, target: target)
    let units = (habit["units"] as? String).map { $0.isEmpty ? "" : " \($0)" } ?? ""
    habit["progress"] = next
    habit["done"] = next >= target
    habit["text"] = "\(next) of \(target)\(units)"
    habit["next"] = next < target ? stepUp(next, step: step, target: target) : NSNull()
    habits[index] = habit
    snapshot["habits"] = habits
    if next >= target, habit["due"] as? Bool == true, var today = snapshot["today"] as? [String: Int] {
      today["done"] = min((today["done"] ?? 0) + 1, today["due"] ?? 0)
      snapshot["today"] = today
    }
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

/// Set by the app (AppDelegate) so a widget's tap, run in the app's process,
/// can have the app log it at once. Nil in the widget extension.
enum AppHook {
  @MainActor static var logsWaiting: (() async -> Void)?
}
