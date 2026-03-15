import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fortune_log_mobile/features/policy/policy_document_page.dart';

void main() {
  testWidgets('shows snackbar when external policy launch fails',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PolicyDocumentPage(
          args: PolicyDocumentRouteArgs(
            type: PolicyDocumentType.terms,
            externalUrl: Uri.parse('https://example.com/terms'),
          ),
          launchExternal: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('웹 문서 열기'));
    await tester.pumpAndSettle();

    expect(find.text('웹 정책 문서를 열 수 없습니다.'), findsOneWidget);
  });
}
