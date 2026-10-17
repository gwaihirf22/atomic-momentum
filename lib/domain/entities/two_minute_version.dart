import 'package:equatable/equatable.dart';

/// A habit's tiny version for hard days ("Put on running shoes"), from
/// *Atomic Habits*: make it easy. Doing it keeps the streak and counts half
/// toward momentum (see StreakCalculator and MomentumCalculator).
class TwoMinuteVersion extends Equatable {
  static const maxLength = 40;

  final String description;

  /// An amount that counts as the two-minute version by itself, e.g. 1 of
  /// 8 glasses. Null when only the "2 min" button logs it.
  final int? minimum;

  /// Whether the habit card shows the "2 min" button.
  final bool showOnCard;

  const TwoMinuteVersion({required this.description, this.minimum, this.showOnCard = true});

  Map<String, dynamic> toJson() => {
        'description': description,
        if (minimum != null) 'minimum': minimum,
        'showOnCard': showOnCard,
      };

  factory TwoMinuteVersion.fromJson(Map<String, dynamic> json) => TwoMinuteVersion(
        description: json['description'] as String? ?? '',
        minimum: (json['minimum'] as num?)?.toInt(),
        showOnCard: json['showOnCard'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [description, minimum, showOnCard];
}

/// What the streak and momentum calculations need to know about two-minute
/// days: the days the button was used, and the amount that counts by itself.
class TwoMinuteLog {
  static const none = TwoMinuteLog();

  /// Momentum credit for a period kept with the two-minute version.
  static const credit = 0.5;

  final Set<DateTime> days;
  final int? minimum;

  const TwoMinuteLog({this.days = const {}, this.minimum});

  bool get isEmpty => days.isEmpty && minimum == null;
}
