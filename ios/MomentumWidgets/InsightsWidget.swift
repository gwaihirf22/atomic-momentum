import AppIntents
import SwiftUI
import WidgetKit

// Insights at a glance: today or this week (small), the heatmap (medium),
// the month (large). Everything comes from the app, so it matches Insights.

enum SmallInsight: String, AppEnum {
  case today
  case week

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Show"
  static var caseDisplayRepresentations: [SmallInsight: DisplayRepresentation] = [
    .today: "Today",
    .week: "This week",
  ]
}

/// Hold the widget → Edit Widget: what the small size shows.
struct PickInsightIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Insights"
  static var description = IntentDescription("Today, this week, the heatmap or the month.")

  @Parameter(title: "Small widget shows", default: .today)
  var small: SmallInsight
}

struct InsightsEntry: TimelineEntry {
  let date: Date
  let snapshot: Snapshot?
  let small: SmallInsight
}

struct InsightsTimeline: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> InsightsEntry { InsightsEntry(date: Date(), snapshot: nil, small: .today) }

  func snapshot(for configuration: PickInsightIntent, in context: Context) async -> InsightsEntry {
    InsightsEntry(date: Date(), snapshot: Snapshot.load(), small: configuration.small)
  }

  func timeline(for configuration: PickInsightIntent, in context: Context) async -> Timeline<InsightsEntry> {
    let now = Date()
    let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
    return Timeline(entries: [InsightsEntry(date: now, snapshot: Snapshot.load(), small: configuration.small)],
                    policy: .after(midnight))
  }
}

struct InsightsWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "insights", intent: PickInsightIntent.self, provider: InsightsTimeline()) { entry in
      InsightsWidgetView(entry: entry)
    }
    .configurationDisplayName("Insights")
    .description("Today, this week, the heatmap, and the month.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

struct InsightsWidgetView: View {
  let entry: InsightsEntry
  @Environment(\.colorScheme) private var scheme
  @Environment(\.widgetFamily) private var family

  private var look: Look { entry.snapshot?.looks.look(for: scheme) ?? .fallback(for: scheme) }

  var body: some View {
    content
      .foregroundStyle(Color(hex: look.text))
      .containerBackground(for: .widget) { Color(hex: look.surface) }
      .widgetURL(URL(string: "momentum://insights"))
  }

  @ViewBuilder
  private var content: some View {
    if let snapshot = entry.snapshot, let insights = snapshot.insights {
      switch family {
      case .systemLarge: InsightsLarge(insights: insights, look: look, now: entry.date)
      case .systemMedium: InsightsMedium(insights: insights, look: look)
      default:
        if entry.small == .week {
          WeekSmall(insights: insights, look: look)
        } else {
          TodaySmall(today: snapshot.today, look: look)
        }
      }
    } else {
      EmptyMessage(title: "Insights", detail: entry.snapshot == nil
        ? "Open the app to show your insights here." : "Add a habit to see how it's going.", look: look)
    }
  }
}

/// The heatmap's five shades over the surface, as the app draws them.
private func shade(_ level: Int, _ look: Look) -> Color {
  switch level {
  case 1: return Color(hex: look.gauge).opacity(0.3)
  case 2: return Color(hex: look.gauge).opacity(0.5)
  case 3: return Color(hex: look.gauge).opacity(0.75)
  case 4: return Color(hex: look.gauge)
  default: return Color(hex: look.raised)
  }
}

private struct SmallLabel: View {
  let text: String
  let look: Look

  var body: some View {
    Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: look.textSecondary))
  }
}

private struct TodaySmall: View {
  let today: TodayCount
  let look: Look

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SmallLabel(text: "Today", look: look)
      Spacer(minLength: 4)
      (Text("\(today.done)").font(.sora(40, bold: true))
        + Text(" of \(today.due)").font(.sora(20)).foregroundColor(Color(hex: look.textSecondary)))
        .lineLimit(1).minimumScaleFactor(0.6)
      Text(today.due == 1 ? "habit done" : "habits done").font(.system(size: 13))
        .foregroundStyle(Color(hex: look.textSecondary))
      Spacer(minLength: 8)
      HStack(spacing: 4) {
        ForEach(0..<max(today.due, 1), id: \.self) { i in
          Capsule().fill(i < today.done ? Color(hex: look.gauge) : Color(hex: look.track)).frame(height: 8)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(today.done) of \(today.due) habits done today")
  }
}

private struct WeekSmall: View {
  let insights: InsightsInfo
  let look: Look

  private var labels: [String] {
    let letters = ["M", "T", "W", "T", "F", "S", "S"]
    return (0..<7).map { letters[(insights.weekStart - 1 + $0) % 7] }
  }

  var body: some View {
    let shown = insights.week.compactMap { $0 }
    let average = shown.isEmpty ? 0 : Int((shown.reduce(0, +) / Double(shown.count) * 100).rounded())
    VStack(spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        SmallLabel(text: "This week", look: look)
        Spacer(minLength: 0)
        Text("\(average)%").font(.sora(15, bold: true))
      }
      HStack(alignment: .bottom, spacing: 6) {
        ForEach(0..<7, id: \.self) { i in
          let level = i < insights.week.count ? insights.week[i] : nil
          let isToday = i == insights.weekToday
          VStack(spacing: 5) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4)
              .fill(isToday ? Color.clear : (level == nil ? Color(hex: look.track) : Color(hex: look.gauge)))
              .overlay(isToday ? RoundedRectangle(cornerRadius: 4).stroke(Color(hex: look.gauge), lineWidth: 1.5) : nil)
              .frame(height: max(4, 66 * (level ?? 0)))
            Text(labels[i]).font(.system(size: 10, weight: isToday ? .bold : .regular))
              .foregroundStyle(Color(hex: isToday ? look.text : look.textSecondary))
          }
          .frame(maxWidth: .infinity)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("This week, \(average) percent of habits done")
  }
}

/// Days as squares, a column a week.
private struct HeatGrid: View {
  let columns: [[Character?]]
  let look: Look
  let cell: CGFloat
  let gap: CGFloat

  var body: some View {
    HStack(spacing: gap) {
      ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
        VStack(spacing: gap) {
          ForEach(0..<7, id: \.self) { row in
            square(row < week.count ? week[row] : nil)
          }
        }
      }
    }
    .accessibilityHidden(true)
  }

  @ViewBuilder
  private func square(_ day: Character?) -> some View {
    let shape = RoundedRectangle(cornerRadius: cell / 4)
    switch day {
    case nil:
      Color.clear.frame(width: cell, height: cell)
    case "-":
      shape.fill(Color(hex: look.raised).opacity(0.5)).frame(width: cell, height: cell)
    case "P":
      shape.fill(shade(4, look)).overlay(shape.stroke(Color(hex: look.text).opacity(0.5), lineWidth: 1))
        .frame(width: cell, height: cell)
    default:
      shape.fill(shade(Int(String(day!)) ?? 0, look)).frame(width: cell, height: cell)
    }
  }
}

private struct InsightsMedium: View {
  let insights: InsightsInfo
  let look: Look

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        SmallLabel(text: "Every day", look: look)
        Spacer(minLength: 0)
        Text("last 15 weeks").font(.system(size: 12)).foregroundStyle(Color(hex: look.textSecondary))
      }
      HStack(alignment: .top, spacing: 14) {
        HeatGrid(columns: insights.columns(weeks: 15), look: look, cell: 12, gap: 3)
        VStack(alignment: .leading, spacing: 10) {
          Stat(value: "\(insights.longestStreak)", label: "best streak", look: look)
          Stat(value: "\(insights.streaksSaved)", label: "streaks saved", look: look)
        }
        .fixedSize()
      }
    }
  }
}

private struct Stat: View {
  let value: String
  let label: String
  let look: Look

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(value).font(.sora(20, bold: true))
      Text(label).font(.system(size: 11)).foregroundStyle(Color(hex: look.textSecondary)).lineLimit(1)
    }
  }
}

private struct InsightsLarge: View {
  let insights: InsightsInfo
  let look: Look
  let now: Date

  private var monthName: String {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("MMMM")
    return f.string(from: now)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(monthName).font(.sora(17, bold: true))
        Spacer(minLength: 0)
        Text("Insights").font(.system(size: 13)).foregroundStyle(Color(hex: look.textSecondary))
      }
      HStack(spacing: 10) {
        tile(title: "Momentum", value: insights.momentum.map(String.init) ?? "–", note: momentumNote, good: momentumUp)
        tile(title: "Periods kept", value: insights.kept.map { "\($0)%" } ?? "–",
             note: insights.twoMinute > 0 ? "\(insights.twoMinute) two-min" : nil, good: false)
      }
      HeatGrid(columns: insights.columns(weeks: 25), look: look, cell: 10, gap: 3)
        .frame(maxWidth: .infinity, alignment: .leading)
      Divider().overlay(Color(hex: look.track))
      VStack(spacing: 7) {
        if let longest = insights.longest { line("Longest streak", "\(longest.name) · \(longest.label)") }
        if let best = insights.bestDay { line("Your best day", best) }
        if let next = insights.next {
          // "365 days without smoking" already names its habit
          let named = next.habit.map { next.title.localizedCaseInsensitiveContains($0) } ?? true
          line("Next", named ? next.title : "\(next.habit!) · \(next.title)")
        }
      }
      Spacer(minLength: 0)
    }
  }

  private var momentumUp: Bool { (insights.momentum ?? 0) > (insights.momentumLast ?? Int.max) }

  private var momentumNote: String? {
    guard let now = insights.momentum, let last = insights.momentumLast else { return nil }
    let change = now - last
    return change == 0 ? "same as last month" : (change > 0 ? "+\(change) on last month" : "\(change) on last month")
  }

  private func tile(title: String, value: String, note: String?, good: Bool) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(.system(size: 11)).foregroundStyle(Color(hex: look.textSecondary))
      Text(value).font(.sora(24, bold: true))
      if let note {
        Text(note).font(.system(size: 11, weight: .semibold))
          .foregroundStyle(Color(hex: good ? look.good : look.textSecondary)).lineLimit(1).minimumScaleFactor(0.8)
      }
    }
    .padding(.horizontal, 12).padding(.vertical, 9)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: look.raised)))
  }

  private func line(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label).foregroundStyle(Color(hex: look.textSecondary))
      Spacer(minLength: 8)
      Text(value).bold().lineLimit(1).minimumScaleFactor(0.8)
    }
    .font(.system(size: 13))
  }
}
