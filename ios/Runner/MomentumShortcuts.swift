import AppIntents
import Foundation

// Siri and Shortcuts (Momentum Plus): log a habit, ask about momentum, open
// a habit. They read the app's snapshot (what the widgets draw, in the App
// Group) and log through the same queue as a widget's +, so the app logs it
// as the card's + would. Without Plus they say so and open the Plus page.

/// Why an intent can't do its job yet, in words Siri says.
@available(iOS 17.0, *)
private enum ShortcutProblem: Error, CustomLocalizedStringResourceConvertible {
  case noSnapshot
  case needsPlus

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .noSnapshot: return "Open Momentum first, so I know your habits."
    case .needsPlus: return "Siri and Shortcuts come with Momentum Plus. Open Momentum to see it in Settings."
    }
  }
}

/// The snapshot, if there is one and Plus is this person's.
@available(iOS 17.0, *)
private func plusSnapshot() throws -> Snapshot {
  guard let snapshot = Snapshot.load() else { throw ShortcutProblem.noSnapshot }
  guard snapshot.plus == true else { throw ShortcutProblem.needsPlus }
  return snapshot
}

/// "Log water in Momentum": one step toward a habit's target today.
@available(iOS 17.0, *)
struct LogHabitShortcut: AppIntent {
  static var title: LocalizedStringResource = "Log a Habit"
  static var description = IntentDescription("Adds one step to a habit for today, as its + does.")

  @Parameter(title: "Habit", requestValueDialog: "Which habit?")
  var habit: HabitEntity

  static var parameterSummary: some ParameterSummary { Summary("Log \(\.$habit)") }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let snapshot = try plusSnapshot()
    guard let info = snapshot.habit(habit.id) else { throw ShortcutProblem.noSnapshot }
    let now = Date()
    WidgetStore.queueLog(habitId: habit.id, at: now)
    WidgetStore.showStep(habitId: habit.id, at: now)
    WidgetStore.reloadAll()
    // The app logs it now (or the next time it opens)
    await AppHook.logsWaiting?()
    let after = Snapshot.load()?.habit(habit.id) ?? info
    return .result(dialog: "Logged \(habit.name). \(after.text).")
  }
}

/// "How's my momentum in Momentum?": the overall score, its level and today.
@available(iOS 17.0, *)
struct MomentumShortcut: AppIntent {
  static var title: LocalizedStringResource = "Check Momentum"
  static var description = IntentDescription("Your overall momentum, its level, and today's habits.")

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let snapshot = try plusSnapshot()
    let today = "\(snapshot.today.done) of \(snapshot.today.due) done today."
    guard let momentum = snapshot.momentum else {
      return .result(dialog: "No momentum yet: it starts with your first logged day. \(today)")
    }
    let trend = momentum.trend > 0 ? ", up \(momentum.trend)" : (momentum.trend < 0 ? ", down \(-momentum.trend)" : "")
    let next = momentum.toNext.map { " \($0.points) to \($0.level)." } ?? ""
    return .result(dialog: "Momentum \(momentum.score), \(momentum.level)\(trend). \(today)\(next)")
  }
}

/// "Open a habit in Momentum": its page, as a reminder's tap opens it.
@available(iOS 17.0, *)
struct OpenHabitShortcut: AppIntent {
  static var title: LocalizedStringResource = "Open a Habit"
  static var description = IntentDescription("Opens a habit's page in Momentum.")
  static var openAppWhenRun = true

  @Parameter(title: "Habit", requestValueDialog: "Which habit?")
  var habit: HabitEntity

  static var parameterSummary: some ParameterSummary { Summary("Open \(\.$habit)") }

  @MainActor
  func perform() async throws -> some IntentResult {
    _ = try plusSnapshot()
    if let url = URL(string: "momentum://habit/\(habit.id)") { _ = WidgetChannel.open(url) }
    return .result()
  }
}

/// What Siri and Spotlight offer without any setup.
@available(iOS 17.0, *)
struct MomentumShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogHabitShortcut(),
      phrases: [
        "Log \(\.$habit) in \(.applicationName)",
        "Log a habit in \(.applicationName)",
        "Add to \(\.$habit) in \(.applicationName)",
      ],
      shortTitle: "Log a Habit",
      systemImageName: "plus.circle.fill"
    )
    AppShortcut(
      intent: MomentumShortcut(),
      phrases: [
        "How's my momentum in \(.applicationName)",
        "Check \(.applicationName)",
        "What's my momentum in \(.applicationName)",
      ],
      shortTitle: "Check Momentum",
      systemImageName: "bolt.fill"
    )
    AppShortcut(
      intent: OpenHabitShortcut(),
      phrases: [
        "Open \(\.$habit) in \(.applicationName)",
        "Show \(\.$habit) in \(.applicationName)",
      ],
      shortTitle: "Open a Habit",
      systemImageName: "circle.dashed"
    )
  }
}
