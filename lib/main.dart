import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/injection/injection_container.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/habit_provider.dart';
import 'presentation/providers/category_provider.dart';
import 'screens/home_screen.dart';

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
          return MaterialApp(
            title: 'Atomic Momentum',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.deepPurple,
              brightness: Brightness.light,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              scaffoldBackgroundColor: Colors.white,
              cardColor: Colors.white,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primarySwatch: Colors.deepPurple,
              primaryColor: Colors.deepPurple,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              scaffoldBackgroundColor: Colors.grey[850],
              cardColor: const Color(0xFF2C2C2C),
              canvasColor: Colors.grey[850],
            ),
            themeMode: themeProvider.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
