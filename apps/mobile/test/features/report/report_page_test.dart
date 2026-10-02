import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fortune_log_mobile/core/network/engine_api_client.dart';
import 'package:fortune_log_mobile/features/report/report_page.dart';

void main() {
  testWidgets('preparation message stays readable at narrow width and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: const ReportPage(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('개인화 상세 리포트 준비 중'), findsOneWidget);
  });

  testWidgets('preparation screen never generates or sells a report', (tester) async {
    final client = _FakeEngineApiClient();
    await tester.pumpWidget(MaterialApp(
      home: ReportPage(args: const ReportPageArgs(chartId: 'chart-1'), engineClient: client),
    ));
    await tester.pumpAndSettle();
    expect(find.text('개인화 상세 리포트 준비 중'), findsOneWidget);
    expect(client.reportRequests, isEmpty);
    expect(find.text('리포트 재생성'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}

class _FakeEngineApiClient implements EngineApiClient {
  final List<GenerateReportRequestDto> reportRequests = [];

  @override
  Future<ReportResponseDto> generateReport(
      GenerateReportRequestDto request) async {
    reportRequests.add(request);
    return ReportResponseDto(
      requestId: 'req-${request.reportType}',
      chartId: request.chartId,
      reportType: request.reportType,
      content: {
        'summary': '${request.reportType} 요약',
        'strengths': ['${request.reportType} 강점'],
        'cautions': ['${request.reportType} 주의'],
        'actions': ['${request.reportType} 행동'],
      },
    );
  }

  @override
  Future<ChartResponseDto> calculateChart(CalculateChartRequestDto request) {
    throw UnimplementedError();
  }

  @override
  Future<DailyFortuneResponseDto> generateDailyFortune(
    GenerateDailyFortuneRequestDto request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ReportResponseDto> generateAiInterpretation(
    GenerateAiInterpretationRequestDto request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CreditBalanceResponseDto> getCredits() {
    throw UnimplementedError();
  }

  @override
  Future<AccountDeletionResponseDto> requestAccountDeletion(
    RequestAccountDeletionRequestDto request,
  ) {
    throw UnimplementedError();
  }
}
