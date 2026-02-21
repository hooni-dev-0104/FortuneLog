import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_prefs.dart';
import '../../core/ui/app_widgets.dart';
import '../app/app_gate.dart';
import 'signup_page.dart';
import 'auth_error_mapper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialEmail});

  static const routeName = '/login';

  final String? initialEmail;

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
  bool _keepSignedIn = true;

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

    AppPrefs.keepSignedIn().then((v) {
      if (!mounted) return;
      setState(() => _keepSignedIn = v);
    });

    final initialEmail = widget.initialEmail?.trim();
    if (initialEmail != null && initialEmail.isNotEmpty && !_emailController.text.contains('@')) {
      _emailController.text = initialEmail;
    }

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
    showAppSnackBar(context, message);
  }

  Future<void> _submitEmailLogin() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AppPrefs.setKeepSignedIn(_keepSignedIn);
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
        _error = AuthErrorMapper.userMessage(e, flow: AuthContextFlow.login);
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

  Future<void> _sendPasswordReset() async {
    setState(() => _error = null);
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = '비밀번호 재설정을 위해 올바른 이메일을 입력해주세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AppPrefs.setKeepSignedIn(_keepSignedIn);
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
        _error = AuthErrorMapper.userMessage(e, flow: AuthContextFlow.passwordReset);
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
    await AppPrefs.setKeepSignedIn(_keepSignedIn);
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
      final queryParams = <String, String>{
        if (provider == OAuthProvider.kakao) 'lang': 'ko',
        if (provider == OAuthProvider.google) 'hl': 'ko',
      };

      final oauthUrl = await _supabase().auth.getOAuthSignInUrl(
            provider: provider,
            redirectTo: _redirectToForMobile(),
            scopes: kakaoScopes,
            queryParams: queryParams.isEmpty ? null : queryParams,
          );
      final launched = await launchUrl(
        Uri.parse(oauthUrl.url),
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
        webOnlyWindowName: '_self',
      );
      if (!launched) {
        throw StateError('소셜 로그인 화면을 열지 못했습니다.');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _oauthInFlight = false;
      _oauthWatchdog?.cancel();
      setState(() {
        _loading = false;
        _error = AuthErrorMapper.userMessage(e, flow: AuthContextFlow.socialLogin);
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
          Text('오늘의 흐름을 이어볼까요', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('로그인하고 금전·연애·일·건강의 흐름을 한 번에 확인하세요.', style: Theme.of(context).textTheme.bodyMedium),
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
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          );
                      final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: const Color(0xFF5B6B65),
                          );

                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _loading ? null : () => setState(() => _keepSignedIn = !_keepSignedIn),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Checkbox(
                                  value: _keepSignedIn,
                                  onChanged: _loading
                                      ? null
                                      : (v) {
                                          setState(() => _keepSignedIn = v ?? true);
                                        },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('로그인 유지하기', style: titleStyle),
                                    const SizedBox(height: 2),
                                    Text('앱을 다시 열어도 로그인 상태를 유지합니다.', style: subtitleStyle),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: _loading ? null : () => Navigator.pushNamed(context, SignupPage.routeName),
                child: const Text('회원가입'),
              ),
              const SizedBox(width: 6),
              TextButton(onPressed: _loading ? null : _sendPasswordReset, child: const Text('비밀번호 찾기')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider(height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('또는', style: Theme.of(context).textTheme.bodySmall),
              ),
              const Expanded(child: Divider(height: 1)),
            ],
          ),
          const SizedBox(height: 16),
          PageSection(
            title: '소셜 로그인',
            subtitle: '간편하게 계속하세요.',
            child: Column(
              children: [
                _SocialLoginButton(
                  provider: OAuthProvider.kakao,
                  label: '카카오로 계속하기',
                  leading: Image.asset(
                    'assets/auth/kakao.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    isAntiAlias: false,
                  ),
                  backgroundColor: const Color(0xFFFEE500),
                  foregroundColor: Colors.black,
                  borderColor: const Color(0xFFE7D200),
                  onPressed: _loading ? null : () => _startSocialLogin(OAuthProvider.kakao),
                  loading: _loading,
                ),
                const SizedBox(height: 10),
                _SocialLoginButton(
                  provider: OAuthProvider.google,
                  label: '구글로 계속하기',
                  leading: SvgPicture.asset(
                    'assets/auth/google.svg',
                    width: 22,
                    height: 22,
                  ),
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF16211D),
                  borderColor: const Color(0xFFD8E0DC),
                  onPressed: _loading ? null : () => _startSocialLogin(OAuthProvider.google),
                  loading: _loading,
                ),
              ],
            ),
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

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.provider,
    required this.label,
    required this.leading,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onPressed,
    required this.loading,
  });

  final OAuthProvider provider;
  final String label;
  final Widget leading;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.65,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              side: BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 10),
                Expanded(child: Text(label)),
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foregroundColor.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
