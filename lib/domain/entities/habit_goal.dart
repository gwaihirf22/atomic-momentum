/// What a habit is for: doing something more, or doing something less.
enum HabitGoal {
  /// Reach the target each period (the usual habit: "drink 8 glasses").
  build,

  /// Don't do it at all: any slip breaks the period ("stop smoking"). The
  /// target is 0.
  quit,

  /// Stay at or under the target each period ("no more than 2 drinks a day").
  limit;

  /// Quit or limit: doing nothing keeps the period, logging slips can break it.
  bool get isBreak => this != build;

  static HabitGoal fromJson(dynamic value) =>
      HabitGoal.values.where((goal) => goal.name == value).firstOrNull ?? HabitGoal.build;
}
