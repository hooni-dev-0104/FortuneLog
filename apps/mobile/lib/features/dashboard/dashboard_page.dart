import 'package:flutter/material.dart';

import '../../core/ui/app_widgets.dart';
import '../report/report_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onTapDaily});

  final VoidCallback onTapDaily;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        const PageSection(
          title: '오늘의 요약 결론',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('실행력은 강하지만 과부하 관리가 핵심입니다.'),
              SizedBox(height: 6),
              Text('중요 의사결정은 오후에, 반복 업무는 오전에 배치하세요.'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const PageSection(
          title: '사주 4주',
          subtitle: '연/월/일/시 기준',
          child: Row(
            children: [
              _PillarCard(label: '연주', value: '갑자'),
              SizedBox(width: 8),
              _PillarCard(label: '월주', value: '을축'),
              SizedBox(width: 8),
              _PillarCard(label: '일주', value: '병인'),
              SizedBox(width: 8),
              _PillarCard(label: '시주', value: '정묘'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PageSection(
          title: '오행 분포',
          subtitle: '시각 요소와 수치를 함께 제공합니다.',
          child: Column(
            children: const [
              _ElementRow(name: '목', value: 2),
              _ElementRow(name: '화', value: 1),
              _ElementRow(name: '토', value: 1),
              _ElementRow(name: '금', value: 0),
              _ElementRow(name: '수', value: 2),
              SizedBox(height: 8),
              Text('수/목 기운이 상대적으로 강하므로 회복 루틴을 일정에 먼저 배치하세요.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.pushNamed(context, ReportPage.routeName),
          child: const Text('상세 리포트 보기'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onTapDaily,
          child: const Text('오늘 운세 보기'),
        ),
      ],
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD8E0DC)),
        ),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _ElementRow extends StatelessWidget {
  const _ElementRow({required this.name, required this.value});

  final String name;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 26, child: Text(name)),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: value / 4))),
          const SizedBox(width: 8),
          Text('$value', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
