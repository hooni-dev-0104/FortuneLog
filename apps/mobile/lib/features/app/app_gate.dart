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
  late final SupabaseClient _supabase;
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _authStream = _supabase.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        final session = _supabase.auth.currentSession;
        if (session == null) {
          return const OnboardingPage();
        }
        return _SignedInGate(userId: session.user.id);
      },
    );
  }
}

class _SignedInGate extends StatelessWidget {
  const _SignedInGate({required this.userId});

  final String userId;

  Future<bool> _hasBirthProfile() async {
    final supabase = Supabase.instance.client;
    final rows = await supabase
        .from('birth_profiles')
        .select('id')
        .eq('user_id', userId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasBirthProfile(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: StatusNotice.error(
                  message: '초기 데이터 확인에 실패했습니다.',
                  requestId: 'app-gate',
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.data == true) {
          return const HomePage();
        }

        return const BirthInputPage();
      },
    );
  }
}

