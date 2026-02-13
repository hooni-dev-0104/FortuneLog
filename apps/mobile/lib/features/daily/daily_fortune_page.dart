import 'package:flutter/material.dart';

import '../../core/ui/app_widgets.dart';

class DailyFortunePage extends StatefulWidget {
  const DailyFortunePage({super.key});

  @override
  State<DailyFortunePage> createState() => _DailyFortunePageState();
}

class _DailyFortunePageState extends State<DailyFortunePage> {
  bool _loading = false;
  bool _hasData = true;
  String? _error;
  DateTime _updatedAt = DateTime.now();

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _loading = false;
      _hasData = true;
      _updatedAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        if (_error != null) ...[
          StatusNotice.error(message: _error!, requestId: 'daily-req-001'),
          const SizedBox(height: 10),
        ],
        if (!_hasData)
          EmptyState(
            title: '오늘 운세가 아직 없습니다',
            description: '오늘 기준 데이터가 없어 지금 바로 생성이 필요합니다.',
            actionText: '오늘 운세 생성',
            onAction: _refresh,
          )
        else ...[
          PageSection(
            title: '오늘 점수 74점',
            subtitle: '기준일: 2026-02-14 (Asia/Seoul)',
            trailing: FilledButton.tonal(onPressed: _refresh, child: const Text('새로고침')),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('총평: 중요한 결정은 오후로 미루고, 오전에는 실행 중심으로 정리하세요.'),
                const SizedBox(height: 8),
                Text(
                  '마지막 갱신: ${_updatedAt.year}-${_updatedAt.month.toString().padLeft(2, '0')}-${_updatedAt.day.toString().padLeft(2, '0')} ${_updatedAt.hour.toString().padLeft(2, '0')}:${_updatedAt.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const PageSection(
            title: '카테고리 점수',
            child: Column(
              children: [
                _CategoryScore(name: '연애', score: 68, summary: '감정 반응보다 사실 확인이 유리합니다.'),
                _CategoryScore(name: '일', score: 81, summary: '집중 구간을 오전에 배치하면 성과가 올라갑니다.'),
                _CategoryScore(name: '재물', score: 72, summary: '소액 반복 지출 점검이 효과적입니다.'),
                _CategoryScore(name: '건강', score: 69, summary: '수면 회복을 우선 순위로 두세요.'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const PageSection(
            title: '오늘 액션 3개',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. 핵심 의사결정은 오후 2시 이후로 미루기'),
                SizedBox(height: 6),
                Text('2. 오늘 지출 상한선을 오전에 설정하기'),
                SizedBox(height: 6),
                Text('3. 저녁 20분 산책으로 긴장도 낮추기'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryScore extends StatelessWidget {
  const _CategoryScore({required this.name, required this.score, required this.summary});

  final String name;
  final int score;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('$score점', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: score / 100),
          ),
          const SizedBox(height: 6),
          Text(summary, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
