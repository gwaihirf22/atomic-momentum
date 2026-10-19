import AppIntents
import SwiftUI
import WidgetKit

// "I will": a habit's Story sentence kept in sight, or a promise in the
// person's own words over the day's numbers.

/// Hold the widget → Edit Widget: a habit's sentence, or your own words.
struct PickPromiseIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "I will"
  static var description = IntentDescription("A habit's sentence, or a promise in your own words.")

  static let defaultWords = "I will complete my habits."

  @Parameter(title: "Habit")
  var habit: HabitEntity?

  @Parameter(title: "Or your own words", default: "I will complete my habits.")
  var words: String?
}

struct PromiseEntry: TimelineEntry {
  let date: Date
  let habit: HabitInfo?
  let words: String
  let today: TodayCount?
  let momentum: MomentumInfo?
  let looks: Looks?
}

struct PromiseTimeline: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> PromiseEntry {
    PromiseEntry(date: Date(), habit: nil, words: PickPromiseIntent.defaultWords, today: nil, momentum: nil, looks: nil)
  }

  func snapshot(for configuration: PickPromiseIntent, in context: Context) async -> PromiseEntry {
    entry(for: configuration, at: Date())
  }

  func timeline(for configuration: PickPromiseIntent, in context: Context) async -> Timeline<PromiseEntry> {
    let now = Date()
    var entries = [entry(for: configuration, at: now)]
    if let ends = entries[0].habit?.periodEndDate, ends > now {
      entries.append(entry(for: configuration, at: ends))
    }
    return Timeline(entries: entries, policy: .atEnd)
  }

  private func entry(for configuration: PickPromiseIntent, at date: Date) -> PromiseEntry {
    let words = configuration.words?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let snapshot = Snapshot.load()
    return PromiseEntry(
      date: date,
      habit: snapshot?.habit(configuration.habit?.id)?.at(date),
      words: words.isEmpty ? PickPromiseIntent.defaultWords : words,
      today: snapshot?.today,
      momentum: snapshot?.momentum,
      looks: snapshot?.looks)
  }
}

struct IWillWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "iwill", intent: PickPromiseIntent.self, provider: PromiseTimeline()) { entry in
      IWillWidgetView(entry: entry)
    }
    .configurationDisplayName("I will")
    .description("A habit's sentence, or a promise in your own words.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
  }
}

struct IWillWidgetView: View {
  let entry: PromiseEntry
  @Environment(\.colorScheme) private var scheme
  @Environment(\.widgetFamily) private var family

  private var look: Look { entry.looks?.look(for: scheme) ?? .fallback(for: scheme) }

  var body: some View {
    content
      .foregroundStyle(Color(hex: look.text))
      .containerBackground(for: .widget) { family == .accessoryRectangular ? Color.clear : Color(hex: look.surface) }
      .widgetURL(URL(string: entry.habit.map { "momentum://habit/\($0.id)" } ?? "momentum://habits"))
  }

  @ViewBuilder
  private var content: some View {
    if family == .accessoryRectangular {
      VStack(alignment: .leading, spacing: 3) {
        Text(entry.habit.map(plainSentence) ?? entry.words)
          .font(.system(size: 13, weight: .bold)).lineLimit(2).minimumScaleFactor(0.8).widgetAccentable()
        Text(entry.habit?.text ?? entry.today.map { "\($0.done) of \($0.due) done" } ?? "")
          .font(.system(size: 11)).opacity(0.8).lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else if let habit = entry.habit {
      if family == .systemMedium {
        HabitPromiseMedium(habit: habit, look: look, scheme: scheme)
      } else {
        HabitPromiseSmall(habit: habit, look: look, scheme: scheme)
      }
    } else if family == .systemMedium {
      WordsMedium(entry: entry, look: look)
    } else {
      WordsSmall(entry: entry, look: look)
    }
  }

  private func plainSentence(_ habit: HabitInfo) -> String {
    (habit.sentence ?? []).map(\.t).joined()
  }
}

/// The sentence with the habit's own words in its color, as Story shows it.
private func sentenceText(_ habit: HabitInfo, color: Color) -> Text {
  (habit.sentence ?? [SentencePart(t: habit.name, k: true)]).reduce(Text("")) { text, part in
    text + (part.k == true ? Text(part.t).foregroundColor(color).fontWeight(.semibold) : Text(part.t))
  }
}

private struct HabitPromiseSmall: View {
  let habit: HabitInfo
  let look: Look
  let scheme: ColorScheme

  var body: some View {
    let color = habit.color.color(for: scheme)
    VStack(alignment: .leading, spacing: 8) {
      sentenceText(habit, color: color).font(.sora(17)).lineSpacing(1).minimumScaleFactor(0.6)
      Spacer(minLength: 0)
      if !habit.isBreak {
        Capsule().fill(Color(hex: look.track)).frame(height: 6)
          .overlay(alignment: .leading) {
            GeometryReader { geo in Capsule().fill(color).frame(width: geo.size.width * habit.fraction) }
          }
      }
      Text(habit.text).font(.system(size: 12)).foregroundStyle(Color(hex: look.textSecondary)).lineLimit(1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

private struct HabitPromiseMedium: View {
  let habit: HabitInfo
  let look: Look
  let scheme: ColorScheme

  var body: some View {
    let color = habit.color.color(for: scheme)
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 10) {
        sentenceText(habit, color: color).font(.sora(19)).lineSpacing(2).minimumScaleFactor(0.6)
        if let hard = habit.hardDay {
          Text("On a hard day, I'll just \(hard).").font(.system(size: 13))
            .foregroundStyle(Color(hex: look.textSecondary)).lineLimit(2)
        } else if habit.isBreak {
          Text(habit.text).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: look.good))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if !habit.isBreak {
        ZStack {
          HabitRing(fraction: habit.fraction, done: habit.done, color: color, track: Color(hex: look.track),
                    checkColor: habit.onColor.color(for: scheme), lineWidth: 8)
          if !habit.done {
            (Text("\(habit.progress)").font(.sora(16, bold: true))
              + Text("/\(habit.target)").font(.sora(11)).foregroundColor(Color(hex: look.textSecondary)))
              .lineLimit(1).minimumScaleFactor(0.5).padding(12)
          }
        }
        .frame(width: 72, height: 72)
      }
    }
  }
}

private struct WordsSmall: View {
  let entry: PromiseEntry
  let look: Look

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(entry.words).font(.sora(18)).lineSpacing(1).minimumScaleFactor(0.6)
      Spacer(minLength: 0)
      if let today = entry.today, today.due > 0 {
        HStack(spacing: 10) {
          ZStack {
            Circle().stroke(Color(hex: look.track), lineWidth: 6)
            Circle().trim(from: 0, to: today.fraction)
              .stroke(Color(hex: look.gauge), style: StrokeStyle(lineWidth: 6, lineCap: .round))
              .rotationEffect(.degrees(-90))
          }
          .frame(width: 34, height: 34)
          (Text("\(today.done) of \(today.due)").bold().foregroundColor(Color(hex: look.text)) + Text("\ndone today"))
            .font(.system(size: 12)).foregroundStyle(Color(hex: look.textSecondary))
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

private struct WordsMedium: View {
  let entry: PromiseEntry
  let look: Look

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("TODAY").font(.system(size: 12, weight: .semibold)).tracking(1.2).foregroundStyle(Color(hex: look.accent))
      Spacer(minLength: 0)
      Text(entry.words).font(.sora(24)).minimumScaleFactor(0.6)
      Spacer(minLength: 0)
      HStack(spacing: 16) {
        if let today = entry.today, today.due > 0 {
          (Text("\(today.done) of \(today.due)").bold().foregroundColor(Color(hex: look.text)) + Text(" habits done"))
        }
        if let momentum = entry.momentum {
          (Text("Momentum ") + Text("\(momentum.score)").bold().foregroundColor(Color(hex: look.text)) + Text(" · \(momentum.level)"))
        }
      }
      .font(.system(size: 13))
      .foregroundStyle(Color(hex: look.textSecondary))
      .lineLimit(1).minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}
