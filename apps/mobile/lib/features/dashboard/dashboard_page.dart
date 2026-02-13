import 'package:flutter/material.dart';

import '../report/report_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('결과 대시보드')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              title: const Text('오늘의 핵심 요약'),
              subtitle: const Text('실행력은 강하지만 과부하 관리가 핵심입니다.'),
            ),
          ),
          const SizedBox(height: 12),
          const Text('사주 4주'),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PillarChip(label: '연주', value: '갑자'),
              _PillarChip(label: '월주', value: '을축'),
              _PillarChip(label: '일주', value: '병인'),
              _PillarChip(label: '시주', value: '정묘'),
            ],
          ),
          const SizedBox(height: 16),
          const Text('오행 분포'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: const [
                  _ElementBar(name: '목', value: 2),
                  _ElementBar(name: '화', value: 1),
                  _ElementBar(name: '토', value: 1),
                  _ElementBar(name: '금', value: 0),
                  _ElementBar(name: '수', value: 2),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, ReportPage.routeName),
            child: const Text('상세 리포트 보기'),
          ),
        ],
      ),
    );
  }
}

class _PillarChip extends StatelessWidget {
  final String label;
  final String value;

  const _PillarChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElementBar extends StatelessWidget {
  final String name;
  final int value;

  const _ElementBar({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text(name)),
          Expanded(
            child: LinearProgressIndicator(value: value / 4),
          ),
          const SizedBox(width: 8),
          Text('$value'),
        ],
      ),
    );
  }
}
