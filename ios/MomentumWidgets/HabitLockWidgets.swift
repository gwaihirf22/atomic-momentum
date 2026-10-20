import AppIntents
import SwiftUI
import WidgetKit

// A habit on the lock screen: the round ring, the rectangle with a + that
// logs it, and the line above the clock. iOS draws them in one tint, so they
// use no theme colours (docs/design/widgets.md).

extension WidgetFamily {
  var isAccessory: Bool { self == .accessoryCircular || self == .accessoryRectangular || self == .accessoryInline }
}

extension HabitInfo {
  /// "days", "weeks", "months" or "in a row", for under a streak's number.
  var streakUnit: String {
    let label = streakLabel ?? ""
    if label.contains("month") { return streak == 1 ? "month" : "months" }
    if label.contains("week") { return streak == 1 ? "week" : "weeks" }
    if label.contains("day") { return streak == 1 ? "day" : "days" }
    return "in a row"
  }

  /// "5/8", "Done", "Clean" or "1 slip": a lock screen's few characters.
  var shortProgress: String {
    if isBreak {
      if target == 0 { return progress == 0 ? "Clean" : "\(progress) slip\(progress == 1 ? "" : "s")" }
      return "\(progress)/\(target)"
    }
    return done ? "Done" : "\(progress)/\(target)"
  }
}

/// The lock screen's habit, by size.
struct HabitLockView: View {
  let habit: HabitInfo?
  @Environment(\.widgetFamily) private var family

  var body: some View {
    switch family {
    case .accessoryCircular: HabitLockCircular(habit: habit)
    case .accessoryRectangular: HabitLockRectangular(habit: habit)
    default: HabitLockInline(habit: habit)
    }
  }
}

/// The ring, filling toward the target: "5 of 8", a check once done, a
/// snowflake while frozen.
struct HabitLockCircular: View {
  let habit: HabitInfo?

  var body: some View {
    if let habit {
      Gauge(value: habit.isBreak ? (habit.progress == 0 ? 1 : 0) : habit.fraction) {
        EmptyView()
      } currentValueLabel: {
        center(habit)
      }
      .gaugeStyle(.accessoryCircularCapacity)
      .widgetAccentable()
      .accessibilityLabel("\(habit.name), \(habit.text)")
    } else {
      ZStack {
        AccessoryWidgetBackground()
        Image(systemName: "plus").font(.system(size: 20, weight: .semibold))
      }
      .accessibilityLabel("Pick a habit")
    }
  }

  @ViewBuilder
  private func center(_ habit: HabitInfo) -> some View {
    if habit.frozen == true {
      Image(systemName: "snowflake").font(.system(size: 20, weight: .semibold))
    } else if habit.done && !habit.isBreak {
      Image(systemName: "checkmark").font(.system(size: 20, weight: .bold))
    } else if habit.isBreak {
      Text(habit.progress == 0 ? "Clean" : "\(habit.progress)")
        .font(.system(size: habit.progress == 0 ? 11 : 18, weight: .bold)).minimumScaleFactor(0.7)
    } else {
      VStack(spacing: -1) {
        Text("\(habit.progress)").font(.sora(18, bold: true)).minimumScaleFactor(0.6)
        Text("of \(habit.target)").font(.system(size: 9, weight: .semibold)).minimumScaleFactor(0.7)
      }
    }
  }
}

/// The name, where it stands today, the streak, and a + that logs one more.
struct HabitLockRectangular: View {
  let habit: HabitInfo?

  var body: some View {
    if let habit {
      HStack(spacing: 6) {
        VStack(alignment: .leading, spacing: 1) {
          Text(habit.name).font(.system(size: 15, weight: .bold)).lineLimit(1).widgetAccentable()
          Text(detail(habit)).font(.system(size: 13, weight: .medium)).lineLimit(1)
          if habit.streak > 0 {
            Label("\(habit.streak) \(habit.streakUnit)", systemImage: habit.atRisk ? "flame" : "flame.fill")
              .font(.system(size: 12, weight: .medium)).lineLimit(1).opacity(0.85)
          }
        }
        Spacer(minLength: 0)
        if habit.next != nil && habit.frozen != true {
          Button(intent: LogHabitIntent(habitId: habit.id)) {
            ZStack {
              AccessoryWidgetBackground().clipShape(Circle())
              Image(systemName: "plus").font(.system(size: 17, weight: .bold))
            }
            .frame(width: 38, height: 38)
          }
          .buttonStyle(.plain)
          .widgetAccentable()
          .accessibilityLabel("\(habit.addLabel ?? "Add one"), \(habit.name)")
        } else if habit.done && !habit.isBreak {
          Image(systemName: "checkmark.circle.fill").font(.system(size: 26)).widgetAccentable()
        }
      }
    } else {
      VStack(alignment: .leading, spacing: 2) {
        Text("Momentum").font(.system(size: 15, weight: .bold)).widgetAccentable()
        Text("Hold to pick a habit").font(.system(size: 13))
      }
    }
  }

  private func detail(_ habit: HabitInfo) -> String {
    if habit.frozen == true { return "Frozen today" }
    if habit.atRisk && !habit.done { return habit.isBreak ? "Don't slip twice" : "Don't miss twice" }
    return habit.text
  }
}

/// The line above the clock: "Drink water 5/8".
struct HabitLockInline: View {
  let habit: HabitInfo?

  var body: some View {
    if let habit {
      Label("\(habit.name) \(habit.shortProgress)",
            systemImage: habit.done && !habit.isBreak ? "checkmark.circle" : (habit.streak > 0 ? "flame.fill" : "circle"))
    } else {
      Label("Momentum", systemImage: "bolt.fill")
    }
  }
}
