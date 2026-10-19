import AppIntents
import SwiftUI
import WidgetKit

// One habit: its ring and today's progress, with a + that logs from the home
// screen. Small and medium.

/// A habit, as the widget's settings list it.
struct HabitEntity: AppEntity {
  let id: String
  let name: String

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
  static var defaultQuery = HabitQuery()

  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct HabitQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [HabitEntity] {
    let habits = Snapshot.load()?.habits ?? []
    return habits.filter { identifiers.contains($0.id) }.map { HabitEntity(id: $0.id, name: $0.name) }
  }

  func suggestedEntities() async throws -> [HabitEntity] {
    (Snapshot.load()?.habits ?? []).map { HabitEntity(id: $0.id, name: $0.name) }
  }
}

/// Hold the widget → Edit Widget: which habit it shows.
struct PickHabitIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Habit"
  static var description = IntentDescription("Pick the habit this widget shows.")

  @Parameter(title: "Habit")
  var habit: HabitEntity?
}

struct HabitEntry: TimelineEntry {
  let date: Date
  let habit: HabitInfo?
  let looks: Looks?
  let hasHabits: Bool
}

struct HabitTimeline: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> HabitEntry {
    HabitEntry(date: Date(), habit: nil, looks: nil, hasHabits: true)
  }

  func snapshot(for configuration: PickHabitIntent, in context: Context) async -> HabitEntry {
    entry(for: configuration, at: Date())
  }

  func timeline(for configuration: PickHabitIntent, in context: Context) async -> Timeline<HabitEntry> {
    let now = Date()
    var entries = [entry(for: configuration, at: now)]
    // Its period ending (midnight for a daily habit): shown as starting over
    if let ends = entries[0].habit?.periodEndDate, ends > now {
      entries.append(entry(for: configuration, at: ends))
    }
    return Timeline(entries: entries, policy: .atEnd)
  }

  private func entry(for configuration: PickHabitIntent, at date: Date) -> HabitEntry {
    guard let snapshot = Snapshot.load() else {
      return HabitEntry(date: date, habit: nil, looks: nil, hasHabits: false)
    }
    let habit = snapshot.habit(configuration.habit?.id) ?? snapshot.firstHabit
    return HabitEntry(date: date, habit: habit?.at(date), looks: snapshot.looks, hasHabits: !snapshot.habits.isEmpty)
  }
}

struct HabitWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "habit", intent: PickHabitIntent.self, provider: HabitTimeline()) { entry in
      HabitWidgetView(entry: entry)
    }
    .configurationDisplayName("Habit")
    .description("A habit's ring and today's progress. Tap + to log it.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct HabitWidgetView: View {
  let entry: HabitEntry
  @Environment(\.colorScheme) private var scheme
  @Environment(\.widgetFamily) private var family

  private var look: Look { entry.looks?.look(for: scheme) ?? .fallback(for: scheme) }

  var body: some View {
    content
      .foregroundStyle(Color(hex: look.text))
      .containerBackground(for: .widget) { Color(hex: look.surface) }
      .widgetURL(entry.habit.flatMap { URL(string: "momentum://habit/\($0.id)") })
  }

  @ViewBuilder
  private var content: some View {
    if let habit = entry.habit {
      if family == .systemMedium {
        HabitMedium(habit: habit, look: look, scheme: scheme)
      } else {
        HabitSmall(habit: habit, look: look, scheme: scheme)
      }
    } else if entry.looks == nil && !entry.hasHabits && !isPlaceholder {
      EmptyMessage(title: "Momentum", detail: "Open the app to show a habit here.", look: look)
    } else if isPlaceholder {
      HabitSmall(habit: .placeholder, look: look, scheme: scheme).redacted(reason: .placeholder)
    } else {
      EmptyMessage(title: "No habits yet", detail: "Add one in Momentum.", look: look)
    }
  }

  private var isPlaceholder: Bool { entry.looks == nil && entry.hasHabits }
}

private struct HabitSmall: View {
  let habit: HabitInfo
  let look: Look
  let scheme: ColorScheme

  var body: some View {
    if habit.isBreak {
      BreakSmall(habit: habit, look: look)
    } else {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top, spacing: 6) {
          Text(habit.name).font(.sora(15)).lineLimit(2)
          Spacer(minLength: 0)
          if habit.streak > 0 { StreakBadge(count: habit.streak, atRisk: habit.atRisk, look: look) }
        }
        Spacer(minLength: 4)
        HStack(alignment: .bottom) {
          ZStack {
            HabitRing(fraction: habit.fraction, done: habit.done, color: habit.color.color(for: scheme),
                      track: Color(hex: look.track), checkColor: habit.onColor.color(for: scheme), lineWidth: 9)
            if !habit.done {
              VStack(spacing: 1) {
                (Text("\(habit.progress)").font(.sora(20, bold: true))
                  + Text("/\(habit.target)").font(.sora(12)).foregroundColor(Color(hex: look.textSecondary)))
                  .lineLimit(1).minimumScaleFactor(0.5)
                if !habit.units.isEmpty {
                  Text(habit.units).font(.system(size: 10)).foregroundStyle(Color(hex: look.textSecondary)).lineLimit(1)
                }
              }
              .padding(12)
            }
          }
          .frame(width: 82, height: 82)
          Spacer(minLength: 0)
          if let _ = habit.next {
            Button(intent: LogHabitIntent(habitId: habit.id)) { PlusOrb(look: look) }
              .buttonStyle(.plain)
              .accessibilityLabel(habit.addLabel ?? "Add one")
          } else if habit.done {
            VStack(alignment: .trailing, spacing: 1) {
              Text("Done").font(.sora(16, bold: true)).foregroundStyle(Color(hex: look.good))
              Text("\(habit.progress) of \(habit.target)").font(.system(size: 11)).foregroundStyle(Color(hex: look.textSecondary))
            }
          }
        }
      }
      .accessibilityElement(children: .contain)
    }
  }
}

/// A habit being broken: its status and clean run. No +, so a stray tap
/// can't log a slip.
private struct BreakSmall: View {
  let habit: HabitInfo
  let look: Look

  var body: some View {
    let clean = habit.progress == 0 || (habit.target > 0 && habit.progress <= habit.target)
    VStack(alignment: .leading, spacing: 6) {
      Text(habit.name).font(.sora(15)).lineLimit(2)
      Spacer(minLength: 0)
      Text(habit.text)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color(hex: clean ? look.good : look.warning))
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Capsule().fill(Color(hex: clean ? look.goodTint : look.raised)))
      if habit.streak > 0 {
        Text("\(habit.streak)").font(.sora(34, bold: true)).minimumScaleFactor(0.5)
        if let label = habit.streakLabel {
          Text(label.replacingOccurrences(of: "\(habit.streak) ", with: ""))
            .font(.system(size: 12)).foregroundStyle(Color(hex: look.textSecondary)).lineLimit(2)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct HabitMedium: View {
  let habit: HabitInfo
  let look: Look
  let scheme: ColorScheme

  var body: some View {
    let color = habit.color.color(for: scheme)
    HStack(spacing: 14) {
      ZStack {
        HabitRing(fraction: habit.isBreak ? 0 : habit.fraction, done: habit.done, color: color,
                  track: Color(hex: look.track), checkColor: habit.onColor.color(for: scheme), lineWidth: 10)
        if !habit.done && !habit.isBreak {
          VStack(spacing: 2) {
            (Text("\(habit.progress)").font(.sora(28, bold: true))
              + Text("/\(habit.target)").font(.sora(15)).foregroundColor(Color(hex: look.textSecondary)))
              .lineLimit(1).minimumScaleFactor(0.5)
            if !habit.units.isEmpty {
              Text(habit.units).font(.system(size: 11)).foregroundStyle(Color(hex: look.textSecondary)).lineLimit(1)
            }
          }
          .padding(14)
        }
      }
      .frame(width: 112, height: 112)

      VStack(alignment: .leading, spacing: 7) {
        Text(habit.name).font(.sora(17)).lineLimit(2)
        // "this week" only where the ring's number isn't a day's
        Text(habit.isBreak || habit.period == "today" ? habit.text : "\(habit.text) \(habit.period)")
          .font(.system(size: 13)).foregroundStyle(Color(hex: look.textSecondary))
          .lineLimit(1).minimumScaleFactor(0.8)
        HStack(spacing: 10) {
          if habit.streak > 0 { StreakBadge(count: habit.streak, atRisk: habit.atRisk, look: look) }
          if let momentum = habit.momentum {
            HStack(spacing: 2) {
              Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundStyle(Color(hex: look.gauge))
              Text("\(momentum)").font(.system(size: 13, weight: .semibold)).monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Momentum \(momentum)")
          }
        }
        if !habit.recent.isEmpty {
          RecentBars(recent: habit.recent, color: color, track: Color(hex: look.track))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if habit.next != nil {
        Button(intent: LogHabitIntent(habitId: habit.id)) { PlusOrb(look: look, size: 48) }
          .buttonStyle(.plain)
          .accessibilityLabel(habit.addLabel ?? "Add one")
      }
    }
  }
}

extension HabitInfo {
  static let placeholder = HabitInfo(
    id: "placeholder", name: "Drink water", category: nil,
    color: ColorPair(light: "#1E7FD0", dark: "#4FA8F5"), onColor: ColorPair(light: "#FFFFFF", dark: "#0E1013"),
    isBreak: false, progress: 5, target: 8, units: "glasses", text: "5 of 8 glasses", done: false, due: true,
    period: "today", periodEnds: nil, next: 6, step: 1, addLabel: "Add one", streak: 23, streakLabel: "23 day streak",
    atRisk: false, momentum: 74, recent: [], quotes: nil)
}
