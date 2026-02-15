import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/ui/app_theme.dart';

import 'features/app/app_gate.dart';
import 'features/auth/login_page.dart';
import 'features/birth/birth_input_page.dart';
import 'features/birth/birth_profile_list_page.dart';
import 'features/devtest/dev_test_page.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/report/report_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  runApp(const FortuneLogApp());
}

class FortuneLogApp extends StatelessWidget {
  const FortuneLogApp({super.key});

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
        LoginPage.routeName: (_) => const LoginPage(),
        BirthInputPage.routeName: (_) => const BirthInputPage(),
        BirthProfileListPage.routeName: (_) => const BirthProfileListPage(),
        HomePage.routeName: (_) => const HomePage(),
        ReportPage.routeName: (_) => const ReportPage(),
        DevTestPage.routeName: (_) => const DevTestPage(),
      },
    );
  }
}
