import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/saju/saju_manseoryeok.dart';
import '../../core/saju/saju_stars.dart';
import '../../core/ui/app_widgets.dart';

class ManseoryeokDetailPage extends StatefulWidget {
  const ManseoryeokDetailPage({super.key, required this.chart});

  static const routeName = '/manseoryeok';

  final Map<String, String> chart;

  @override
  State<ManseoryeokDetailPage> createState() => _ManseoryeokDetailPageState();
}

class _HeaderData {
  const _HeaderData({
    required this.displayName,
    required this.birthProfile,
    this.errorMessage,
  });

  final String displayName;
  final Map<String, dynamic>? birthProfile;
  final String? errorMessage;
}

class _ManseoryeokDetailPageState extends State<ManseoryeokDetailPage> {
  late Future<_HeaderData> _headerFuture;

  @override
  void initState() {
    super.initState();
    _headerFuture = _loadHeader();
  }

  Future<_HeaderData> _loadHeader() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw StateError('로그인이 필요합니다.');

      var displayName = (user.userMetadata?['display_name'] as String?)?.trim();
      if (displayName == null || displayName.isEmpty) {
        displayName = user.email?.trim() ?? '사용자';
      }

      final rows = await supabase
          .from('birth_profiles')
          .select('birth_datetime_local, birth_timezone, birth_location, calendar_type, is_leap_month, gender, unknown_birth_time, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1);
      final birthProfile = rows.isEmpty ? null : rows.first;
      return _HeaderData(displayName: displayName, birthProfile: birthProfile);
    } on PostgrestException catch (e) {
      return _HeaderData(displayName: '사용자', birthProfile: null, errorMessage: e.message);
    } on StateError catch (e) {
      return _HeaderData(displayName: '사용자', birthProfile: null, errorMessage: e.message);
    } catch (_) {
      return const _HeaderData(displayName: '사용자', birthProfile: null, errorMessage: '만세력 정보를 불러오지 못했습니다.');
    }
  }

  String _birthSummary(Map<String, dynamic>? birthProfile) {
    final p = birthProfile;
    if (p == null) return '출생정보가 없습니다.';
    final dt = (p['birth_datetime_local'] as String?) ?? '';
    final cal = (p['calendar_type'] as String?) ?? 'solar';
    final unknown = (p['unknown_birth_time'] as bool?) ?? false;

    String ymd = dt;
    String hm = '';
    if (dt.contains('T')) {
      final parts = dt.split('T');
      ymd = parts.first;
      hm = parts.last.length >= 5 ? parts.last.substring(0, 5) : '';
    }
    final calLabel = cal == 'lunar' ? '음력' : '양력';
    final timeLabel = unknown ? '시간 미상' : (hm.isEmpty ? '' : hm);
    return '($calLabel) $ymd ${timeLabel.isEmpty ? '' : timeLabel}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chart;
    final hour = c['hour'] ?? '-';
    final day = c['day'] ?? '-';
    final month = c['month'] ?? '-';
    final year = c['year'] ?? '-';

    final dayStem = SajuStars.stemOf(day);

    return Scaffold(
      appBar: AppBar(title: const Text('만세력 상세')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          FutureBuilder<_HeaderData>(
            future: _headerFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final name = data?.displayName ?? '불러오는 중...';
              final birthLine = data == null ? '출생정보를 불러오는 중...' : _birthSummary(data.birthProfile);

              return Column(
                children: [
                  _HeaderCard(name: name, birthLine: birthLine),
                  if (data?.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    StatusNotice.warning(message: data!.errorMessage!, requestId: 'manseoryeok-header'),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _headerFuture = _loadHeader()),
                        child: const Text('다시 불러오기'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          PageSection(
            title: '사주팔자(4주)',
            subtitle: '시/일/월/년 순서',
            child: Column(
              children: [
                _PillarsTable(
                  dayStem: dayStem,
                  hour: hour,
                  day: day,
                  month: month,
                  year: year,
                ),
                const SizedBox(height: 10),
                _RelationsSummary(hour: hour, day: day, month: month, year: year),
              ],
            ),
          ),
          const SizedBox(height: 10),
          PageSection(
            title: '길신/흉살(요약)',
            subtitle: '대시보드와 동일한 기준으로 계산',
            trailing: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/saju-guide', arguments: c),
              child: const Text('용어 보기'),
            ),
            child: _StarsChips(chart: c),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.name, required this.birthLine});

  final String name;
  final String birthLine;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5F1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFE2D8)),
              ),
              child: const Icon(Icons.person_outline, color: Color(0xFF096B52)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(birthLine, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('만세력(사주팔자)'),
                  content: const Text(
                    '이 화면은 사주팔자(4주)의 천간/지지, 오행 색상, 십신(간단)을 보여줍니다.\n'
                    '해석은 참고용이며, 전체 사주 맥락에 따라 달라질 수 있습니다.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
                  ],
                ),
              ),
              icon: const Icon(Icons.info_outline),
              tooltip: '설명',
            ),
          ],
        ),
      ),
    );
  }
}

class _PillarsTable extends StatelessWidget {
  const _PillarsTable({
    required this.dayStem,
    required this.hour,
    required this.day,
    required this.month,
    required this.year,
  });

  final String? dayStem;
  final String hour;
  final String day;
  final String month;
  final String year;

  @override
  Widget build(BuildContext context) {
    final cols = <({String label, String pillar})>[
      (label: '시주', pillar: hour),
      (label: '일주', pillar: day),
      (label: '월주', pillar: month),
      (label: '년주', pillar: year),
    ];

    return Row(
      children: [
        for (final col in cols) ...[
          Expanded(child: _PillarDetailColumn(label: col.label, pillar: col.pillar, dayStem: dayStem)),
          if (col != cols.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _PillarDetailColumn extends StatelessWidget {
  const _PillarDetailColumn({required this.label, required this.pillar, required this.dayStem});

  final String label;
  final String pillar;
  final String? dayStem;

  @override
  Widget build(BuildContext context) {
    final stem = SajuStars.stemOf(pillar);
    final branch = SajuStars.branchOf(pillar);

    final stemHanja = stem == null ? null : SajuStars.stemHanja(stem);
    final branchHanja = branch == null ? null : SajuStars.branchHanja(branch);

    final stemEl = stem == null ? null : SajuStars.stemElementKey(stem);
    final branchEl = branch == null ? null : SajuStars.branchElementKey(branch);

    final tenGodLabel = (label == '일주')
        ? '일간(나)'
        : (dayStem != null && stem != null ? SajuManseoryeok.tenGod(dayStem: dayStem!, targetStem: stem) : null);

    final hidden = branch == null ? const <String>[] : SajuManseoryeok.hiddenStems(branch);

    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        if (tenGodLabel != null && tenGodLabel.trim().isNotEmpty) ...[
          Text(tenGodLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
        ],
        _GlyphTile(
          primaryText: stemHanja ?? '-',
          secondaryText: stem,
          elementKey: stemEl,
        ),
        const SizedBox(height: 6),
        _GlyphTile(
          primaryText: branchHanja ?? '-',
          secondaryText: branch,
          elementKey: branchEl,
        ),
        const SizedBox(height: 6),
        Text(pillar, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (hidden.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('지장간', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final hs in hidden)
                _MiniChip(
                  label: '$hs${SajuStars.stemHanja(hs) == null ? '' : ' ${SajuStars.stemHanja(hs)}'}',
                ),
            ],
          ),
        ] else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('지장간 없음', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ],
    );
  }
}

class _GlyphTile extends StatelessWidget {
  const _GlyphTile({required this.primaryText, required this.secondaryText, required this.elementKey});

  final String primaryText;
  final String? secondaryText;
  final String? elementKey;

  @override
  Widget build(BuildContext context) {
    final bg = elementKey == null ? const Color(0xFFF3F4F6) : SajuManseoryeok.elementColor(elementKey!);
    final border = elementKey == null ? const Color(0xFFE5E7EB) : Colors.transparent;
    final brightness = ThemeData.estimateBrightnessForColor(bg);
    final fg = brightness == Brightness.dark ? Colors.white : const Color(0xFF111827);

    final elLabel = elementKey == null ? null : SajuManseoryeok.elementLabel(elementKey!);

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                primaryText,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
              ),
            ),
            if (secondaryText != null && secondaryText!.trim().isNotEmpty)
              Positioned(
                left: 8,
                bottom: 6,
                child: Text(
                  secondaryText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.92)),
                ),
              ),
            if (elLabel != null && elLabel.trim().isNotEmpty)
              Positioned(
                right: 8,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    elLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8E0DC)),
        color: Colors.white,
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _RelationsSummary extends StatelessWidget {
  const _RelationsSummary({required this.hour, required this.day, required this.month, required this.year});

  final String hour;
  final String day;
  final String month;
  final String year;

  @override
  Widget build(BuildContext context) {
    final dayS = SajuStars.stemOf(day);
    final dayB = SajuStars.branchOf(day);

    final items = <String>[];

    // Day vs others (simple, scan-friendly).
    final pairs = <({String label, String pillar})>[
      (label: '시', pillar: hour),
      (label: '월', pillar: month),
      (label: '년', pillar: year),
    ];
    for (final p in pairs) {
      final s = SajuStars.stemOf(p.pillar);
      final b = SajuStars.branchOf(p.pillar);

      if (dayS != null && s != null) {
        final c = SajuManseoryeok.stemCombine(dayS, s);
        if (c != null) items.add('일간- ${p.label}간: $c');
      }
      if (dayB != null && b != null) {
        final clash = SajuManseoryeok.branchClash(dayB, b);
        final six = SajuManseoryeok.branchSixCombine(dayB, b);
        if (six != null) items.add('일지- ${p.label}지: $six');
        if (clash != null) items.add('일지- ${p.label}지: $clash');
      }
    }

    if (items.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text('합/충 정보가 없습니다.', style: Theme.of(context).textTheme.bodySmall),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('간단 관계(합/충)', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(items.join('\n'), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StarsChips extends StatelessWidget {
  const _StarsChips({required this.chart});

  final Map<String, String> chart;

  @override
  Widget build(BuildContext context) {
    final day = chart['day'] ?? '';
    final dayStem = SajuStars.stemOf(day);
    if (dayStem == null) {
      return Text('별(길신/흉살)을 계산할 수 없습니다.', style: Theme.of(context).textTheme.bodySmall);
    }

    final pillars = <String>[
      chart['year'] ?? '',
      chart['month'] ?? '',
      chart['day'] ?? '',
      chart['hour'] ?? '',
    ];
    final stems = pillars.map(SajuStars.stemOf).whereType<String>().toList(growable: false);
    final branches = pillars.map(SajuStars.branchOf).whereType<String>().toList(growable: false);

    final chips = <String>[];

    // 길신
    final cheonEulTargets = SajuStars.cheonEulTargets(dayStem);
    if (cheonEulTargets.any((t) => branches.contains(t))) chips.add('천을귀인');
    final munChang = SajuStars.munChangTarget(dayStem);
    if (munChang != null && branches.contains(munChang)) chips.add('문창귀인');
    final taeGeukTargets = SajuStars.taeGeukTargets(dayStem);
    if (taeGeukTargets.any((t) => branches.contains(t))) chips.add('태극귀인');
    final hakDang = SajuStars.hakDangTarget(dayStem);
    if (hakDang != null && branches.contains(hakDang)) chips.add('학당귀인');
    final munGok = SajuStars.munGokTarget(dayStem);
    if (munGok != null && branches.contains(munGok)) chips.add('문곡귀인');
    final gwanGwi = SajuStars.gwanGwiHakGwanTarget(dayStem);
    if (gwanGwi != null && branches.contains(gwanGwi)) chips.add('사관귀인');
    final cheonJu = SajuStars.cheonJuTarget(dayStem);
    if (cheonJu != null && branches.contains(cheonJu)) chips.add('천주귀인');
    final geumYeo = SajuStars.geumYeoTarget(dayStem);
    if (geumYeo != null && branches.contains(geumYeo)) chips.add('금여');
    final amRok = SajuStars.amRokTarget(dayStem);
    if (amRok != null && branches.contains(amRok)) chips.add('암록');
    final monthBranch = SajuStars.branchOf(chart['month'] ?? '');
    if (monthBranch != null) {
      final wd = SajuStars.wolDeokStemByMonthBranch(monthBranch);
      if (wd != null && stems.contains(wd)) chips.add('월덕귀인');
      final cd = SajuStars.cheonDeokStemByMonthBranch(monthBranch);
      if (cd != null && stems.contains(cd)) chips.add('천덕귀인');
      final ce = SajuStars.cheonEuiTargetByMonthBranch(monthBranch);
      if (ce != null && branches.contains(ce)) chips.add('천의성');
    }
    if (SajuStars.hasSamGi(pillars)) chips.add('삼기귀인');

    // 흉살(일부)
    final yangIn = SajuStars.yangInTarget(dayStem);
    if (yangIn != null && branches.contains(yangIn)) chips.add('양인살');
    if (pillars.any(SajuStars.isBaekHoPillar)) chips.add('백호살');
    if (SajuStars.isGueGangDayPillar(day)) chips.add('괴강살');
    final hongYeom = SajuStars.hongYeomTarget(dayStem);
    if (hongYeom != null && branches.contains(hongYeom)) chips.add('홍염살');
    final yearBranch = SajuStars.branchOf(chart['year'] ?? '');
    final dayBranch = SajuStars.branchOf(chart['day'] ?? '');
    if (SajuStars.isGyeokGak(yearBranch: yearBranch, dayBranch: dayBranch)) chips.add('격각살');
    final goJinT1 = yearBranch == null ? null : SajuStars.goJinTargetByBaseBranch(yearBranch);
    final goJinT2 = dayBranch == null ? null : SajuStars.goJinTargetByBaseBranch(dayBranch);
    if ((goJinT1 != null && branches.contains(goJinT1)) || (goJinT2 != null && branches.contains(goJinT2))) chips.add('고진살');
    final gwaSukT1 = yearBranch == null ? null : SajuStars.gwaSukTargetByBaseBranch(yearBranch);
    final gwaSukT2 = dayBranch == null ? null : SajuStars.gwaSukTargetByBaseBranch(dayBranch);
    if ((gwaSukT1 != null && branches.contains(gwaSukT1)) || (gwaSukT2 != null && branches.contains(gwaSukT2))) chips.add('과숙살');
    if (SajuStars.hasGwiMunGwanSal(
      monthBranch: SajuStars.branchOf(chart['month'] ?? ''),
      dayBranch: dayBranch,
      hourBranch: SajuStars.branchOf(chart['hour'] ?? ''),
    )) {
      chips.add('귀문관살');
    }
    final geupGakTargets = monthBranch == null ? const <String>{} : SajuStars.geupGakTargetsByMonthBranch(monthBranch);
    if (geupGakTargets.isNotEmpty && geupGakTargets.any(branches.contains)) chips.add('급각살');
    final danGyoTarget = monthBranch == null ? null : SajuStars.danGyoGwanTargetByMonthBranch(monthBranch);
    if (danGyoTarget != null &&
        (dayBranch == danGyoTarget || SajuStars.branchOf(chart['hour'] ?? '') == danGyoTarget)) {
      chips.add('단교관살');
    }
    if (pillars.any(SajuStars.isGokGakPillar)) chips.add('곡각살');
    final cheonRaJiMangType = SajuStars.cheonRaJiMangType(dayBranch: dayBranch, allBranches: branches);
    if (cheonRaJiMangType != null) chips.add('천라지망');
    final daeMoTarget = yearBranch == null ? null : SajuStars.daeMoTargetByYearBranch(yearBranch);
    if (daeMoTarget != null && branches.contains(daeMoTarget)) chips.add('대모살');
    if (SajuStars.isGuGyoDayPillar(day)) chips.add('구교살');
    if (SajuStars.pyeongDuCount(pillars) >= 4) chips.add('평두살');
    if (SajuStars.isSipAkDaePaeDayPillar(day)) chips.add('십악대패');
    if (SajuStars.hyeonChimCount(pillars) >= 2) chips.add('현침살');
    if (SajuStars.hasJangHyeongSal(branches)) chips.add('장형살');
    if (yearBranch != null) {
      final sangMun = SajuStars.sangMunTargetByYearBranch(yearBranch);
      if (sangMun != null && branches.contains(sangMun)) chips.add('상문살');
      final joGaek = SajuStars.joGaekTargetByYearBranch(yearBranch);
      if (joGaek != null && branches.contains(joGaek)) chips.add('조객살');
    }

    if (chips.isEmpty) {
      return Text('표시할 길신/흉살이 없습니다.', style: Theme.of(context).textTheme.bodySmall);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chips) _MiniChip(label: c),
      ],
    );
  }
}
