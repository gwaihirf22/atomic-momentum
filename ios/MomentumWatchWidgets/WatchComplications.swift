import AppIntents
import SwiftUI
import WidgetKit

// The watch's complications and Smart Stack widget (docs/design/watch.md),
// drawn from the snapshot the phone sent (WatchModel keeps it in the
// watch's App Group). A tap opens the watch app (on the habit, for one).

@main
struct MomentumWatchWidgets: WidgetBundle {
  var body: some Widget {
    TodayComplication()
    MomentumComplication()
    HabitComplication()
    NextUpWidget()
  }
}

/// A timeline of the snapshot now and when its next period ends (midnight,
/// usually), when habits start again from nothing.
private func entries<E: TimelineEntry>(_ make: (Date, Snapshot?) -> E) -> Timeline<E> {
  let now = Date()
  let snapshot = Snapshot.load()
  var list = [make(now, snapshot)]
  if let next = snapshot?.nextChange(after: now) { list.append(make(next, snapshot)) }
  return Timeline(entries: list, policy: .atEnd)
}

private extension View {
  /// The black every watch complication sits on (watchOS 10 asks for one).
  func complicationBackground() -> some View {
    containerBackground(for: .widget) { Color.black }
  }
}

private var look: Look { Snapshot.load()?.looks.dark ?? .charged }

// MARK: Today: "3/6"

struct TodayEntry: TimelineEntry {
  let date: Date
  let today: TodayCount?
}

struct TodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayEntry { TodayEntry(date: Date(), today: TodayCount(done: 3, due: 6)) }
  func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
    completion(TodayEntry(date: Date(), today: Snapshot.load()?.today ?? TodayCount(done: 3, due: 6)))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
    // At a period's end nothing is done yet
    completion(entries { date, snapshot in
      let today = snapshot?.today
      return TodayEntry(date: date, today: date > Date() ? today.map { TodayCount(done: 0, due: $0.due) } : today)
    })
  }
}

struct TodayComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "WatchToday", provider: TodayProvider()) { entry in
      TodayComplicationView(entry: entry)
        .complicationBackground()
        .widgetURL(URL(string: "momentum://today"))
    }
    .configurationDisplayName("Today")
    .description("How many of today's habits are done.")
    .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
  }
}

struct TodayComplicationView: View {
  @Environment(\.widgetFamily) private var family
  let entry: TodayEntry

  var body: some View {
    let today = entry.today ?? TodayCount(done: 0, due: 0)
    let allDone = today.due > 0 && today.done >= today.due
    let color = Color(hex: allDone ? look.gold : look.good)
    switch family {
    case .accessoryInline:
      Text(allDone ? "All done today" : "\(today.done) of \(today.due) done")
    case .accessoryCorner:
      Image(systemName: allDone ? "checkmark" : "circle.dotted")
        .font(.title3)
        .widgetLabel {
          Gauge(value: today.fraction) { Text("Today") } currentValueLabel: { Text("\(today.done)/\(today.due)") }
            .tint(color)
        }
    default:
      Gauge(value: today.fraction) {
        Text("Today")
      } currentValueLabel: {
        Text("\(today.done)/\(today.due)").font(.system(size: 14, weight: .bold)).monospacedDigit()
      }
      .gaugeStyle(.accessoryCircularCapacity)
      .tint(color)
    }
  }
}

// MARK: Momentum: the gauge, "Momentum 74 · Strong"

struct MomentumEntry: TimelineEntry {
  let date: Date
  let momentum: MomentumInfo?
}

struct MomentumProvider: TimelineProvider {
  static let sample = MomentumInfo(score: 74, trend: 3, level: "Strong", formed: 80, habits: 6, rising: 4)
  func placeholder(in context: Context) -> MomentumEntry { MomentumEntry(date: Date(), momentum: Self.sample) }
  func getSnapshot(in context: Context, completion: @escaping (MomentumEntry) -> Void) {
    completion(MomentumEntry(date: Date(), momentum: Snapshot.load()?.momentum ?? Self.sample))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<MomentumEntry>) -> Void) {
    completion(entries { date, snapshot in MomentumEntry(date: date, momentum: snapshot?.momentum) })
  }
}

struct MomentumComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "WatchMomentum", provider: MomentumProvider()) { entry in
      MomentumComplicationView(entry: entry)
        .complicationBackground()
        .widgetURL(URL(string: "momentum://momentum"))
    }
    .configurationDisplayName("Momentum")
    .description("Your momentum and its level.")
    .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
  }
}

struct MomentumComplicationView: View {
  @Environment(\.widgetFamily) private var family
  let entry: MomentumEntry

  var body: some View {
    let score = entry.momentum?.score ?? 0
    let color = Color(hex: entry.momentum?.isAtomic == true ? look.gold : look.gauge)
    switch family {
    case .accessoryInline:
      Text(entry.momentum.map { "Momentum \($0.score) · \($0.level)" } ?? "Momentum")
    case .accessoryCorner:
      // The score in the corner, the gauge along the screen's curve
      Text("\(score)")
        .font(.system(size: 20, weight: .bold))
        .monospacedDigit()
        .widgetLabel {
          Gauge(value: Double(score), in: 0...100) { Text("Momentum") }
            .tint(color)
        }
    case .accessoryRectangular:
      HStack(spacing: 8) {
        Gauge(value: Double(score), in: 0...100) { Text("") } currentValueLabel: { Text("\(score)").monospacedDigit() }
          .gaugeStyle(.accessoryCircular)
          .tint(color)
        VStack(alignment: .leading, spacing: 0) {
          Text("Momentum").font(.headline)
          Text(entry.momentum?.level ?? "Building").foregroundStyle(color)
          if let next = entry.momentum?.toNext {
            Text("\(next.points) to \(next.level)").font(.caption2).foregroundStyle(.secondary)
          }
        }
      }
    default:
      Gauge(value: Double(score), in: 0...100) {
        Text("M")
      } currentValueLabel: {
        Text("\(score)").font(.system(size: 16, weight: .bold)).monospacedDigit()
      }
      .gaugeStyle(.accessoryCircular)
      .tint(color)
    }
  }
}

// MARK: A habit: its ring and number, or name, ring and streak

struct HabitPick: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Habit"
  static var description = IntentDescription("The habit to show.")

  @Parameter(title: "Habit")
  var habit: HabitEntity?
}

struct HabitEntry: TimelineEntry {
  let date: Date
  let habit: HabitInfo?
}

struct HabitProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> HabitEntry { HabitEntry(date: Date(), habit: nil) }

  func snapshot(for pick: HabitPick, in context: Context) async -> HabitEntry {
    let snapshot = Snapshot.load()
    return HabitEntry(date: Date(), habit: snapshot?.habit(pick.habit?.id) ?? snapshot?.firstHabit)
  }

  func timeline(for pick: HabitPick, in context: Context) async -> Timeline<HabitEntry> {
    entries { date, snapshot in
      HabitEntry(date: date, habit: (snapshot?.habit(pick.habit?.id) ?? snapshot?.firstHabit)?.at(date))
    }
  }

  /// A watch face lists one of these per habit (it has no settings screen).
  func recommendations() -> [AppIntentRecommendation<HabitPick>] {
    (Snapshot.load()?.habits ?? []).map { habit in
      let pick = HabitPick()
      pick.habit = HabitEntity(id: habit.id, name: habit.name)
      return AppIntentRecommendation(intent: pick, description: Text(habit.name))
    }
  }
}

struct HabitComplication: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "WatchHabit", intent: HabitPick.self, provider: HabitProvider()) { entry in
      HabitComplicationView(habit: entry.habit)
        .complicationBackground()
        .widgetURL(URL(string: "momentum://habit/\(entry.habit?.id ?? "")"))
    }
    .configurationDisplayName("Habit")
    .description("One habit's ring, with its number.")
    .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
  }
}

struct HabitComplicationView: View {
  @Environment(\.widgetFamily) private var family
  let habit: HabitInfo?

  var body: some View {
    if let habit {
      let color = habit.color.color(for: .dark)
      switch family {
      case .accessoryInline:
        Text("\(habit.name) · \(habit.text)")
      case .accessoryCorner:
        Text("\(habit.progress)")
          .font(.system(size: 20, weight: .bold))
          .monospacedDigit()
          .widgetLabel {
            Gauge(value: habit.fraction) { Text(habit.name) }
              .tint(color)
          }
      case .accessoryRectangular:
        HabitRectangle(habit: habit, color: color)
      default:
        Gauge(value: habit.fraction) {
          Text(habit.name)
        } currentValueLabel: {
          Text(habit.done ? "✓" : "\(habit.progress)").font(.system(size: 15, weight: .bold)).monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(color)
      }
    } else {
      Text("Momentum").font(.footnote)
    }
  }
}

/// A habit's name, ring and streak (the rectangle and the Smart Stack).
struct HabitRectangle: View {
  let habit: HabitInfo
  let color: Color
  var heading: String?

  var body: some View {
    HStack(spacing: 8) {
      Gauge(value: habit.fraction) { Text("") }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(color)
      VStack(alignment: .leading, spacing: 0) {
        if let heading {
          Text(heading).font(.caption2.bold()).foregroundStyle(Color(hex: look.warning))
        }
        Text(habit.name).font(.headline).lineLimit(1)
        Text(habit.text).font(.caption).lineLimit(1)
        if habit.streak > 0 {
          Label("\(habit.streak)", systemImage: "flame.fill")
            .font(.caption2)
            .foregroundStyle(Color(hex: habit.atRisk ? look.warning : look.flame))
        }
      }
    }
  }
}

// MARK: Smart Stack: the habit to do next, "Don't miss twice" first

struct NextUpEntry: TimelineEntry {
  let date: Date
  let habit: HabitInfo?
  let atRisk: Bool
  let relevance: TimelineEntryRelevance?
}

struct NextUpProvider: TimelineProvider {
  func placeholder(in context: Context) -> NextUpEntry { NextUpEntry(date: Date(), habit: nil, atRisk: false, relevance: nil) }

  func getSnapshot(in context: Context, completion: @escaping (NextUpEntry) -> Void) {
    completion(entry(at: Date(), snapshot: Snapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<NextUpEntry>) -> Void) {
    completion(entries { date, snapshot in entry(at: date, snapshot: snapshot) })
  }

  /// A habit due and not done; one whose streak a miss today would end comes
  /// first, and with Momentum Plus it's what the Smart Stack brings up.
  private func entry(at date: Date, snapshot: Snapshot?) -> NextUpEntry {
    let open = (snapshot?.habits ?? []).map { $0.at(date) }.filter { $0.due && !$0.done && !$0.isBreak && $0.frozen != true }
    let risky = open.first(where: \.atRisk)
    let habit = risky ?? open.first
    let plus = snapshot?.plus == true
    let score: Float = habit == nil ? 0 : (risky != nil && plus ? 1 : 0.2)
    return NextUpEntry(date: date, habit: habit, atRisk: risky != nil, relevance: TimelineEntryRelevance(score: score))
  }
}

struct NextUpWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "WatchNextUp", provider: NextUpProvider()) { entry in
      Group {
        if let habit = entry.habit {
          HabitRectangle(
            habit: habit, color: habit.color.color(for: .dark), heading: entry.atRisk ? "DON'T MISS TWICE" : nil)
        } else {
          Text("Today's habits are done.").font(.footnote)
        }
      }
      .complicationBackground()
      .widgetURL(URL(string: "momentum://habit/\(entry.habit?.id ?? "")"))
    }
    .configurationDisplayName("Next up")
    .description("The habit to do next; a streak at stake comes first.")
    .supportedFamilies([.accessoryRectangular])
  }
}
