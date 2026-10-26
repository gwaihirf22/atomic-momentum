import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/injection/injection_container.dart';
import '../../core/services/freeze_bank.dart';
import '../../core/sync/sync_service.dart';
import '../providers/category_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/quote_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

/// Connects [SyncService] to the person's own providers (above the tours'
/// example world, which sync never sees), for as long as the app is up.
/// Draws nothing of its own.
class SyncHost extends StatefulWidget {
  final Widget child;

  const SyncHost({super.key, required this.child});

  @override
  State<SyncHost> createState() => _SyncHostState();
}

class _SyncHostState extends State<SyncHost> {
  bool _attached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tests that set up their own dependencies may leave sync out
    if (_attached || !sl.isRegistered<SyncService>()) return;
    _attached = true;
    get<SyncService>().attach(
      habits: context.read<HabitProvider>(),
      settings: context.read<SettingsProvider>(),
      theme: context.read<ThemeProvider>(),
      categories: context.read<CategoryProvider>(),
      quotes: context.read<QuoteProvider>(),
      bank: sl.isRegistered<FreezeBank>() ? get<FreezeBank>() : null,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
