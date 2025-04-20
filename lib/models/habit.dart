class Habit {
  final String id;
  final String name;
  final int target;
  final int progress;

  Habit({
    required this.id,
    required this.name,
    required this.target,
    required this.progress,
  });

  // Create a copy of this habit with modified properties
  Habit copyWith({
    String? id,
    String? name,
    int? target,
    int? progress,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      target: target ?? this.target,
      progress: progress ?? this.progress,
    );
  }

  // Convert Habit to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target': target,
      'progress': progress,
    };
  }

  // Create a Habit from a Map
  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      target: map['target'] ?? 0,
      progress: map['progress'] ?? 0,
    );
  }
}
