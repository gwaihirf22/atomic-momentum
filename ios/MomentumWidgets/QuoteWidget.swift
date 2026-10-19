import AppIntents
import SwiftUI
import WidgetKit

// A quote: the day's (the same one Inspire shows), or one of a habit's own
// ("Words for this habit"), taking turns a day at a time.

/// Hold the widget → Edit Widget: the day's quote, or a habit's.
struct PickQuoteIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Quote"
  static var description = IntentDescription("The quote of the day, or the words you keep with a habit.")

  @Parameter(title: "Words for a habit")
  var habit: HabitEntity?
}

struct QuoteEntry: TimelineEntry {
  let date: Date
  let quote: QuoteInfo?
  /// For small and lock screen widgets: one short enough to show whole.
  let short: QuoteInfo?
  /// The habit whose words these are, if one was picked.
  let habit: HabitInfo?
  let looks: Looks?
}

struct QuoteTimeline: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> QuoteEntry {
    let quote = QuoteInfo(id: "placeholder", text: "First say to yourself what you would be; and then do what you have to do.",
                          author: "Epictetus", source: "Discourses 3.23")
    return QuoteEntry(date: Date(), quote: quote, short: quote, habit: nil, looks: nil)
  }

  func snapshot(for configuration: PickQuoteIntent, in context: Context) async -> QuoteEntry {
    entry(for: configuration, at: Date(), tomorrow: false)
  }

  func timeline(for configuration: PickQuoteIntent, in context: Context) async -> Timeline<QuoteEntry> {
    let now = Date()
    // A new quote at midnight, even if the app hasn't written by then
    let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
    return Timeline(entries: [
      entry(for: configuration, at: now, tomorrow: false),
      entry(for: configuration, at: midnight, tomorrow: true),
    ], policy: .atEnd)
  }

  private func entry(for configuration: PickQuoteIntent, at date: Date, tomorrow: Bool) -> QuoteEntry {
    guard let snapshot = Snapshot.load() else {
      return QuoteEntry(date: date, quote: nil, short: nil, habit: nil, looks: nil)
    }
    // Tomorrow's entry: tomorrow's quote, unless the app has already
    // written for that day
    let ahead = tomorrow && snapshot.day != WidgetStore.dayString(date)
    let day = ahead ? snapshot.quoteNext : snapshot.quote
    let dayShort = ahead ? snapshot.shortQuoteNext : snapshot.shortQuote
    if let habit = snapshot.habit(configuration.habit?.id), let quote = habit.quote(on: date) {
      return QuoteEntry(date: date, quote: quote, short: quote, habit: habit.at(date), looks: snapshot.looks)
    }
    return QuoteEntry(date: date, quote: day, short: dayShort ?? day, habit: nil, looks: snapshot.looks)
  }
}

struct QuoteWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "quote", intent: PickQuoteIntent.self, provider: QuoteTimeline()) { entry in
      QuoteWidgetView(entry: entry)
    }
    .configurationDisplayName("Quote")
    .description("The quote of the day, or the words you keep with a habit.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
  }
}

struct QuoteWidgetView: View {
  let entry: QuoteEntry
  @Environment(\.colorScheme) private var scheme
  @Environment(\.widgetFamily) private var family

  private var look: Look { entry.looks?.look(for: scheme) ?? .fallback(for: scheme) }

  var body: some View {
    content
      .foregroundStyle(Color(hex: look.text))
      .containerBackground(for: .widget) { family == .accessoryRectangular ? Color.clear : Color(hex: look.surface) }
      .widgetURL(URL(string: entry.habit.map { "momentum://habit/\($0.id)" } ?? "momentum://inspire"))
  }

  @ViewBuilder
  private var content: some View {
    switch family {
    case .accessoryRectangular:
      if let quote = entry.short {
        VStack(alignment: .leading, spacing: 2) {
          Text(quote.text).font(.system(size: 13, weight: .semibold)).lineLimit(3).minimumScaleFactor(0.8)
          if !quote.author.isEmpty { Text(quote.author).font(.system(size: 11)).opacity(0.8).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Text("Momentum").font(.system(size: 13, weight: .semibold))
      }
    case .systemLarge:
      if let quote = entry.quote { QuoteLarge(quote: quote, habit: entry.habit, look: look, scheme: scheme) } else { empty }
    case .systemMedium:
      if let quote = entry.quote { QuoteBody(quote: quote, look: look, size: 17, markSize: 22) } else { empty }
    default:
      if let quote = entry.short { QuoteBody(quote: quote, look: look, size: 14, markSize: 18) } else { empty }
    }
  }

  private var empty: some View {
    EmptyMessage(title: "Quote", detail: "Open the app to show a quote here.", look: look)
  }
}

/// The open-quote mark, in the accent.
private struct QuoteMark: View {
  let look: Look
  let size: CGFloat

  var body: some View {
    Image(systemName: "quote.opening")
      .font(.system(size: size, weight: .bold))
      .foregroundStyle(Color(hex: look.accent))
      .accessibilityHidden(true)
  }
}

private struct QuoteBody: View {
  let quote: QuoteInfo
  let look: Look
  let size: CGFloat
  let markSize: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      QuoteMark(look: look, size: markSize)
      Text(quote.text)
        .font(.sora(size))
        .lineSpacing(2)
        .minimumScaleFactor(0.55)
      Spacer(minLength: 0)
      if !quote.author.isEmpty {
        Text(quote.author).font(.system(size: 13)).foregroundStyle(Color(hex: look.textSecondary)).lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

private struct QuoteLarge: View {
  let quote: QuoteInfo
  let habit: HabitInfo?
  let look: Look
  let scheme: ColorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      QuoteMark(look: look, size: 26)
      Spacer(minLength: 0)
      // Short quotes sit large in the middle; long ones shrink to fit
      Text(quote.text).font(.sora(quote.text.count < 120 ? 26 : 21)).lineSpacing(3).minimumScaleFactor(0.5)
      VStack(alignment: .leading, spacing: 2) {
        if !quote.author.isEmpty { Text(quote.author).font(.system(size: 14, weight: .semibold)) }
        if let source = quote.source, !source.isEmpty {
          Text(source).font(.system(size: 12)).foregroundStyle(Color(hex: look.textSecondary)).lineLimit(1)
        }
      }
      Spacer(minLength: 0)
      if let habit {
        Divider().overlay(Color(hex: look.track))
        HStack(spacing: 12) {
          HabitRing(fraction: habit.fraction, done: habit.done, color: habit.color.color(for: scheme),
                    track: Color(hex: look.track), checkColor: habit.onColor.color(for: scheme), lineWidth: 5)
            .frame(width: 34, height: 34)
          VStack(alignment: .leading, spacing: 1) {
            Text(habit.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            Text("Words for this habit · \(habit.isBreak || habit.period == "today" ? habit.text : "\(habit.text) \(habit.period)")")
              .font(.system(size: 12)).foregroundStyle(Color(hex: look.textSecondary)).lineLimit(1)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}
