import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/dev/year_of_use.dart';
import '../../core/injection/injection_container.dart';
import '../../domain/entities/habit_color.dart';
import '../providers/habit_provider.dart';
import '../providers/quote_provider.dart';
import '../widgets/adaptive.dart';
import '../widgets/settings_list.dart';

/// Settings → Developer (debug builds only): load a year of use in place of
/// the person's habits, and put theirs back.
List<Widget> yearOfUseTiles(BuildContext context) => [
      SettingsTile(
        tileKey: const Key('loadYearOfUse'),
        icon: CupertinoIcons.calendar,
        iconColor: HabitColor.blueGrey.color,
        title: 'Load a year of use',
        subtitle: 'Twelve habits with a year of history, ending today',
        showChevron: false,
        onTap: () => _load(context),
      ),
      SettingsTile(
        tileKey: const Key('restoreMyHabits'),
        icon: CupertinoIcons.arrow_uturn_left,
        iconColor: HabitColor.blueGrey.color,
        title: 'Put my habits back',
        subtitle: 'As they were before a year was loaded',
        showChevron: false,
        onTap: () => _restore(context),
      ),
    ];

Future<void> _load(BuildContext context) async {
  final confirmed = await confirmAdaptive(
    context,
    title: 'Load a year of use?',
    message: 'Replaces your habits with a year of sample use. Yours are kept, and "Put my habits back" restores them.',
    confirmLabel: 'Load',
    confirmKey: const Key('loadYearConfirm'),
  );
  if (!confirmed || !context.mounted) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  // A few seconds' work: say so, and keep taps out until it's done
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CupertinoActivityIndicator(radius: 14),
              SizedBox(height: 12),
              Text('Loading a year…', key: Key('loadingYear')),
            ]),
          ),
        ),
      ),
    ),
  );
  try {
    await YearOfUse.load(get<SharedPreferences>(), clock.now());
    if (context.mounted) await _reload(context);
  } finally {
    navigator.pop();
  }
  if (context.mounted) _say(context, 'Loaded a year of use');
}

Future<void> _restore(BuildContext context) async {
  final prefs = get<SharedPreferences>();
  if (!YearOfUse.hasBackup(prefs)) {
    _say(context, 'Nothing to put back: your own habits are in place');
    return;
  }
  await YearOfUse.restore(prefs);
  if (!context.mounted) return;
  await _reload(context);
  if (context.mounted) _say(context, 'Your habits are back');
}

/// Everything that read what was replaced reads it again.
Future<void> _reload(BuildContext context) async {
  final habits = context.read<HabitProvider>();
  final quotes = context.read<QuoteProvider>();
  await habits.loadHabits();
  await quotes.load();
}

void _say(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));
