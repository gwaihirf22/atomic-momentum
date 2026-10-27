import SwiftUI

/// The first screen: "3 of 6 done", then today's habits, each with its ring
/// and a +; done ones sink to the bottom. Tapping a habit opens its own
/// screen (Momentum Plus).
struct TodayView: View {
  @EnvironmentObject private var model: WatchModel
  @State private var path: [String] = []
  @State private var locked = false

  var body: some View {
    NavigationStack(path: $path) {
      Group {
        if let snapshot = model.snapshot, !snapshot.habits.isEmpty {
          list(snapshot)
        } else {
          VStack(spacing: 6) {
            Text("Momentum").font(.sora(17, bold: true))
            Text(model.snapshot == nil
                 ? "Open Momentum on your iPhone to bring your habits here."
                 : "Add a habit in Momentum on your iPhone.")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
        }
      }
      .navigationTitle("Today")
      .navigationDestination(for: String.self) { id in HabitView(habitId: id) }
      .sheet(isPresented: $locked) { PlusLockedView(what: "A habit's own screen, with the Digital Crown and 2 min,") }
    }
    .onChange(of: model.openHabit) { _, id in
      guard let id else { return }
      model.openHabit = nil
      open(id)
    }
  }

  private func open(_ id: String) {
    if model.plus { path = [id] } else { locked = true }
  }

  private func list(_ snapshot: Snapshot) -> some View {
    let habits = snapshot.habits.map(\.now)
    let due = habits.filter(\.due)
    let open = due.filter { !$0.done }
    let done = due.filter(\.done)
    let other = habits.filter { !$0.due }
    let look = model.look
    return List {
      Section {
        TodayHeader(today: snapshot.today, look: look, waiting: isLate)
          .listRowBackground(Color.clear)
      }
      Section {
        ForEach(open + done) { habit in row(habit) }
      }
      if !other.isEmpty {
        Section("Not today") {
          ForEach(other) { habit in row(habit) }
        }
      }
    }
  }

  private var isLate: Bool {
    guard let since = model.waitingSince else { return false }
    return Date().timeIntervalSince(since) > WatchModel.lateAfter
  }

  private func row(_ habit: HabitInfo) -> some View {
    HabitRow(habit: habit, look: model.look, onOpen: { open(habit.id) }, onStep: { model.step(habit) })
  }
}

/// "3 of 6 done", or the gold "All done".
private struct TodayHeader: View {
  let today: TodayCount
  let look: Look
  let waiting: Bool

  var body: some View {
    let allDone = today.due > 0 && today.done >= today.due
    HStack(spacing: 10) {
      HabitRing(
        fraction: today.fraction, done: allDone, color: Color(hex: allDone ? look.gold : look.good),
        track: Color(hex: look.track), checkColor: .black, lineWidth: 5)
        .frame(width: 34, height: 34)
      VStack(alignment: .leading, spacing: 1) {
        Text(allDone ? "All done" : "\(today.done) of \(today.due) done")
          .font(.sora(16, bold: true))
          .foregroundStyle(allDone ? Color(hex: look.gold) : .white)
        if waiting {
          Label("Not on your iPhone yet", systemImage: "iphone.slash")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// A habit on Today: ring, name, "5 of 8", and + (none for a habit being
/// broken, one frozen, or one done).
struct HabitRow: View {
  let habit: HabitInfo
  let look: Look
  let onOpen: () -> Void
  let onStep: () -> Void

  var body: some View {
    let color = habit.color.color(for: .dark)
    HStack(spacing: 8) {
      Button(action: onOpen) {
        HStack(spacing: 8) {
          HabitRing(
            fraction: habit.fraction, done: habit.done, color: habit.frozen == true ? Color(hex: look.ice ?? look.track) : color,
            track: Color(hex: look.track), checkColor: habit.onColor.color(for: .dark), lineWidth: 4)
            .frame(width: 28, height: 28)
          VStack(alignment: .leading, spacing: 1) {
            Text(habit.name)
              .font(.system(size: 15, weight: .semibold))
              .lineLimit(2)
            Text(habit.frozen == true ? "Frozen" : habit.text)
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
          Spacer(minLength: 0)
        }
      }
      .buttonStyle(.plain)
      if habit.canStep {
        Button(action: onStep) {
          PlusOrb(look: look, size: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(habit.addLabel ?? "Add one")
      } else if habit.done {
        Image(systemName: "checkmark").foregroundStyle(Color(hex: look.good))
      }
    }
    .padding(.vertical, 2)
  }
}
