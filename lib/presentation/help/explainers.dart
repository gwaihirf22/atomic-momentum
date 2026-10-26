import 'package:flutter/cupertino.dart';

/// Something the app explains with an (i): what it is, why it helps, how
/// to use it.
enum InfoTopic {
  twoMinute('About two-minute days'),
  momentum('About momentum'),
  inspire('About Inspire'),
  health('About filling in from Health'),
  freezes('About freezes'),
  sync('About sync');

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

  /// [android] names Health Connect where the iPhone has Apple Health.
  static Explainer of(InfoTopic topic, {bool android = false}) => switch (topic) {
        InfoTopic.twoMinute => twoMinute,
        InfoTopic.momentum => momentum,
        InfoTopic.inspire => inspire,
        InfoTopic.health => health(android: android),
        InfoTopic.freezes => freezes,
        InfoTopic.sync => sync(android: android),
      };

  /// Sync between the person's own devices (Momentum Plus): where it goes,
  /// that the developer never sees it, how two devices' days add up.
  static Explainer sync({bool android = false}) {
    final cloud = android ? 'Google Drive' : 'iCloud';
    final health = android ? 'Health Connect' : 'Apple Health';
    return Explainer(
      title: 'Sync with $cloud',
      intro: android
          ? 'Your habits on every Android phone and tablet signed in to the same Google account. Log on one, '
              'and it\'s on the other.'
          : 'Your habits on every iPhone and iPad signed in to the same Apple ID. Log on one, and it\'s on the other.',
      points: [
        ExplainerPoint(
          android
              ? 'To a hidden folder in your own Google Drive that only Momentum can open. I never see it: there\'s '
                  'no account and no server of mine.'
              : 'To your own iCloud. I never see it: there\'s no account and no server of mine.',
          lead: 'Where it goes',
          badge: '1',
        ),
        const ExplainerPoint(
          'Logged on two devices at once, even offline? Both count: the day adds up. Change a habit on both, and '
              'the later change wins.',
          lead: 'Both count',
          badge: '2',
        ),
        ExplainerPoint(
          'Habits, notes, freezes, categories, quotes and settings. $health numbers stay out of it: each device '
              'fills them in from its own.',
          lead: 'What syncs',
          badge: '3',
        ),
        ExplainerPoint(
          'Turning it off keeps everything on this device. You can also delete the copy in $cloud, for every device.',
          lead: 'Turning it off',
          badge: '4',
        ),
      ],
    );
  }

  static const freezes = Explainer(
    title: 'Freezes',
    intro: 'Life gets in the way, and that\'s okay. A freeze holds one habit exactly as it was for one day '
        '(or week, or month): neither kept nor missed.',
    points: [
      ExplainerPoint(
        'The streak doesn\'t grow or break, momentum stays put, and that day\'s reminders and warnings stop.',
        lead: 'What it does',
        badge: '1',
      ),
      ExplainerPoint(
        'Ahead (up to a month), on the day, or after a miss (up to a week back), from the habit\'s page. '
        'If you end up keeping that day anyway, the freeze comes back.',
        lead: 'When',
        badge: '2',
      ),
      ExplainerPoint(
        'You start with 3 and can hold 5. Every streak milestone and every habit formed earns one more.',
        lead: 'Earning them',
        badge: '3',
      ),
      ExplainerPoint(
        'Away for a while? Vacation mode (Settings) pauses every habit at once, without spending freezes.',
        lead: 'Longer breaks',
        badge: '4',
      ),
    ],
  );

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
        'Never miss twice: show up the next time after a miss and win back half of what it cost. '
        "After a slump, it climbs fastest when it's low.",
        icon: CupertinoIcons.chevron_up,
      ),
      ExplainerPoint(
        'Each habit has its own. The ring on Habits blends them, and a new habit counts more as it forms, '
        "so starting one won't drag it down.",
        icon: CupertinoIcons.circle_grid_hex,
      ),
    ],
    source: 'Habit formation time: Lally et al., 2009.',
  );

  /// Filling in from Apple Health (Health Connect on Android), named as
  /// such: App Review wants HealthKit use clearly identified (2.5.1).
  static Explainer health({bool android = false}) {
    final name = android ? 'Health Connect' : 'Apple Health';
    final allow = android ? 'Health Connect → App permissions' : 'the Health app → Sharing → Apps';
    return Explainer(
      title: 'From $name',
      intro: 'Link a habit to $name and it fills itself in: steps walked, exercise, sleep, '
          'mindful minutes or water. Only the habits you link, and only if you allow it.',
      points: [
        ExplainerPoint(
          'Steps, exercise minutes, workouts, sleep, ${android ? '' : 'mindful minutes '}and water, '
          'for the habits you link. Water${android ? '' : ' and mindful minutes'} you log can go back in.',
          lead: 'What it reads',
          icon: CupertinoIcons.heart,
        ),
        const ExplainerPoint(
          'Your health data stays on this phone. Momentum never sends it anywhere or shares it.',
          lead: 'Private',
          icon: CupertinoIcons.lock_shield,
        ),
        ExplainerPoint(
          "The higher of $name and what you log counts each day. You can't go below its number; "
          'change it there.',
          lead: 'Which wins',
          icon: CupertinoIcons.arrow_up_circle,
        ),
        const ExplainerPoint(
          'It checks when you open or return to the app, at midnight and with Sync now, filling in the past week.',
          lead: 'When',
          icon: CupertinoIcons.arrow_2_circlepath,
        ),
        const ExplainerPoint(
          'Pick the unit you count in (glasses, ml, fl oz, hours or minutes). Sleep counts on the morning you wake.',
          lead: 'Units',
          icon: CupertinoIcons.moon,
        ),
        ExplainerPoint(
          'Numbers staying at 0? Allow Momentum in $allow.',
          lead: 'Permissions',
          icon: CupertinoIcons.lock,
        ),
      ],
    );
  }

  static const inspire = Explainer(
    title: 'Inspire',
    intro: 'A few words to carry into your day, from thinkers and stories that have helped people keep going '
        'for centuries.',
    points: [
      ExplainerPoint(
        'The same quote all day, a new one at midnight. Every quote takes a turn before any comes back.',
        lead: 'Quote of the day',
        icon: CupertinoIcons.sun_max,
      ),
      ExplainerPoint(
        'Stoics, Christian writers, Puritans, Scripture, stories and thinkers. Turn any off in Settings or under ⋯.',
        lead: 'Sources',
        icon: CupertinoIcons.book,
      ),
      ExplainerPoint(
        'Search browses by source, theme or author, or finds the words you type. Filter to narrow it down.',
        lead: 'Find',
        icon: CupertinoIcons.search,
      ),
      ExplainerPoint(
        'Add quotes you love, even ones still under copyright: they stay on this phone. File each under a '
        'source and themes so filters find it.',
        lead: 'Your own',
        icon: CupertinoIcons.person,
      ),
      ExplainerPoint(
        'Keep a quote with a habit, and it shows on the habit\'s page for the days it\'s hard.',
        lead: 'With a habit',
        icon: CupertinoIcons.plus_circle,
      ),
    ],
    source: 'Scripture: New King James Version, © 1982 Thomas Nelson, used by permission. Other built-in quotes are '
        'public domain. See Sources & credits.',
  );
}
