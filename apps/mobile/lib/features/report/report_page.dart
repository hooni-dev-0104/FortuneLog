import 'package:flutter/material.dart';

import '../../core/ui/app_widgets.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  static const routeName = '/report';

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _regenerate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('상세 리포트'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '성향'),
            Tab(text: '연애'),
            Tab(text: '직업'),
          ],
        ),
      ),
      body: _loading
          ? const _ReportSkeleton()
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: StatusNotice.error(message: _error!, requestId: 'report-req-001'),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [
                      _ReportTab(
                        summary: '핵심 에너지는 추진력과 몰입에 강점이 있으나, 과도한 자기압박이 발생하기 쉽습니다.',
                        strengths: '강점: 목표 집중력, 실행 속도, 변동성 대응력',
                        caution: '주의: 과한 완벽주의로 인한 피로 누적',
                        actions: [
                          '중요 목표는 2개 이하로 제한하기',
                          '하루 마감 15분 회고로 과부하 정리하기',
                          '주 1회 일정 비우는 회복 슬롯 고정하기',
                        ],
                      ),
                      _ReportTab(
                        summary: '관계에서는 감정 표현보다 맥락 설명이 효과적이며, 즉흥 반응을 줄일수록 안정적입니다.',
                        strengths: '강점: 배려 중심의 관계 유지, 문제 해결 지향 대화',
                        caution: '주의: 감정 누적 후 급격한 거리두기',
                        actions: [
                          '감정 표현 전 사실-요청 구조로 문장화하기',
                          '갈등 시 30분 후 대화 규칙 세우기',
                          '주간 체크인 루틴으로 기대치 정렬하기',
                        ],
                      ),
                      _ReportTab(
                        summary: '업무에서는 빠른 실행이 장점이지만, 우선순위 정렬 없이 확장하면 효율이 떨어집니다.',
                        strengths: '강점: 초기 세팅 속도, 책임감, 마감 대응력',
                        caution: '주의: 동시다발 과제 수용으로 인한 품질 저하',
                        actions: [
                          '주간 Top3 우선순위 선언 후 공유하기',
                          '회의 전 의사결정 항목 미리 정의하기',
                          '집중 블록(90분)과 소통 블록 분리하기',
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child: FilledButton.icon(
          onPressed: _regenerate,
          icon: const Icon(Icons.refresh),
          label: const Text('리포트 재생성'),
        ),
      ),
    );
  }
}

class _ReportTab extends StatelessWidget {
  const _ReportTab({
    required this.summary,
    required this.strengths,
    required this.caution,
    required this.actions,
  });

  final String summary;
  final String strengths;
  final String caution;
  final List<String> actions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
      children: [
        PageSection(
          title: '요약',
          child: Text(summary, style: Theme.of(context).textTheme.bodyLarge),
        ),
        const SizedBox(height: 10),
        PageSection(
          title: '강점',
          child: Text(strengths, style: Theme.of(context).textTheme.bodyLarge),
        ),
        const SizedBox(height: 10),
        PageSection(
          title: '주의 포인트',
          child: Text(caution, style: Theme.of(context).textTheme.bodyLarge),
        ),
        const SizedBox(height: 10),
        PageSection(
          title: '행동 가이드',
          subtitle: '즉시 실행 가능한 체크리스트',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: actions
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.check_circle_outline, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: const [
        _SkeletonBox(height: 120),
        SizedBox(height: 10),
        _SkeletonBox(height: 90),
        SizedBox(height: 10),
        _SkeletonBox(height: 90),
        SizedBox(height: 10),
        _SkeletonBox(height: 140),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECEA),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
