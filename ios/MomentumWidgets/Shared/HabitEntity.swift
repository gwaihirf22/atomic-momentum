import AppIntents

/// A habit, as the widgets' settings, Siri and Shortcuts list it (from the
/// app's snapshot). Built into both the app and the widget extension.
@available(iOS 17.0, *)
struct HabitEntity: AppEntity {
  let id: String
  let name: String

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
  static var defaultQuery = HabitQuery()

  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

@available(iOS 17.0, *)
struct HabitQuery: EntityStringQuery {
  private var all: [HabitEntity] {
    (Snapshot.load()?.habits ?? []).map { HabitEntity(id: $0.id, name: $0.name) }
  }

  func entities(for identifiers: [String]) async throws -> [HabitEntity] {
    all.filter { identifiers.contains($0.id) }
  }

  /// A habit said to Siri ("water" finds "Drink water").
  func entities(matching string: String) async throws -> [HabitEntity] {
    let spoken = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    return all.filter { $0.name.lowercased().contains(spoken) || spoken.contains($0.name.lowercased()) }
  }

  func suggestedEntities() async throws -> [HabitEntity] { all }
}
