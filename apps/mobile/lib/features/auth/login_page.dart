import 'package:flutter/material.dart';

import '../../core/ui/app_widgets.dart';
import '../birth/birth_input_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() => _loading = false);
    Navigator.pushReplacementNamed(context, BirthInputPage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('다시 만나서 반가워요', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('이메일 계정으로 로그인하고 리포트를 이어서 확인하세요.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (_error != null) ...[
            StatusNotice.error(message: _error!, requestId: 'dev-login-001'),
            const SizedBox(height: 12),
          ],
          PageSection(
            title: '계정 인증',
            subtitle: '입력 완료 후 로그인 버튼이 활성화됩니다.',
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
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
                    decoration: const InputDecoration(labelText: '비밀번호'),
                    validator: (v) {
                      if (v == null || v.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(onPressed: () {}, child: const Text('회원가입')),
              const SizedBox(width: 6),
              TextButton(onPressed: () {}, child: const Text('비밀번호 찾기')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('로그인'),
        ),
      ),
    );
  }
}
