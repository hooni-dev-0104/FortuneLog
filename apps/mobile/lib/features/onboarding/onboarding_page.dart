import 'package:flutter/material.dart';

import '../../core/ui/app_widgets.dart';
import '../auth/login_page.dart';
import '../devtest/dev_test_page.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  static const routeName = '/onboarding';

  @override
  Widget build(BuildContext context) {
    final values = [
      ('사주 기반 맞춤 해석', '출생정보를 기준으로 성향과 흐름을 이해하기 쉽게 요약합니다.'),
      ('오늘 액션 제안', '연애·일·재물·건강별로 오늘 바로 실행할 행동을 제공합니다.'),
      ('신뢰 가능한 상태 안내', '로딩, 빈화면, 오류를 한 패턴으로 보여줘 헷갈리지 않습니다.'),
      ('문의 가능한 오류 추적', '문제 발생 시 requestId를 함께 표시해 빠르게 대응할 수 있습니다.'),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE9F4F1), Color(0xFFF6F8F7)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            children: [
              Text('FortuneLog', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('당신의 오늘을 더 명확하게', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(
                '결과는 참고용 해석이며 중요한 의사결정은 전문가 상담을 권장합니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              ...values.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PageSection(
                    title: item.$1,
                    child: Text(item.$2, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pushReplacementNamed(context, LoginPage.routeName),
                child: const Text('시작하기'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, DevTestPage.routeName),
                child: const Text('개발 테스트 화면'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
