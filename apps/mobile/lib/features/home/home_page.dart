import 'package:flutter/material.dart';

import '../daily/daily_fortune_page.dart';
import '../dashboard/dashboard_page.dart';
import '../mypage/my_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const routeName = '/home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final _pages = const [
    DashboardPage(),
    DailyFortunePage(),
    MyPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '대시보드'),
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), label: '오늘 운세'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '마이'),
        ],
      ),
    );
  }
}
