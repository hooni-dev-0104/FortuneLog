import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_widgets.dart';
import '../../core/ui/korean_cities.dart';
import '../../core/network/location_search_client.dart';
import '../../core/network/engine_api_client_factory.dart';
import '../../core/network/engine_api_client.dart';
import '../../core/network/http_engine_api_client.dart';
import '../home/home_page.dart';

class BirthInputPage extends StatefulWidget {
  const BirthInputPage({super.key, this.initialProfile});

  static const routeName = '/birth-input';

  final Map<String, dynamic>? initialProfile;

  @override
  State<BirthInputPage> createState() => _BirthInputPageState();
}

class _BirthInputPageState extends State<BirthInputPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _locationController;
  late final FocusNode _locationFocusNode;
  late final LocationSearchClient _locationSearchClient;
  Timer? _locationDebounce;
  String _lastLocationQuery = '';
  bool _locationSearching = false;
  List<LocationSuggestion> _locationSuggestions = const [];

  String? _editingBirthProfileId;

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _parseDate(_dateController.text.trim()) ?? DateTime(now.year - 30, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: '생년월일 선택',
    );
    if (picked == null) return;
    _dateController.text =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {});
  }

  Future<void> _pickBirthTime() async {
    if (_unknownBirthTime) return;
    final initial = _parseTime(_timeController.text.trim()) ?? const TimeOfDay(hour: 12, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: '출생시간 선택',
    );
    if (picked == null) return;
    _timeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {});
  }

  DateTime? _parseDate(String v) {
    try {
      final parts = v.split('-').map((e) => int.parse(e)).toList();
      if (parts.length != 3) return null;
      return DateTime(parts[0], parts[1], parts[2]);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseTime(String v) {
    try {
      final parts = v.split(':').map((e) => int.parse(e)).toList();
      if (parts.length != 2) return null;
      return TimeOfDay(hour: parts[0], minute: parts[1]);
    } catch (_) {
      return null;
    }
  }

  bool _unknownBirthTime = false;
  bool _isLunar = false;
  bool _isLeapMonth = false;
  String _gender = 'female';
  bool _saving = false;
  String? _error;
  String? _lastRequestId;

  List<String> _summaryErrors = const [];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _editingBirthProfileId = p?['id'] as String?;
    _locationSearchClient = LocationSearchClient();

    _unknownBirthTime = (p?['unknown_birth_time'] as bool?) ?? false;
    _isLunar = ((p?['calendar_type'] as String?) ?? 'solar') == 'lunar';
    _isLeapMonth = (p?['is_leap_month'] as bool?) ?? false;
    _gender = (p?['gender'] as String?) ?? 'female';

    if (p == null) {
      _dateController = TextEditingController(text: '');
      _timeController = TextEditingController(text: '');
      _locationController = TextEditingController(text: '');
      _locationFocusNode = FocusNode();
      return;
    }

    final dt = (p['birth_datetime_local'] as String?) ?? '';
    final date = dt.contains('T') ? dt.split('T').first : '';
    final time = dt.contains('T') ? dt.split('T').last.substring(0, 5) : '';

    _dateController = TextEditingController(text: date);
    _timeController = TextEditingController(text: time);
    _locationController = TextEditingController(text: (p['birth_location'] as String?) ?? '');
    _locationFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    _locationFocusNode.dispose();
    _locationDebounce?.cancel();
    _locationSearchClient.dispose();
    super.dispose();
  }

  void _onLocationChanged(String value) {
    final q = value.trim();
    if (q == _lastLocationQuery) return;
    _lastLocationQuery = q;

    _locationDebounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _locationSearching = false;
        _locationSuggestions = const [];
      });
      return;
    }

    // Show local suggestions immediately while we fetch a full search result set.
    final local = koreanCitySuggestions
        .where((c) => c.startsWith(q) || c.contains(q))
        .take(8)
        .map((c) => LocationSuggestion(label: c, value: c))
        .toList(growable: false);
    setState(() => _locationSuggestions = local);

    _locationDebounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _locationSearching = true);
      try {
        final results = await _locationSearchClient.searchKoreaCities(q);
        if (!mounted) return;
        // If user typed more while we were fetching, ignore stale results.
        if (_lastLocationQuery != q) return;
        setState(() {
          _locationSearching = false;
          _locationSuggestions = results.isEmpty ? local : results;
        });
      } catch (_) {
        if (!mounted) return;
        if (_lastLocationQuery != q) return;
        setState(() => _locationSearching = false);
      }
    });
  }

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

      final payload = <String, dynamic>{
        'birth_datetime_local': birthDatetime,
        'birth_timezone': birthTimezone,
        'birth_location': _locationController.text.trim(),
        'calendar_type': _isLunar ? 'lunar' : 'solar',
        'is_leap_month': _isLeapMonth,
        'gender': _gender,
        'unknown_birth_time': _unknownBirthTime,
      };

      String birthProfileId;
      if (_editingBirthProfileId != null && _editingBirthProfileId!.isNotEmpty) {
        final row = await supabase
            .from('birth_profiles')
            .update(payload)
            .eq('id', _editingBirthProfileId!)
            .eq('user_id', userId)
            .select('id')
            .single();
        birthProfileId = row['id'] as String;
      } else {
        // Enforce "single birth profile per user" at the app level too:
        // if one exists, update it; otherwise insert.
        try {
          final existing = await supabase
              .from('birth_profiles')
              .select('id')
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          final existingId = existing?['id'] as String?;
          if (existingId != null && existingId.isNotEmpty) {
            final row = await supabase
                .from('birth_profiles')
                .update(payload)
                .eq('id', existingId)
                .eq('user_id', userId)
                .select('id')
                .single();
            birthProfileId = row['id'] as String;
          } else {
            final row = await supabase
                .from('birth_profiles')
                .insert({
                  'user_id': userId,
                  ...payload,
                })
                .select('id')
                .single();
            birthProfileId = row['id'] as String;
          }
        } on PostgrestException {
          // Fallback: if the environment doesn't support maybeSingle or ordering,
          // insert and rely on DB constraints/migrations to clean up.
          final row = await supabase
              .from('birth_profiles')
              .insert({
                'user_id': userId,
                ...payload,
              })
              .select('id')
              .single();
          birthProfileId = row['id'] as String;
        }
      }

      final client = _engineClient();
      final chartResponse = await client.calculateChart(
        CalculateChartRequestDto(
          birthProfileId: birthProfileId,
          birthDate: _dateController.text.trim(),
          birthTime: _unknownBirthTime ? '12:00' : _timeController.text.trim(),
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
      _error = kDebugMode
          ? 'ENGINE_BASE_URL이 비어 있습니다. .env 설정을 확인해주세요.'
          : '운세 계산 서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.';
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
    final isEdit = _editingBirthProfileId != null && _editingBirthProfileId!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '출생정보 수정' : '출생정보 입력')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Text(
            '사주 계산에 사용할 정보를 입력해주세요.\n입력값은 운세/리포트 생성에만 사용됩니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: '생년월일',
                          hintText: 'YYYY-MM-DD',
                          suffixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                        onTap: _pickBirthDate,
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
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: '출생시간',
                          hintText: 'HH:mm',
                          suffixIcon: Icon(Icons.schedule_outlined),
                        ),
                        onTap: _pickBirthTime,
                        validator: (v) {
                          if (_unknownBirthTime) return null;
                          if (v == null || v.trim().isEmpty) return '출생시간을 입력해주세요.';
                          if (!v.contains(':')) return 'HH:mm 형식으로 입력해주세요.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      RawAutocomplete<LocationSuggestion>(
                        focusNode: _locationFocusNode,
                        textEditingController: _locationController,
                        optionsBuilder: (value) {
                          final q = value.text.trim();
                          if (q.isEmpty) return const Iterable<LocationSuggestion>.empty();
                          return _locationSuggestions
                              .where((s) => s.value.startsWith(q) || s.value.contains(q))
                              .take(8);
                        },
                        displayStringForOption: (o) => o.value,
                        onSelected: (selection) {
                          _locationController.text = selection.value;
                          setState(() {});
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            onChanged: _onLocationChanged,
                            decoration: const InputDecoration(
                              labelText: '출생 지역(도시)',
                              hintText: '예: 서울',
                              suffixIcon: Icon(Icons.location_on_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return '출생 지역을 입력해주세요.';
                              return null;
                            },
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 260, maxWidth: 420),
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final o = options.elementAt(index);
                                    return ListTile(
                                      dense: true,
                                      title: Text(o.label),
                                      trailing: _locationSearching && index == 0
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                          : null,
                                      onTap: () => onSelected(o),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
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
              : Text(isEdit ? '수정하고 결과 보기' : '저장하고 결과 보기'),
        ),
      ),
    );
  }
}
