import AppIntents
import SwiftUI
import WidgetKit

// "Log a habit": a button for Control Center or a lock screen corner (iOS
// 18), in place of the flashlight or camera. One tap adds one step to the
// habit picked for it, through the same LogHabitIntent as a widget's +.

@available(iOS 18.0, *)
struct PickHabitControlIntent: ControlConfigurationIntent {
  static var title: LocalizedStringResource = "Log a habit"
  static var description = IntentDescription("Pick the habit this button logs.")

  @Parameter(title: "Habit")
  var habit: HabitEntity?

  init() {}
}

@available(iOS 18.0, *)
struct LogHabitControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    AppIntentControlConfiguration(kind: "logHabit", provider: Provider()) { value in
      ControlWidgetButton(action: LogHabitIntent(habitId: value.id ?? "")) {
        Label(value.name, systemImage: value.done ? "checkmark.circle.fill" : "plus.circle.fill")
      }
    }
    .displayName("Log a habit")
    .description("One tap adds one step to a habit.")
  }
}

@available(iOS 18.0, *)
extension LogHabitControl {
  /// What the button shows: the habit's name, and whether it's done today.
  struct Value {
    let id: String?
    let name: String
    let done: Bool
  }

  struct Provider: AppIntentControlValueProvider {
    func previewValue(configuration: PickHabitControlIntent) -> Value {
      Value(id: configuration.habit?.id, name: configuration.habit?.name ?? "Log a habit", done: false)
    }

    func currentValue(configuration: PickHabitControlIntent) async throws -> Value {
      let snapshot = Snapshot.load()
      guard let habit = (snapshot?.habit(configuration.habit?.id) ?? snapshot?.firstHabit)?.at(Date()) else {
        return Value(id: nil, name: "Log a habit", done: false)
      }
      return Value(id: habit.id, name: habit.name, done: habit.done && !habit.isBreak)
    }
  }
}
