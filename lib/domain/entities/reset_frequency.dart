enum ResetFrequency {
  daily("Daily", Duration(days: 1)),
  weekly("Weekly", Duration(days: 7)),
  monthly("Monthly", Duration(days: 30)),
  never("Never", null);

  const ResetFrequency(this.displayName, this.duration);

  final String displayName;
  final Duration? duration;

  static ResetFrequency fromString(String value) {
    return ResetFrequency.values.firstWhere(
      (frequency) => frequency.name == value,
      orElse: () => ResetFrequency.daily,
    );
  }

  bool shouldReset(DateTime lastResetDate, DateTime currentDate) {
    if (duration == null) return false;
    
    final timeSinceReset = currentDate.difference(lastResetDate);
    return timeSinceReset >= duration!;
  }

  DateTime getNextResetDate(DateTime currentDate) {
    if (duration == null) {
      throw StateError('Cannot calculate next reset date for never frequency');
    }
    
    return currentDate.add(duration!);
  }

  @override
  String toString() => name;
}