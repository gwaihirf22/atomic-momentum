import SwiftUI

/// The second page (Momentum Plus): overall momentum, its level and trend,
/// and how far the next level is.
struct MomentumPage: View {
  @EnvironmentObject private var model: WatchModel

  var body: some View {
    if !model.plus {
      PlusLockedView(what: "Momentum on your watch")
    } else if let momentum = model.snapshot?.momentum {
      let look = model.look
      VStack(spacing: 6) {
        ZStack {
          MomentumGauge(
            score: momentum.score, color: Color(hex: momentum.isAtomic ? look.gold : look.gauge),
            track: Color(hex: look.track), tick: Color(hex: look.text), lineWidth: 10)
          VStack(spacing: 0) {
            Text("\(momentum.score)").font(.sora(34, bold: true)).monospacedDigit()
            Text(momentum.level).font(.footnote).foregroundStyle(Color(hex: look.gauge))
          }
        }
        .frame(width: 120, height: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Momentum \(momentum.score), \(momentum.level)")
        HStack(spacing: 4) {
          Image(systemName: momentum.trend > 0 ? "arrow.up.right" : momentum.trend < 0 ? "arrow.down.right" : "arrow.right")
          Text(trendText(momentum.trend))
        }
        .font(.footnote)
        .foregroundStyle(momentum.trend >= 0 ? Color(hex: look.good) : .secondary)
        if let next = momentum.toNext {
          Text("\(next.points) to \(next.level)").font(.footnote).foregroundStyle(.secondary)
        }
      }
    } else {
      Text("Momentum shows once a habit has a few days behind it.")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  private func trendText(_ trend: Int) -> String {
    trend == 0 ? "Steady this week" : "\(trend > 0 ? "+" : "")\(trend) this week"
  }
}

/// What a Plus screen shows without Momentum Plus.
struct PlusLockedView: View {
  let what: String

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: "bolt.circle.fill").font(.title2).foregroundStyle(Color(hex: Look.charged.accent))
      Text("\(what) comes with Momentum Plus.")
        .font(.footnote)
        .multilineTextAlignment(.center)
      Text("Get it in Momentum on your iPhone: Settings, Momentum Plus.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 4)
  }
}
