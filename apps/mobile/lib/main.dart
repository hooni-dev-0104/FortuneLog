import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/devtest/dev_test_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  runApp(const FortuneLogDevApp());
}

class FortuneLogDevApp extends StatelessWidget {
  const FortuneLogDevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FortuneLog Dev',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7A5F)),
        useMaterial3: true,
      ),
      home: const DevTestPage(),
    );
  }
}
