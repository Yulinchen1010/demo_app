import 'package:flutter/material.dart';
import 'ui\/splash_page.dart';

void main() {
  runApp(const FatigueTreeApp());
}

class FatigueTreeApp extends StatelessWidget {
  const FatigueTreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00D1FF),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: '疲勞樹',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E141B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}


