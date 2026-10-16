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

  /// Changes smaller than a point aren't worth an arrow.
  bool get isRising => trend >= 1;
  bool get isFalling => trend <= -1;

  @override
  List<Object?> get props => [score, trend];

  @override
  String toString() => 'Momentum(${score.toStringAsFixed(1)}, trend ${trend.toStringAsFixed(1)})';
}
