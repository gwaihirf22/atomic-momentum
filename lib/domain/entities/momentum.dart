import 'package:equatable/equatable.dart';

/// How strongly a habit is going: a 0–100 score that builds with practice and
/// fades gently with misses, plus its change over the last week.
class Momentum extends Equatable {
  /// 0–100.
  final double score;

  /// Points gained (positive) or lost (negative) compared with 7 days ago.
  final double trend;

  /// How formed the habit is, 0–1: the score steady practice would have
  /// reached by now (from the due periods that have ended). It weighs the
  /// habit in [overall].
  final double formed;

  const Momentum({required this.score, required this.trend, this.formed = 1});

  /// Overall momentum: the average of [scores], each weighed by how formed
  /// its habit is, so a habit just started barely moves it. Null when
  /// there's nothing to average.
  static Momentum? overall(Iterable<Momentum> scores) {
    if (scores.isEmpty) return null;
    final weight = scores.fold(0.0, (sum, m) => sum + m.formed);
    double average(double Function(Momentum m) of) => scores.fold(0.0, (sum, m) => sum + of(m) * m.formed) / weight;
    return Momentum(score: average((m) => m.score), trend: average((m) => m.trend), formed: 1);
  }

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
  List<Object?> get props => [score, trend, formed];

  @override
  String toString() => 'Momentum(${score.toStringAsFixed(1)}, trend ${trend.toStringAsFixed(1)})';
}

/// Momentum by name, so a number like 72 reads as something.
enum MomentumLevel {
  building('Building', 0),
  rolling('Rolling', 40),
  strong('Strong', 70),
  unstoppable('Unstoppable', 80),
  atomic('Atomic', 90);

  final String label;

  /// The lowest (rounded) score at this level.
  final int from;

  const MomentumLevel(this.label, this.from);

  static MomentumLevel of(double score) {
    final shown = score.round();
    return values.lastWhere((level) => shown >= level.from);
  }
}
