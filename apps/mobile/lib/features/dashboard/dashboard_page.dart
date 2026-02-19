import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_widgets.dart';
import '../../core/saju/saju_stars.dart';
import '../../core/saju/saju_chart_persistence.dart';
import '../../core/network/engine_api_client.dart';
import '../../core/network/engine_api_client_factory.dart';
import '../../core/network/http_engine_api_client.dart';
import '../../core/network/engine_error_mapper.dart';
import '../birth/birth_input_page.dart';
import '../birth/birth_profile_list_page.dart';
import '../report/report_page.dart';
import '../saju/manseoryeok_detail_page.dart';
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

  String? _chartId;
  Map<String, String>? _chart;
  Map<String, int>? _fiveElements;
  Map<String, dynamic>? _aiContent;
  bool _aiLoading = false;
  String? _aiError;
  String? _aiRequestId;
  bool _hasBirthProfile = false;

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
      _aiError = null;
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
        // Used for UX: if birth profile exists but chart doesn't, we should guide to "사주 계산하기"
        // instead of "출생정보 입력".
        final bp = await _supabase()
            .from('birth_profiles')
            .select('id')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(1);
        setState(() {
          _loading = false;
          _chartId = null;
          _chart = null;
          _fiveElements = null;
          _aiContent = null;
          _aiLoading = false;
          _hasBirthProfile = (bp as List).isNotEmpty;
        });
        return;
      }

      final row = rows.first;
      final chartId = row['id'] as String;
      final chartJson = row['chart_json'] as Map<String, dynamic>;
      final fiveJson = row['five_elements_json'] as Map<String, dynamic>;
      final aiRows = await _supabase()
          .from('reports')
          .select('content_json, created_at')
          .eq('user_id', userId)
          .eq('chart_id', chartId)
          .eq('report_type', 'ai_interpretation')
          .order('created_at', ascending: false)
          .limit(1);
      final aiContent = (aiRows as List).isEmpty
          ? null
          : (aiRows.first['content_json'] as Map).cast<String, dynamic>();

      setState(() {
        _loading = false;
        _chartId = chartId;
        _chart = chartJson.map((k, v) => MapEntry(k, v as String));
        _fiveElements = fiveJson.map((k, v) => MapEntry(k, v as int));
        _aiContent = aiContent;
        _aiLoading = false;
        _hasBirthProfile = true;
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

  Future<void> _generateAiInterpretation() async {
    final chartId = _chartId;
    if (chartId == null || chartId.isEmpty) {
      setState(() {
        _aiError = '사주 차트가 없어 AI 해석을 생성할 수 없습니다.';
      });
      return;
    }

    setState(() {
      _aiLoading = true;
      _aiError = null;
      _aiRequestId = null;
    });

    try {
      final response = await _engineClient().generateAiInterpretation(
        GenerateAiInterpretationRequestDto(chartId: chartId),
      );
      if (!mounted) return;
      setState(() => _aiRequestId = response.requestId);
      await _refresh();
    } on EngineApiException catch (e) {
      setState(() {
        _aiLoading = false;
        _aiError = EngineErrorMapper.userMessage(e);
        _aiRequestId = e.requestId;
      });
    } on FormatException {
      setState(() {
        _aiLoading = false;
        _aiError = kDebugMode
            ? 'ENGINE_BASE_URL이 비어 있습니다. .env 설정을 확인해주세요.'
            : 'AI 해석 서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.';
      });
    } catch (_) {
      setState(() {
        _aiLoading = false;
        _aiError = 'AI 해석 생성에 실패했습니다.';
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
      final birthLocationForEngine = birthLocation.trim().isEmpty ? '미입력' : birthLocation.trim();

      final response = await _engineClient().calculateChart(
        CalculateChartRequestDto(
          birthProfileId: birthProfileId,
          birthDate: datePart,
          birthTime: timePart,
          birthTimezone: birthTimezone,
          birthLocation: birthLocationForEngine,
          calendarType: calendarType,
          leapMonth: isLeapMonth,
          gender: gender,
          unknownBirthTime: unknownBirthTime,
        ),
      );

      setState(() => _requestId = response.requestId);

      // Ensure the chart exists in the same Supabase project the app reads from.
      await SajuChartPersistence.ensureSavedFromResponse(
        supabase: _supabase(),
        userId: userId,
        birthProfileId: birthProfileId,
        response: response,
      );

      await _refresh();
    } on EngineApiException catch (e) {
      setState(() {
        _loading = false;
        _error = EngineErrorMapper.userMessage(e);
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
            description: _hasBirthProfile
                ? '출생정보는 저장되어 있습니다. 사주 계산을 완료하면 대시보드에 표시됩니다.'
                : '출생정보로 사주 계산을 완료하면 대시보드에 표시됩니다.',
            actionText: _hasBirthProfile ? '사주 계산하기' : '출생정보 입력',
            onAction: _hasBirthProfile
                ? _recalculateFromLatestBirthProfile
                : () => Navigator.pushNamed(context, BirthInputPage.routeName),
            icon: Icons.auto_graph_outlined,
            tone: _hasBirthProfile ? BadgeTone.warning : BadgeTone.neutral,
          ),
          const SizedBox(height: 10),
          if (_hasBirthProfile)
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, BirthProfileListPage.routeName),
              child: const Text('출생정보 확인/수정'),
            )
          else
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
            subtitle: '천간/지지 한문(漢字) 표기 + 오행 색상',
            trailing: TextButton(
              onPressed: () => Navigator.pushNamed(context, ManseoryeokDetailPage.routeName, arguments: _chart),
              child: const Text('상세보기'),
            ),
            child: _MansePillars(chart: _chart!),
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
          const SizedBox(height: 10),
          _AiInterpretationSection(
            loading: _aiLoading,
            error: _aiError,
            requestId: _aiRequestId,
            content: _aiContent,
            onGenerate: _generateAiInterpretation,
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

class _AiInterpretationSection extends StatelessWidget {
  const _AiInterpretationSection({
    required this.loading,
    required this.error,
    required this.requestId,
    required this.content,
    required this.onGenerate,
  });

  final bool loading;
  final String? error;
  final String? requestId;
  final Map<String, dynamic>? content;
  final VoidCallback onGenerate;

  static List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }

  static Map<String, dynamic> _toStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }

  Widget _bullets(BuildContext context, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Text('• $item', style: Theme.of(context).textTheme.bodyMedium),
          if (item != items.last) const SizedBox(height: 4),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = content?['summary']?.toString().trim();
    final traits = _toStringList(content?['coreTraits']);
    final strengths = _toStringList(content?['strengths']);
    final cautions = _toStringList(content?['cautions']);
    final actionTips = _toStringList(content?['actionTips']);
    final themes = _toStringMap(content?['themes']);
    final period = _toStringMap(content?['fortuneByPeriod']);
    final disclaimer = content?['disclaimer']?.toString().trim();

    return PageSection(
      title: 'AI 사주 해석',
      subtitle: 'Gemini 기반 상세 해석',
      trailing: FilledButton.tonal(
        onPressed: loading ? null : onGenerate,
        child: Text(loading ? '생성 중...' : (content == null ? '해석 생성' : '다시 생성')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null) ...[
            StatusNotice.error(message: error!, requestId: requestId ?? 'ai-interpretation'),
            const SizedBox(height: 10),
          ],
          if (content == null && !loading) ...[
            const Text('아직 AI 해석이 없습니다. 해석 생성을 눌러 결과를 확인하세요.'),
            const SizedBox(height: 8),
            Text(
              '정식 결제 적용 전까지는 테스트 형태로 동작합니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (loading && content == null) ...[
            const Text('AI 해석을 생성하고 있어요. 잠시만 기다려주세요.'),
          ] else ...[
            if (summary != null && summary.isNotEmpty) ...[
              Text(summary, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 10),
            ],
            if (traits.isNotEmpty) ...[
              Text('핵심 성향', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              _bullets(context, traits),
              const SizedBox(height: 10),
            ],
            if (strengths.isNotEmpty) ...[
              Text('강점', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              _bullets(context, strengths),
              const SizedBox(height: 10),
            ],
            if (cautions.isNotEmpty) ...[
              Text('주의 포인트', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              _bullets(context, cautions),
              const SizedBox(height: 10),
            ],
            if (themes.isNotEmpty) ...[
              Text('분야별 운세', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              if ((themes['money']?.toString().trim().isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('금전: ${themes['money']}'),
                ),
              if ((themes['relationship']?.toString().trim().isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('연애/결혼: ${themes['relationship']}'),
                ),
              if ((themes['career']?.toString().trim().isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('직업: ${themes['career']}'),
                ),
              if ((themes['health']?.toString().trim().isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('건강: ${themes['health']}'),
                ),
              const SizedBox(height: 10),
            ],
            if (period.isNotEmpty) ...[
              Text('기간별 흐름', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              if ((period['year']?.toString().trim().isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('올해: ${period['year']}'),
                ),
              if ((period['month']?.toString().trim().isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('이번 달: ${period['month']}'),
                ),
              if ((period['week']?.toString().trim().isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('이번 주: ${period['week']}'),
                ),
              if ((period['day']?.toString().trim().isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('오늘: ${period['day']}'),
                ),
              const SizedBox(height: 10),
            ],
            if (actionTips.isNotEmpty) ...[
              Text('실행 팁', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              for (int i = 0; i < actionTips.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${i + 1}. ${actionTips[i]}'),
                ),
              const SizedBox(height: 8),
            ],
            if (disclaimer != null && disclaimer.isNotEmpty)
              Text(
                disclaimer,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ],
      ),
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

  List<({String label, String pillar, String? stem, String? branch})> _pillarEntries(Map<String, String> chart) {
    final year = chart['year'] ?? '';
    final month = chart['month'] ?? '';
    final day = chart['day'] ?? '';
    final hour = chart['hour'] ?? '';
    return [
      (label: '년주', pillar: year, stem: SajuStars.stemOf(year), branch: SajuStars.branchOf(year)),
      (label: '월주', pillar: month, stem: SajuStars.stemOf(month), branch: SajuStars.branchOf(month)),
      (label: '일주', pillar: day, stem: SajuStars.stemOf(day), branch: SajuStars.branchOf(day)),
      (label: '시주', pillar: hour, stem: SajuStars.stemOf(hour), branch: SajuStars.branchOf(hour)),
    ];
  }

  String? _hintForStems(List<({String label, String pillar, String? stem, String? branch})> entries, Set<String> targets) {
    if (targets.isEmpty) return null;
    final labels = <String>[];
    for (final e in entries) {
      final s = e.stem;
      if (s != null && targets.contains(s)) labels.add(e.label);
    }
    return labels.isEmpty ? null : labels.join('/');
  }

  String? _hintForBranches(List<({String label, String pillar, String? stem, String? branch})> entries, Set<String> targets) {
    if (targets.isEmpty) return null;
    final labels = <String>[];
    for (final e in entries) {
      final b = e.branch;
      if (b != null && targets.contains(b)) labels.add(e.label);
    }
    return labels.isEmpty ? null : labels.join('/');
  }

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
    final entries = _pillarEntries(chart);
    final stems = pillars.map(SajuStars.stemOf).whereType<String>().toList(growable: false);
    final branches = pillars.map(SajuStars.branchOf).whereType<String>().toList(growable: false);

    final cheonEulTargets = SajuStars.cheonEulTargets(dayStem);
    final hasCheonEul = cheonEulTargets.any((t) => SajuStars.hasAnyBranch(branches, t));

    final munChangTarget = SajuStars.munChangTarget(dayStem);
    final hasMunChang = munChangTarget != null && SajuStars.hasAnyBranch(branches, munChangTarget);

    final taeGeukTargets = SajuStars.taeGeukTargets(dayStem);
    final hasTaeGeuk = taeGeukTargets.any((t) => SajuStars.hasAnyBranch(branches, t));

    final cheonJuTarget = SajuStars.cheonJuTarget(dayStem);
    final hasCheonJu = cheonJuTarget != null && SajuStars.hasAnyBranch(branches, cheonJuTarget);

    final hakDangTarget = SajuStars.hakDangTarget(dayStem);
    final hasHakDang = hakDangTarget != null && SajuStars.hasAnyBranch(branches, hakDangTarget);

    final gwanGwiTarget = SajuStars.gwanGwiHakGwanTarget(dayStem);
    final hasGwanGwi = gwanGwiTarget != null && SajuStars.hasAnyBranch(branches, gwanGwiTarget);

    final munGokTarget = SajuStars.munGokTarget(dayStem);
    final hasMunGok = munGokTarget != null && SajuStars.hasAnyBranch(branches, munGokTarget);

    final geumYeoTarget = SajuStars.geumYeoTarget(dayStem);
    final hasGeumYeo = geumYeoTarget != null && SajuStars.hasAnyBranch(branches, geumYeoTarget);

    final amRokTarget = SajuStars.amRokTarget(dayStem);
    final hasAmRok = amRokTarget != null && SajuStars.hasAnyBranch(branches, amRokTarget);

    final monthBranch = SajuStars.branchOf(chart['month'] ?? '');
    final wolDeokStem = monthBranch == null ? null : SajuStars.wolDeokStemByMonthBranch(monthBranch);
    final hasWolDeok = wolDeokStem != null && stems.contains(wolDeokStem);

    final cheonDeokStem = monthBranch == null ? null : SajuStars.cheonDeokStemByMonthBranch(monthBranch);
    final hasCheonDeok = cheonDeokStem != null && stems.contains(cheonDeokStem);

    final cheonEuiTarget = monthBranch == null ? null : SajuStars.cheonEuiTargetByMonthBranch(monthBranch);
    final hasCheonEui = cheonEuiTarget != null && SajuStars.hasAnyBranch(branches, cheonEuiTarget);

    final geonRokBranch = SajuStars.geonRokBranch(dayStem);
    final hasGeonRok = geonRokBranch != null && SajuStars.hasAnyBranch(branches, geonRokBranch);

    final yearBranch = SajuStars.branchOf(chart['year'] ?? '');
    final dayBranch = SajuStars.branchOf(chart['day'] ?? '');
    final yeokMaTarget = SajuStars.yeokMaTarget(yearBranch: yearBranch, dayBranch: dayBranch);
    final hasYeokMa = yeokMaTarget != null && SajuStars.hasAnyBranch(branches, yeokMaTarget);
    final hasRokMa = hasGeonRok && hasYeokMa;
    final isRokMaDongHyang = hasRokMa && geonRokBranch == yeokMaTarget;

    final hasSamGi = SajuStars.hasSamGi(pillars);

    final stars = <_StarCardData>[
      if (hasWolDeok)
        _StarCardData(
          name: '월덕귀인',
          description: '대인관계/인복, 정서적 안정과 연결해 풀이하는 경우가 있습니다.',
          hint: _hintForStems(entries, {wolDeokStem}),
        ),
      if (hasCheonDeok)
        _StarCardData(
          name: '천덕귀인',
          description: '덕으로 풀리는 복, 큰 흐름에서 보호받는 느낌으로 설명되기도 합니다.',
          hint: _hintForStems(entries, {cheonDeokStem}),
        ),
      if (hasCheonEul)
        _StarCardData(
          name: '천을귀인',
          description: '도움/지원의 기운으로 자주 설명됩니다.',
          hint: _hintForBranches(entries, cheonEulTargets.toSet()),
        ),
      if (hasTaeGeuk)
        _StarCardData(
          name: '태극귀인',
          description: '위기 회피/난관 돌파에 유리한 길신으로 소개되곤 합니다.',
          hint: _hintForBranches(entries, taeGeukTargets.toSet()),
        ),
      if (hasMunChang)
        _StarCardData(
          name: '문창귀인',
          description: '공부/문서/표현력의 기운으로 자주 설명됩니다.',
          hint: _hintForBranches(entries, {munChangTarget}),
        ),
      if (hasHakDang)
        _StarCardData(
          name: '학당귀인',
          description: '학업/자격/연구로 풀어 설명되는 경우가 있습니다.',
          hint: _hintForBranches(entries, {hakDangTarget}),
        ),
      if (hasMunGok)
        _StarCardData(
          name: '문곡귀인',
          description: '문장/글/표현력이 돋보인다고 풀이되는 경우가 있습니다.',
          hint: _hintForBranches(entries, {munGokTarget}),
        ),
      if (hasGwanGwi)
        _StarCardData(
          name: '사관귀인',
          description: '관직/직위/조직 내 역할과 연결해서 풀이하는 경우가 있습니다.',
          hint: _hintForBranches(entries, {gwanGwiTarget}),
        ),
      if (hasCheonJu)
        _StarCardData(
          name: '천주귀인',
          description: '환경의 도움/보호로 설명되는 경우가 있습니다.',
          hint: _hintForBranches(entries, {cheonJuTarget}),
        ),
      if (hasGeumYeo)
        _StarCardData(
          name: '금여',
          description: '재물/배우자 복과 연결해 설명되는 경우가 있습니다.',
          hint: _hintForBranches(entries, {geumYeoTarget}),
        ),
      if (hasAmRok)
        _StarCardData(
          name: '암록',
          description: '예상하지 못한 도움/수입처럼 “숨은 복”으로 풀이되기도 합니다.',
          hint: _hintForBranches(entries, {amRokTarget}),
        ),
      if (hasCheonEui)
        _StarCardData(
          name: '천의성',
          description: '건강/치유/상담 등과 연결해서 해석하는 경우가 있습니다.',
          hint: _hintForBranches(entries, {cheonEuiTarget}),
        ),
      if (hasRokMa)
        _StarCardData(
          name: isRokMaDongHyang ? '녹마동향' : '록마교치',
          description: '움직임(역마)과 성취(록)가 맞물릴 때의 흐름을 말합니다.',
          hint: () {
            final rokHint = _hintForBranches(entries, {geonRokBranch});
            final maHint = _hintForBranches(entries, {yeokMaTarget});
            if (isRokMaDongHyang) {
              // Same pillar can satisfy both.
              return rokHint;
            }
            return '건록:$rokHint / 역마:$maHint';
          }(),
        ),
      if (hasSamGi)
        const _StarCardData(
          name: '삼기귀인',
          description: '배움/재능/특별한 기회로 설명되는 경우가 있습니다.',
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

  List<({String label, String pillar, String? stem, String? branch})> _pillarEntries(Map<String, String> chart) {
    final year = chart['year'] ?? '';
    final month = chart['month'] ?? '';
    final day = chart['day'] ?? '';
    final hour = chart['hour'] ?? '';
    return [
      (label: '년주', pillar: year, stem: SajuStars.stemOf(year), branch: SajuStars.branchOf(year)),
      (label: '월주', pillar: month, stem: SajuStars.stemOf(month), branch: SajuStars.branchOf(month)),
      (label: '일주', pillar: day, stem: SajuStars.stemOf(day), branch: SajuStars.branchOf(day)),
      (label: '시주', pillar: hour, stem: SajuStars.stemOf(hour), branch: SajuStars.branchOf(hour)),
    ];
  }

  String? _hintForBranches(List<({String label, String pillar, String? stem, String? branch})> entries, Set<String> targets) {
    if (targets.isEmpty) return null;
    final labels = <String>[];
    for (final e in entries) {
      final b = e.branch;
      if (b != null && targets.contains(b)) labels.add(e.label);
    }
    return labels.isEmpty ? null : labels.join('/');
  }

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
    final entries = _pillarEntries(chart);
    final branches = pillars.map(SajuStars.branchOf).whereType<String>().toList(growable: false);

    final yangInTarget = dayStem == null ? null : SajuStars.yangInTarget(dayStem);
    final hasYangIn = yangInTarget != null && SajuStars.hasAnyBranch(branches, yangInTarget);

    final hasBaekHo = pillars.any(SajuStars.isBaekHoPillar);
    final hongYeomTarget = dayStem == null ? null : SajuStars.hongYeomTarget(dayStem);
    final hasHongYeom = hongYeomTarget != null && branches.contains(hongYeomTarget);

    final yearBranch = SajuStars.branchOf(chart['year'] ?? '');
    final dayBranch = SajuStars.branchOf(chart['day'] ?? '');

    final hasGyeokGak = SajuStars.isGyeokGak(yearBranch: yearBranch, dayBranch: dayBranch);

    final goJinT1 = yearBranch == null ? null : SajuStars.goJinTargetByBaseBranch(yearBranch);
    final goJinT2 = dayBranch == null ? null : SajuStars.goJinTargetByBaseBranch(dayBranch);
    final hasGoJin = (goJinT1 != null && branches.contains(goJinT1)) || (goJinT2 != null && branches.contains(goJinT2));

    final gwaSukT1 = yearBranch == null ? null : SajuStars.gwaSukTargetByBaseBranch(yearBranch);
    final gwaSukT2 = dayBranch == null ? null : SajuStars.gwaSukTargetByBaseBranch(dayBranch);
    final hasGwaSuk = (gwaSukT1 != null && branches.contains(gwaSukT1)) || (gwaSukT2 != null && branches.contains(gwaSukT2));

    final hasGwiMun = SajuStars.hasGwiMunGwanSal(
      monthBranch: SajuStars.branchOf(chart['month'] ?? ''),
      dayBranch: dayBranch,
      hourBranch: SajuStars.branchOf(chart['hour'] ?? ''),
    );

    final monthBranch = SajuStars.branchOf(chart['month'] ?? '');
    final geupGakTargets = monthBranch == null ? const <String>{} : SajuStars.geupGakTargetsByMonthBranch(monthBranch);
    final hasGeupGak = geupGakTargets.isNotEmpty && geupGakTargets.any(branches.contains);

    final danGyoTarget = monthBranch == null ? null : SajuStars.danGyoGwanTargetByMonthBranch(monthBranch);
    final hasDanGyo = danGyoTarget != null && (dayBranch == danGyoTarget || SajuStars.branchOf(chart['hour'] ?? '') == danGyoTarget);

    final hasGokGak = pillars.any(SajuStars.isGokGakPillar);

    final cheonRaJiMangType = SajuStars.cheonRaJiMangType(dayBranch: dayBranch, allBranches: branches);
    final hasCheonRaJiMang = cheonRaJiMangType != null;

    final daeMoTarget = yearBranch == null ? null : SajuStars.daeMoTargetByYearBranch(yearBranch);
    final hasDaeMo = daeMoTarget != null && branches.contains(daeMoTarget);

    final hasGuGyo = SajuStars.isGuGyoDayPillar(day);

    final pyeongDuCount = SajuStars.pyeongDuCount(pillars);
    final hasPyeongDu = pyeongDuCount >= 4;

    final hasJangHyeong = SajuStars.hasJangHyeongSal(branches);

    final sangMunTarget = yearBranch == null ? null : SajuStars.sangMunTargetByYearBranch(yearBranch);
    final hasSangMun = sangMunTarget != null && branches.contains(sangMunTarget);
    final joGaekTarget = yearBranch == null ? null : SajuStars.joGaekTargetByYearBranch(yearBranch);
    final hasJoGaek = joGaekTarget != null && branches.contains(joGaekTarget);

    const goran = {'갑인', '을사', '정사', '무신', '신해'};
    final hasGoran = goran.contains(day.trim());

    final hasGueGang = SajuStars.isGueGangDayPillar(day);
    final hasSipAkDaePae = SajuStars.isSipAkDaePaeDayPillar(day);

    final hyeonChimCount = SajuStars.hyeonChimCount(pillars);
    final hasHyeonChim = hyeonChimCount >= 2;

    final stars = <_StarCardData>[
      if (hasYangIn)
        _StarCardData(
          name: '양인살',
          description: '강한 추진력/에너지를 뜻하는 것으로 소개되며, 과열과 충돌에 주의하라고 풀이되기도 합니다.',
          hint: _hintForBranches(entries, {yangInTarget}),
        ),
      if (hasBaekHo)
        _StarCardData(
          name: '백호살',
          description: '큰 변화/사고수로 연결해 풀이되는 경우가 있어, 생활 리스크 관리로 해석하기도 합니다.',
          hint: () {
            final labels = <String>[];
            for (final e in entries) {
              if (SajuStars.isBaekHoPillar(e.pillar)) labels.add(e.label);
            }
            return labels.isEmpty ? null : labels.join('/');
          }(),
        ),
      if (hasGueGang)
        const _StarCardData(
          name: '괴강살',
          description: '강한 기질/독립성으로 설명되며, 장단이 뚜렷하게 나타난다고 풀이되기도 합니다.',
        ),
      if (hasHongYeom)
        _StarCardData(
          name: '홍염살',
          description: '매력/호감/관계 이슈와 연결해 해석하는 경우가 있습니다.',
          hint: _hintForBranches(entries, {hongYeomTarget}),
        ),
      if (hasGoJin)
        _StarCardData(
          name: '고진살',
          description: '고독/고립감으로 연결해 풀이하는 경우가 있습니다.',
          hint: _hintForBranches(entries, {if (goJinT1 != null) goJinT1, if (goJinT2 != null) goJinT2}),
        ),
      if (hasGwaSuk)
        _StarCardData(
          name: '과숙살',
          description: '관계의 단절감/혼자 감당하는 기운으로 풀이되는 경우가 있습니다.',
          hint: _hintForBranches(entries, {if (gwaSukT1 != null) gwaSukT1, if (gwaSukT2 != null) gwaSukT2}),
        ),
      if (hasGyeokGak)
        const _StarCardData(
          name: '격각살',
          description: '부딪힘/충돌로 풀이되기도 하며, 안전·규칙을 강조하는 해석이 있습니다.',
        ),
      if (hasGwiMun)
        const _StarCardData(
          name: '귀문관살',
          description: '예민함/몰입으로 풀이되기도 하며, 마음 관리가 중요하다고 해석하기도 합니다.',
        ),
      if (hasGeupGak)
        _StarCardData(
          name: '급각살',
          description: '급작스러운 변수로 해석하는 경우가 있습니다.',
          hint: _hintForBranches(entries, geupGakTargets),
        ),
      if (hasDanGyo)
        _StarCardData(
          name: '단교관살',
          description: '관계의 단절/끊김으로 풀이되는 경우가 있습니다.',
          hint: _hintForBranches(entries, {danGyoTarget}),
        ),
      if (hasGokGak)
        _StarCardData(
          name: '곡각살',
          description: '말/상처/굴곡으로 연결해 풀이하는 경우가 있습니다.',
          hint: () {
            final labels = <String>[];
            for (final e in entries) {
              if (SajuStars.isGokGakPillar(e.pillar)) labels.add(e.label);
            }
            return labels.isEmpty ? null : labels.join('/');
          }(),
        ),
      if (hasCheonRaJiMang)
        _StarCardData(
          name: '천라지망',
          description: '답답함/제약으로 풀이되기도 하며, 장기적으로 정리/정돈이 필요하다고 해석하기도 합니다.',
          hint: () {
            if (dayBranch == '술') return _hintForBranches(entries, {'술', '해'});
            if (dayBranch == '해') return _hintForBranches(entries, {'술', '해'});
            if (dayBranch == '진') return _hintForBranches(entries, {'진', '사'});
            if (dayBranch == '사') return _hintForBranches(entries, {'진', '사'});
            return cheonRaJiMangType;
          }(),
        ),
      if (hasDaeMo)
        _StarCardData(
          name: '대모살',
          description: '큰 지출/손재로 풀이되는 경우가 있어, 리스크 관리를 강조하기도 합니다.',
          hint: _hintForBranches(entries, {daeMoTarget}),
        ),
      if (hasGuGyo)
        const _StarCardData(
          name: '구교살',
          description: '구설/오해로 연결해 풀이하는 경우가 있습니다.',
        ),
      if (hasSipAkDaePae)
        const _StarCardData(
          name: '십악대패',
          description: '흐름이 거칠어지기 쉬운 날주로 소개되며, 리스크 관리가 중요하다고 풀이되기도 합니다.',
        ),
      if (hasGoran)
        const _StarCardData(
          name: '고란살',
          description: '관계에서의 외로움/고독으로 풀이되는 경우가 있습니다.',
        ),
      if (hasPyeongDu)
        _StarCardData(
          name: '평두살',
          description: '막힘/꺾임으로 풀이되는 경우가 있습니다.',
          hint: () {
            // Based on pyeongDuCount implementation.
            final labels = <String>{};
            for (final e in entries) {
              final s = e.stem;
              final b = e.branch;
              if (s == '갑' || s == '병' || s == '정' || s == '임') labels.add(e.label);
              if (b == '진' || b == '자') labels.add(e.label);
            }
            final list = labels.toList()..sort();
            return list.isEmpty ? null : list.join('/');
          }(),
        ),
      if (hasHyeonChim)
        _StarCardData(
          name: '현침살',
          description: '말/표현이 날카롭게 비칠 수 있다고 설명되며, 정밀함이 강점이 되기도 합니다.',
          hint: () {
            final labels = <String>{};
            for (final e in entries) {
              final s = e.stem;
              final b = e.branch;
              if (s == '갑' || s == '신') labels.add(e.label);
              if (b == '묘' || b == '오' || b == '신') labels.add(e.label);
            }
            final list = labels.toList()..sort();
            return list.isEmpty ? null : list.join('/');
          }(),
        ),
      if (hasJangHyeong)
        const _StarCardData(
          name: '장형살',
          description: '벌/형벌/규정과 연결해 풀이되는 경우가 있어, 규칙 준수를 강조하기도 합니다.',
        ),
      if (hasSangMun)
        _StarCardData(
          name: '상문살',
          description: '상실/이별로 풀이되는 경우가 있어, 마음 관리를 권하기도 합니다.',
          hint: _hintForBranches(entries, {sangMunTarget}),
        ),
      if (hasJoGaek)
        _StarCardData(
          name: '조객살',
          description: '외부 방문/변동 이슈로 풀이되기도 합니다.',
          hint: _hintForBranches(entries, {joGaekTarget}),
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

class _MansePillars extends StatelessWidget {
  const _MansePillars({required this.chart});

  final Map<String, String> chart;

  @override
  Widget build(BuildContext context) {
    // Match common 만세력 UI ordering: 시/일/월/년.
    final hour = chart['hour'] ?? '-';
    final day = chart['day'] ?? '-';
    final month = chart['month'] ?? '-';
    final year = chart['year'] ?? '-';

    return Row(
      children: [
        _MansePillarColumn(label: '시주', pillar: hour),
        const SizedBox(width: 8),
        _MansePillarColumn(label: '일주', pillar: day),
        const SizedBox(width: 8),
        _MansePillarColumn(label: '월주', pillar: month),
        const SizedBox(width: 8),
        _MansePillarColumn(label: '년주', pillar: year),
      ],
    );
  }
}

class _MansePillarColumn extends StatelessWidget {
  const _MansePillarColumn({required this.label, required this.pillar});

  final String label;
  final String pillar;

  static const Color _unknownBg = Color(0xFFF3F4F6);
  static const Color _unknownBorder = Color(0xFFE5E7EB);

  Color _elementColor(String key) {
    switch (key) {
      case 'wood':
        return const Color(0xFF1F8A5B);
      case 'fire':
        return const Color(0xFFE14C3A);
      case 'earth':
        return const Color(0xFFF0C24A);
      case 'metal':
        return const Color(0xFF9CA3AF);
      case 'water':
        return const Color(0xFF0F172A);
    }
    return _unknownBg;
  }

  String _elementLabel(String key) {
    switch (key) {
      case 'wood':
        return '목';
      case 'fire':
        return '화';
      case 'earth':
        return '토';
      case 'metal':
        return '금';
      case 'water':
        return '수';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final stem = SajuStars.stemOf(pillar);
    final branch = SajuStars.branchOf(pillar);

    final stemHanja = stem == null ? null : SajuStars.stemHanja(stem);
    final branchHanja = branch == null ? null : SajuStars.branchHanja(branch);

    final stemEl = stem == null ? null : SajuStars.stemElementKey(stem);
    final branchEl = branch == null ? null : SajuStars.branchElementKey(branch);

    final pillarHanja = SajuStars.pillarHanja(pillar);

    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          _HanjaTile(
            hanja: stemHanja,
            hangul: stem,
            elementKey: stemEl,
            elementLabel: stemEl == null ? null : _elementLabel(stemEl),
            unknownBg: _unknownBg,
            unknownBorder: _unknownBorder,
            elementColor: (k) => _elementColor(k),
          ),
          const SizedBox(height: 6),
          _HanjaTile(
            hanja: branchHanja,
            hangul: branch,
            elementKey: branchEl,
            elementLabel: branchEl == null ? null : _elementLabel(branchEl),
            unknownBg: _unknownBg,
            unknownBorder: _unknownBorder,
            elementColor: (k) => _elementColor(k),
          ),
          const SizedBox(height: 6),
          Text(pillar, style: Theme.of(context).textTheme.titleMedium),
          if (pillarHanja != null && pillarHanja.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(pillarHanja, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _HanjaTile extends StatelessWidget {
  const _HanjaTile({
    required this.hanja,
    required this.hangul,
    required this.elementKey,
    required this.elementLabel,
    required this.unknownBg,
    required this.unknownBorder,
    required this.elementColor,
  });

  final String? hanja;
  final String? hangul;
  final String? elementKey;
  final String? elementLabel;
  final Color unknownBg;
  final Color unknownBorder;
  final Color Function(String key) elementColor;

  @override
  Widget build(BuildContext context) {
    final bg = elementKey == null ? unknownBg : elementColor(elementKey!);
    final border = elementKey == null ? unknownBorder : Colors.transparent;
    final brightness = ThemeData.estimateBrightnessForColor(bg);
    final fg = brightness == Brightness.dark ? Colors.white : const Color(0xFF111827);

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
                hanja ?? '-',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
              ),
            ),
            if (hangul != null && hangul!.trim().isNotEmpty) ...[
              Positioned(
                left: 8,
                bottom: 6,
                child: Text(
                  hangul!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.92)),
                ),
              ),
            ],
            if (elementLabel != null && elementLabel!.trim().isNotEmpty) ...[
              Positioned(
                right: 8,
                top: 6,
                child: Text(
                  elementLabel!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.92)),
                ),
              ),
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
