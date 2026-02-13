import 'package:flutter/material.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  static const routeName = '/report';

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String _tab = '성향';

  @override
  Widget build(BuildContext context) {
    final tabs = ['성향', '연애', '직업'];

    return Scaffold(
      appBar: AppBar(title: const Text('상세 리포트')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 8,
            children: tabs
                .map((e) => ChoiceChip(label: Text(e), selected: _tab == e, onSelected: (_) => setState(() => _tab = e)))
                .toList(),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_tab 요약', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('핵심 강점은 유지하되, 일정 과부하를 피하는 방향이 좋습니다.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _Section(title: '강점', items: ['빠른 판단', '높은 집중력']),
          const _Section(title: '주의', items: ['무리한 일정', '감정 과열']),
          const _Section(title: '행동 가이드', items: ['오늘 우선순위 1개 완료', '오후 30분 회복 시간 확보']),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> items;

  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [const Text('• '), Expanded(child: Text(e))]),
                )),
          ],
        ),
      ),
    );
  }
}
