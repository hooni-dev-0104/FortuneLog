import 'package:flutter/material.dart';

import '../birth/birth_input_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _loading = false;
        _error = '이메일과 비밀번호를 입력해 주세요.';
      });
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, BirthInputPage.routeName);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '이메일'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '비밀번호'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('로그인'),
            ),
            const SizedBox(height: 8),
            const Text('회원가입/비밀번호 찾기는 디자인 확정 후 연결 예정'),
          ],
        ),
      ),
    );
  }
}
