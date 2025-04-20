import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MomentumApp());
}

class MomentumApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atomic Momentum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
      ),
      themeMode: ThemeMode.system,
      home: HomeScreen(),
    );
  }
}
