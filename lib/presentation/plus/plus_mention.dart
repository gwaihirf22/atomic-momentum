import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/injection/injection_container.dart';
import '../../core/services/plus_store.dart';
import '../../core/theme/app_palette.dart';
import '../../screens/plus_screen.dart';
import '../layout/app_layout.dart';
import '../tour/world_scope.dart';
import '../widgets/stat_card.dart';

/// The one gentle mention of Momentum Plus: at the end of a week in review,
/// "Using an iPad too?". Only on an iPhone, without Plus, from the second
/// week looked at, and once ever: never a nag.
class PlusMention extends StatefulWidget {
  /// The reviewed week's first day: weeks looked at are counted by it.
  final DateTime week;

  const PlusMention({super.key, required this.week});

  static const shownKey = 'plus_mention_v1';
  static const weeksKey = 'plus_mention_weeks_v1';

  /// Whether to show it now, recording [week] as looked at; once it's
  /// decided to show, it never shows again.
  static bool decide(SharedPreferences prefs, PlusStore? plus, DateTime week, {required bool tablet}) {
    final key = '${week.year}-${week.month}-${week.day}';
    final weeks = {...?prefs.getStringList(weeksKey)};
    if (weeks.length < 8 && weeks.add(key)) prefs.setStringList(weeksKey, weeks.toList()..sort());
    final show = plus != null &&
        plus.isSupported &&
        !plus.unlocked &&
        !tablet &&
        weeks.length >= 2 &&
        !prefs.containsKey(shownKey);
    if (show) prefs.setBool(shownKey, true);
    return show;
  }

  @override
  State<PlusMention> createState() => _PlusMentionState();
}

class _PlusMentionState extends State<PlusMention> {
  bool? _show;
  bool _dismissed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decided once, so marking it shown doesn't take it away while it's up;
    // never over the tours' example habits (it's the person's own once-ever)
    _show ??= !WorldScope.isDemo(context) &&
        sl.isRegistered<SharedPreferences>() &&
        PlusMention.decide(
          get<SharedPreferences>(),
          sl.isRegistered<PlusStore>() ? get<PlusStore>() : null,
          widget.week,
          tablet: AppLayout.isTablet(context),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_show != true || _dismissed) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: StatCard(
        key: const Key('plusMention'),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(CupertinoIcons.device_laptop, color: palette.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Using an iPad too?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: palette.text),
              ),
              const SizedBox(height: 4),
              Text(
                'Momentum Plus keeps them in sync.',
                style: TextStyle(fontSize: 15, height: 1.35, color: palette.textSecondary),
              ),
              const SizedBox(height: 10),
              PillButton(
                key: const Key('plusMentionOpen'),
                label: 'See Momentum Plus',
                icon: CupertinoIcons.chevron_right,
                onPressed: () => PlusScreen.open(context),
              ),
            ]),
          ),
          CupertinoButton(
            key: const Key('plusMentionClose'),
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            onPressed: () => setState(() => _dismissed = true),
            child: Icon(CupertinoIcons.xmark, size: 18, color: palette.textSecondary, semanticLabel: 'Not now'),
          ),
        ]),
      ),
    );
  }
}
