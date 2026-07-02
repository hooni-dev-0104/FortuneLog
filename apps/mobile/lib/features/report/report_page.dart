import 'package:flutter/material.dart';

import '../../core/network/engine_api_client.dart';
import '../../core/network/engine_api_client_factory.dart';
import '../../core/network/engine_error_mapper.dart';
import '../../core/network/http_engine_api_client.dart';
import '../../core/ui/app_widgets.dart';

class ReportPageArgs {
  const ReportPageArgs({
    required this.chartId,
    this.initialReportType = 'personality',
  });

  final String chartId;
  final String initialReportType;
}

class ReportPage extends StatefulWidget {
  const ReportPage({
    super.key,
    this.args,
    EngineApiClient? engineClient,
  }) : _engineClientOverride = engineClient;

  static const routeName = '/report';

  final ReportPageArgs? args;
  final EngineApiClient? _engineClientOverride;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage>
    with SingleTickerProviderStateMixin {
  static const List<_ReportTabSpec> _tabs = [
    _ReportTabSpec(label: '성향', reportType: 'personality'),
    _ReportTabSpec(label: '연애', reportType: 'relationship'),
    _ReportTabSpec(label: '직업', reportType: 'career'),
  ];

  late final TabController _tabController;
  final Map<String, _ReportContent> _contents = {};
  final Set<String> _loadingTypes = {};
  final Map<String, String> _errors = {};
  final Map<String, String?> _requestIds = {};

  String? get _chartId {
    final chartId = widget.args?.chartId.trim();
    if (chartId == null || chartId.isEmpty) return null;
    return chartId;
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabs.indexWhere(
      (tab) => tab.reportType == widget.args?.initialReportType,
    );
    _tabController = TabController(
      length: _tabs.length,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      vsync: this,
    );
    _tabController.addListener(_loadSelectedTabIfNeeded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSelectedTab(force: false);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_loadSelectedTabIfNeeded);
    _tabController.dispose();
    super.dispose();
  }

  EngineApiClient _engineClient() {
    final override = widget._engineClientOverride;
    if (override != null) return override;

    final baseUrl = const String.fromEnvironment('ENGINE_BASE_URL');
    if (baseUrl.isEmpty) {
      throw const FormatException('ENGINE_BASE_URL is empty');
    }
    return EngineApiClientFactory.create(baseUrl: baseUrl);
  }

  String _selectedReportType() => _tabs[_tabController.index].reportType;

  void _loadSelectedTabIfNeeded() {
    if (_tabController.indexIsChanging) return;
    _loadSelectedTab(force: false);
  }

  Future<void> _loadSelectedTab({required bool force}) async {
    final reportType = _selectedReportType();
    if (!force && _contents.containsKey(reportType)) return;
    if (_loadingTypes.contains(reportType)) return;
    await _loadReport(reportType, force: force);
  }

  Future<void> _loadReport(String reportType, {required bool force}) async {
    final chartId = _chartId;
    if (chartId == null) {
      return;
    }

    setState(() {
      _loadingTypes.add(reportType);
      _errors.remove(reportType);
      _requestIds.remove(reportType);
      if (force) {
        _contents.remove(reportType);
      }
    });

    try {
      final response = await _engineClient().generateReport(
        GenerateReportRequestDto(chartId: chartId, reportType: reportType),
      );
      if (!mounted) return;
      setState(() {
        _contents[reportType] = _ReportContent.fromJson(response.content);
        _requestIds[reportType] = response.requestId;
        _loadingTypes.remove(reportType);
      });
    } on EngineApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errors[reportType] = EngineErrorMapper.userMessage(e);
        _requestIds[reportType] = e.requestId;
        _loadingTypes.remove(reportType);
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _errors[reportType] = 'ENGINE_BASE_URL이 비어 있습니다. .env 설정을 확인해주세요.';
        _loadingTypes.remove(reportType);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errors[reportType] = '리포트를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
        _loadingTypes.remove(reportType);
      });
    }
  }

  Future<void> _regenerate() async {
    await _loadSelectedTab(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final chartId = _chartId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('상세 리포트'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [for (final tab in _tabs) Tab(text: tab.label)],
        ),
      ),
      body: chartId == null
          ? const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: EmptyState(
                title: '사주 차트가 필요합니다',
                description: '출생정보로 사주 계산을 완료한 뒤 상세 리포트를 확인할 수 있습니다.',
                icon: Icons.assignment_outlined,
                tone: BadgeTone.warning,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                for (final tab in _tabs)
                  _ReportTab(
                    loading: _loadingTypes.contains(tab.reportType),
                    error: _errors[tab.reportType],
                    requestId: _requestIds[tab.reportType],
                    content: _contents[tab.reportType],
                    onRetry: () => _loadReport(tab.reportType, force: true),
                  ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child: FilledButton.icon(
          onPressed: chartId == null ? null : _regenerate,
          icon: const Icon(Icons.refresh),
          label: const Text('리포트 재생성'),
        ),
      ),
    );
  }
}

class _ReportTabSpec {
  const _ReportTabSpec({
    required this.label,
    required this.reportType,
  });

  final String label;
  final String reportType;
}

class _ReportContent {
  const _ReportContent({
    required this.summary,
    required this.strengths,
    required this.cautions,
    required this.actions,
  });

  final String summary;
  final List<String> strengths;
  final List<String> cautions;
  final List<String> actions;

  factory _ReportContent.fromJson(Map<String, dynamic> json) {
    return _ReportContent(
      summary: _stringValue(json['summary'], fallback: '요약 정보가 없습니다.'),
      strengths: _stringList(json['strengths']),
      cautions: _stringList(json['cautions']),
      actions: _stringList(json['actions']),
    );
  }

  static String _stringValue(dynamic value, {required String fallback}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return const [];
    return [text];
  }
}

class _ReportTab extends StatelessWidget {
  const _ReportTab({
    required this.loading,
    required this.error,
    required this.requestId,
    required this.content,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final String? requestId;
  final _ReportContent? content;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading && content == null) {
      return const _ReportSkeleton();
    }

    if (content == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
        children: [
          if (error != null) ...[
            StatusNotice.error(message: error!, requestId: requestId),
            const SizedBox(height: 10),
          ],
          EmptyState(
            title: '생성된 리포트가 없습니다',
            description: '선택한 탭의 리포트를 생성하면 요약, 강점, 주의 포인트, 행동 가이드가 표시됩니다.',
            actionText: '리포트 생성',
            onAction: onRetry,
            icon: Icons.article_outlined,
            tone: BadgeTone.info,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
      children: [
        if (error != null) ...[
          StatusNotice.error(message: error!, requestId: requestId),
          const SizedBox(height: 10),
        ],
        PageSection(
          title: '요약',
          child: Text(content!.summary,
              style: Theme.of(context).textTheme.bodyLarge),
        ),
        const SizedBox(height: 10),
        PageSection(
          title: '강점',
          child: AppTextList(
            items: content!.strengths,
            marker: AppListMarker.check,
            emptyText: '강점 정보가 없습니다.',
          ),
        ),
        const SizedBox(height: 10),
        PageSection(
          title: '주의 포인트',
          child: AppTextList(
            items: content!.cautions,
            marker: AppListMarker.bullet,
            emptyText: '주의 포인트 정보가 없습니다.',
          ),
        ),
        const SizedBox(height: 10),
        PageSection(
          title: '행동 가이드',
          subtitle: '즉시 실행 가능한 체크리스트',
          child: AppTextList(
            items: content!.actions,
            marker: AppListMarker.check,
            emptyText: '행동 가이드가 없습니다.',
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
        AppSkeleton(height: 120),
        SizedBox(height: 10),
        AppSkeleton(height: 90),
        SizedBox(height: 10),
        AppSkeleton(height: 90),
        SizedBox(height: 10),
        AppSkeleton(height: 140),
      ],
    );
  }
}
