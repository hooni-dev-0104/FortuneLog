import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final titles = const ['결과 대시보드', 'AI 사주 해석', '마이페이지'];

    final pages = [
      const DashboardPage(
        showMainSections: true,
        showDailySection: true,
        showAiSection: false,
      ),
      const DashboardPage(
        showMainSections: false,
        showDailySection: false,
        showAiSection: true,
      ),
      const MyPage(),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: SafeArea(
        top: false,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '대시보드'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'AI 해석'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '마이'),
        ],
      ),
    );
  }
}
