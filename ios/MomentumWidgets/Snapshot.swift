import SwiftUI

/// What the app wrote for the widgets
/// (lib/presentation/home_widgets/widget_snapshot.dart, version 1). Everything
/// is worked out by the app; the widgets only lay it out.
struct Snapshot: Decodable {
  let v: Int
  let day: String
  let looks: Looks
  let momentum: MomentumInfo?
  let today: TodayCount
  let habits: [HabitInfo]
  let categories: [CategoryInfo]?
  let insights: InsightsInfo?
  let quote: QuoteInfo?
  let quoteNext: QuoteInfo?
  let shortQuote: QuoteInfo?
  let shortQuoteNext: QuoteInfo?

  static let supportedVersion = 1

  /// The latest snapshot, or nil before the app has written one (or when it
  /// was written by a newer version these widgets can't read).
  static func load() -> Snapshot? {
    guard let data = WidgetStore.snapshotJSON()?.data(using: .utf8),
          let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
          snapshot.v == supportedVersion
    else { return nil }
    return snapshot
  }

  func habit(_ id: String?) -> HabitInfo? {
    habits.first { $0.id == id }
  }

  /// The habit a widget shows before one is picked: the first one due and
  /// not yet done, else the first.
  var firstHabit: HabitInfo? {
    habits.first { $0.due && !$0.done } ?? habits.first
  }

  /// When the widgets should next redraw by themselves: the soonest end of a
  /// period (usually midnight), when progress starts again from nothing.
  func nextChange(after now: Date) -> Date? {
    habits.compactMap(\.periodEndDate).filter { $0 > now }.min()
  }
}

struct Looks: Decodable {
  let light: Look
  let dark: Look

  func look(for scheme: ColorScheme) -> Look { scheme == .dark ? dark : light }
}

/// The app's palette for one of its themes (AppPalette).
struct Look: Decodable {
  let theme: String
  let background, surface, raised, track, text, textSecondary: String
  let accent, gauge, orbStart, orbEnd, onOrb: String
  let good, goodTint, gold, flame, warning: String

  var orb: LinearGradient {
    LinearGradient(colors: [Color(hex: orbStart), Color(hex: orbEnd)], startPoint: .topLeading, endPoint: .bottomTrailing)
  }
}

struct MomentumInfo: Decodable {
  let score: Int
  let trend: Int
  let level: String
  let formed: Int
  let habits: Int
  let rising: Int

  var isAtomic: Bool { score >= 90 }

  /// The next level up and the points to it ("6 to Unstoppable"); nil at Atomic.
  var toNext: (level: String, points: Int)? {
    let levels = [(40, "Rolling"), (70, "Strong"), (80, "Unstoppable"), (90, "Atomic")]
    guard let next = levels.first(where: { score < $0.0 }) else { return nil }
    return (next.1, next.0 - score)
  }

  /// 0–4: which of the five levels the score is in.
  var levelIndex: Int { [40, 70, 80, 90].filter { score >= $0 }.count }
}

struct TodayCount: Decodable {
  let done: Int
  let due: Int

  var fraction: Double { due == 0 ? 0 : Double(done) / Double(due) }
}

struct ColorPair: Decodable {
  let light: String
  let dark: String

  func color(for scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? dark : light) }
}

struct RecentInfo: Decodable {
  let mark: String
  let fraction: Double
}

struct HabitInfo: Decodable, Identifiable {
  let id: String
  let name: String
  let category: String?
  let color: ColorPair
  let onColor: ColorPair
  let isBreak: Bool
  var progress: Int
  let target: Int
  let units: String
  var text: String
  var done: Bool
  let due: Bool
  let period: String
  let periodEnds: String?
  var next: Int?
  let step: Int
  let addLabel: String?
  let streak: Int
  let streakLabel: String?
  let atRisk: Bool
  let momentum: Int?
  let recent: [RecentInfo]
  /// "Words for this habit", in order.
  let quotes: [QuoteInfo]?
  /// Story's sentence, its own words marked.
  let sentence: [SentencePart]?
  /// "fill one glass" (On a hard day, I'll just …).
  let hardDay: String?

  /// The habit's quote for [date]: they take turns, a new one each day.
  func quote(on date: Date) -> QuoteInfo? {
    guard let quotes, !quotes.isEmpty else { return nil }
    return quotes[DayNumber.of(date) % quotes.count]
  }

  var periodEndDate: Date? { periodEnds.flatMap(WidgetStore.parseLocal) }

  var fraction: Double { target == 0 ? 0 : min(Double(progress) / Double(target), 1) }

  /// The habit as it stands at [date]: once its period has ended the new one
  /// starts from nothing (until the app writes again).
  func at(_ date: Date) -> HabitInfo {
    guard let ends = periodEndDate, ends <= date else { return self }
    var fresh = self
    fresh.progress = 0
    fresh.done = false
    let unitsSuffix = units.isEmpty ? "" : " \(units)"
    if isBreak {
      fresh.text = target == 0 ? "Clean \(period)" : "0 of \(target)\(unitsSuffix) \(period)"
      fresh.next = nil
    } else {
      fresh.text = "0 of \(target)\(unitsSuffix)"
      fresh.next = WidgetStore.stepUp(0, step: max(step, 1), target: target)
    }
    return fresh
  }
}

struct QuoteInfo: Decodable {
  let id: String
  let text: String
  let author: String
  let source: String?
}

struct SentencePart: Decodable {
  let t: String
  let k: Bool?
}

/// Insights at a glance (WidgetSnapshot._insights).
struct InsightsInfo: Decodable {
  let weekStart: Int
  let from: String
  /// A character a day from [from] to today: "-" nothing due, "0"–"4" how
  /// full, "P" a perfect day.
  let days: String
  let week: [Double?]
  let weekToday: Int
  let momentum: Int?
  let momentumLast: Int?
  let kept: Int?
  let twoMinute: Int
  let streaksSaved: Int
  let longestStreak: Int
  let longest: LongestInfo?
  let bestDay: String?
  let next: NextInfo?

  struct LongestInfo: Decodable {
    let name: String
    let label: String
  }

  struct NextInfo: Decodable {
    let title: String
    let habit: String?
    let current: Int
    let goal: Int
  }

  /// The last [weeks] weeks of days, week by week (columns), each 7 long;
  /// nil for days before [from] or after today.
  func columns(weeks: Int) -> [[Character?]] {
    let chars = Array(days)
    let total = chars.count
    // Days run from a week's start to today; pad the end of this week
    let padded = chars.map(Optional.some) + Array(repeating: nil, count: (7 - total % 7) % 7)
    var cols: [[Character?]] = stride(from: 0, to: padded.count, by: 7).map { Array(padded[$0..<min($0 + 7, padded.count)]) }
    if cols.count > weeks { cols = Array(cols.suffix(weeks)) }
    while cols.count < weeks { cols.insert(Array(repeating: nil, count: 7), at: 0) }
    return cols
  }
}

struct CategoryInfo: Decodable {
  let id: String
  let name: String
}

/// Days since 2024-01-01 for a date's calendar day, as the app counts them
/// (QuoteOfTheDay.dayNumber).
enum DayNumber {
  static func of(_ date: Date) -> Int {
    let calendar = Calendar.current
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let day = utc.date(from: parts)!
    let epoch = utc.date(from: DateComponents(year: 2024, month: 1, day: 1))!
    return max(0, utc.dateComponents([.day], from: epoch, to: day).day ?? 0)
  }
}

extension Color {
  /// "#RRGGBB".
  init(hex: String) {
    var value: UInt64 = 0
    Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
    self.init(
      .sRGB,
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255,
      opacity: 1
    )
  }
}
