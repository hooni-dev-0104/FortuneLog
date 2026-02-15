import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_widgets.dart';
import '../../core/network/engine_api_client_factory.dart';
import '../../core/network/engine_api_client.dart';
import '../../core/network/http_engine_api_client.dart';
import '../birth/birth_input_page.dart';

class DailyFortunePage extends StatefulWidget {
  const DailyFortunePage({super.key});

  @override
  State<DailyFortunePage> createState() => _DailyFortunePageState();
}

class _DailyFortunePageState extends State<DailyFortunePage> {
  bool _loading = false;
  String? _error;
  String? _requestId;
  bool _missingChart = false;

  Map<String, dynamic>? _content;

  SupabaseClient _supabase() => Supabase.instance.client;

  EngineApiClient _engineClient() {
    final baseUrl = const String.fromEnvironment('ENGINE_BASE_URL');
    if (baseUrl.isEmpty) {
      throw const FormatException('ENGINE_BASE_URL is empty');
    }
    return EngineApiClientFactory.create(baseUrl: baseUrl);
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _requestId = null;
      _missingChart = false;
    });

    try {
      final session = _supabase().auth.currentSession;
      if (session == null) {
        throw StateError('로그인이 필요합니다.');
      }

      final userId = session.user.id;
      final today = _todayDateString();

      List<dynamic> rows;
      try {
        // Preferred schema: reports.target_date exists.
        rows = await _supabase()
            .from('reports')
            .select('id, content_json, target_date, created_at')
            .eq('user_id', userId)
            .eq('report_type', 'daily')
            .eq('target_date', today)
            .order('created_at', ascending: false)
            .limit(1);
      } on PostgrestException catch (e) {
        // Backward-compatible schema: reports.target_date doesn't exist yet.
        // Fall back to "latest daily report" and validate the embedded content date.
        final msg = e.message.toLowerCase();
        if (!msg.contains('target_date') || !msg.contains('does not exist')) rethrow;

        rows = await _supabase()
            .from('reports')
            .select('id, content_json, created_at')
            .eq('user_id', userId)
            .eq('report_type', 'daily')
            .order('created_at', ascending: false)
            .limit(1);
      }

      if (rows.isEmpty) {
        setState(() {
          _loading = false;
          _content = null;
        });
        return;
      }

      final row = rows.first as Map<String, dynamic>;
      final content = row['content_json'] as Map<String, dynamic>;

      // If we used the fallback query (no target_date), ensure this record is for "today".
      final contentDate = content['date']?.toString();
      if (contentDate != null && contentDate.isNotEmpty && contentDate != today) {
        setState(() {
          _loading = false;
          _content = null;
        });
        return;
      }

      setState(() {
        _loading = false;
        _content = content;
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
        _error = '오늘 운세를 불러오지 못했습니다.';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<String> _fetchLatestChartId() async {
    final session = _supabase().auth.currentSession;
    if (session == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final userId = session.user.id;
    final rows = await _supabase()
        .from('saju_charts')
        .select('id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) {
      throw StateError('사주 차트가 없습니다. 먼저 출생정보 입력 후 계산을 완료해주세요.');
    }

    final row = rows.first;
    return row['id'] as String;
  }

  Future<void> _generateToday() async {
    setState(() {
      _loading = true;
      _error = null;
      _requestId = null;
      _missingChart = false;
    });

    try {
      final chartId = await _fetchLatestChartId();
      final today = _todayDateString();

      final response = await _engineClient().generateDailyFortune(
        GenerateDailyFortuneRequestDto(
          chartId: chartId,
          date: today,
        ),
      );
      _requestId = response.requestId;
      await _refresh();
    } on EngineApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
        _requestId = e.requestId;
      });
    } on FormatException {
      setState(() {
        _loading = false;
        _error = 'ENGINE_BASE_URL이 비어 있습니다. .env 설정을 확인해주세요.';
      });
    } on StateError catch (e) {
      setState(() {
        _loading = false;
        _missingChart = e.message.contains('사주 차트가 없습니다');
        _error = _missingChart ? null : e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = '오늘 운세 생성에 실패했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PageLoading(title: '불러오는 중', message: '오늘 운세를 준비하고 있어요.');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        // "차트 없음"은 정상적인 온보딩 상태이므로 에러 박스로 보이지 않게 한다.
        if (_error != null && !_missingChart) ...[
          StatusNotice.error(message: _error!, requestId: _requestId ?? 'daily'),
          const SizedBox(height: 10),
        ],
        if (_content == null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _missingChart
                  ? EmptyState(
                      title: '사주 차트가 없습니다',
                      description: '먼저 출생정보를 입력하고 사주 계산을 완료해주세요.',
                      actionText: '출생정보 입력',
                      onAction: () => Navigator.pushNamed(context, BirthInputPage.routeName),
                    )
                  : EmptyState(
                      title: '오늘 운세가 아직 없습니다',
                      description: '오늘 기준 데이터가 없어 지금 바로 생성이 필요합니다.',
                      actionText: '오늘 운세 생성',
                      onAction: _generateToday,
                    ),
              const SizedBox(height: 10),
              // Even when the failure reason isn't the "missing chart" message,
              // provide an escape hatch to the required input screen.
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, BirthInputPage.routeName),
                child: const Text('출생정보 입력'),
              ),
            ],
          )
        else ...[
          PageSection(
            title: '오늘 점수 ${_content!['score'] ?? '-'}점',
            subtitle: '기준일: ${_content!['date'] ?? _todayDateString()} (Asia/Seoul)',
            trailing: FilledButton.tonal(onPressed: _refresh, child: const Text('새로고침')),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('총평: ${(_content!['summary'] ?? '오늘 액션을 확인해보세요.').toString()}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          PageSection(
            title: '카테고리',
            child: _CategoryList(category: _content!['category'] as Map<String, dynamic>?),
          ),
          const SizedBox(height: 10),
          PageSection(
            title: '오늘 액션',
            child: _ActionList(actions: _content!['actions'] as List<dynamic>?),
          ),
        ],
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.category});

  final Map<String, dynamic>? category;

  @override
  Widget build(BuildContext context) {
    final c = category;
    if (c == null || c.isEmpty) {
      return const Text('카테고리 정보가 없습니다.');
    }

    final entries = c.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${e.key}: ${e.value}'),
            ),
          )
          .toList(),
    );
  }
}

class _ActionList extends StatelessWidget {
  const _ActionList({required this.actions});

  final List<dynamic>? actions;

  @override
  Widget build(BuildContext context) {
    final list = actions;
    if (list == null || list.isEmpty) {
      return const Text('액션 정보가 없습니다.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${i + 1}. ${list[i]}'),
          ),
      ],
    );
  }
}
