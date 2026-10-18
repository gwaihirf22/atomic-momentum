import 'package:equatable/equatable.dart';

/// How strongly a habit is going: a 0–100 score that builds with practice and
/// fades gently with misses, plus its change over the last week.
class Momentum extends Equatable {
  /// 0–100.
  final double score;

  /// Points gained (positive) or lost (negative) compared with 7 days ago.
  final double trend;

  const Momentum({required this.score, required this.trend});

  /// For habits that never reset, which have no periods to build momentum over.
  static const none = Momentum(score: 0, trend: 0);

  /// The score as shown to people.
  int get rounded => score.round();

  /// Where the score stands, by name ("Strong").
  MomentumLevel get level => MomentumLevel.of(score);

  /// The score at which a habit has, on average, formed: steady practice
  /// reaches it in about 66 days.
  static const habitFormed = 80;

  /// Changes smaller than a point aren't worth an arrow.
  bool get isRising => trend >= 1;
  bool get isFalling => trend <= -1;

  @override
  List<Object?> get props => [score, trend];

  @override
  String toString() => 'Momentum(${score.toStringAsFixed(1)}, trend ${trend.toStringAsFixed(1)})';
}

/// Momentum by name, so a number like 72 reads as something.
enum MomentumLevel {
  building('Building', 0),
  rolling('Rolling', 40),
  strong('Strong', 70),
  unstoppable('Unstoppable', 90);

  final String label;

  /// The lowest (rounded) score at this level.
  final int from;

  const MomentumLevel(this.label, this.from);

  static MomentumLevel of(double score) {
    final shown = score.round();
    return values.lastWhere((level) => shown >= level.from);
  }
}
