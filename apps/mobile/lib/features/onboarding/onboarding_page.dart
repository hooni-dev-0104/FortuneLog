import 'package:flutter/material.dart';

import '../../core/ui/app_theme.dart';
import '../../core/ui/app_widgets.dart';
import '../auth/login_page.dart';
import '../saju/saju_guide_page.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  static const routeName = '/onboarding';

  @override
  Widget build(BuildContext context) {
    final bullets = const [
      ('사주 기반 요약', '출생정보를 기준으로 흐름을 간결하게 정리합니다.'),
      ('오늘 운세 액션', '연애·일·재물·건강별로 오늘 할 일 3가지를 제공합니다.'),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            20,
            AppTheme.pagePadding,
            16,
          ),
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
            Text('FortuneLog',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('당신의 오늘을 더 명확하게',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center),
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
                    AppInfoRow(
                      title: b.$1,
                      subtitle: b.$2,
                      leadingIcon: Icons.check_circle_outline,
                    ),
                    if (b != bullets.last) const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            PageSection(
              title: '사주팔자(4주) 한눈에',
              subtitle: '연/월/일/시 4기둥이 의미하는 것',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('사주팔자는 4개의 기둥(연주·월주·일주·시주)으로 구성됩니다.'),
                  const SizedBox(height: 12),
                  const _FourPillarsMeaningTable(),
                  const SizedBox(height: 12),
                  const Text(
                    '각 기둥은 천간+지지(2글자)로 표시되며, 조합을 바탕으로 해석이 만들어집니다.',
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, SajuGuidePage.routeName),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('용어/설명 보기'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, LoginPage.routeName),
              child: const Text('시작하기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FourPillarsMeaningTable extends StatelessWidget {
  const _FourPillarsMeaningTable();

  @override
  Widget build(BuildContext context) {
    return const AppKeyValueTable(
      firstHeader: '구분',
      secondHeader: '의미',
      rows: [
        ('연주', '가문·조상·사회적 배경'),
        ('월주', '성장 환경·부모·직업 기질'),
        ('일주', '나 자신·성격·배우자'),
        ('시주', '말년운·자녀·잠재 능력'),
      ],
    );
  }
}
