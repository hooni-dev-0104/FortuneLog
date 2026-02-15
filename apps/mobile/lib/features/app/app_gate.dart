import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    try {
      _supabase = Supabase.instance.client;
      _authStream = _supabase!.auth.onAuthStateChange;
    } catch (_) {
      _initError = 'SUPABASE_URL / SUPABASE_ANON_KEY dart-define가 필요합니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return _GateError(
        message: _initError!,
        requestId: 'app-gate-init',
        onRetry: () => setState(() => _initError = null),
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

  Future<bool> _hasBirthProfile() async {
    final supabase = Supabase.instance.client;
    final rows = await supabase
        .from('birth_profiles')
        .select('id')
        .eq('user_id', widget.userId)
        .limit(1);
    return (rows as List).isNotEmpty;
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F7B64), Color(0xFF11524E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/branding/fortunelog-logo.png',
                    width: 84,
                    height: 84,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'FortuneLog',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
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
  const _GateError({required this.message, required this.requestId, required this.onRetry});

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
