import SwiftUI
import WidgetKit

// Momentum: the overall ring and its level (the Habits screen's
// MomentumRing), on the home screen and the lock screen. And "today", how
// many of today's habits are done, for the lock screen.

struct SnapshotEntry: TimelineEntry {
  let date: Date
  let snapshot: Snapshot?
}

struct SnapshotTimeline: TimelineProvider {
  func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: Date(), snapshot: nil) }

  func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
    completion(SnapshotEntry(date: Date(), snapshot: Snapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
    let now = Date()
    let snapshot = Snapshot.load()
    // Redrawn when the app writes; at midnight too, though only the app can
    // work out the new day's numbers
    let next = snapshot?.nextChange(after: now) ?? Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
    completion(Timeline(entries: [SnapshotEntry(date: now, snapshot: snapshot)], policy: .after(next)))
  }
}

struct MomentumWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "momentum", provider: SnapshotTimeline()) { entry in
      MomentumWidgetView(entry: entry)
    }
    .configurationDisplayName("Momentum")
    .description("Your momentum and its level. The mark is 80, habit formed.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
  }
}

struct TodayWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "today", provider: SnapshotTimeline()) { entry in
      TodayWidgetView(entry: entry)
    }
    .configurationDisplayName("Today")
    .description("How many of today's habits are done.")
    .supportedFamilies([.accessoryCircular])
  }
}

struct MomentumWidgetView: View {
  let entry: SnapshotEntry
  @Environment(\.colorScheme) private var scheme
  @Environment(\.widgetFamily) private var family

  private var look: Look { entry.snapshot?.looks.look(for: scheme) ?? .fallback(for: scheme) }

  var body: some View {
    content
      .containerBackground(for: .widget) { family.isAccessory ? Color.clear : Color(hex: look.surface) }
      .widgetURL(URL(string: "momentum://momentum"))
  }

  @ViewBuilder
  private var content: some View {
    let momentum = entry.snapshot?.momentum
    switch family {
    case .accessoryCircular: LockCircular(momentum: momentum)
    case .accessoryRectangular: LockRectangular(momentum: momentum)
    case .accessoryInline: LockInline(momentum: momentum)
    case .systemMedium:
      if let momentum { MomentumMedium(momentum: momentum, look: look) } else { noMomentum }
    default:
      if let momentum { MomentumSmall(momentum: momentum, look: look) } else { noMomentum }
    }
  }

  private var noMomentum: some View {
    EmptyMessage(title: "Momentum", detail: entry.snapshot == nil
      ? "Open the app to show your momentum here."
      : "Log a habit to start building momentum.", look: look)
      .foregroundStyle(Color(hex: look.text))
  }
}

private extension WidgetFamily {
  var isAccessory: Bool { self == .accessoryCircular || self == .accessoryRectangular || self == .accessoryInline }
}

private struct ScoreLabel: View {
  let momentum: MomentumInfo
  let look: Look
  var size: CGFloat = 36

  var body: some View {
    let tint = Color(hex: momentum.isAtomic ? look.gold : look.gauge)
    VStack(spacing: 2) {
      if momentum.isAtomic {
        Image(systemName: "bolt.fill").font(.system(size: size * 0.4)).foregroundStyle(tint)
      }
      Text("\(momentum.score)").font(.sora(size, bold: true)).foregroundStyle(Color(hex: look.text))
      Text(momentum.isAtomic ? "ATOMIC" : momentum.level)
        .font(.system(size: size * 0.35, weight: momentum.isAtomic ? .bold : .semibold))
        .tracking(momentum.isAtomic ? 1.5 : 0)
        .foregroundStyle(tint)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Momentum \(momentum.score), \(momentum.level)")
  }
}

private struct Trend: View {
  let momentum: MomentumInfo
  let look: Look

  var body: some View {
    let trend = momentum.trend
    if trend != 0 {
      HStack(spacing: 3) {
        Image(systemName: trend > 0 ? "arrow.up" : "arrow.down").font(.system(size: 10, weight: .bold))
        Text("\(abs(trend)) this week").font(.system(size: 12))
      }
      .foregroundStyle(Color(hex: trend > 0 ? look.good : look.textSecondary))
    }
  }
}

private struct MomentumSmall: View {
  let momentum: MomentumInfo
  let look: Look

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        MomentumGauge(score: momentum.score, color: Color(hex: momentum.isAtomic ? look.gold : look.gauge),
                      track: Color(hex: look.track), tick: momentum.isAtomic ? nil : Color(hex: look.textSecondary))
        ScoreLabel(momentum: momentum, look: look, size: momentum.isAtomic ? 32 : 36).padding(.top, 6)
      }
      .frame(width: 120, height: 120)
      Trend(momentum: momentum, look: look).offset(y: -8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct MomentumMedium: View {
  let momentum: MomentumInfo
  let look: Look

  var body: some View {
    let tint = Color(hex: momentum.isAtomic ? look.gold : look.gauge)
    HStack(spacing: 16) {
      ZStack {
        MomentumGauge(score: momentum.score, color: tint, track: Color(hex: look.track),
                      tick: momentum.isAtomic ? nil : Color(hex: look.textSecondary))
        ScoreLabel(momentum: momentum, look: look, size: 32).padding(.top, 6)
      }
      .frame(width: 118, height: 118)

      VStack(alignment: .leading, spacing: 9) {
        if let next = momentum.toNext {
          Text("\(next.points) to \(next.level)").font(.sora(16)).foregroundStyle(Color(hex: look.text))
        } else {
          Text("Atomic momentum").font(.sora(16)).foregroundStyle(Color(hex: look.text))
        }
        HStack(spacing: 3) {
          ForEach(0..<5) { i in
            Capsule().fill(i <= momentum.levelIndex ? tint : Color(hex: look.track)).frame(height: 6)
          }
        }
        Trend(momentum: momentum, look: look)
        Text(momentum.habits == 1 ? "1 habit" : "\(momentum.habits) habits\(momentum.rising > 0 ? ", \(momentum.rising) rising" : "")")
          .font(.system(size: 12)).foregroundStyle(Color(hex: look.textSecondary))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// The lock screen draws these in one tint (vibrant), so no theme colors.

private struct LockCircular: View {
  let momentum: MomentumInfo?

  var body: some View {
    Gauge(value: Double(momentum?.score ?? 0), in: 0...100) {
      Image(systemName: "bolt.fill")
    } currentValueLabel: {
      Text(momentum.map { "\($0.score)" } ?? "–").font(.sora(18, bold: true))
    }
    .gaugeStyle(.accessoryCircular)
    .widgetAccentable()
    .accessibilityLabel(momentum.map { "Momentum \($0.score), \($0.level)" } ?? "No momentum yet")
  }
}

private struct LockRectangular: View {
  let momentum: MomentumInfo?

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Label(momentum.map { "Momentum \($0.score)" } ?? "Momentum", systemImage: "bolt.fill")
        .font(.system(size: 14, weight: .bold))
        .widgetAccentable()
      Gauge(value: Double(momentum?.score ?? 0), in: 0...100) { EmptyView() }
        .gaugeStyle(.accessoryLinearCapacity)
      Text(detail).font(.system(size: 12)).lineLimit(1)
    }
  }

  private var detail: String {
    guard let momentum else { return "Log a habit to start" }
    if momentum.trend > 0 { return "\(momentum.level) · up \(momentum.trend) this week" }
    if momentum.trend < 0 { return "\(momentum.level) · down \(-momentum.trend)" }
    return momentum.level
  }
}

private struct LockInline: View {
  let momentum: MomentumInfo?

  var body: some View {
    Label(momentum.map { "Momentum \($0.score) · \($0.level)" } ?? "Momentum", systemImage: "bolt.fill")
  }
}

struct TodayWidgetView: View {
  let entry: SnapshotEntry

  var body: some View {
    let today = entry.snapshot?.today
    Gauge(value: today?.fraction ?? 0) {
      Text("today")
    } currentValueLabel: {
      Text(today.map { "\($0.done)/\($0.due)" } ?? "–").font(.sora(16, bold: true)).minimumScaleFactor(0.6)
    }
    .gaugeStyle(.accessoryCircularCapacity)
    .widgetAccentable()
    .containerBackground(for: .widget) { Color.clear }
    .widgetURL(URL(string: "momentum://today"))
    .accessibilityLabel(today.map { "\($0.done) of \($0.due) habits done today" } ?? "Habits today")
  }
}
