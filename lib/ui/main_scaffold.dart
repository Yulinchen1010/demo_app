import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../nav/bottom_nav_controller.dart';
import 'pages/connect_page.dart';
import 'pages/history_page.dart';
import 'pages/live_monitor_page.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final idx = context.watch<BottomNavController>().index;
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: idx,
          children: const [
            ConnectPage(),
            LiveMonitorPage(),
            HistoryPage(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) => context.read<BottomNavController>().setIndex(i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_bluetooth),
            label: '\u9023\u7dda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.speed),
            label: '\u5373\u6642\u76e3\u6e2c',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '\u6b77\u53f2\u8cc7\u6599',
          ),
        ],
      ),
    );
  }
}
