import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/ui/app_theme.dart';

import 'features/app/app_gate.dart';
import 'features/auth/login_page.dart';
import 'features/auth/signup_page.dart';
import 'features/birth/birth_input_page.dart';
import 'features/birth/birth_profile_list_page.dart';
import 'features/devtest/dev_test_page.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/report/report_page.dart';
import 'features/saju/manseoryeok_detail_page.dart';
import 'features/saju/saju_guide_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  runApp(const FortuneLogApp());
}

class FortuneLogApp extends StatefulWidget {
  const FortuneLogApp({super.key});

  @override
  State<FortuneLogApp> createState() => _FortuneLogAppState();
}

class _FortuneLogAppState extends State<FortuneLogApp> {
  static const _nativeSplashChannel = MethodChannel('fortunelog/splash');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // iOS-only: hide the native splash overlay after Flutter draws its first frame.
      // This avoids showing any unstyled intermediate frame between LaunchScreen and Flutter UI.
      if (kIsWeb) return;
      try {
        await _nativeSplashChannel.invokeMethod('hide');
      } catch (_) {
        // Ignore: older builds might not have the native channel wired yet.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FortuneLog',
      theme: AppTheme.light(),
      // Force Korean for date/time pickers and Material strings.
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: AppGate.routeName,
      routes: {
        AppGate.routeName: (_) => const AppGate(),
        OnboardingPage.routeName: (_) => const OnboardingPage(),
        LoginPage.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return LoginPage(initialEmail: args is String ? args : null);
        },
        SignupPage.routeName: (_) => const SignupPage(),
        BirthInputPage.routeName: (_) => const BirthInputPage(),
        BirthProfileListPage.routeName: (_) => const BirthProfileListPage(),
        HomePage.routeName: (_) => const HomePage(),
        ReportPage.routeName: (_) => const ReportPage(),
        ManseoryeokDetailPage.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return ManseoryeokDetailPage(chart: args is Map<String, String> ? args : const {});
        },
        SajuGuidePage.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return SajuGuidePage(chart: args is Map<String, String> ? args : null);
        },
        DevTestPage.routeName: (_) => const DevTestPage(),
      },
    );
  }
}
