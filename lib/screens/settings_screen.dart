import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_palette.dart';
import '../core/branding/app_icons.dart';
import '../core/dev/dev_tools.dart';
import '../core/injection/injection_container.dart';
import '../core/services/app_icon_service.dart';
import '../core/services/sharer.dart';
import '../core/services/support_link.dart';
import '../core/services/web_pages.dart';
import '../core/services/notification_service.dart';
import '../domain/entities/habit_color.dart';
import '../presentation/tour/tour_controller.dart';
import '../domain/entities/habit_notify.dart';
import '../domain/entities/quiet_hours.dart';
import '../domain/entities/quote.dart';
import '../domain/entities/streak_warning_settings.dart';
import '../presentation/dev/tour_style_preview.dart';
import '../presentation/tour/world_scope.dart';
import '../presentation/dev/year_of_use_tiles.dart';
import '../presentation/providers/habit_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/inspire/quote_widgets.dart';
import '../presentation/widgets/adaptive.dart';
import '../presentation/widgets/large_title_scaffold.dart';
import '../presentation/widgets/freezes_settings_section.dart';
import '../presentation/widgets/health_settings_section.dart';
import '../presentation/widgets/sync_settings_section.dart';
import '../presentation/widgets/settings_list.dart';
import 'app_icon_screen.dart';
import 'tours_screen.dart';
import 'categories_screen.dart';
import 'notification_tester_screen.dart';
import 'how_to_screen.dart';
import '../presentation/layout/app_layout.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild when the appearance changes
    return LargeTitleScaffold(
      title: 'Settings',
      backgroundColor: AppPalette.of(context).background,
      header: const LargeTitleHeader(title: 'Settings', titleKey: Key('settingsTitle')),
      slivers: [_buildSettingsList(context)],
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final settings = context.watch<SettingsProvider>();
    final streakWarnings = settings.streakWarnings;
    final demo = WorldScope.isDemo(context);

    Future<void> resync() async {
      if (context.mounted) await context.read<HabitProvider>().resyncStreakWarnings();
    }

    final automaticWeekStart = 'Automatic (${_dayNames[settings.regionalFirstDay - 1]})';

    return SliverList.list(
      children: [
        if (!demo)
          SettingsSection(
            header: 'Help',
            children: [
              SettingsTile(
                tileKey: const Key('openHowTo'),
                icon: CupertinoIcons.book_fill,
                iconColor: HabitColor.teal.color,
                title: 'How to',
                subtitle: 'Every part of the app, in pictures',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HowToScreen())),
              ),
              SettingsTile(
                tileKey: const Key('openTours'),
                icon: CupertinoIcons.play_circle_fill,
                iconColor: HabitColor.orange.color,
                title: 'Tours',
                subtitle: 'Short guided looks at each part of the app',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ToursScreen())),
              ),
              const _ReplayToursTile(),
            ],
          ),
        SettingsSection(
          header: 'Display',
          footer: 'Habits greetings follow your day. Working nights? Set when you wake up.',
          children: [
            SettingsTile(
              tileKey: const Key('appearanceSetting'),
              icon: CupertinoIcons.circle_lefthalf_fill,
              iconColor: HabitColor.indigo.color,
              title: 'Appearance',
              value: _appearanceLabel(themeProvider.appearance),
              onTap: () async {
                final appearance = await chooseAdaptive<Appearance>(
                  context,
                  title: 'Appearance',
                  selected: themeProvider.appearance,
                  options: [
                    for (final appearance in Appearance.values)
                      AdaptiveOption(appearance, _appearanceLabel(appearance), key: Key('appearance_${appearance.name}')),
                  ],
                );
                if (appearance != null) await themeProvider.setAppearance(appearance);
              },
            ),
            // System is dark at night; this picks its daytime look
            if (themeProvider.appearance == Appearance.system)
              SettingsTile(
                tileKey: const Key('dayThemeSetting'),
                icon: CupertinoIcons.sun_max_fill,
                iconColor: HabitColor.amber.color,
                title: 'In light mode',
                value: _themeLabel(themeProvider.dayTheme),
                onTap: () async {
                  final theme = await chooseAdaptive<AppTheme>(
                    context,
                    title: 'In light mode',
                    selected: themeProvider.dayTheme,
                    options: [
                      for (final theme in ThemeProvider.dayThemes)
                        AdaptiveOption(theme, _themeLabel(theme), key: Key('dayTheme_${theme.name}')),
                    ],
                  );
                  if (theme != null) await themeProvider.setDayTheme(theme);
                },
              ),
            if (!demo && get<AppIconService>().isSupported) const _AppIconSetting(),
            SettingsSwitchTile(
              tileKey: const Key('introSwitch'),
              icon: CupertinoIcons.play_circle_fill,
              iconColor: HabitColor.deepPurple.color,
              title: 'Launch intro',
              subtitle: 'The Atomic Momentum animation when the app opens',
              value: settings.playIntro,
              onChanged: settings.setPlayIntro,
            ),
            SettingsTile(
              tileKey: const Key('dayStartSetting'),
              icon: CupertinoIcons.sunrise_fill,
              iconColor: HabitColor.orange.color,
              title: 'My day starts at',
              value: settings.dayStart.format(context),
              onTap: () async {
                final time = await pickTimeAdaptive(context, initial: settings.dayStart);
                if (time != null) await settings.setDayStart(time);
              },
            ),
          ],
        ),
        SettingsSection(
          header: 'Habits',
          footer: 'Adding and editing open in this style. Switch any time at the top of the page.',
          children: [
            SettingsTile(
              tileKey: const Key('addHabitStyleSetting'),
              icon: CupertinoIcons.wand_stars,
              iconColor: HabitColor.deepOrange.color,
              title: 'Habit editor',
              value: _styleLabel(settings.addHabitStyle),
              onTap: () async {
                final style = await chooseAdaptive<AddHabitStyle>(
                  context,
                  title: 'Open the habit editor in',
                  selected: settings.addHabitStyle,
                  options: [
                    for (final style in AddHabitStyle.values)
                      AdaptiveOption(
                        style,
                        _styleLabel(style),
                        subtitle: _styleDescription(style),
                        key: Key('addHabitStyle_${style.name}'),
                      ),
                  ],
                );
                if (style != null) await settings.setAddHabitStyle(style);
              },
            ),
            SettingsTile(
              tileKey: const Key('openCategories'),
              icon: CupertinoIcons.square_grid_2x2_fill,
              iconColor: HabitColor.orange.color,
              title: 'Arrange',
              subtitle: 'Categories, and the order of your habits',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Calendar',
          children: [
            SettingsTile(
              tileKey: const Key('weekStartSetting'),
              icon: CupertinoIcons.calendar,
              iconColor: HabitColor.red.color,
              title: 'Start week on',
              value:
                  settings.weekStartOverride == null ? automaticWeekStart : _dayNames[settings.weekStartOverride! - 1],
              onTap: () async {
                // 0 stands for Automatic (null can't mean both "cancelled" and "automatic")
                final day = await chooseAdaptive<int>(
                  context,
                  title: 'Start week on',
                  selected: settings.weekStartOverride ?? 0,
                  options: [
                    AdaptiveOption(0, automaticWeekStart, key: const Key('weekStart_auto')),
                    for (final day in const [DateTime.sunday, DateTime.monday, DateTime.saturday])
                      AdaptiveOption(day, _dayNames[day - 1], key: Key('weekStart_$day')),
                  ],
                );
                if (day == null || !context.mounted) return;
                await settings.setWeekStart(day == 0 ? null : day);
                // The week in review comes on the week's last day
                if (context.mounted) await context.read<HabitProvider>().resyncWeeklyReview();
              },
            ),
          ],
        ),
        SettingsSection(
          header: 'Notifications',
          footer: 'New habits remind you at the default time, with this sound. Change either for any habit '
              'when you edit it. Nothing arrives during quiet hours: late ones come just before, early ones after.',
          children: [
            SettingsTile(
              tileKey: const Key('defaultReminderTime'),
              icon: CupertinoIcons.alarm_fill,
              iconColor: HabitColor.green.color,
              title: 'Default time',
              value: settings.defaultReminderTime.format(context),
              onTap: () async {
                final time = await pickTimeAdaptive(context, initial: settings.defaultReminderTime);
                if (time == null || !context.mounted) return;
                await settings.setDefaultReminderTime(time);
                // Vacation notices come at this time too
                if (context.mounted) await context.read<HabitProvider>().resyncVacationNotices();
              },
            ),
            SettingsTile(
              tileKey: const Key('notifySoundSetting'),
              icon: CupertinoIcons.music_note_2,
              iconColor: HabitColor.pink.color,
              title: 'Sound',
              value: settings.notifySound.label,
              onTap: () async {
                final sound = await chooseAdaptive<NotifySound>(
                  context,
                  title: 'Sound',
                  selected: settings.notifySound,
                  options: [
                    for (final sound in NotifySound.values)
                      AdaptiveOption(sound, sound.label, key: Key('notifySound_${sound.name}')),
                  ],
                );
                if (sound == null) return;
                await settings.setNotifySound(sound);
                await NotificationService.preview(sound);
                await resync();
              },
            ),
            SettingsSwitchTile(
              tileKey: const Key('quietHoursSwitch'),
              icon: CupertinoIcons.moon_fill,
              iconColor: HabitColor.indigo.color,
              title: 'Quiet hours',
              subtitle: 'Nothing arrives overnight',
              value: settings.quietHours.enabled,
              onChanged: (value) async {
                final quiet = settings.quietHours;
                await settings.setQuietHours(QuietHours(enabled: value, start: quiet.start, end: quiet.end));
                await resync();
              },
            ),
            if (settings.quietHours.enabled) ...[
              for (final (key, title, isStart) in const [('quietStart', 'From', true), ('quietEnd', 'To', false)])
                SettingsTile(
                  tileKey: Key(key),
                  icon: isStart ? CupertinoIcons.moon : CupertinoIcons.sun_max,
                  iconColor: HabitColor.indigo.color,
                  title: title,
                  value: (isStart ? settings.quietHours.start : settings.quietHours.end).format(context),
                  onTap: () async {
                    final quiet = settings.quietHours;
                    final time = await pickTimeAdaptive(context, initial: isStart ? quiet.start : quiet.end);
                    if (time == null) return;
                    await settings.setQuietHours(QuietHours(
                      enabled: true,
                      start: isStart ? time : quiet.start,
                      end: isStart ? quiet.end : time,
                    ));
                    await resync();
                  },
                ),
            ],
            SettingsSwitchTile(
              tileKey: const Key('allowTimeSensitiveSwitch'),
              icon: CupertinoIcons.exclamationmark_circle_fill,
              iconColor: HabitColor.red.color,
              title: 'Time-sensitive alerts',
              subtitle: 'Let habits you mark come through Focus',
              value: settings.allowTimeSensitive,
              onChanged: (value) async {
                await settings.setAllowTimeSensitive(value);
                await resync();
              },
            ),
            SettingsSwitchTile(
              tileKey: const Key('weeklyReviewSwitch'),
              icon: CupertinoIcons.chart_bar_square_fill,
              iconColor: HabitColor.teal.color,
              title: 'Weekly review',
              subtitle: "Your week's wins, on its last evening",
              value: settings.weeklyReview,
              onChanged: (value) async {
                await settings.setWeeklyReview(value);
                if (context.mounted) await context.read<HabitProvider>().resyncWeeklyReview();
              },
            ),
            if (settings.weeklyReview)
              SettingsTile(
                tileKey: const Key('weeklyReviewTime'),
                icon: CupertinoIcons.clock_fill,
                iconColor: HabitColor.teal.color,
                title: 'Review time',
                value: settings.weeklyReviewTime.format(context),
                onTap: () async {
                  final time = await pickTimeAdaptive(context, initial: settings.weeklyReviewTime);
                  if (time == null || !context.mounted) return;
                  await settings.setWeeklyReview(true);
                  await settings.setWeeklyReviewTime(time);
                  if (context.mounted) await context.read<HabitProvider>().resyncWeeklyReview();
                },
              ),
          ],
        ),
        SettingsSection(
          header: 'Streaks',
          children: [
            SettingsSwitchTile(
              tileKey: const Key('streakWarningsSwitch'),
              icon: Icons.local_fire_department,
              iconColor: HabitColor.orange.color,
              title: 'Streak warnings',
              subtitle: 'Before a second miss would end it',
              value: streakWarnings.enabled,
              onChanged: (value) async {
                await settings.setStreakWarningsEnabled(value);
                await resync();
              },
            ),
            SettingsTile(
              tileKey: const Key('streakWarningLeadTime'),
              icon: CupertinoIcons.clock_fill,
              iconColor: HabitColor.blue.color,
              title: 'Warn me',
              value: _leadTimeLabel(streakWarnings.leadTime.inHours),
              enabled: streakWarnings.enabled,
              onTap: () async {
                final hours = await chooseAdaptive<int>(
                  context,
                  title: 'Warn me',
                  selected: streakWarnings.leadTime.inHours,
                  options: [
                    for (final hours in _leadTimeOptions(streakWarnings))
                      AdaptiveOption(hours, _leadTimeLabel(hours), key: Key('leadTime_$hours')),
                  ],
                );
                if (hours == null) return;
                await settings.setStreakWarningLeadTime(Duration(hours: hours));
                await resync();
              },
            ),
            SettingsSwitchTile(
              tileKey: const Key('streakWarningFirstMissSwitch'),
              icon: CupertinoIcons.bell_fill,
              iconColor: HabitColor.purple.color,
              title: 'Early nudge',
              subtitle: 'Remind before a first miss, too',
              value: streakWarnings.remindBeforeFirstMiss,
              onChanged: streakWarnings.enabled
                  ? (value) async {
                      await settings.setRemindBeforeFirstMiss(value);
                      await resync();
                    }
                  : null,
            ),
          ],
        ),
        const FreezesSettingsSection(),
        SettingsSection(
          header: 'Inspire',
          footer: 'A quote for each day, from the sources you choose and quotes you add.',
          children: [
            SettingsSwitchTile(
              tileKey: const Key('inspireTabSwitch'),
              icon: CupertinoIcons.quote_bubble_fill,
              iconColor: HabitColor.amber.color,
              title: 'Inspire tab',
              subtitle: 'A quote to start each day',
              value: settings.showInspireTab,
              onChanged: settings.setShowInspireTab,
            ),
            if (settings.showInspireTab)
              SettingsTile(
                tileKey: const Key('quoteSourcesSetting'),
                icon: CupertinoIcons.book_fill,
                iconColor: HabitColor.teal.color,
                title: 'Quote sources',
                value: '${settings.quoteFamilies.length} of ${QuoteFamily.values.length}',
                onTap: () => showQuoteSourcesSheet(context),
              ),
            SettingsTile(
              tileKey: const Key('quoteCreditsSetting'),
              icon: CupertinoIcons.info_circle_fill,
              iconColor: HabitColor.blueGrey.color,
              title: 'Sources & credits',
              onTap: () => showQuoteCreditsSheet(context),
            ),
          ],
        ),
        const HealthSettingsSection(),
        // Momentum Plus: only in builds with Developer tools until it's sold
        if (!demo) const SyncSettingsSection(),
        if (!demo) const _SupportSection(),
        if (!demo) const _AboutSection(),
        // Debug builds, and test builds made with DEV_TOOLS; never in a store build
        // Never over a tour's example habits: these act on the person's own data
        if (DevTools.enabled && !demo)
          SettingsSection(
            header: 'Developer',
            children: [
              SettingsTile(
                tileKey: const Key('addSampleHabits'),
                icon: CupertinoIcons.lab_flask_solid,
                iconColor: HabitColor.blueGrey.color,
                title: 'Add sample habits',
                subtitle: 'One per built-in category, with a few days of history',
                showChevron: false,
                onTap: () async {
                  final added = await context.read<HabitProvider>().addSampleHabits();
                  if (!context.mounted) return;
                  // Replace rather than queue behind a message from an earlier tap
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text(added == 0
                          ? 'Sample habits are already added'
                          : 'Added $added sample ${added == 1 ? 'habit' : 'habits'}'),
                    ));
                },
              ),
              ...yearOfUseTiles(context),
              SettingsTile(
                tileKey: const Key('openExampleWorld'),
                icon: CupertinoIcons.sparkles,
                iconColor: HabitColor.blueGrey.color,
                title: 'Open example world',
                subtitle: "The tours' example habits, in memory only. Tap Done at the top to leave",
                showChevron: false,
                onTap: () => context.read<WorldController>().enterDemo(),
              ),
              SettingsTile(
                tileKey: const Key('devPlayTour'),
                icon: CupertinoIcons.play_fill,
                iconColor: HabitColor.blueGrey.color,
                title: 'Play a tour',
                subtitle: 'Every tour, from the start (also in Help → Tours)',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ToursScreen())),
              ),
              SettingsTile(
                tileKey: const Key('tourStylePreview'),
                icon: CupertinoIcons.scope,
                iconColor: HabitColor.blueGrey.color,
                title: 'Tour style preview',
                subtitle: 'The tours\' spotlight and bubbles over the Habits screen',
                showChevron: false,
                onTap: () => TourStylePreview.show(context),
              ),
              SettingsTile(
                tileKey: const Key('openNotificationTester'),
                icon: CupertinoIcons.bell_fill,
                iconColor: HabitColor.blueGrey.color,
                title: 'Notification tester',
                subtitle: 'Check permission, send and schedule test notifications',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationTesterScreen()),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Keep a stored value selectable even if it is no longer one of the presets
  List<int> _leadTimeOptions(StreakWarningSettings current) {
    final options = {...StreakWarningSettings.leadTimeOptionsInHours, current.leadTime.inHours}.toList()..sort();
    return options;
  }

  static String _leadTimeLabel(int hours) =>
      hours == 24 ? '1 day before' : '$hours ${hours == 1 ? 'hour' : 'hours'} before';

  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String _appearanceLabel(Appearance appearance) => switch (appearance) {
        Appearance.system => 'System',
        Appearance.light => 'Light',
        Appearance.sepia => 'Sepia',
        Appearance.dark => 'Dark',
      };

  static String _styleLabel(AddHabitStyle style) => switch (style) {
        AddHabitStyle.builder => 'Builder',
        AddHabitStyle.story => 'Story',
      };

  static String _styleDescription(AddHabitStyle style) => switch (style) {
        AddHabitStyle.builder => 'Three quick steps',
        AddHabitStyle.story => 'Write it as one sentence',
      };

  static String _themeLabel(AppTheme theme) => switch (theme) {
        AppTheme.light => 'Light',
        AppTheme.sepia => 'Sepia',
        AppTheme.dark => 'Dark',
      };
}

/// Settings → App icon, showing the icon the phone has now.
class _AppIconSetting extends StatefulWidget {
  const _AppIconSetting();

  @override
  State<_AppIconSetting> createState() => _AppIconSettingState();
}

class _AppIconSettingState extends State<_AppIconSetting> {
  final _service = get<AppIconService>();
  AppIconChoice? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final icon = await _service.current();
    if (mounted) setState(() => _current = icon);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      tileKey: const Key('appIconSetting'),
      icon: CupertinoIcons.app_fill,
      iconColor: HabitColor.blue.color,
      title: 'App icon',
      value: _current?.label,
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AppIconScreen()));
        await _load();
      },
    );
  }
}

/// "Buy Paul a coffee": a personal tip for the developer, the only way to give
/// something, as the app is free. Shown only where it's allowed and once
/// there's a page (SupportLink).
class _SupportSection extends StatefulWidget {
  const _SupportSection();

  @override
  State<_SupportSection> createState() => _SupportSectionState();
}

class _SupportSectionState extends State<_SupportSection> {
  final _link = get<SupportLink>();
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _link.isAvailable().then((available) {
      if (mounted && available) setState(() => _available = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    return SettingsSection(
      header: 'Say thanks',
      footer: 'Momentum is free, with no ads. If you\'d like to say thanks, you can tip me there.',
      children: [
        SettingsTile(
          tileKey: const Key('buyMeACoffee'),
          icon: Icons.local_cafe_rounded,
          iconColor: HabitColor.brown.color,
          title: 'Buy Paul a coffee',
          subtitle: 'Opens buymeacoffee.com in your browser',
          onTap: () async {
            if (!await _link.open() && context.mounted) {
              await showAdaptiveAlert<void>(
                context,
                title: 'Couldn\'t open the page',
                message: 'Check your connection and try again.',
                actions: const [AdaptiveAction(label: 'OK', value: null, isDefault: true)],
              );
            }
          },
        ),
      ],
    );
  }
}

/// About: the privacy policy (App Review wants it reachable in the app,
/// not only in the listing) and the support page, opened in the browser.
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  static Future<void> _open(BuildContext context, String url) async {
    if (await get<WebPages>().open(url) || !context.mounted) return;
    await showAdaptiveAlert<void>(
      context,
      title: 'Couldn\'t open the page',
      message: 'Check your connection and try again. It\'s at $url',
      actions: const [AdaptiveAction(label: 'OK', value: null, isDefault: true)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      header: 'About',
      footer: 'Momentum collects nothing: no accounts, no ads, no tracking. Your habits stay on ${DeviceWords.thisDevice(context)}.\n\n'
          'Made by ${AppLinks.maker}. ${AppLinks.copyright}',
      children: [
        SettingsTile(
          tileKey: const Key('privacyPolicy'),
          icon: CupertinoIcons.lock_shield_fill,
          iconColor: HabitColor.green.color,
          title: 'Privacy policy',
          onTap: () => _open(context, AppLinks.privacy),
        ),
        SettingsTile(
          tileKey: const Key('contactSupport'),
          icon: CupertinoIcons.envelope_fill,
          iconColor: HabitColor.blue.color,
          title: 'Contact & support',
          subtitle: AppLinks.supportEmail,
          onTap: () => _open(context, AppLinks.support),
        ),
      ],
    );
  }
}

/// Help → "Replay tours": the next launch starts over, from the welcome, as
/// on a new phone (every tour comes back). Turns itself off once it has.
class _ReplayToursTile extends StatefulWidget {
  const _ReplayToursTile();

  @override
  State<_ReplayToursTile> createState() => _ReplayToursTileState();
}

class _ReplayToursTileState extends State<_ReplayToursTile> {
  @override
  Widget build(BuildContext context) {
    // The person's own, through the tours (none without them)
    final store = TourController.maybeOf(context)?.store;
    if (store == null) return const SizedBox.shrink();
    return SettingsSwitchTile(
      tileKey: const Key('replayTours'),
      icon: CupertinoIcons.arrow_counterclockwise_circle_fill,
      iconColor: HabitColor.orange.color,
      title: 'Replay tours',
      subtitle: 'From the welcome, the next time you open Momentum',
      value: store.replayNextLaunch,
      onChanged: (on) async {
        await store.setReplayNextLaunch(on);
        if (mounted) setState(() {});
      },
    );
  }
}
