import 'package:flutter/material.dart';
import 'pages/connect_page.dart';
import 'pages/realtime_page.dart';
import 'pages/history_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [ConnectPage(), RealtimePage(), HistoryPage()];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1A1A1A),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.settings_bluetooth), label: '連線'),
          NavigationDestination(icon: Icon(Icons.speed), label: '即時監測'),
          NavigationDestination(icon: Icon(Icons.history), label: '歷史資料'),
        ],
      ),
    );
  }
}

