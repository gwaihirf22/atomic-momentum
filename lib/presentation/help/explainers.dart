import 'package:flutter/cupertino.dart';

/// Something the app explains with an (i): what it is, why it helps, how
/// to use it.
enum InfoTopic {
  twoMinute('About two-minute days'),
  momentum('About momentum');

  /// What the (i) button reads as to VoiceOver.
  final String buttonLabel;

  const InfoTopic(this.buttonLabel);
}

/// One point in an explainer: a short lead ("Why it works") and its text,
/// marked by a small [badge] (a number or a word) or an [icon].
class ExplainerPoint {
  final String? lead;
  final String text;
  final String? badge;
  final IconData? icon;

  const ExplainerPoint(this.text, {this.lead, this.badge, this.icon});
}

/// The words of one explainer sheet.
class Explainer {
  final String title;
  final String intro;
  final List<ExplainerPoint> points;

  /// Where the idea comes from, in small print.
  final String? source;

  const Explainer({required this.title, required this.intro, required this.points, this.source});

  static Explainer of(InfoTopic topic) => switch (topic) {
        InfoTopic.twoMinute => twoMinute,
        InfoTopic.momentum => momentum,
      };

  static const twoMinute = Explainer(
    title: 'Two-minute days',
    intro: "Some days you won't have it in you. On those days, do a version so small it takes two minutes "
        'or less, and the day still counts.',
    points: [
      ExplainerPoint(
        'A habit has to exist before it can grow. Showing up small keeps it alive, and getting started '
        'is often all it takes.',
        lead: 'Why it works',
        badge: '1',
      ),
      ExplainerPoint(
        'It keeps your streak going and never lowers your momentum. Full days are still how momentum climbs.',
        lead: 'What it does',
        badge: '2',
      ),
      ExplainerPoint(
        'Tap "2 min" when you\'ve done the small version, or log the minimum you set. Two-minute days are '
        'counted apart from full days.',
        lead: 'How',
        badge: '3',
      ),
    ],
    source: 'From the two-minute rule in Atomic Habits, by James Clear.',
  );

  static const momentum = Explainer(
    title: 'Momentum',
    intro: "How consistently you've been showing up lately, from 0 to 100. Recent days count most, so it rises "
        'as you keep going and dips gently when you miss.',
    points: [
      ExplainerPoint(
        'About 66 days of steady practice reaches 80, the average time it takes a habit to form. '
        'The mark on the ring shows it.',
        badge: '80',
      ),
      ExplainerPoint(
        'A missed day takes off a little. Rest days and two-minute days never lower it.',
        icon: CupertinoIcons.chevron_down,
      ),
      ExplainerPoint(
        "Coming back after a slump? It climbs fastest when it's low.",
        icon: CupertinoIcons.chevron_up,
      ),
      ExplainerPoint(
        'Each habit has its own. The ring on Habits is the average of all of them.',
        icon: CupertinoIcons.circle_grid_hex,
      ),
    ],
    source: 'Habit formation time: Lally et al., 2009.',
  );
}
