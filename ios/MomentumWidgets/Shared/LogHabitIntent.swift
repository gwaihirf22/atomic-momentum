import AppIntents
import WidgetKit

/// The + on a habit's widget: one step toward the target.
///
/// Built into both the app and the widget extension. Being an
/// AudioPlaybackIntent makes iOS run it in the app's process (starting the
/// app in the background if needed), so the app can log the tap straight
/// away, the way a tap on the card does: streaks, momentum, Health and
/// reminders all follow. The widget shows the step at once in the meantime.
@available(iOS 17.0, *)
struct LogHabitIntent: AppIntent {
  static var title: LocalizedStringResource = "Log a habit"
  static var description = IntentDescription("Adds one step to a habit's progress for today.")
  static var isDiscoverable = false

  @Parameter(title: "Habit")
  var habitId: String

  init() {}

  init(habitId: String) {
    self.habitId = habitId
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    let now = Date()
    WidgetStore.queueLog(habitId: habitId, at: now)
    WidgetStore.showStep(habitId: habitId, at: now)
    WidgetCenter.shared.reloadAllTimelines()
    // The app logs it and writes the real snapshot (or, if it can't run now,
    // the tap waits in the queue until it next opens)
    await AppHook.logsWaiting?()
    return .result()
  }
}

@available(iOS 17.0, *)
extension LogHabitIntent: AudioPlaybackIntent {}
