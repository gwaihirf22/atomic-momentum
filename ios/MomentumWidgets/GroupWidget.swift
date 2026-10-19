import AppIntents
import SwiftUI
import WidgetKit

// A group of habits: today's, a category's, or habits picked by hand. Rows
// with a + each (large), four rings (medium), or a 2×2 of rings (small).

/// What a group widget shows: "Today" or a category.
struct GroupEntity: AppEntity {
  static let todayId = "today"

  let id: String
  let name: String

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Group"
  static var defaultQuery = GroupQuery()

  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

  static let today = GroupEntity(id: todayId, name: "Today")
}

struct GroupQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [GroupEntity] {
    try await suggestedEntities().filter { identifiers.contains($0.id) }
  }

  /// Today, then each category that has a habit.
  func suggestedEntities() async throws -> [GroupEntity] {
    guard let snapshot = Snapshot.load() else { return [.today] }
    let used = Set(snapshot.habits.compactMap(\.category))
    let categories = (snapshot.categories ?? []).filter { used.contains($0.id) }
    return [.today] + categories.map { GroupEntity(id: $0.id, name: $0.name) }
  }

  func defaultResult() async -> GroupEntity? { .today }
}

/// Hold the widget → Edit Widget: which habits it shows.
struct PickGroupIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Habits"
  static var description = IntentDescription("Today's habits, a category, or habits you pick.")

  @Parameter(title: "Show")
  var group: GroupEntity?

  @Parameter(title: "Or pick habits")
  var habits: [HabitEntity]?
}

struct GroupEntry: TimelineEntry {
  let date: Date
  let title: String
  let habits: [HabitInfo]
  let looks: Looks?
  let hasSnapshot: Bool
}

struct GroupTimeline: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> GroupEntry {
    GroupEntry(date: Date(), title: "Today", habits: [.placeholder, .placeholder, .placeholder, .placeholder],
               looks: nil, hasSnapshot: true)
  }

  func snapshot(for configuration: PickGroupIntent, in context: Context) async -> GroupEntry {
    entry(for: configuration, at: Date())
  }

  func timeline(for configuration: PickGroupIntent, in context: Context) async -> Timeline<GroupEntry> {
    let now = Date()
    var entries = [entry(for: configuration, at: now)]
    if let next = Snapshot.load()?.nextChange(after: now) {
      entries.append(entry(for: configuration, at: next))
    }
    return Timeline(entries: entries, policy: .atEnd)
  }

  private func entry(for configuration: PickGroupIntent, at date: Date) -> GroupEntry {
    guard let snapshot = Snapshot.load() else {
      return GroupEntry(date: date, title: "Today", habits: [], looks: nil, hasSnapshot: false)
    }
    let picked = (configuration.habits ?? []).compactMap { snapshot.habit($0.id) }
    let group = configuration.group ?? .today
    var title = group.name
    var habits: [HabitInfo]
    if !picked.isEmpty {
      habits = picked
      title = "Habits"
    } else if group.id == GroupEntity.todayId {
      habits = snapshot.habits.filter(\.due)
    } else {
      habits = snapshot.habits.filter { $0.category == group.id }
    }
    habits = habits.map { $0.at(date) }
    // Still to do first, in the app's order
    habits = habits.filter { !$0.done } + habits.filter(\.done)
    return GroupEntry(date: date, title: title, habits: habits, looks: snapshot.looks, hasSnapshot: true)
  }
}

struct GroupWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "group", intent: PickGroupIntent.self, provider: GroupTimeline()) { entry in
      GroupWidgetView(entry: entry)
    }
    .configurationDisplayName("Habits")
    .description("Today's habits, a category, or habits you pick. Tap + to log one.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

struct GroupWidgetView: View {
  let entry: GroupEntry
  @Environment(\.colorScheme) private var scheme
  @Environment(\.widgetFamily) private var family

  private var look: Look { entry.looks?.look(for: scheme) ?? .fallback(for: scheme) }

  var body: some View {
    content
      .foregroundStyle(Color(hex: look.text))
      .containerBackground(for: .widget) { Color(hex: look.surface) }
      .widgetURL(URL(string: "momentum://habits"))
  }

  @ViewBuilder
  private var content: some View {
    if !entry.hasSnapshot {
      EmptyMessage(title: "Momentum", detail: "Open the app to show your habits here.", look: look)
    } else if entry.habits.isEmpty {
      EmptyMessage(title: entry.title, detail: "Nothing due here today.", look: look)
    } else {
      switch family {
      case .systemLarge: GroupList(entry: entry, look: look, scheme: scheme)
      case .systemMedium: GroupRings(entry: entry, look: look, scheme: scheme)
      default: GroupGrid(habits: Array(entry.habits.prefix(4)), look: look, scheme: scheme)
      }
    }
  }
}

/// "3 of 6 done", over the habits shown.
private struct GroupHeading: View {
  let entry: GroupEntry
  let look: Look

  var body: some View {
    let done = entry.habits.filter(\.done).count
    HStack(alignment: .firstTextBaseline) {
      Text(entry.title).font(.sora(16, bold: true)).lineLimit(1)
      Spacer(minLength: 6)
      (Text("\(done) of \(entry.habits.count)").bold().foregroundColor(Color(hex: look.text)) + Text(" done"))
        .font(.system(size: 13))
        .foregroundStyle(Color(hex: look.textSecondary))
    }
  }
}

/// A habit's ring with its progress or initials inside.
private struct MiniRing: View {
  let habit: HabitInfo
  let look: Look
  let scheme: ColorScheme
  let label: String
  var lineWidth: CGFloat = 7

  var body: some View {
    ZStack {
      HabitRing(fraction: habit.isBreak ? (habit.progress == 0 ? 1 : 0) : habit.fraction, done: habit.done,
                color: habit.color.color(for: scheme), track: Color(hex: look.track),
                checkColor: habit.onColor.color(for: scheme), lineWidth: lineWidth)
      if !habit.done {
        Text(label).font(.sora(12, bold: true)).lineLimit(1).minimumScaleFactor(0.6).padding(lineWidth + 4)
      }
    }
  }
}

private struct GroupGrid: View {
  let habits: [HabitInfo]
  let look: Look
  let scheme: ColorScheme

  var body: some View {
    let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    LazyVGrid(columns: columns, spacing: 8) {
      ForEach(habits) { habit in
        Link(destination: URL(string: "momentum://habit/\(habit.id)")!) {
          MiniRing(habit: habit, look: look, scheme: scheme, label: String(habit.name.prefix(2)), lineWidth: 8)
            .frame(width: 60, height: 60)
        }
        .accessibilityLabel("\(habit.name), \(habit.text)")
      }
    }
  }
}

private struct GroupRings: View {
  let entry: GroupEntry
  let look: Look
  let scheme: ColorScheme

  var body: some View {
    VStack(spacing: 10) {
      GroupHeading(entry: entry, look: look)
      HStack(alignment: .top, spacing: 8) {
        ForEach(Array(entry.habits.prefix(4))) { habit in
          Link(destination: URL(string: "momentum://habit/\(habit.id)")!) {
            VStack(spacing: 6) {
              MiniRing(habit: habit, look: look, scheme: scheme,
                       label: habit.isBreak ? "" : "\(habit.progress)/\(habit.target)", lineWidth: 7)
                .frame(width: 62, height: 62)
              Text(habit.name).font(.system(size: 12)).foregroundStyle(Color(hex: look.textSecondary))
                .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
          }
          .accessibilityLabel("\(habit.name), \(habit.text)")
        }
      }
      Spacer(minLength: 0)
    }
  }
}

private struct GroupList: View {
  let entry: GroupEntry
  let look: Look
  let scheme: ColorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      GroupHeading(entry: entry, look: look).padding(.bottom, 6)
      ForEach(Array(entry.habits.prefix(6))) { habit in
        Divider().overlay(Color(hex: look.track))
        GroupRow(habit: habit, look: look, scheme: scheme).frame(height: 50)
      }
      Spacer(minLength: 0)
    }
  }
}

private struct GroupRow: View {
  let habit: HabitInfo
  let look: Look
  let scheme: ColorScheme

  var body: some View {
    HStack(spacing: 12) {
      Link(destination: URL(string: "momentum://habit/\(habit.id)")!) {
        HStack(spacing: 12) {
          MiniRing(habit: habit, look: look, scheme: scheme, label: "", lineWidth: 5).frame(width: 36, height: 36)
          VStack(alignment: .leading, spacing: 1) {
            Text(habit.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
            Text(detail).font(.system(size: 12)).foregroundStyle(Color(hex: detailColor)).lineLimit(1)
          }
          Spacer(minLength: 0)
        }
      }
      if habit.next != nil {
        Button(intent: LogHabitIntent(habitId: habit.id)) {
          Circle()
            .fill(Color(hex: look.raised))
            .frame(width: 34, height: 34)
            .overlay(Image(systemName: "plus").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: look.accent)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habit.addLabel ?? "Add one"), \(habit.name)")
      }
    }
  }

  private var detail: String {
    if habit.frozen == true { return "Frozen today" }
    if habit.atRisk && !habit.done { return habit.isBreak ? "Don't slip twice" : "Don't miss twice" }
    if habit.done, let streak = habit.streakLabel { return "Done · \(streak)" }
    if habit.done { return "Done" }
    return habit.isBreak || habit.period == "today" ? habit.text : "\(habit.text) \(habit.period)"
  }

  private var detailColor: String { habit.atRisk && !habit.done ? look.warning : look.textSecondary }
}
