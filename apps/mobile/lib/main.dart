import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/ui/app_theme.dart';

import 'features/auth/login_page.dart';
import 'features/birth/birth_input_page.dart';
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
      initialRoute: OnboardingPage.routeName,
      routes: {
        OnboardingPage.routeName: (_) => const OnboardingPage(),
        LoginPage.routeName: (_) => const LoginPage(),
        BirthInputPage.routeName: (_) => const BirthInputPage(),
        HomePage.routeName: (_) => const HomePage(),
        ReportPage.routeName: (_) => const ReportPage(),
        DevTestPage.routeName: (_) => const DevTestPage(),
      },
    );
  }
}
