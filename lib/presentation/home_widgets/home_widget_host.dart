import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/injection/injection_container.dart';
import '../../core/services/home_widget_bridge.dart';
import '../providers/category_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/quote_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import 'home_widget_sync.dart';

/// Runs [HomeWidgetSync] for as long as the app is up, with the providers
/// above it. Draws nothing of its own.
class HomeWidgetHost extends StatefulWidget {
  final Widget child;

  const HomeWidgetHost({super.key, required this.child});

  @override
  State<HomeWidgetHost> createState() => _HomeWidgetHostState();
}

class _HomeWidgetHostState extends State<HomeWidgetHost> {
  HomeWidgetSync? _sync;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tests that set up their own dependencies may leave the bridge out
    if (_sync != null || !sl.isRegistered<HomeWidgetBridge>()) return;
    _sync = HomeWidgetSync(
      bridge: get<HomeWidgetBridge>(),
      habits: context.read<HabitProvider>(),
      settings: context.read<SettingsProvider>(),
      theme: context.read<ThemeProvider>(),
      quotes: context.read<QuoteProvider>(),
      categories: context.read<CategoryProvider>(),
    )..start();
  }

  @override
  void dispose() {
    _sync?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
