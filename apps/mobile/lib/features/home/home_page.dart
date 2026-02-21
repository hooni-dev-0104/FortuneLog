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
  String? _selectedBirthProfileId;

  @override
  Widget build(BuildContext context) {
    final titles = const ['만세력', '오늘의 운세', '프리미엄 사주풀이', '내정보'];

    final pages = [
      DashboardPage(
        key: const ValueKey('tab-manseoryeok'),
        showMainSections: true,
        showDailySection: false,
        showAiSection: false,
        selectedBirthProfileId: _selectedBirthProfileId,
        onSelectedBirthProfileChanged: (id) {
          if (_selectedBirthProfileId == id) return;
          setState(() => _selectedBirthProfileId = id);
        },
      ),
      DashboardPage(
        key: const ValueKey('tab-daily'),
        showMainSections: false,
        showDailySection: true,
        showAiSection: false,
        selectedBirthProfileId: _selectedBirthProfileId,
        onSelectedBirthProfileChanged: (id) {
          if (_selectedBirthProfileId == id) return;
          setState(() => _selectedBirthProfileId = id);
        },
      ),
      DashboardPage(
        key: const ValueKey('tab-premium-ai'),
        showMainSections: false,
        showDailySection: false,
        showAiSection: true,
        selectedBirthProfileId: _selectedBirthProfileId,
        onSelectedBirthProfileChanged: (id) {
          if (_selectedBirthProfileId == id) return;
          setState(() => _selectedBirthProfileId = id);
        },
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
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: '만세력'),
          NavigationDestination(icon: Icon(Icons.today_outlined), label: '오늘 운세'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: '프리미엄'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '내정보'),
        ],
      ),
    );
  }
}
