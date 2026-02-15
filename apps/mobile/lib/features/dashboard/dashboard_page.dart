import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_widgets.dart';
import '../../core/network/engine_api_client.dart';
import '../../core/network/engine_api_client_factory.dart';
import '../../core/network/http_engine_api_client.dart';
import '../birth/birth_input_page.dart';
import '../report/report_page.dart';

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
        _error = 'ENGINE_BASE_URL이 비어 있습니다. .env 설정을 확인해주세요.';
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
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        if (_error != null) ...[
          StatusNotice.error(message: _error!, requestId: _requestId ?? 'dashboard'),
          const SizedBox(height: 10),
        ],
        if (_chart == null || _fiveElements == null) ...[
          EmptyState(
            title: '아직 사주 결과가 없습니다',
            description: '출생정보로 사주 계산을 완료하면 대시보드에 표시됩니다.',
            actionText: '출생정보 입력',
            onAction: () => Navigator.pushNamed(context, BirthInputPage.routeName),
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
            title: '사주 4주',
            subtitle: '연/월/일/시 기준',
            child: Row(
              children: [
                _PillarCard(label: '연주', value: _chart!['year'] ?? '-'),
                const SizedBox(width: 8),
                _PillarCard(label: '월주', value: _chart!['month'] ?? '-'),
                const SizedBox(width: 8),
                _PillarCard(label: '일주', value: _chart!['day'] ?? '-'),
                const SizedBox(width: 8),
                _PillarCard(label: '시주', value: _chart!['hour'] ?? '-'),
              ],
            ),
          ),
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
