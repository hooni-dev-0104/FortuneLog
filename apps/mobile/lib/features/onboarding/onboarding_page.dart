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
              const SizedBox(height: 10),
              const PageSection(
                title: '사주팔자(4주) 한눈에',
                subtitle: '연/월/일/시 4기둥이 의미하는 것',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('사주팔자는 4개의 기둥(연주·월주·일주·시주)으로 구성됩니다.'),
                    SizedBox(height: 12),
                    _FourPillarsMeaningTable(),
                    SizedBox(height: 12),
                    Text(
                      '각 기둥은 천간+지지(2글자)로 표시되며, 조합을 바탕으로 해석이 만들어집니다.',
                    ),
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

class _FourPillarsMeaningTable extends StatelessWidget {
  const _FourPillarsMeaningTable();

  TableRow _row(BuildContext context, {required String left, required String right, bool header = false}) {
    final leftStyle = header
        ? Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodySmall;
    final rightStyle = header
        ? Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodySmall;

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Text(left, style: leftStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Text(right, style: rightStyle),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD8E0DC)),
          color: Colors.white,
        ),
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(86),
            1: FlexColumnWidth(),
          },
          border: const TableBorder(
            horizontalInside: BorderSide(color: Color(0xFFD8E0DC)),
            verticalInside: BorderSide(color: Color(0xFFD8E0DC)),
          ),
          children: [
            _row(context, left: '구분', right: '의미', header: true),
            _row(context, left: '연주', right: '가문·조상·사회적 배경'),
            _row(context, left: '월주', right: '성장 환경·부모·직업 기질'),
            _row(context, left: '일주', right: '나 자신·성격·배우자'),
            _row(context, left: '시주', right: '말년운·자녀·잠재 능력'),
          ],
        ),
      ),
    );
  }
}
