import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  StreamSubscription<AuthState>? _authSubscription;
  bool _loading = false;
  String? _error;

  SupabaseClient _supabase() => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _authSubscription = _supabase().auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      if (event.event == AuthChangeEvent.signedIn) {
        setState(() {
          _loading = false;
          _error = null;
        });
        Navigator.pushReplacementNamed(context, BirthInputPage.routeName);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailLogin() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _supabase().auth.signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pushReplacementNamed(context, BirthInputPage.routeName);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '로그인 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  Future<void> _startSocialLogin(OAuthProvider provider) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final redirectTo = const String.fromEnvironment('AUTH_REDIRECT_TO');
      if (!kIsWeb && redirectTo.isEmpty) {
        throw const FormatException('AUTH_REDIRECT_TO is empty');
      }

      await _supabase().auth.signInWithOAuth(
            provider,
            redirectTo: kIsWeb ? null : redirectTo,
          );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'AUTH_REDIRECT_TO가 비어 있습니다. 실행 스크립트의 dart-define 값을 확인해주세요.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '소셜 로그인 시작에 실패했습니다.';
      });
    }
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
          Text('이메일 또는 소셜 계정으로 로그인하고 리포트를 이어서 확인하세요.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (_error != null) ...[
            StatusNotice.error(message: _error!, requestId: 'auth-login-001'),
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialIconButton(
                onPressed: _loading ? null : () => _startSocialLogin(OAuthProvider.kakao),
                backgroundColor: const Color(0xFFFEE500),
                icon: SimpleIcons.kakaotalk,
                iconColor: const Color(0xFF181600),
                semanticsLabel: '카카오 로그인',
              ),
              const SizedBox(width: 14),
              _SocialIconButton(
                onPressed: _loading ? null : () => _startSocialLogin(OAuthProvider.google),
                backgroundColor: Colors.white,
                icon: SimpleIcons.google,
                iconColor: const Color(0xFF4285F4),
                semanticsLabel: '구글 로그인',
                borderColor: const Color(0xFFDADCE0),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
          onPressed: _loading ? null : _submitEmailLogin,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('이메일 로그인'),
        ),
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.semanticsLabel,
    this.borderColor,
  });

  final VoidCallback? onPressed;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final String semanticsLabel;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor ?? Colors.transparent),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}
