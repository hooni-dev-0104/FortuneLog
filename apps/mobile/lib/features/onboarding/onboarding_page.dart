import 'package:flutter/material.dart';

import '../../core/ui/app_widgets.dart';
import '../auth/login_page.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  static const routeName = '/onboarding';

  @override
  Widget build(BuildContext context) {
    final bullets = const [
      ('사주 기반 요약', '출생정보를 기준으로 흐름을 간결하게 정리합니다.'),
      ('오늘 운세 액션', '연애·일·재물·건강별로 오늘 할 일 3가지를 제공합니다.'),
      ('끊김 없는 안내', '기다림/오류 상황에서도 다음 행동을 바로 알려드립니다.'),
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
              Center(
                child: Image.asset(
                  'assets/branding/fortunelog-logo.png',
                  width: 86,
                  height: 86,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),
              Text('FortuneLog', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('당신의 오늘을 더 명확하게', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                '결과는 참고용 해석이며 중요한 의사결정은 전문가 상담을 권장합니다.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              PageSection(
                title: '핵심 기능',
                child: Column(
                  children: [
                    for (final b in bullets) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Icon(Icons.check_circle_outline, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.$1, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(b.$2, style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (b != bullets.last) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pushReplacementNamed(context, LoginPage.routeName),
                child: const Text('시작하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
