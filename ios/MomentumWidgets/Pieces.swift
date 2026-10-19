import SwiftUI

// Drawing pieces shared by the widgets, after the app's own (the habit ring,
// MomentumRing, the card's last 7 days).

extension Font {
  /// Sora, the app's display face (bundled with the extension).
  static func sora(_ size: CGFloat, bold: Bool = false) -> Font {
    .custom(bold ? "Sora-Bold" : "Sora-SemiBold", size: size)
  }
}

/// A habit's progress ring; full and filled with a check once done.
struct HabitRing: View {
  let fraction: Double
  let done: Bool
  let color: Color
  let track: Color
  let checkColor: Color
  var lineWidth: CGFloat = 9

  var body: some View {
    ZStack {
      if done {
        Circle().fill(color)
        Image(systemName: "checkmark")
          .font(.system(size: 100, weight: .heavy))
          .minimumScaleFactor(0.01)
          .padding(lineWidth * 2.2)
          .foregroundStyle(checkColor)
      } else {
        Circle().stroke(track, lineWidth: lineWidth)
        Circle()
          .trim(from: 0, to: fraction)
          .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
          .rotationEffect(.degrees(-90))
      }
    }
    .padding(lineWidth / 2)
  }
}

/// The momentum gauge: a 270° arc, with a tick at 80 (habit formed).
struct MomentumGauge: View {
  let score: Int
  let color: Color
  let track: Color
  let tick: Color?
  var lineWidth: CGFloat = 10

  var body: some View {
    GeometryReader { geo in
      let size = min(geo.size.width, geo.size.height)
      ZStack {
        Circle()
          .trim(from: 0, to: 0.75)
          .stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        Circle()
          .trim(from: 0, to: 0.75 * min(Double(score), 100) / 100)
          .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        if let tick {
          // At 80% of the arc
          Capsule()
            .fill(tick)
            .frame(width: lineWidth * 1.7, height: 2.5)
            .offset(x: (size - lineWidth) / 2)
            .rotationEffect(.degrees(0.75 * 360 * 0.8))
        }
      }
      .rotationEffect(.degrees(135))
      .frame(width: size, height: size)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(lineWidth / 2)
  }
}

/// The amber "+" (the app's orb).
struct PlusOrb: View {
  let look: Look
  var size: CGFloat = 44

  var body: some View {
    Circle()
      .fill(look.orb)
      .frame(width: size, height: size)
      .overlay(
        Image(systemName: "plus")
          .font(.system(size: size * 0.42, weight: .bold))
          .foregroundStyle(Color(hex: look.onOrb))
      )
  }
}

/// The streak: a flame and its count.
struct StreakBadge: View {
  let count: Int
  let atRisk: Bool
  let look: Look

  var body: some View {
    HStack(spacing: 2) {
      Image(systemName: "flame.fill").font(.system(size: 11, weight: .semibold))
      Text("\(count)").font(.system(size: 13, weight: .semibold)).monospacedDigit()
    }
    .foregroundStyle(Color(hex: atRisk ? look.warning : look.flame))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(atRisk ? "\(count) streak, don't miss twice" : "\(count) streak")
  }
}

/// The card's last 7 periods: full = done, half = two-minute, partial
/// height, flat = missed, outline = under way, dot = rest day.
struct RecentBars: View {
  let recent: [RecentInfo]
  let color: Color
  let track: Color
  var height: CGFloat = 22

  var body: some View {
    HStack(alignment: .bottom, spacing: 5) {
      ForEach(Array(recent.enumerated()), id: \.offset) { _, period in
        bar(period)
      }
    }
    .frame(height: height, alignment: .bottom)
    .accessibilityHidden(true)
  }

  @ViewBuilder
  private func bar(_ period: RecentInfo) -> some View {
    let shape = RoundedRectangle(cornerRadius: 3)
    switch period.mark {
    case "done":
      shape.fill(color).frame(width: 9, height: height)
    case "twoMinute":
      shape.fill(color).frame(width: 9, height: height / 2)
    case "partial":
      shape.fill(color.opacity(0.6)).frame(width: 9, height: max(4, height * period.fraction))
    case "missed":
      shape.fill(track).frame(width: 9, height: 3)
    case "current":
      ZStack(alignment: .bottom) {
        shape.stroke(color, lineWidth: 1.5)
        shape.fill(color.opacity(0.5)).frame(height: height * period.fraction)
      }
      .frame(width: 9, height: height)
    case "rest":
      Circle().fill(track).frame(width: 5, height: 5).frame(width: 9)
    default:
      Color.clear.frame(width: 9, height: 3)
    }
  }
}

/// Shown before the app has written anything (or has no habits).
struct EmptyMessage: View {
  let title: String
  let detail: String
  let look: Look?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.sora(15))
      Text(detail).font(.system(size: 12)).foregroundStyle(look.map { Color(hex: $0.textSecondary) } ?? .secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

extension Look {
  /// For previews and before the app's first snapshot: Charged.
  static let charged = Look(
    theme: "dark", background: "#0E1013", surface: "#171A20", raised: "#22262E", track: "#2A2E36",
    text: "#F4F4F6", textSecondary: "#9A9DA6", accent: "#FFB020", gauge: "#FFB020",
    orbStart: "#FFC24D", orbEnd: "#FF7A1A", onOrb: "#1A1206", good: "#6EE7A0", goodTint: "#12301F",
    gold: "#FFC24D", flame: "#FF8A3D", warning: "#FFB020")

  static let light = Look(
    theme: "light", background: "#F4F5F7", surface: "#FFFFFF", raised: "#ECEEF1", track: "#E3E5EA",
    text: "#111318", textSecondary: "#5F636B", accent: "#C26A08", gauge: "#F29A0C",
    orbStart: "#FFC24D", orbEnd: "#F27A12", onOrb: "#1A1206", good: "#17723A", goodTint: "#DDF5E6",
    gold: "#7A5200", flame: "#D9480F", warning: "#B45309")

  static func fallback(for scheme: ColorScheme) -> Look { scheme == .dark ? charged : light }
}
