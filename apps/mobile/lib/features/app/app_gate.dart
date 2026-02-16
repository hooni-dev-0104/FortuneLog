import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_widgets.dart';
import '../../core/app_prefs.dart';
import '../birth/birth_input_page.dart';
import '../home/home_page.dart';
import '../onboarding/onboarding_page.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  static const routeName = '/';

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  SupabaseClient? _supabase;
  Stream<AuthState>? _authStream;
  String? _initError;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _supabase = Supabase.instance.client;
      _authStream = _supabase!.auth.onAuthStateChange;
      _initError = null;

      final keep = await AppPrefs.keepSignedIn();
      final session = _supabase!.auth.currentSession;
      if (!keep && session != null) {
        // User opted out of persisting login. Clear any stored session on app start.
        await _supabase!.auth.signOut();
      }
    } catch (_) {
      _supabase = null;
      _authStream = null;
      if (kDebugMode) {
        debugPrint(
          '[AppGate] Supabase.instance.client init failed. '
          'Likely missing SUPABASE_URL/SUPABASE_ANON_KEY dart-define (or Supabase.initialize not called).',
        );
      }
      // Keep user-facing message short. Debug guidance belongs in logs/docs, not UI.
      _initError = '서비스 연결에 실패했습니다. 앱을 다시 실행해주세요.';
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const _GateLoading(message: '초기화 중...');
    }
    if (_initError != null) {
      return _GateError(
        message: _initError!,
        requestId: 'app-gate-init',
        onRetry: () => setState(() {
          _initializing = true;
          _initError = null;
          _init();
        }),
      );
    }
    final supabase = _supabase;
    final authStream = _authStream;
    if (supabase == null || authStream == null) {
      return const _GateLoading(message: '초기화 중...');
    }

    return StreamBuilder<AuthState>(
      stream: authStream,
      builder: (context, snapshot) {
        // Avoid flicker during session restore:
        // before the first auth event arrives, show a branded loading state.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _GateLoading(message: '세션 확인 중...');
        }

        final session = supabase.auth.currentSession;
        if (session == null) {
          return const OnboardingPage();
        }
        return _SignedInGate(userId: session.user.id);
      },
    );
  }
}

class _SignedInGate extends StatefulWidget {
  const _SignedInGate({required this.userId});

  final String userId;

  @override
  State<_SignedInGate> createState() => _SignedInGateState();
}

class _SignedInGateState extends State<_SignedInGate> {
  late Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = _hasBirthProfile();
  }

  Future<void> _seedBirthProfileFromAuthMetadataIfPossible() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final meta = user?.userMetadata;
    if (meta == null) return;

    final birthDate = meta['birth_date'] as String?;
    final unknownBirthTime = meta['unknown_birth_time'] as bool? ?? false;
    final birthTime = meta['birth_time'] as String?;
    final birthTimezone =
        (meta['birth_timezone'] as String?)?.trim().isNotEmpty == true
            ? (meta['birth_timezone'] as String).trim()
            : 'Asia/Seoul';
    final birthLocation = (meta['birth_location'] as String?)?.trim() ?? '';
    final calendarType = (meta['calendar_type'] as String?) ?? 'solar';
    final isLeapMonth = meta['is_leap_month'] as bool? ?? false;
    final gender = (meta['gender'] as String?) ?? 'female';
    final profileName = (meta['profile_name'] as String?)?.trim() ?? '';
    final profileTag = (meta['profile_tag'] as String?)?.trim() ?? '';

    if (birthDate == null || birthDate.trim().isEmpty) return;

    // birth_datetime_local is stored as "YYYY-MM-DDTHH:mm:ss" (no timezone).
    final timePart = unknownBirthTime
        ? '12:00:00'
        : ((birthTime != null && birthTime.trim().isNotEmpty)
            ? '${birthTime.trim()}:00'
            : '12:00:00');
    final birthDatetime = '${birthDate.trim()}T$timePart';

    try {
      await supabase.from('birth_profiles').insert({
        'user_id': widget.userId,
        'profile_name': profileName.isEmpty ? '내 출생정보' : profileName,
        'profile_tag': profileTag.isEmpty ? '본인' : profileTag,
        'birth_datetime_local': birthDatetime,
        'birth_timezone': birthTimezone,
        'birth_location': birthLocation,
        'calendar_type': calendarType,
        'is_leap_month': isLeapMonth,
        'gender': gender,
        'unknown_birth_time': unknownBirthTime,
      });
    } on PostgrestException {
      // Ignore: might already exist (unique user_id) or policies might block.
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<bool> _hasBirthProfile() async {
    final supabase = Supabase.instance.client;
    final rows = await supabase
        .from('birth_profiles')
        .select('id')
        .eq('user_id', widget.userId)
        .limit(1);
    if ((rows as List).isNotEmpty) return true;

    // If the user just signed up, the app may have birth info in auth metadata.
    // Seed DB row so we don't ask the user to re-enter.
    await _seedBirthProfileFromAuthMetadataIfPossible();

    final rows2 = await supabase
        .from('birth_profiles')
        .select('id')
        .eq('user_id', widget.userId)
        .limit(1);
    return (rows2 as List).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _GateError(
            message: '초기 데이터 확인에 실패했습니다.',
            requestId: 'app-gate',
            onRetry: () => setState(() => _future = _hasBirthProfile()),
          );
        }

        if (!snapshot.hasData) {
          return const _GateLoading(message: '초기 데이터 준비 중...');
        }

        if (snapshot.data == true) {
          return const HomePage();
        }

        return const BirthInputPage();
      },
    );
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0F7B64),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    // Use the mark-only asset on solid/brand backgrounds.
                    // The full logo includes a rounded-rect background which looks like a "square patch"
                    // during app start when the background is also brand green.
                    'assets/branding/fortunelog-mark.png',
                    width: 92,
                    height: 92,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'FortuneLog',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GateError extends StatelessWidget {
  const _GateError(
      {required this.message, required this.requestId, required this.onRetry});

  final String message;
  final String requestId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusNotice.error(message: message, requestId: requestId),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: onRetry, child: const Text('재시도')),
            ],
          ),
        ),
      ),
    );
  }
}
