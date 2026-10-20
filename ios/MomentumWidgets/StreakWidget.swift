import SwiftUI
import WidgetKit

// A habit's streak on the lock screen: a flame over the count, round or as
// the line above the clock. Picked like the Habit widget (PickHabitIntent).

struct StreakWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "streak", intent: PickHabitIntent.self, provider: HabitTimeline(longestStreakFirst: true)) { entry in
      StreakWidgetView(habit: entry.habit)
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(entry.habit.flatMap { URL(string: "momentum://habit/\($0.id)") })
    }
    .configurationDisplayName("Streak")
    .description("A habit's streak, at a glance.")
    .supportedFamilies([.accessoryCircular, .accessoryInline])
  }
}

struct StreakWidgetView: View {
  let habit: HabitInfo?
  @Environment(\.widgetFamily) private var family

  var body: some View {
    if family == .accessoryInline {
      inline
    } else {
      circular
    }
  }

  /// At risk ("Don't miss twice"), the flame is only outlined, with a "!".
  private var circular: some View {
    ZStack {
      AccessoryWidgetBackground()
      if let habit {
        VStack(spacing: 0) {
          Image(systemName: habit.atRisk ? "flame" : "flame.fill")
            .font(.system(size: 15, weight: .semibold))
            .overlay(alignment: .topTrailing) {
              if habit.atRisk {
                Text("!").font(.system(size: 11, weight: .heavy)).offset(x: 7, y: -3)
              }
            }
            .widgetAccentable()
          Text("\(habit.streak)").font(.sora(habit.streak >= 1000 ? 15 : 19, bold: true)).minimumScaleFactor(0.6)
          Text(habit.streak == 0 ? "start" : habit.streakUnit)
            .font(.system(size: 9, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 4)
      } else {
        Image(systemName: "flame").font(.system(size: 22, weight: .semibold))
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
  }

  private var inline: some View {
    Label(habit.map { "\($0.name) · \($0.streakLabel ?? "no streak yet")" } ?? "Streak",
          systemImage: habit?.atRisk == true ? "flame" : "flame.fill")
  }

  private var label: String {
    guard let habit else { return "Pick a habit" }
    let streak = habit.streakLabel ?? "No streak yet"
    return habit.atRisk ? "\(habit.name), \(streak), don't miss twice" : "\(habit.name), \(streak)"
  }
}
