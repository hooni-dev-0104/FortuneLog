import 'package:flutter/material.dart';

import '../auth/login_page.dart';
import '../devtest/dev_test_page.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  static const routeName = '/onboarding';

  @override
  Widget build(BuildContext context) {
    final items = [
      ('사주 기반 맞춤 해석', '출생정보로 핵심 성향과 흐름을 정리합니다.'),
      ('오늘 액션 제안', '연애/일/재물/건강 카테고리별 실행 문장을 제공합니다.'),
      ('신뢰 가능한 상태 표시', '로딩/오류/requestId를 명확히 안내합니다.'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('FortuneLog')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('당신의 오늘을 더 명확하게', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('결과는 참고용 해석이며 중요한 결정은 전문가 상담을 권장합니다.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (_, i) => Card(
                  child: ListTile(
                    title: Text(items[i].$1),
                    subtitle: Text(items[i].$2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pushReplacementNamed(context, LoginPage.routeName),
              child: const Text('시작하기'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, DevTestPage.routeName),
              child: const Text('개발 테스트 화면으로 이동'),
            ),
          ],
        ),
      ),
    );
  }
}
