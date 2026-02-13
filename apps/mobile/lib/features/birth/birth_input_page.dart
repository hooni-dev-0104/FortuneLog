import 'package:flutter/material.dart';

import '../../core/ui/app_widgets.dart';
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

  List<String> _summaryErrors = const [];

  void _validateAndSubmit() async {
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
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _saving = false);

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
          onPressed: _saving ? null : _validateAndSubmit,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('저장하고 결과 보기'),
        ),
      ),
    );
  }
}
