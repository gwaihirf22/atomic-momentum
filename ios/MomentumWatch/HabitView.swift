import SwiftUI

/// A habit's own screen (Momentum Plus): the big ring with its number, the
/// Digital Crown setting the amount (between Apple Health's number and the
/// target, as + stops there), 2 min, the streak and the last 7 periods.
struct HabitView: View {
  @EnvironmentObject private var model: WatchModel
  let habitId: String

  /// The Crown's amount, while it's turning (nil: the habit's own).
  @State private var crown: Double = 0
  @State private var turning = false
  @State private var settle: Task<Void, Never>?

  var body: some View {
    if let habit = model.snapshot?.habit(habitId)?.now {
      content(habit)
    } else {
      Text("This habit isn't on your iPhone any more.")
        .font(.footnote)
        .multilineTextAlignment(.center)
    }
  }

  private func content(_ habit: HabitInfo) -> some View {
    let look = model.look
    let color = habit.color.color(for: .dark)
    let canTurn = !habit.isBreak && habit.frozen != true
    let low = Double(habit.floor ?? 0)
    let high = Double(max(habit.target, habit.progress, habit.floor ?? 0))
    let shown = turning ? Int(crown.rounded()) : habit.progress
    return ScrollView {
      VStack(spacing: 8) {
        ZStack {
          HabitRing(
            fraction: habit.target == 0 ? 0 : min(Double(shown) / Double(habit.target), 1),
            done: shown >= habit.target && !habit.isBreak, color: color,
            track: Color(hex: look.track), checkColor: habit.onColor.color(for: .dark), lineWidth: 10)
          if shown < habit.target || habit.isBreak {
            VStack(spacing: 0) {
              Text("\(shown)").font(.sora(30, bold: true)).monospacedDigit()
              Text("of \(habit.target)").font(.caption2).foregroundStyle(.secondary)
            }
          }
        }
        .frame(width: 110, height: 110)
        .focusable(canTurn)
        .digitalCrownRotation(
          $crown, from: low, through: high, by: Double(max(habit.step, 1)),
          sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { _, value in
          guard turning || Int(value.rounded()) != habit.progress else { return }
          turning = true
          settle?.cancel()
          // Logs once the Crown rests
          settle = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            let amount = Int(value.rounded())
            if amount != habit.progress { model.set(habit, to: amount) }
            turning = false
          }
        }
        .onAppear { crown = Double(habit.progress) }
        .accessibilityElement()
        .accessibilityLabel("\(habit.name), \(habit.text)")
        .accessibilityAdjustableAction { direction in
          let next = direction == .increment
            ? min(habit.progress + habit.step, Int(high))
            : max(habit.progress - habit.step, Int(low))
          if next != habit.progress { model.set(habit, to: next) }
        }

        Text(habit.name).font(.headline).multilineTextAlignment(.center).lineLimit(2)
        Text(habit.frozen == true ? "Frozen" : habit.text).font(.footnote).foregroundStyle(.secondary)

        HStack(spacing: 8) {
          if let two = habit.twoMinute, two.can, !two.done {
            Button("2 min") { model.twoMinute(habit) }
              .tint(Color(hex: look.accent))
          } else if habit.twoMinute?.done == true {
            Label("2 min kept", systemImage: "checkmark")
              .font(.footnote)
              .foregroundStyle(Color(hex: look.good))
          }
          if habit.canStep {
            Button { model.step(habit) } label: { PlusOrb(look: look, size: 36) }
              .buttonStyle(.plain)
              .accessibilityLabel(habit.addLabel ?? "Add one")
          }
        }

        if habit.streak > 0 {
          VStack(spacing: 2) {
            StreakBadge(count: habit.streak, atRisk: habit.atRisk, look: look)
            if habit.atRisk {
              Text("Don't miss twice").font(.caption2).foregroundStyle(Color(hex: look.warning))
            } else if let label = habit.streakLabel {
              Text(label).font(.caption2).foregroundStyle(.secondary)
            }
          }
        }

        RecentBars(recent: habit.recent, color: color, track: Color(hex: look.track), height: 18)
          .padding(.top, 2)
      }
    }
    .navigationTitle(habit.name)
  }
}
