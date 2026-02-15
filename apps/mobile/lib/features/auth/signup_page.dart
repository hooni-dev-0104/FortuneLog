import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/engine_api_client.dart';
import '../../core/network/engine_api_client_factory.dart';
import '../../core/network/http_engine_api_client.dart';
import '../../core/ui/app_widgets.dart';
import '../../core/ui/korean_cities.dart';
import '../../core/saju/saju_chart_persistence.dart';
import '../app/app_gate.dart';
import 'auth_error_mapper.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  static const routeName = '/signup';

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();

  final _dateController = TextEditingController(text: '');
  final _timeController = TextEditingController(text: '');
  final _locationController = TextEditingController(text: '');

  bool _unknownBirthTime = false;
  bool _isLunar = false;
  bool _isLeapMonth = false;
  String _gender = 'female';

  bool _loading = false;
  String? _error;
  bool _alreadyRegistered = false;
  List<String> _summaryErrors = const [];

  SupabaseClient _supabase() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('서비스 연결에 실패했습니다. 앱을 다시 실행해주세요.');
    }
  }

  EngineApiClient _engineClient() {
    final baseUrl = const String.fromEnvironment('ENGINE_BASE_URL');
    if (baseUrl.isEmpty) {
      throw const FormatException('ENGINE_BASE_URL is empty');
    }
    return EngineApiClientFactory.create(baseUrl: baseUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _alreadyRegistered = false;
      _summaryErrors = const [];
    });

    final errors = <String>[];
    if (!_formKey.currentState!.validate()) {
      errors.add('필수 입력값을 확인해주세요.');
    }
    if (_isLeapMonth && !_isLunar) {
      errors.add('윤달은 음력 선택 시에만 설정할 수 있습니다.');
    }
    if (!_unknownBirthTime && _timeController.text.trim().isEmpty) {
      errors.add('출생시간을 선택하거나 “출생시간 미상”을 켜주세요.');
    }
    if (errors.isNotEmpty) {
      setState(() => _summaryErrors = errors);
      return;
    }

    setState(() => _loading = true);
    try {
      final supabase = _supabase();

      // 1) Create account. We intentionally don't force emailRedirectTo here.
      //    If the Supabase project requires email confirmation, session may be null.
      final auth = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'display_name': _nameController.text.trim(),
        },
      );

      // Prefer immediate session. If not available, try signing in right away.
      // Some Supabase configurations return null session on signUp.
      var session = auth.session ?? supabase.auth.currentSession;
      if (session == null) {
        try {
          final signedIn = await supabase.auth.signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          session = signedIn.session ?? supabase.auth.currentSession;
        } on AuthException catch (e) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            // Common case: "Email not confirmed" when confirmations are enabled in Supabase.
            _error = e.message.toLowerCase().contains('confirm')
                ? '회원가입은 완료됐지만, 현재 설정상 이메일 인증 후에만 로그인할 수 있습니다.'
                : '회원가입은 완료됐지만, 바로 로그인할 수 없습니다. 로그인 화면에서 다시 로그인해주세요.';
          });
          return;
        }
      }

      if (session == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '회원가입은 완료됐지만, 바로 로그인할 수 없습니다. 로그인 화면에서 다시 로그인해주세요.';
        });
        return;
      }

      final userId = session.user.id;

      // 2) Insert birth profile (single profile per user in current UX).
      final timePart = _unknownBirthTime ? '12:00:00' : '${_timeController.text.trim()}:00';
      final birthDatetime = '${_dateController.text.trim()}T$timePart';
      const birthTimezone = 'Asia/Seoul';

      final payload = <String, dynamic>{
        'user_id': userId,
        'birth_datetime_local': birthDatetime,
        'birth_timezone': birthTimezone,
        'birth_location': _locationController.text.trim(),
        'calendar_type': _isLunar ? 'lunar' : 'solar',
        'is_leap_month': _isLeapMonth,
        'gender': _gender,
        'unknown_birth_time': _unknownBirthTime,
      };

      final row = await supabase.from('birth_profiles').insert(payload).select('id').single();
      final birthProfileId = row['id'] as String;

      // 3) Calculate chart and persist.
      final chartResponse = await _engineClient().calculateChart(
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

      // In some dev environments the engine might be configured against a different Supabase project.
      // Ensure the chart exists in the same Supabase the app reads from so Dashboard is never empty after signup.
      await SajuChartPersistence.ensureSavedFromResponse(
        supabase: supabase,
        userId: userId,
        birthProfileId: birthProfileId,
        response: chartResponse,
      );

      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pushNamedAndRemoveUntil(context, AppGate.routeName, (route) => false);
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = AuthErrorMapper.userMessage(e, flow: AuthContextFlow.signup);
      final already = AuthErrorMapper.isUserAlreadyRegisteredMessage(e.message);
      setState(() {
        _loading = false;
        _alreadyRegistered = already;
        _error = msg;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on EngineApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = kDebugMode
            ? 'ENGINE_BASE_URL이 비어 있습니다. .env 설정을 확인해주세요.'
            : '운세 계산 서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.';
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '회원가입 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Text('회원가입하고 사주 계산을 시작해요', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('필수 정보만 간단히 입력하면 바로 결과를 볼 수 있어요.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          if (_summaryErrors.isNotEmpty) ...[
            StatusNotice.error(message: _summaryErrors.join('\n'), requestId: 'signup-validate'),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            StatusNotice.error(message: _error!, requestId: 'signup-submit'),
            if (_alreadyRegistered) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          Navigator.pushReplacementNamed(
                            context,
                            LoginPage.routeName,
                            arguments: _emailController.text.trim(),
                          );
                        },
                  child: const Text('로그인으로 이동'),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          Form(
            key: _formKey,
            child: Column(
              children: [
                PageSection(
                  title: '계정 정보',
                  subtitle: '이름, 이메일, 비밀번호',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '이름'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '이름을 입력해주세요.';
                          if (v.trim().length < 2) return '이름을 2자 이상 입력해주세요.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '이메일'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '이메일을 입력해주세요.';
                          if (!v.contains('@')) return '이메일 형식이 올바르지 않습니다.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '비밀번호'),
                        validator: (v) {
                          if (v == null || v.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password2Controller,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: '비밀번호 확인'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return '비밀번호 확인을 입력해주세요.';
                          if (v != _passwordController.text) return '비밀번호가 일치하지 않습니다.';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                PageSection(
                  title: '사주 계산 정보',
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
                      const SizedBox(height: 10),
                      if (_isLunar)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('윤달'),
                          value: _isLeapMonth,
                          onChanged: (v) => setState(() => _isLeapMonth = v),
                        ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(labelText: '성별'),
                        items: const [
                          DropdownMenuItem(value: 'female', child: Text('여성')),
                          DropdownMenuItem(value: 'male', child: Text('남성')),
                        ],
                        onChanged: (value) => setState(() => _gender = value ?? 'female'),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('출생시간 미상'),
                        subtitle: const Text('기본값(정오)으로 계산됩니다.'),
                        value: _unknownBirthTime,
                        onChanged: (v) => setState(() => _unknownBirthTime = v),
                      ),
                      const SizedBox(height: 10),
                      if (!_unknownBirthTime)
                        TextFormField(
                          controller: _timeController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: '출생시간',
                            hintText: 'HH:mm',
                            suffixIcon: Icon(Icons.schedule_outlined),
                          ),
                          onTap: _pickBirthTime,
                        ),
                      const SizedBox(height: 12),
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue value) {
                          final q = value.text.trim();
                          if (q.isEmpty) return const Iterable<String>.empty();
                          return koreanCitySuggestions
                              .where((c) => c.startsWith(q) || c.contains(q))
                              .take(10);
                        },
                        fieldViewBuilder: (context, controller, focusNode, _) {
                          controller.text = _locationController.text;
                          controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: controller.text.length),
                          );
                          controller.addListener(() {
                            _locationController.text = controller.text;
                          });
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: '출생지(선택)',
                              hintText: '예: 서울',
                            ),
                          );
                        },
                        onSelected: (s) => setState(() => _locationController.text = s),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('가입하고 사주 계산하기'),
          ),
        ],
      ),
    );
  }
}
