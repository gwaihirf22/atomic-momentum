import SwiftUI

/// Momentum on Apple Watch: today's habits with a +, a habit's own screen
/// (the Crown, 2 min) and momentum. Adding and editing stay on the phone.
@main
struct MomentumWatchApp: App {
  @StateObject private var model = WatchModel.shared
  @Environment(\.scenePhase) private var phase

  init() {
    WatchModel.shared.start()
    #if DEBUG
    // For trying the round trip on a simulator, which can't be tapped from
    // the command line: `xcrun simctl launch <watch>
    // com.paulblake.momentum.watchkitapp -momentumTest step/<habit name>`
    // (or set/6/<name>, twoMinute/<name>, open/<name>)
    let arguments = ProcessInfo.processInfo.arguments
    if let index = arguments.firstIndex(of: "-momentumTest"), index + 1 < arguments.count {
      let parts = arguments[index + 1].split(separator: "/").map(String.init)
      Task { @MainActor in
        try? await Task.sleep(for: .seconds(1))
        Self.test(parts)
      }
    }
    #endif
  }

  var body: some Scene {
    WindowGroup {
      TabView {
        TodayView()
        MomentumPage()
      }
      .tabViewStyle(.verticalPage)
      .environmentObject(model)
      .onOpenURL { url in
        // momentum://habit/<id> from a complication
        guard url.host() == "habit" else { return }
        model.openHabit = url.pathComponents.dropFirst().first
      }
    }
    .onChange(of: phase) { _, phase in
      if phase == .active { model.reload() }
    }
  }

  #if DEBUG
  @MainActor private static func test(_ parts: [String]) {
    let model = WatchModel.shared
    guard parts.count >= 2, let habit = model.snapshot?.habits.first(where: { $0.name == parts.last })?.now else { return }
    switch parts[0] {
    case "step": model.step(habit)
    case "twoMinute": model.twoMinute(habit)
    case "set": if parts.count == 3, let amount = Int(parts[1]) { model.set(habit, to: amount) }
    case "open": model.openHabit = habit.id
    default: break
    }
  }
  #endif
}

/// The watch's colours: always dark, Charged's (or the phone's dark look).
extension WatchModel {
  var look: Look { snapshot?.looks.dark ?? .charged }
}
