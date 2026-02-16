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
                  status: _statusForWolDeok(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '천덕귀인',
                  description: '덕으로 풀리는 복, 큰 흐름에서 보호받는 느낌으로 설명되기도 합니다.',
                  status: _statusForCheonDeok(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '태극귀인',
                  description: '위기 회피/난관 돌파에 유리한 길신으로 소개되곤 합니다.',
                  status: _statusForTaeGeuk(chart),
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
                  status: _statusForGwanGwiHakGwan(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '천록천마/록마교치/녹마동향',
                  description: '움직임(역마)과 성취(록)가 맞물릴 때의 흐름을 말합니다.',
                  status: _statusForRokMa(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '정인(본가인)',
                  description: '입신양명/품성 등으로 소개되는 신살입니다. (현재는 “십신 정인” 기준으로만 참고 계산됩니다)',
                  status: _statusForJeongIn(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '금여',
                  description: '재물/배우자 복과 연결해 설명되는 경우가 있습니다.',
                  status: _statusForGeumYeo(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '암록',
                  description: '예상하지 못한 도움/수입처럼 “숨은 복”으로 풀이되기도 합니다.',
                  status: _statusForAmRok(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '천의성',
                  description: '건강/치유/상담 등과 연결해서 해석하는 경우가 있습니다.',
                  status: _statusForCheonEui(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '덕수',
                  description: '총명함/온화함 같은 기질로 풀이되는 경우가 있습니다.',
                  status: _statusForDeokSu(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '삼기귀인',
                  description: '배움/재능/특별한 기회로 설명되는 경우가 있습니다.',
                  status: _statusForSamGi(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '괴성',
                  description: '시험/직위/관운과 연결해서 풀이되는 경우가 있습니다.',
                  status: _statusForGoeSeong(chart),
                ),
                const SizedBox(height: 12),
                Text(
                  '주의: 길신이 있다고 항상 “무조건 좋은 것”은 아니고, 전체 사주 맥락에 따라 해석이 달라질 수 있습니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          PageSection(
            title: '신살의 흉살(凶煞)',
            subtitle: '사주 해석에서 “주의가 필요한 기운”으로 자주 설명됩니다.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StarGuideRow(
                  title: '양인살',
                  description: '강한 추진력/에너지로 소개되며, 과열과 충돌에 주의하라고 풀이되기도 합니다.',
                  status: _statusForYangIn(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '백호살',
                  description: '큰 변화/사고수로 연결해 풀이되는 경우가 있어, 생활 리스크 관리로 해석하기도 합니다.',
                  status: _statusForBaekHo(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '괴강살',
                  description: '기질이 강하게 드러나는 날주로 소개되며, 장단이 뚜렷하다고 풀이되기도 합니다.',
                  status: _statusForGueGang(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '홍염살',
                  description: '매력/호감/관계 이슈와 연결해 해석하는 경우가 있습니다.',
                  status: _statusForHongYeom(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '고진살',
                  description: '고독/고립감으로 연결해 풀이하는 경우가 있습니다.',
                  status: _statusForGoJin(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '과숙살',
                  description: '관계의 단절감/혼자 감당하는 기운으로 풀이되는 경우가 있습니다.',
                  status: _statusForGwaSuk(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '격각살',
                  description: '부딪힘/충돌로 풀이되기도 하며, 안전·규칙을 강조하는 해석이 있습니다.',
                  status: _statusForGyeokGak(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '암금적살',
                  description: '대외적으로 드러나지 않는 갈등/손실로 해석하는 경우가 있습니다.',
                  status: StarCalcStatus.none,
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '귀문관살',
                  description: '예민함/몰입으로 풀이되기도 하며, 마음 관리가 중요하다고 해석하기도 합니다.',
                  status: _statusForGwiMun(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '급각살',
                  description: '급작스러운 변수로 해석하는 경우가 있습니다.',
                  status: _statusForGeupGak(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '단교관살',
                  description: '관계의 단절/끊김으로 풀이되는 경우가 있습니다.',
                  status: _statusForDanGyoGwan(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '곡각살',
                  description: '말/상처/굴곡으로 연결해 풀이하는 경우가 있습니다.',
                  status: _statusForGokGak(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '천라지망',
                  description: '답답함/제약으로 풀이되기도 하며, 장기적으로 정리/정돈이 필요하다고 해석하기도 합니다.',
                  status: _statusForCheonRaJiMang(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '대모살',
                  description: '가족/양육/돌봄 이슈와 연결해 풀이되는 경우가 있습니다.',
                  status: _statusForDaeMo(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '구교살',
                  description: '구설/오해로 연결해 풀이하는 경우가 있습니다.',
                  status: _statusForGuGyo(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '십악대패',
                  description: '흐름이 거칠어지기 쉬운 날주로 소개되며, 리스크 관리가 중요하다고 풀이되기도 합니다.',
                  status: _statusForSipAkDaePae(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '고란과곡살',
                  description: '외로움/고립으로 풀이되기도 하며, 관계의 균형을 강조하기도 합니다.',
                  status: _statusForGoRanGwaGok(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '평두살',
                  description: '막힘/꺾임으로 풀이되는 경우가 있습니다.',
                  status: _statusForPyeongDu(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '현침살',
                  description: '표현이 날카롭게 비칠 수 있다고 풀이되기도 하며, 정밀함이 강점이 되기도 합니다.',
                  status: _statusForHyeonChim(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '장형살',
                  description: '벌/형벌/규정과 연결해 풀이되는 경우가 있어, 규칙 준수를 강조하기도 합니다.',
                  status: _statusForJangHyeong(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '상문살',
                  description: '상실/이별로 풀이되는 경우가 있어, 마음 관리를 권하기도 합니다.',
                  status: _statusForSangMun(chart),
                ),
                const SizedBox(height: 10),
                _StarGuideRow(
                  title: '조객살',
                  description: '외부 방문/변동 이슈로 풀이되기도 합니다.',
                  status: _statusForJoGaek(chart),
                ),
                const SizedBox(height: 12),
                Text(
                  '주의: 흉살이 있어도 “무조건 나쁜 일”이 생긴다는 뜻은 아니고, 전체 사주 맥락에 따라 해석이 달라질 수 있습니다.',
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

  static StarCalcStatus _statusForYangIn(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final dayStem = SajuStars.stemOf(chart['day'] ?? '');
    if (dayStem == null) return StarCalcStatus.none;
    final target = SajuStars.yangInTarget(dayStem);
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

  static StarCalcStatus _statusForGueGang(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final day = chart['day'] ?? '';
    if (day.trim().length < 2) return StarCalcStatus.none;
    return SajuStars.isGueGangDayPillar(day) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForSipAkDaePae(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final day = chart['day'] ?? '';
    if (day.trim().length < 2) return StarCalcStatus.none;
    return SajuStars.isSipAkDaePaeDayPillar(day) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForHyeonChim(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final pillars = <String>[
      chart['year'] ?? '',
      chart['month'] ?? '',
      chart['day'] ?? '',
      chart['hour'] ?? '',
    ];
    final c = SajuStars.hyeonChimCount(pillars);
    // In many references, it is treated as "present" when 2+ relevant elements exist.
    return c >= 2 ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForWolDeok(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final monthBranch = SajuStars.branchOf(chart['month'] ?? '');
    if (monthBranch == null) return StarCalcStatus.none;
    final targetStem = SajuStars.wolDeokStemByMonthBranch(monthBranch);
    if (targetStem == null) return StarCalcStatus.none;
    final stems = [
      SajuStars.stemOf(chart['year'] ?? ''),
      SajuStars.stemOf(chart['month'] ?? ''),
      SajuStars.stemOf(chart['day'] ?? ''),
      SajuStars.stemOf(chart['hour'] ?? ''),
    ].whereType<String>();
    return stems.contains(targetStem) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForCheonDeok(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final monthBranch = SajuStars.branchOf(chart['month'] ?? '');
    if (monthBranch == null) return StarCalcStatus.none;
    final targetStem = SajuStars.cheonDeokStemByMonthBranch(monthBranch);
    if (targetStem == null) return StarCalcStatus.none;
    final stems = [
      SajuStars.stemOf(chart['year'] ?? ''),
      SajuStars.stemOf(chart['month'] ?? ''),
      SajuStars.stemOf(chart['day'] ?? ''),
      SajuStars.stemOf(chart['hour'] ?? ''),
    ].whereType<String>();
    return stems.contains(targetStem) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForTaeGeuk(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final dayStem = SajuStars.stemOf(chart['day'] ?? '');
    if (dayStem == null) return StarCalcStatus.none;
    final targets = SajuStars.taeGeukTargets(dayStem);
    if (targets.isEmpty) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    return targets.any(branches.contains) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForGwanGwiHakGwan(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final dayStem = SajuStars.stemOf(chart['day'] ?? '');
    if (dayStem == null) return StarCalcStatus.none;
    final target = SajuStars.gwanGwiHakGwanTarget(dayStem);
    if (target == null) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    return branches.contains(target) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForGeumYeo(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final dayStem = SajuStars.stemOf(chart['day'] ?? '');
    if (dayStem == null) return StarCalcStatus.none;
    final target = SajuStars.geumYeoTarget(dayStem);
    if (target == null) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    return branches.contains(target) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForAmRok(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final dayStem = SajuStars.stemOf(chart['day'] ?? '');
    if (dayStem == null) return StarCalcStatus.none;
    final target = SajuStars.amRokTarget(dayStem);
    if (target == null) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    return branches.contains(target) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForCheonEui(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final monthBranch = SajuStars.branchOf(chart['month'] ?? '');
    if (monthBranch == null) return StarCalcStatus.none;
    final target = SajuStars.cheonEuiTargetByMonthBranch(monthBranch);
    if (target == null) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    return branches.contains(target) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForSamGi(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final pillars = <String>[
      chart['year'] ?? '',
      chart['month'] ?? '',
      chart['day'] ?? '',
      chart['hour'] ?? '',
    ];
    return SajuStars.hasSamGi(pillars) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForRokMa(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final dayStem = SajuStars.stemOf(chart['day'] ?? '');
    if (dayStem == null) return StarCalcStatus.none;
    final geonRok = SajuStars.geonRokBranch(dayStem);
    final yearBranch = SajuStars.branchOf(chart['year'] ?? '');
    final dayBranch = SajuStars.branchOf(chart['day'] ?? '');
    final yeokMa = SajuStars.yeokMaTarget(yearBranch: yearBranch, dayBranch: dayBranch);
    if (geonRok == null || yeokMa == null) return StarCalcStatus.none;

    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    final hasRok = branches.contains(geonRok);
    final hasMa = branches.contains(yeokMa);
    return (hasRok && hasMa) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForHongYeom(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final dayStem = SajuStars.stemOf(chart['day'] ?? '');
    if (dayStem == null) return StarCalcStatus.none;
    final target = SajuStars.hongYeomTarget(dayStem);
    if (target == null) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    return branches.contains(target) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForBaekHo(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final pillars = <String>[
      chart['year'] ?? '',
      chart['month'] ?? '',
      chart['day'] ?? '',
      chart['hour'] ?? '',
    ];
    final present = pillars.any(SajuStars.isBaekHoPillar);
    return present ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForGoJin(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final yearBranch = SajuStars.branchOf(chart['year'] ?? '');
    final dayBranch = SajuStars.branchOf(chart['day'] ?? '');
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>().toList(growable: false);
    final t1 = yearBranch == null ? null : SajuStars.goJinTargetByBaseBranch(yearBranch);
    final t2 = dayBranch == null ? null : SajuStars.goJinTargetByBaseBranch(dayBranch);
    final present = (t1 != null && branches.contains(t1)) || (t2 != null && branches.contains(t2));
    return present ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForGwaSuk(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final yearBranch = SajuStars.branchOf(chart['year'] ?? '');
    final dayBranch = SajuStars.branchOf(chart['day'] ?? '');
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>().toList(growable: false);
    final t1 = yearBranch == null ? null : SajuStars.gwaSukTargetByBaseBranch(yearBranch);
    final t2 = dayBranch == null ? null : SajuStars.gwaSukTargetByBaseBranch(dayBranch);
    final present = (t1 != null && branches.contains(t1)) || (t2 != null && branches.contains(t2));
    return present ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForGyeokGak(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final yearBranch = SajuStars.branchOf(chart['year'] ?? '');
    final dayBranch = SajuStars.branchOf(chart['day'] ?? '');
    return SajuStars.isGyeokGak(yearBranch: yearBranch, dayBranch: dayBranch) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForGwiMun(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final monthBranch = SajuStars.branchOf(chart['month'] ?? '');
    final dayBranch = SajuStars.branchOf(chart['day'] ?? '');
    final hourBranch = SajuStars.branchOf(chart['hour'] ?? '');
    final present = SajuStars.hasGwiMunGwanSal(monthBranch: monthBranch, dayBranch: dayBranch, hourBranch: hourBranch);
    return present ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForGeupGak(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final monthBranch = SajuStars.branchOf(chart['month'] ?? '');
    if (monthBranch == null) return StarCalcStatus.none;
    final targets = SajuStars.geupGakTargetsByMonthBranch(monthBranch);
    if (targets.isEmpty) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    final present = targets.any(branches.contains);
    return present ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForDanGyoGwan(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final monthBranch = SajuStars.branchOf(chart['month'] ?? '');
    if (monthBranch == null) return StarCalcStatus.none;
    final target = SajuStars.danGyoGwanTargetByMonthBranch(monthBranch);
    if (target == null) return StarCalcStatus.none;
    final dayBranch = SajuStars.branchOf(chart['day'] ?? '');
    final hourBranch = SajuStars.branchOf(chart['hour'] ?? '');
    final present = dayBranch == target || hourBranch == target;
    return present ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForGokGak(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final pillars = <String>[
      chart['year'] ?? '',
      chart['month'] ?? '',
      chart['day'] ?? '',
      chart['hour'] ?? '',
    ];
    final present = pillars.any(SajuStars.isGokGakPillar);
    return present ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForCheonRaJiMang(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final dayBranch = SajuStars.branchOf(chart['day'] ?? '');
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>().toList(growable: false);
    final t = SajuStars.cheonRaJiMangType(dayBranch: dayBranch, allBranches: branches);
    return t != null ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForDaeMo(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final yearBranch = SajuStars.branchOf(chart['year'] ?? '');
    if (yearBranch == null) return StarCalcStatus.none;
    final target = SajuStars.daeMoTargetByYearBranch(yearBranch);
    if (target == null) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    return branches.contains(target) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForGuGyo(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final day = chart['day'] ?? '';
    if (day.trim().length < 2) return StarCalcStatus.none;
    return SajuStars.isGuGyoDayPillar(day) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForGoRanGwaGok(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    // 현재는 "고란살" 기준(일주 5종)만 표시합니다.
    final day = chart['day'] ?? '';
    if (day.trim().length < 2) return StarCalcStatus.none;
    const goran = {'갑인', '을사', '정사', '무신', '신해'};
    return goran.contains(day.trim()) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForPyeongDu(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final pillars = <String>[
      chart['year'] ?? '',
      chart['month'] ?? '',
      chart['day'] ?? '',
      chart['hour'] ?? '',
    ];
    final c = SajuStars.pyeongDuCount(pillars);
    return c >= 4 ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForJangHyeong(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>().toList(growable: false);
    return SajuStars.hasJangHyeongSal(branches) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForSangMun(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final yearBranch = SajuStars.branchOf(chart['year'] ?? '');
    if (yearBranch == null) return StarCalcStatus.none;
    final target = SajuStars.sangMunTargetByYearBranch(yearBranch);
    if (target == null) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    return branches.contains(target) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForJoGaek(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final yearBranch = SajuStars.branchOf(chart['year'] ?? '');
    if (yearBranch == null) return StarCalcStatus.none;
    final target = SajuStars.joGaekTargetByYearBranch(yearBranch);
    if (target == null) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>();
    return branches.contains(target) ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForJeongIn(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    final dayStem = SajuStars.stemOf(chart['day'] ?? '');
    if (dayStem == null) return StarCalcStatus.none;
    final targetStem = SajuStars.jeongInStemForDayStem(dayStem);
    if (targetStem == null) return StarCalcStatus.none;
    final stems = [
      SajuStars.stemOf(chart['year'] ?? ''),
      SajuStars.stemOf(chart['month'] ?? ''),
      SajuStars.stemOf(chart['day'] ?? ''),
      SajuStars.stemOf(chart['hour'] ?? ''),
    ].whereType<String>();
    final present = stems.contains(targetStem);
    return present ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForDeokSu(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    // 실무적으로는 '덕(천덕/월덕)' + '수(정인)' 흐름으로 참고하는 경우가 있어, 보수적으로 조합 체크만 합니다.
    final monthBranch = SajuStars.branchOf(chart['month'] ?? '');
    if (monthBranch == null) return StarCalcStatus.none;
    final wd = SajuStars.wolDeokStemByMonthBranch(monthBranch);
    final cd = SajuStars.cheonDeokStemByMonthBranch(monthBranch);
    final stems = [
      SajuStars.stemOf(chart['year'] ?? ''),
      SajuStars.stemOf(chart['month'] ?? ''),
      SajuStars.stemOf(chart['day'] ?? ''),
      SajuStars.stemOf(chart['hour'] ?? ''),
    ].whereType<String>().toList(growable: false);
    final hasDeok = (wd != null && stems.contains(wd)) || (cd != null && stems.contains(cd));
    if (!hasDeok) return StarCalcStatus.absent;
    return _statusForJeongIn(chart) == StarCalcStatus.present ? StarCalcStatus.present : StarCalcStatus.absent;
  }

  static StarCalcStatus _statusForGoeSeong(Map<String, String>? chart) {
    if (chart == null) return StarCalcStatus.none;
    // 괴성은 시험/직위 해석으로 문창/학당/사관 계열과 함께 언급되는 경우가 많아,
    // 현재 UI에서는 해당 길신 중 하나라도 있으면 참고 '있음'으로 표시합니다.
    final dayStem = SajuStars.stemOf(chart['day'] ?? '');
    if (dayStem == null) return StarCalcStatus.none;
    final branches = [
      SajuStars.branchOf(chart['year'] ?? ''),
      SajuStars.branchOf(chart['month'] ?? ''),
      SajuStars.branchOf(chart['day'] ?? ''),
      SajuStars.branchOf(chart['hour'] ?? ''),
    ].whereType<String>().toList(growable: false);
    final mc = SajuStars.munChangTarget(dayStem);
    final hd = SajuStars.hakDangTarget(dayStem);
    final gg = SajuStars.gwanGwiHakGwanTarget(dayStem);
    final present =
        (mc != null && branches.contains(mc)) || (hd != null && branches.contains(hd)) || (gg != null && branches.contains(gg));
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
