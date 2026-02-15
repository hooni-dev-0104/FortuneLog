import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/app_widgets.dart';
import '../app/app_gate.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _oauthWatchdog;
  bool _oauthInFlight = false;
  bool _loading = false;
  String? _error;

  SupabaseClient _supabase() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('SUPABASE_URL / SUPABASE_ANON_KEY dart-define가 필요합니다.');
    }
  }

  String? _redirectToForMobile() {
    if (kIsWeb) return null;
    final redirectTo = const String.fromEnvironment('AUTH_REDIRECT_TO');
    if (redirectTo.isEmpty) {
      throw const FormatException('AUTH_REDIRECT_TO is empty');
    }
    return redirectTo;
  }

  String _authRedirectMissingMessage() {
    if (kDebugMode) {
      return 'AUTH_REDIRECT_TO가 비어 있습니다. .env 설정을 확인해주세요.';
    }
    return '현재 환경에서 소셜 로그인을 시작할 수 없습니다.';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    try {
      _authSubscription = _supabase().auth.onAuthStateChange.listen((event) {
        if (!mounted) return;
        if (event.event == AuthChangeEvent.signedIn) {
          _oauthInFlight = false;
          _oauthWatchdog?.cancel();
          setState(() {
            _loading = false;
            _error = null;
          });
          // iOS 인앱 OAuth(SafariViewController)가 리다이렉트 이후 흰 화면으로 남는 경우가 있어,
          // 로그인 완료 시점에 자동으로 닫아 UX를 자연스럽게 만든다.
          // (Android는 closeInAppWebView를 지원하지 않을 수 있으므로 호출 실패는 무시)
          closeInAppWebView().catchError((_) {});
          Navigator.pushReplacementNamed(context, AppGate.routeName);
        }
      });
    } on StateError catch (e) {
      _error = e.message;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When a user closes the in-app OAuth screen (e.g. taps "Done"),
    // we typically get a resume without a signedIn event. In that case,
    // unblock the UI so they can retry.
    if (state != AppLifecycleState.resumed) return;
    if (!_oauthInFlight) return;

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final session = _supabase().auth.currentSession;
      if (session != null) return;

      _oauthInFlight = false;
      _oauthWatchdog?.cancel();
      setState(() => _loading = false);
      // Don't show as an "error" box. Cancellation is a normal path.
      _showSnack('로그인이 취소되었습니다.');
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _oauthWatchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
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
        _error = '로그인 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  Future<void> _submitSignUp() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _supabase().auth.signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            emailRedirectTo: _redirectToForMobile(),
          );
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('회원가입 요청 완료. 이메일 인증 후 로그인해주세요.');
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
        _error = _authRedirectMissingMessage();
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _sendPasswordReset() async {
    setState(() => _error = null);
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = '비밀번호 재설정을 위해 올바른 이메일을 입력해주세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      await _supabase().auth.resetPasswordForEmail(
            email,
            redirectTo: _redirectToForMobile(),
          );
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('비밀번호 재설정 메일을 보냈습니다. 메일함을 확인해주세요.');
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
        _error = _authRedirectMissingMessage();
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _startSocialLogin(OAuthProvider provider) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _oauthInFlight = true;
    _oauthWatchdog?.cancel();
    _oauthWatchdog = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      if (!_oauthInFlight) return;

      final session = _supabase().auth.currentSession;
      if (session != null) return;

      _oauthInFlight = false;
      setState(() => _loading = false);
      _showSnack('로그인이 완료되지 않았습니다. 다시 시도해주세요.');
    });

    try {
      final kakaoScopes =
          provider == OAuthProvider.kakao ? 'profile_nickname profile_image' : null;

      await _supabase().auth.signInWithOAuth(
            provider,
            redirectTo: _redirectToForMobile(),
            scopes: kakaoScopes,
            // 인앱으로 열고, signedIn 시점에 closeInAppWebView()로 자동 닫힘 처리한다.
            authScreenLaunchMode: LaunchMode.inAppBrowserView,
          );
    } on AuthException catch (e) {
      if (!mounted) return;
      _oauthInFlight = false;
      _oauthWatchdog?.cancel();
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on FormatException {
      if (!mounted) return;
      _oauthInFlight = false;
      _oauthWatchdog?.cancel();
      setState(() {
        _loading = false;
        _error = _authRedirectMissingMessage();
      });
    } on StateError catch (e) {
      if (!mounted) return;
      _oauthInFlight = false;
      _oauthWatchdog?.cancel();
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      _oauthInFlight = false;
      _oauthWatchdog?.cancel();
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
          Center(
            child: Image.asset(
              'assets/branding/fortunelog-logo.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
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
            subtitle: '이메일과 비밀번호를 입력한 뒤 로그인해주세요.',
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialIconButton(
                onPressed: _loading ? null : () => _startSocialLogin(OAuthProvider.kakao),
                // Keep the original PNG to match the exact silhouette 1:1.
                // Render close to native size to avoid blurry upscaling.
                icon: Image.asset(
                  'assets/auth/kakao.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  isAntiAlias: false,
                ),
                semanticsLabel: '카카오 로그인',
                decorated: false,
              ),
              const SizedBox(width: 14),
              _SocialIconButton(
                onPressed: _loading ? null : () => _startSocialLogin(OAuthProvider.google),
                icon: SvgPicture.asset(
                  'assets/auth/google.svg',
                  width: 34,
                  height: 34,
                ),
                semanticsLabel: '구글 로그인',
                decorated: false,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(onPressed: _loading ? null : _submitSignUp, child: const Text('회원가입')),
              const SizedBox(width: 6),
              TextButton(onPressed: _loading ? null : _sendPasswordReset, child: const Text('비밀번호 찾기')),
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
    required this.icon,
    required this.semanticsLabel,
    this.decorated = true,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String semanticsLabel;
  final bool decorated;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: 56,
              height: 56,
              decoration: decorated
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE6E8EB)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A0B0F14),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Color(0x0A0B0F14),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    )
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Center(child: icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
