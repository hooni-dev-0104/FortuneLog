import 'package:flutter/material.dart';

class DailyFortunePage extends StatelessWidget {
  const DailyFortunePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오늘 운세')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              title: const Text('2026-02-14 기준'),
              subtitle: const Text('오늘 점수 74점 · 중요한 결정은 오후로 미루세요.'),
              trailing: FilledButton.tonal(onPressed: () {}, child: const Text('새로고침')),
            ),
          ),
          const SizedBox(height: 12),
          const _CategoryTile(name: '연애', text: '대화의 온도를 낮추면 관계가 안정됩니다.'),
          const _CategoryTile(name: '일', text: '집중 시간대를 오전에 배치하세요.'),
          const _CategoryTile(name: '재물', text: '소액 반복 지출 점검이 유리합니다.'),
          const _CategoryTile(name: '건강', text: '수면 리듬을 우선 복구하세요.'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('오늘 액션 3개'),
                  SizedBox(height: 8),
                  Text('1. 중요한 결정은 오후로 미루기'),
                  Text('2. 오늘의 지출 상한 정하기'),
                  Text('3. 저녁 20분 산책'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String name;
  final String text;

  const _CategoryTile({required this.name, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(title: Text(name), subtitle: Text(text)),
    );
  }
}
