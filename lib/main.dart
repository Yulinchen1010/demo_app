import 'package:flutter/material.dart';
import 'ui/home.dart';

void main() {
  runApp(const FatigueTreeApp());
}

class FatigueTreeApp extends StatelessWidget {
  const FatigueTreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fatigue Tree',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const HomeScaffold(),
    );
  }
}

