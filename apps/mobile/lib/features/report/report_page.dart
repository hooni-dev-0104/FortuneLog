import 'package:flutter/material.dart';

import '../../core/network/engine_api_client.dart';
import '../../core/ui/app_widgets.dart';

class ReportPageArgs {
  const ReportPageArgs({
    required this.chartId,
    this.initialReportType = 'personality',
  });

  final String chartId;
  final String initialReportType;
}

// Public entry stays closed until personalized report types are verified server-side.
class ReportPage extends StatelessWidget {
  const ReportPage({super.key, this.args, EngineApiClient? engineClient});

  static const routeName = '/report';
  final ReportPageArgs? args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상세 리포트')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: EmptyState(
            title: '개인화 상세 리포트 준비 중',
            description: '성향·연애·직업별 해석을 준비하고 있습니다. '
                '현재는 리포트를 생성하거나 이용권을 차감하지 않습니다.',
            icon: Icons.auto_stories_outlined,
            tone: BadgeTone.info,
          ),
        ),
      ),
    );
  }
}
