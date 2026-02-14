import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/app_widgets.dart';
import '../home/home_page.dart';

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

  @override
  void initState() {
    super.initState();

    try {
      _authSubscription = _supabase().auth.onAuthStateChange.listen((event) {
        if (!mounted) return;
        if (event.event == AuthChangeEvent.signedIn) {
          setState(() {
            _loading = false;
            _error = null;
          });
          // iOS 인앱 OAuth(SafariViewController)가 리다이렉트 이후 흰 화면으로 남는 경우가 있어,
          // 로그인 완료 시점에 자동으로 닫아 UX를 자연스럽게 만든다.
          // (Android는 closeInAppWebView를 지원하지 않을 수 있으므로 호출 실패는 무시)
          closeInAppWebView().catchError((_) {});
          Navigator.pushReplacementNamed(context, HomePage.routeName);
        }
      });
    } on StateError catch (e) {
      _error = e.message;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
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
        _error = 'AUTH_REDIRECT_TO가 비어 있습니다. .env 설정을 확인해주세요.';
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
        _error = 'AUTH_REDIRECT_TO가 비어 있습니다. .env 설정을 확인해주세요.';
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
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'AUTH_REDIRECT_TO가 비어 있습니다. .env 설정을 확인해주세요.';
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialIconButton(
                onPressed: _loading ? null : () => _startSocialLogin(OAuthProvider.kakao),
                backgroundColor: const Color(0xFFFEE500),
                icon: const _KakaoTalkMark(size: 26, color: Color(0xFF181600)),
                semanticsLabel: '카카오 로그인',
              ),
              const SizedBox(width: 14),
              _SocialIconButton(
                onPressed: _loading ? null : () => _startSocialLogin(OAuthProvider.google),
                backgroundColor: Colors.white,
                icon: const _GoogleGMark(size: 26),
                semanticsLabel: '구글 로그인',
                borderColor: const Color(0xFFE6E8EB),
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
    required this.backgroundColor,
    required this.icon,
    required this.semanticsLabel,
    this.borderColor,
  });

  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Widget icon;
  final String semanticsLabel;
  final Color? borderColor;

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
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor ?? Colors.transparent),
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
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

class _KakaoTalkMark extends StatelessWidget {
  const _KakaoTalkMark({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _KakaoTalkMarkPainter(color)),
    );
  }
}

class _KakaoTalkMarkPainter extends CustomPainter {
  const _KakaoTalkMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final s = math.min(size.width, size.height);
    final cx = size.width / 2;
    final cy = size.height * 0.44;
    final r = s * 0.37;

    final bubble = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    // Tail: small rounded wedge at bottom.
    final tail = Path()
      ..moveTo(cx - s * 0.10, cy + r * 0.55)
      ..quadraticBezierTo(cx - s * 0.06, cy + r * 0.98, cx + s * 0.02, cy + r * 0.78)
      ..quadraticBezierTo(cx + s * 0.10, cy + r * 0.62, cx + s * 0.12, cy + r * 0.45)
      ..close();

    canvas.drawPath(bubble, paint);
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _KakaoTalkMarkPainter oldDelegate) => oldDelegate.color != color;
}

class _GoogleGMark extends StatelessWidget {
  const _GoogleGMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _GoogleGMarkPainter()),
    );
  }
}

class _GoogleGMarkPainter extends CustomPainter {
  const _GoogleGMarkPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFDB4437);
  static const _yellow = Color(0xFFF4B400);
  static const _green = Color(0xFF0F9D58);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final stroke = s * 0.18;
    final rect = Rect.fromLTWH(
      (size.width - s) / 2 + stroke / 2,
      (size.height - s) / 2 + stroke / 2,
      s - stroke,
      s - stroke,
    );

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // We draw in a layer so we can "erase" the opening on the right.
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Segment arcs (approximation of the official Google "G" mark).
    // Angles are in radians; 0 rad points to the right.
    void arc(Color c, double startDeg, double sweepDeg) {
      arcPaint.color = c;
      canvas.drawArc(rect, _deg(startDeg), _deg(sweepDeg), false, arcPaint);
    }

    arc(_red, 315, 90); // top-right
    arc(_yellow, 45, 90); // top-left
    arc(_green, 135, 90); // bottom-left
    arc(_blue, 225, 90); // bottom-right

    // Erase top-right and bottom-right parts to create the "G" opening.
    final clear = Paint()..blendMode = BlendMode.clear;
    final openX = (size.width - s) / 2 + s * 0.63;
    final openW = s * 0.40;
    canvas.drawRect(Rect.fromLTWH(openX, (size.height - s) / 2 + s * 0.02, openW, s * 0.38), clear);
    canvas.drawRect(Rect.fromLTWH(openX, (size.height - s) / 2 + s * 0.64, openW, s * 0.34), clear);

    // Blue horizontal bar.
    final barPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final barY = size.height / 2;
    canvas.drawLine(
      Offset((size.width - s) / 2 + s * 0.50, barY),
      Offset((size.width - s) / 2 + s * 0.92, barY),
      barPaint,
    );

    canvas.restore();
  }

  static double _deg(double degrees) => degrees * math.pi / 180.0;

  @override
  bool shouldRepaint(covariant _GoogleGMarkPainter oldDelegate) => false;
}
