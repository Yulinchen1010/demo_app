import 'package:flutter/material.dart';

import '../ui/main_scaffold.dart';
import '../ui/pages/connect_page.dart';
import '../ui/pages/history_page.dart';
import '../ui/pages/live_monitor_page.dart';
import '../ui/splash_page.dart';

class Routes {
  static const splash = '/';
  static const main = '/main';
  static const connect = '/connect';
  static const live = '/live';
  static const history = '/history';
}

class AppRouter {
  const AppRouter();

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.splash:
        return MaterialPageRoute(
          builder: (_) => const SplashPage(),
          settings: settings,
        );
      case Routes.main:
        return MaterialPageRoute(
          builder: (_) => const MainScaffold(),
          settings: settings,
        );
      case Routes.connect:
        return MaterialPageRoute(
          builder: (_) => const ConnectPage(),
          settings: settings,
        );
      case Routes.live:
        return MaterialPageRoute(
          builder: (_) => const LiveMonitorPage(),
          settings: settings,
        );
      case Routes.history:
        return MaterialPageRoute(
          builder: (_) => const HistoryPage(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const SplashPage(),
          settings: settings,
        );
    }
  }
}
