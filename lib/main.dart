import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/ble_connection_service.dart';
import 'data/telemetry_service.dart';
import 'data/history_repository.dart';
import 'nav/bottom_nav_controller.dart';
import 'router/app_router.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BottomNavController()),
        ChangeNotifierProvider(create: (_) => BleConnectionService()),
        ChangeNotifierProvider(create: (_) => TelemetryService()),
        Provider(create: (_) => HistoryRepository()),
      ],
      child: const FatigueTreeApp(),
    ),
  );
}

class FatigueTreeApp extends StatelessWidget {
  const FatigueTreeApp({super.key});

  static const AppRouter _router = AppRouter();

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00D1FF),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Fatigue Tree',
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
      initialRoute: Routes.splash,
      onGenerateRoute: _router.onGenerateRoute,
    );
  }
}

