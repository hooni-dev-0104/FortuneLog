import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_widgets.dart';
import '../../core/network/engine_api_client_factory.dart';
import '../../core/network/engine_api_client.dart';
import '../../core/network/http_engine_api_client.dart';
import '../home/home_page.dart';

class BirthInputPage extends StatefulWidget {
  const BirthInputPage({super.key});

  static const routeName = '/birth-input';

  @override
  State<BirthInputPage> createState() => _BirthInputPageState();
}

class _BirthInputPageState extends State<BirthInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController(text: '1994-11-21');
  final _timeController = TextEditingController(text: '14:30');
  final _locationController = TextEditingController(text: 'Seoul, KR');

  bool _unknownBirthTime = false;
  bool _isLunar = false;
  bool _isLeapMonth = false;
  String _gender = 'female';
  bool _saving = false;
  String? _error;
  String? _lastRequestId;

  List<String> _summaryErrors = const [];

  EngineApiClient _engineClient() {
    final baseUrl = const String.fromEnvironment('ENGINE_BASE_URL');
    if (baseUrl.isEmpty) {
      throw const FormatException('ENGINE_BASE_URL is empty');
    }
    return EngineApiClientFactory.create(baseUrl: baseUrl);
  }

  Future<void> _validateAndSubmit() async {
    final errors = <String>[];

    if (!_formKey.currentState!.validate()) {
      errors.add('필수 입력값을 확인해주세요.');
    }

    if (_isLeapMonth && !_isLunar) {
      errors.add('윤달은 음력 선택 시에만 설정할 수 있습니다.');
    }

    if (errors.isNotEmpty) {
      setState(() => _summaryErrors = errors);
      return;
    }

    setState(() {
      _summaryErrors = const [];
      _saving = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) {
        throw StateError('로그인이 필요합니다.');
      }

      final userId = session.user.id;
      final timePart = _unknownBirthTime ? '12:00:00' : '${_timeController.text.trim()}:00';
      final birthDatetime = '${_dateController.text.trim()}T$timePart';

      // For now, timezone is fixed to Asia/Seoul in the production UX. (DevTest lets you override it.)
      const birthTimezone = 'Asia/Seoul';

      final row = await supabase
          .from('birth_profiles')
          .insert({
            'user_id': userId,
            'birth_datetime_local': birthDatetime,
            'birth_timezone': birthTimezone,
            'birth_location': _locationController.text.trim(),
            'calendar_type': _isLunar ? 'lunar' : 'solar',
            'is_leap_month': _isLeapMonth,
            'gender': _gender,
            'unknown_birth_time': _unknownBirthTime,
          })
          .select('id')
          .single();

      final birthProfileId = row['id'] as String;

      final client = _engineClient();
      final chartResponse = await client.calculateChart(
        CalculateChartRequestDto(
          birthProfileId: birthProfileId,
          birthDate: _dateController.text.trim(),
          birthTime: _timeController.text.trim(),
          birthTimezone: birthTimezone,
          birthLocation: _locationController.text.trim(),
          calendarType: _isLunar ? 'lunar' : 'solar',
          leapMonth: _isLeapMonth,
          gender: _gender,
          unknownBirthTime: _unknownBirthTime,
        ),
      );
      _lastRequestId = chartResponse.requestId;
    } on StateError catch (e) {
      _error = e.message;
    } on PostgrestException catch (e) {
      _error = e.message;
    } on EngineApiException catch (e) {
      _error = e.message;
      _lastRequestId = e.requestId;
    } on FormatException {
      _error = 'ENGINE_BASE_URL이 비어 있습니다. .env 설정을 확인해주세요.';
    } catch (_) {
      _error = '저장 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (_error != null) {
      return;
    }

    Navigator.pushReplacementNamed(context, HomePage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('출생정보 입력')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Text('사주 계산에 사용할 정보를 입력해주세요.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          if (_summaryErrors.isNotEmpty) ...[
            StatusNotice.error(message: _summaryErrors.join('\n'), requestId: 'dev-birth-validate'),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            StatusNotice.error(message: _error!, requestId: _lastRequestId ?? 'birth-submit'),
            const SizedBox(height: 12),
          ],
          Form(
            key: _formKey,
            child: Column(
              children: [
                PageSection(
                  title: '기본 정보',
                  subtitle: '필수값: 생년월일, 달력종류, 성별',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: '생년월일',
                          hintText: 'YYYY-MM-DD',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '생년월일을 입력해주세요.';
                          final parts = v.split('-');
                          if (parts.length != 3) return 'YYYY-MM-DD 형식으로 입력해주세요.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('양력')),
                          ButtonSegment(value: true, label: Text('음력')),
                        ],
                        selected: {_isLunar},
                        onSelectionChanged: (value) {
                          setState(() {
                            _isLunar = value.first;
                            if (!_isLunar) _isLeapMonth = false;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(labelText: '성별'),
                        items: const [
                          DropdownMenuItem(value: 'female', child: Text('여성')),
                          DropdownMenuItem(value: 'male', child: Text('남성')),
                        ],
                        onChanged: (value) => setState(() => _gender = value ?? 'female'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                PageSection(
                  title: '시간 / 장소',
                  subtitle: '출생시간이 없으면 정확도 안내 문구가 함께 노출됩니다.',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('출생시간 미상'),
                        subtitle: const Text('기본값(정오)으로 계산되어 일부 해석 정밀도가 낮아질 수 있습니다.'),
                        value: _unknownBirthTime,
                        onChanged: (v) => setState(() => _unknownBirthTime = v),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _timeController,
                        enabled: !_unknownBirthTime,
                        decoration: const InputDecoration(
                          labelText: '출생시간',
                          hintText: 'HH:mm',
                        ),
                        validator: (v) {
                          if (_unknownBirthTime) return null;
                          if (v == null || v.trim().isEmpty) return '출생시간을 입력해주세요.';
                          if (!v.contains(':')) return 'HH:mm 형식으로 입력해주세요.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(labelText: '출생지', hintText: '예: Seoul, KR'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '출생지를 입력해주세요.';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                PageSection(
                  title: '캘린더 옵션',
                  subtitle: '음력 선택 시 윤달 설정 가능',
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isLeapMonth,
                    onChanged: _isLunar ? (v) => setState(() => _isLeapMonth = v ?? false) : null,
                    title: const Text('윤달'),
                    subtitle: Text(
                      _isLunar ? '실제 출생 월이 윤달이면 체크해주세요.' : '윤달은 음력 선택 시 활성화됩니다.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child: FilledButton(
          onPressed: _saving ? null : () => _validateAndSubmit(),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('저장하고 결과 보기'),
        ),
      ),
    );
  }
}
