import 'package:flutter/material.dart';

import '../../core/ui/app_widgets.dart';
import '../../core/saju/saju_stars.dart';

class SajuGuidePage extends StatelessWidget {
  const SajuGuidePage({super.key, this.chart});

  static const routeName = '/saju-guide';

  /// Optional: pass 4 pillars to show "present/absent" for a small subset we can calculate.
  final Map<String, String>? chart;

  @override
  Widget build(BuildContext context) {
    final chart = this.chart;
    return Scaffold(
      appBar: AppBar(title: const Text('사주 용어 가이드')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          const PageSection(
            title: '사주팔자(4주)',
            subtitle: '연/월/일/시 4기둥이 의미하는 것',
            child: _FourPillarsMeaningTable(),
          ),
          const SizedBox(height: 10),
          PageSection(
            title: '신살의 길신(吉神)',
            subtitle: '사주 해석에서 “도와주는 기운”으로 자주 설명됩니다.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StarGuideRow(
                  title: '천을귀인',
                  description: '도움과 지원의 흐름으로 설명되는 경우가 많습니다.',
                  status: _statusForCheonEul(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '월덕귀인',
                  description: '대인관계/인복, 정서적 안정과 연결해 풀이하는 경우가 있습니다.',
                  status: StarCalcStatus.todo,
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '천덕귀인',
                  description: '덕으로 풀리는 복, 큰 흐름에서 보호받는 느낌으로 설명되기도 합니다.',
                  status: StarCalcStatus.todo,
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '태극귀인',
                  description: '위기 회피/난관 돌파에 유리한 길신으로 소개되곤 합니다.',
                  status: StarCalcStatus.todo,
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '학당/문창귀인',
                  description: '학업/문서/표현력(글/말)과 연관된 길신으로 설명됩니다.',
                  status: _statusForMunChang(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '사관귀인',
                  description: '관직/직위/조직 내 역할과 연결해서 풀이하는 경우가 있습니다.',
                  status: StarCalcStatus.todo,
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '천록천마/록마교치/녹마동향',
                  description: '움직임(역마)과 성취(록)가 맞물릴 때의 흐름을 말합니다.',
                  status: StarCalcStatus.todo,
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '정인(본가인)',
                  description: '입신양명/품성 등으로 소개되는 신살입니다. (십신 정인과는 다르게 다루기도 합니다)',
                  status: StarCalcStatus.todo,
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '금여',
                  description: '재물/배우자 복과 연결해 설명되는 경우가 있습니다.',
                  status: StarCalcStatus.todo,
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '암록',
                  description: '예상하지 못한 도움/수입처럼 “숨은 복”으로 풀이되기도 합니다.',
                  status: StarCalcStatus.todo,
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '천의성',
                  description: '건강/치유/상담 등과 연결해서 해석하는 경우가 있습니다.',
                  status: StarCalcStatus.todo,
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '덕수',
                  description: '총명함/온화함 같은 기질로 풀이되는 경우가 있습니다.',
                  status: StarCalcStatus.todo,
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '삼기귀인',
                  description: '배움/재능/특별한 기회로 설명되는 경우가 있습니다.',
                  status: StarCalcStatus.todo,
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '괴성',
                  description: '시험/직위/관운과 연결해서 풀이되는 경우가 있습니다.',
                  status: StarCalcStatus.todo,
                ),
                const SizedBox(height: 12),
                Text(
                  '주의: 길신이 있다고 항상 “무조건 좋은 것”은 아니고, 전체 사주 맥락에 따라 해석이 달라질 수 있습니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static StarCalcStatus _statusForCheonEul(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final dayStem = SajuStars.stemOf(chart['day'] ?? '');
    if (dayStem == null) return StarCalcStatus.none;
    final targets = SajuStars.cheonEulTargets(dayStem);
    if (targets.isEmpty) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    final present = targets.any((t) => branches.contains(t));
    return present ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForMunChang(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final dayStem = SajuStars.stemOf(chart['day'] ?? '');
    if (dayStem == null) return StarCalcStatus.none;
    final target = SajuStars.munChangTarget(dayStem);
    if (target == null) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    final present = branches.contains(target);
    return present ? StarCalcStatus.present : StarCalcStatus.absent;
  }
}

enum StarCalcStatus { none, present, absent, todo }

class _StarGuideRow extends StatelessWidget {
  const _StarGuideRow({required this.title, required this.description, required this.status});

  final String title;
  final String description;
  final StarCalcStatus status;

  @override
  Widget build(BuildContext context) {
    final (badgeLabel, tone) = switch (status) {
      StarCalcStatus.present => ('있음', BadgeTone.success),
      StarCalcStatus.absent => ('없음', BadgeTone.neutral),
      StarCalcStatus.todo => ('준비 중', BadgeTone.warning),
      StarCalcStatus.none => ('-', BadgeTone.neutral),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  StatusBadge(label: badgeLabel, tone: tone),
                ],
              ),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _FourPillarsMeaningTable extends StatelessWidget {
  const _FourPillarsMeaningTable();

  TableRow _row(BuildContext context, {required String left, required String right, bool header = false}) {
    final style = header
        ? Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodySmall;

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Text(left, style: style),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Text(right, style: style),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD8E0DC)),
          color: Colors.white,
        ),
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(86),
            1: FlexColumnWidth(),
          },
          border: const TableBorder(
            horizontalInside: BorderSide(color: Color(0xFFD8E0DC)),
            verticalInside: BorderSide(color: Color(0xFFD8E0DC)),
          ),
          children: [
            _row(context, left: '구분', right: '의미', header: true),
            _row(context, left: '연주', right: '가문·조상·사회적 배경'),
            _row(context, left: '월주', right: '성장 환경·부모·직업 기질'),
            _row(context, left: '일주', right: '나 자신·성격·배우자'),
            _row(context, left: '시주', right: '말년운·자녀·잠재 능력'),
          ],
        ),
      ),
    );
  }
}

