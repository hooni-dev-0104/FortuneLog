import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_widgets.dart';
import '../../core/saju/saju_stars.dart';
import '../../core/network/engine_api_client.dart';
import '../../core/network/engine_api_client_factory.dart';
import '../../core/network/http_engine_api_client.dart';
import '../birth/birth_input_page.dart';
import '../report/report_page.dart';
import '../saju/saju_guide_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.onTapDaily});

  final VoidCallback onTapDaily;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;
  String? _requestId;

  Map<String, String>? _chart;
  Map<String, int>? _fiveElements;

  SupabaseClient _supabase() => Supabase.instance.client;

  EngineApiClient _engineClient() {
    final baseUrl = const String.fromEnvironment('ENGINE_BASE_URL');
    if (baseUrl.isEmpty) {
      throw const FormatException('ENGINE_BASE_URL is empty');
    }
    return EngineApiClientFactory.create(baseUrl: baseUrl);
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _requestId = null;
    });

    try {
      final session = _supabase().auth.currentSession;
      if (session == null) {
        throw StateError('로그인이 필요합니다.');
      }

      final userId = session.user.id;
      final rows = await _supabase()
          .from('saju_charts')
          .select('id, chart_json, five_elements_json, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);

      if (rows.isEmpty) {
        setState(() {
          _loading = false;
          _chart = null;
          _fiveElements = null;
        });
        return;
      }

      final row = rows.first;
      final chartJson = row['chart_json'] as Map<String, dynamic>;
      final fiveJson = row['five_elements_json'] as Map<String, dynamic>;

      setState(() {
        _loading = false;
        _chart = chartJson.map((k, v) => MapEntry(k, v as String));
        _fiveElements = fiveJson.map((k, v) => MapEntry(k, v as int));
      });
    } on PostgrestException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on StateError catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = '대시보드 데이터를 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _recalculateFromLatestBirthProfile() async {
    setState(() {
      _loading = true;
      _error = null;
      _requestId = null;
    });

    try {
      final session = _supabase().auth.currentSession;
      if (session == null) {
        throw StateError('로그인이 필요합니다.');
      }

      final userId = session.user.id;
      final rows = await _supabase()
          .from('birth_profiles')
          .select('id, birth_datetime_local, birth_timezone, birth_location, calendar_type, is_leap_month, gender, unknown_birth_time, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);

      if (rows.isEmpty) {
        throw StateError('출생정보가 없습니다. 출생정보를 먼저 입력해주세요.');
      }

      final row = rows.first;
      final birthProfileId = row['id'] as String;
      final birthDatetime = row['birth_datetime_local'] as String;
      final birthTimezone = row['birth_timezone'] as String;
      final birthLocation = row['birth_location'] as String;
      final calendarType = row['calendar_type'] as String;
      final isLeapMonth = row['is_leap_month'] as bool;
      final gender = row['gender'] as String;
      final unknownBirthTime = row['unknown_birth_time'] as bool;

      // birth_datetime_local is stored as "YYYY-MM-DDTHH:mm:ss" (timestamp, no timezone).
      final datePart = birthDatetime.split('T').first;
      final timePart = birthDatetime.split('T').last.substring(0, 5);

      final response = await _engineClient().calculateChart(
        CalculateChartRequestDto(
          birthProfileId: birthProfileId,
          birthDate: datePart,
          birthTime: timePart,
          birthTimezone: birthTimezone,
          birthLocation: birthLocation,
          calendarType: calendarType,
          leapMonth: isLeapMonth,
          gender: gender,
          unknownBirthTime: unknownBirthTime,
        ),
      );

      setState(() => _requestId = response.requestId);
      await _refresh();
    } on EngineApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
        _requestId = e.requestId;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on FormatException {
      setState(() {
        _loading = false;
        _error = kDebugMode
            ? 'ENGINE_BASE_URL이 비어 있습니다. .env 설정을 확인해주세요.'
            : '운세 계산 서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.';
      });
    } on StateError catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = '사주 계산에 실패했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PageLoading(title: '불러오는 중', message: '대시보드를 준비하고 있어요.');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        if (_error != null) ...[
          StatusNotice.error(message: _error!, requestId: _requestId ?? 'dashboard'),
          const SizedBox(height: 10),
          FilledButton.tonal(onPressed: _refresh, child: const Text('재시도')),
          const SizedBox(height: 10),
        ],
        if (_chart == null || _fiveElements == null) ...[
          EmptyState(
            title: '아직 사주 결과가 없습니다',
            description: '출생정보로 사주 계산을 완료하면 대시보드에 표시됩니다.',
            actionText: '출생정보 입력',
            onAction: () => Navigator.pushNamed(context, BirthInputPage.routeName),
            icon: Icons.auto_graph_outlined,
            tone: BadgeTone.neutral,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _recalculateFromLatestBirthProfile,
            child: const Text('사주 계산하기'),
          ),
          const SizedBox(height: 10),
        ] else ...[
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
          PageSection(
            title: '만세력(사주팔자)',
            subtitle: '한글/한문(漢字) 표기',
            child: Row(
              children: [
                _PillarCard(
                  label: '연주',
                  value: _chart!['year'] ?? '-',
                  hanja: SajuStars.pillarHanja(_chart!['year'] ?? ''),
                ),
                const SizedBox(width: 8),
                _PillarCard(
                  label: '월주',
                  value: _chart!['month'] ?? '-',
                  hanja: SajuStars.pillarHanja(_chart!['month'] ?? ''),
                ),
                const SizedBox(width: 8),
                _PillarCard(
                  label: '일주',
                  value: _chart!['day'] ?? '-',
                  hanja: SajuStars.pillarHanja(_chart!['day'] ?? ''),
                ),
                const SizedBox(width: 8),
                _PillarCard(
                  label: '시주',
                  value: _chart!['hour'] ?? '-',
                  hanja: SajuStars.pillarHanja(_chart!['hour'] ?? ''),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _AuspiciousStarsSection(chart: _chart!),
          const SizedBox(height: 10),
          _InauspiciousStarsSection(chart: _chart!),
          const SizedBox(height: 10),
          PageSection(
            title: '오행 분포',
            subtitle: '시각 요소와 수치를 함께 제공합니다.',
            child: Column(
              children: [
                _ElementRow(name: '목', value: _fiveElements!['wood'] ?? 0),
                _ElementRow(name: '화', value: _fiveElements!['fire'] ?? 0),
                _ElementRow(name: '토', value: _fiveElements!['earth'] ?? 0),
                _ElementRow(name: '금', value: _fiveElements!['metal'] ?? 0),
                _ElementRow(name: '수', value: _fiveElements!['water'] ?? 0),
                const SizedBox(height: 8),
                const Text('오행 분포는 참고용이며 해석은 리포트에서 제공합니다.'),
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
            onPressed: widget.onTapDaily,
            child: const Text('오늘 운세 보기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _refresh,
            child: const Text('새로고침'),
          ),
        ],
      ],
    );
  }
}

class _StarCardData {
  const _StarCardData({
    required this.name,
    required this.description,
    this.hint,
  });

  final String name;
  final String description;
  final String? hint;
}

class _AuspiciousStarsSection extends StatelessWidget {
  const _AuspiciousStarsSection({required this.chart});

  final Map<String, String> chart;

  @override
  Widget build(BuildContext context) {
    final day = chart['day'] ?? '';
    final dayStem = SajuStars.stemOf(day);
    if (dayStem == null) {
      return const PageSection(
        title: '길신',
        subtitle: '참고용',
        child: Text('귀인 정보를 계산할 수 없습니다.'),
      );
    }

    final pillars = <String>[
      chart['year'] ?? '',
      chart['month'] ?? '',
      chart['day'] ?? '',
      chart['hour'] ?? '',
    ];
    final branches = pillars.map(SajuStars.branchOf).whereType<String>().toList(growable: false);

    final cheonEulTargets = SajuStars.cheonEulTargets(dayStem);
    final hasCheonEul = cheonEulTargets.any((t) => SajuStars.hasAnyBranch(branches, t));

    final munChangTarget = SajuStars.munChangTarget(dayStem);
    final hasMunChang = munChangTarget != null && SajuStars.hasAnyBranch(branches, munChangTarget);

    final stars = <_StarCardData>[
      if (hasCheonEul)
        _StarCardData(
          name: '천을귀인',
          description: '도움/지원의 기운으로 자주 설명됩니다.',
          hint: cheonEulTargets.isEmpty ? null : cheonEulTargets.join(', '),
        ),
      if (hasMunChang)
        _StarCardData(
          name: '문창귀인',
          description: '공부/문서/표현력의 기운으로 자주 설명됩니다.',
          hint: munChangTarget,
        ),
    ];

    return PageSection(
      title: '길신',
      subtitle: '신살 중 “도와주는 기운”으로 자주 소개되는 요소',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stars.isEmpty) ...[
            Text(
              '현재 계산 가능한 길신이 없습니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
          ] else ...[
            for (final s in stars) ...[
              _StarRow(
                name: s.name,
                hint: s.hint,
                description: s.description,
              ),
              if (s != stars.last) const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
          ],
          Text(
            '길신은 참고용이며, 전체 사주 맥락에 따라 해석이 달라질 수 있습니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                SajuGuidePage.routeName,
                arguments: chart,
              ),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('용어/설명 보기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InauspiciousStarsSection extends StatelessWidget {
  const _InauspiciousStarsSection({required this.chart});

  final Map<String, String> chart;

  @override
  Widget build(BuildContext context) {
    final day = chart['day'] ?? '';
    final dayStem = SajuStars.stemOf(day);

    final pillars = <String>[
      chart['year'] ?? '',
      chart['month'] ?? '',
      chart['day'] ?? '',
      chart['hour'] ?? '',
    ];
    final branches = pillars.map(SajuStars.branchOf).whereType<String>().toList(growable: false);

    final yangInTarget = dayStem == null ? null : SajuStars.yangInTarget(dayStem);
    final hasYangIn = yangInTarget != null && SajuStars.hasAnyBranch(branches, yangInTarget);

    final hasGueGang = SajuStars.isGueGangDayPillar(day);
    final hasSipAkDaePae = SajuStars.isSipAkDaePaeDayPillar(day);

    final hyeonChimCount = SajuStars.hyeonChimCount(pillars);
    final hasHyeonChim = hyeonChimCount >= 2;

    final stars = <_StarCardData>[
      if (hasYangIn)
        _StarCardData(
          name: '양인살',
          description: '강한 추진력/에너지를 뜻하는 것으로 소개되며, 과열과 충돌에 주의하라고 풀이되기도 합니다.',
          hint: yangInTarget,
        ),
      if (hasGueGang)
        const _StarCardData(
          name: '괴강살',
          description: '강한 기질/독립성으로 설명되며, 장단이 뚜렷하게 나타난다고 풀이되기도 합니다.',
        ),
      if (hasSipAkDaePae)
        const _StarCardData(
          name: '십악대패',
          description: '흐름이 거칠어지기 쉬운 날주로 소개되며, 리스크 관리가 중요하다고 풀이되기도 합니다.',
        ),
      if (hasHyeonChim)
        _StarCardData(
          name: '현침살',
          description: '말/표현이 날카롭게 비칠 수 있다고 설명되며, 정밀함이 강점이 되기도 합니다.',
          hint: '$hyeonChimCount',
        ),
    ];

    return PageSection(
      title: '흉살',
      subtitle: '신살 중 “주의가 필요한 기운”으로 자주 소개되는 요소',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stars.isEmpty) ...[
            Text(
              '현재 계산 가능한 흉살이 없습니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
          ] else ...[
            for (final s in stars) ...[
              _StarRow(
                name: s.name,
                hint: s.hint,
                description: s.description,
              ),
              if (s != stars.last) const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
          ],
          Text(
            '흉살이 있다고 해서 “무조건 나쁜 일”이 생긴다는 뜻은 아니며, 해석은 전체 맥락에 따라 달라질 수 있습니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                SajuGuidePage.routeName,
                arguments: chart,
              ),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('용어/설명 보기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.name,
    this.hint,
    required this.description,
  });

  final String name;
  final String? hint;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (hint != null && hint!.trim().isNotEmpty) ...[
          const SizedBox(width: 12),
          StatusBadge(label: hint!, tone: BadgeTone.neutral),
        ],
      ],
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({required this.label, required this.value, this.hanja});

  final String label;
  final String value;
  final String? hanja;

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
            if (hanja != null && hanja!.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(hanja!, style: Theme.of(context).textTheme.bodySmall),
            ],
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
