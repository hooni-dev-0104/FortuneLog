import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/network/engine_api_client.dart';
import '../../core/network/http_engine_api_client.dart';

class DevTestPage extends StatefulWidget {
  const DevTestPage({super.key});

  @override
  State<DevTestPage> createState() => _DevTestPageState();
}

class _DevTestPageState extends State<DevTestPage> {
  final _baseUrlController = TextEditingController(text: 'http://localhost:8080');
  final _tokenController = TextEditingController();
  final _userIdController = TextEditingController();
  final _birthProfileIdController = TextEditingController();
  final _birthDateController = TextEditingController(text: '1994-11-21');
  final _birthTimeController = TextEditingController(text: '14:30');
  final _birthTimezoneController = TextEditingController(text: 'Asia/Seoul');
  final _birthLocationController = TextEditingController(text: 'Seoul, KR');
  final _genderController = TextEditingController(text: 'female');
  final _reportTypeController = TextEditingController(text: 'career');
  final _dateController = TextEditingController(text: '2026-02-14');

  bool _unknownBirthTime = false;
  String _calendarType = 'solar';
  String _chartId = '';
  String _result = '';
  bool _loading = false;

  Future<void> _calculateChart() async {
    await _withLoading(() async {
      final client = _client;
      final response = await client.calculateChart(
        CalculateChartRequestDto(
          userId: _userIdController.text.trim(),
          birthProfileId: _birthProfileIdController.text.trim(),
          birthDate: _birthDateController.text.trim(),
          birthTime: _birthTimeController.text.trim(),
          birthTimezone: _birthTimezoneController.text.trim(),
          birthLocation: _birthLocationController.text.trim(),
          calendarType: _calendarType,
          leapMonth: false,
          gender: _genderController.text.trim(),
          unknownBirthTime: _unknownBirthTime,
        ),
      );
      _chartId = response.chartId;
      _setResult({
        'action': 'calculateChart',
        'chartId': response.chartId,
        'engineVersion': response.engineVersion,
        'chart': response.chart,
        'fiveElements': response.fiveElements,
      });
    });
  }

  Future<void> _generateReport() async {
    await _withLoading(() async {
      final chartId = _resolveChartId();
      final response = await _client.generateReport(
        GenerateReportRequestDto(
          userId: _userIdController.text.trim(),
          chartId: chartId,
          reportType: _reportTypeController.text.trim(),
        ),
      );
      _setResult({
        'action': 'generateReport',
        'chartId': response.chartId,
        'reportType': response.reportType,
        'content': response.content,
      });
    });
  }

  Future<void> _generateDailyFortune() async {
    await _withLoading(() async {
      final chartId = _resolveChartId();
      final response = await _client.generateDailyFortune(
        GenerateDailyFortuneRequestDto(
          userId: _userIdController.text.trim(),
          chartId: chartId,
          date: _dateController.text.trim(),
        ),
      );
      _setResult({
        'action': 'generateDailyFortune',
        'userId': response.userId,
        'date': response.date,
        'score': response.score,
        'category': response.category,
        'actions': response.actions,
      });
    });
  }

  String _resolveChartId() {
    if (_chartId.isNotEmpty) {
      return _chartId;
    }
    throw const EngineApiException(
      code: 'CHART_ID_REQUIRED',
      message: 'calculate chart first, or keep returned chartId in state',
    );
  }

  HttpEngineApiClient get _client => HttpEngineApiClient(
    baseUrl: _baseUrlController.text.trim(),
    tokenProvider: _ManualTokenProvider(_tokenController.text.trim()),
  );

  Future<void> _withLoading(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } catch (e) {
      _setResult({'error': e.toString()});
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _setResult(Map<String, dynamic> json) {
    final encoder = const JsonEncoder.withIndent('  ');
    setState(() {
      _result = encoder.convert(json);
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    _userIdController.dispose();
    _birthProfileIdController.dispose();
    _birthDateController.dispose();
    _birthTimeController.dispose();
    _birthTimezoneController.dispose();
    _birthLocationController.dispose();
    _genderController.dispose();
    _reportTypeController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FortuneLog Dev Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_baseUrlController, 'Engine Base URL'),
          _field(_tokenController, 'Supabase Access Token (JWT)'),
          _field(_userIdController, 'User ID (UUID)'),
          _field(_birthProfileIdController, 'Birth Profile ID (UUID)'),
          _field(_birthDateController, 'Birth Date (YYYY-MM-DD)'),
          _field(_birthTimeController, 'Birth Time (HH:mm)'),
          _field(_birthTimezoneController, 'Birth Timezone'),
          _field(_birthLocationController, 'Birth Location'),
          _field(_genderController, 'Gender (male/female/other)'),
          _field(_reportTypeController, 'Report Type'),
          _field(_dateController, 'Fortune Date (YYYY-MM-DD)'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _calendarType,
            items: const [
              DropdownMenuItem(value: 'solar', child: Text('solar')),
              DropdownMenuItem(value: 'lunar', child: Text('lunar (not supported yet)')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _calendarType = value);
            },
            decoration: const InputDecoration(labelText: 'Calendar Type'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _unknownBirthTime,
            onChanged: (value) => setState(() => _unknownBirthTime = value ?? false),
            title: const Text('Unknown Birth Time'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _loading ? null : _calculateChart,
                child: const Text('1) Calculate Chart'),
              ),
              FilledButton(
                onPressed: _loading ? null : _generateReport,
                child: const Text('2) Generate Report'),
              ),
              FilledButton(
                onPressed: _loading ? null : _generateDailyFortune,
                child: const Text('3) Daily Fortune'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(
            _result.isEmpty ? 'Result will appear here.' : _result,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }
}

class _ManualTokenProvider implements AccessTokenProvider {
  final String token;

  const _ManualTokenProvider(this.token);

  @override
  Future<String?> getAccessToken() async => token;
}
