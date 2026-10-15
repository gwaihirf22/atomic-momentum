import 'package:equatable/equatable.dart';

/// User preference for being warned before a streak expires.
class StreakWarningSettings extends Equatable {
  final bool enabled;

  /// How long before the streak deadline the warning fires.
  final Duration leadTime;

  const StreakWarningSettings({
    required this.enabled,
    required this.leadTime,
  });

  static const defaults = StreakWarningSettings(
    enabled: true,
    leadTime: Duration(hours: 4),
  );

  /// Lead times offered in Settings, in hours.
  static const leadTimeOptionsInHours = [1, 2, 4, 8, 12, 24];

  StreakWarningSettings copyWith({bool? enabled, Duration? leadTime}) {
    return StreakWarningSettings(
      enabled: enabled ?? this.enabled,
      leadTime: leadTime ?? this.leadTime,
    );
  }

  @override
  List<Object?> get props => [enabled, leadTime];
}
