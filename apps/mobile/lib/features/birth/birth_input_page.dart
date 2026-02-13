import 'package:flutter/material.dart';

import '../home/home_page.dart';

class BirthInputPage extends StatefulWidget {
  const BirthInputPage({super.key});

  static const routeName = '/birth-input';

  @override
  State<BirthInputPage> createState() => _BirthInputPageState();
}

class _BirthInputPageState extends State<BirthInputPage> {
  final _birthDateController = TextEditingController(text: '1994-11-21');
  final _birthTimeController = TextEditingController(text: '14:30');
  final _birthLocationController = TextEditingController(text: 'Seoul, KR');
  final _genderController = TextEditingController(text: 'female');

  bool _isLunar = false;
  bool _isLeapMonth = false;
  bool _unknownBirthTime = false;
  String? _error;

  void _save() {
    setState(() => _error = null);
    if (_birthDateController.text.trim().isEmpty || _birthLocationController.text.trim().isEmpty) {
      setState(() => _error = '생년월일과 출생지를 입력해 주세요.');
      return;
    }
    if (_isLeapMonth && !_isLunar) {
      setState(() => _error = '윤달은 음력일 때만 선택할 수 있습니다.');
      return;
    }

    Navigator.pushReplacementNamed(context, HomePage.routeName);
  }

  @override
  void dispose() {
    _birthDateController.dispose();
    _birthTimeController.dispose();
    _birthLocationController.dispose();
    _genderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('출생정보 입력')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('기본정보'),
          const SizedBox(height: 8),
          TextField(
            controller: _birthDateController,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '생년월일 (YYYY-MM-DD)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _genderController,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '성별'),
          ),
          const SizedBox(height: 16),
          const Text('시간 / 장소'),
          const SizedBox(height: 8),
          TextField(
            controller: _birthTimeController,
            enabled: !_unknownBirthTime,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '출생시간 (HH:mm)'),
          ),
          CheckboxListTile(
            value: _unknownBirthTime,
            onChanged: (v) => setState(() => _unknownBirthTime = v ?? false),
            title: const Text('출생시간 미상'),
            contentPadding: EdgeInsets.zero,
          ),
          TextField(
            controller: _birthLocationController,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '출생지'),
          ),
          const SizedBox(height: 16),
          const Text('캘린더 옵션'),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _isLunar,
            onChanged: (v) => setState(() {
              _isLunar = v;
              if (!_isLunar) _isLeapMonth = false;
            }),
            title: const Text('음력 사용'),
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _isLeapMonth,
            onChanged: _isLunar ? (v) => setState(() => _isLeapMonth = v ?? false) : null,
            title: const Text('윤달'),
            contentPadding: EdgeInsets.zero,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          FilledButton(onPressed: _save, child: const Text('저장하고 결과 보기')),
        ],
      ),
    );
  }
}
