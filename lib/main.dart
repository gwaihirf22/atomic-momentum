import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/injection/injection_container.dart';
import 'core/theme/ios_theme.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/habit_provider.dart';
import 'presentation/providers/category_provider.dart';
import 'screens/ios_main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency injection
  await initializeDependencies();
  
  // Set preferred orientations and viewport settings to prevent unwanted zoom
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set specific system UI overlays and style
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MomentumApp());
}

class MomentumApp extends StatelessWidget {
  const MomentumApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => get<ThemeProvider>(),
        ),
        ChangeNotifierProvider<HabitProvider>(
          create: (_) => get<HabitProvider>(),
        ),
        ChangeNotifierProvider<CategoryProvider>(
          create: (_) => get<CategoryProvider>(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final isDark = themeProvider.themeMode == ThemeMode.dark ||
              (themeProvider.themeMode == ThemeMode.system &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark);
          
          return CupertinoApp(
            title: 'Atomic Momentum',
            debugShowCheckedModeBanner: false,
            theme: IOSTheme.getTheme(isDark ? Brightness.dark : Brightness.light),
            home: const IOSMainNavigation(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
          );
        },
      ),
    );
  }
}
