import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fortune_log_mobile/core/network/engine_api_client.dart';
import 'package:fortune_log_mobile/features/report/report_page.dart';

void main() {
  testWidgets('shows empty state when chart id is missing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReportPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('사주 차트가 필요합니다'), findsOneWidget);
    expect(
      find.text('출생정보로 사주 계산을 완료한 뒤 상세 리포트를 확인할 수 있습니다.'),
      findsOneWidget,
    );
  });

  testWidgets('loads report content from engine', (tester) async {
    final client = _FakeEngineApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: ReportPage(
          args: const ReportPageArgs(chartId: 'chart-1'),
          engineClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(client.reportRequests.map((request) => request.reportType), [
      'personality',
    ]);
    expect(find.text('personality 요약'), findsOneWidget);
    expect(find.text('personality 강점'), findsOneWidget);
    expect(find.text('personality 주의'), findsOneWidget);
    expect(find.text('personality 행동'), findsOneWidget);
  });

  testWidgets('loads selected report tab once', (tester) async {
    final client = _FakeEngineApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: ReportPage(
          args: const ReportPageArgs(chartId: 'chart-1'),
          engineClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('연애'));
    await tester.pumpAndSettle();

    expect(client.reportRequests.map((request) => request.reportType), [
      'personality',
      'relationship',
    ]);
    expect(find.text('relationship 요약'), findsOneWidget);

    await tester.tap(find.text('성향'));
    await tester.pumpAndSettle();

    expect(client.reportRequests.map((request) => request.reportType), [
      'personality',
      'relationship',
    ]);
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
