import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fortune_log_mobile/features/mypage/my_page.dart';
import 'package:fortune_log_mobile/features/policy/policy_document_page.dart';

void main() {
  testWidgets('shows commerce and policy sections', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MyPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('주문 / 결제 · 구독'), findsOneWidget);
    expect(find.text('회원 탈퇴 요청'), findsOneWidget);
    expect(
      find.text('결제/구독 상태를 불러오지 못했습니다.'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('정책 문서'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('정책 문서'), findsOneWidget);
    expect(find.text('환불 정책'), findsOneWidget);
  });

  testWidgets('opens in-app policy document page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: MyPage()),
        routes: {
          PolicyDocumentPage.routeName: (context) {
            final args = ModalRoute.of(context)!.settings.arguments
                as PolicyDocumentRouteArgs;
            return PolicyDocumentPage(args: args);
          },
        },
      ),
    );
    await tester.pumpAndSettle();

    Future<void> openAndAssert(String rowTitle, String pageTitle) async {
      await tester.scrollUntilVisible(
        find.text(rowTitle),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(rowTitle));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(pageTitle),
        ),
        findsOneWidget,
      );
      expect(find.text('웹 문서 열기'), findsOneWidget);
      expect(
        find.text('베타 배포 기준 정책 문서입니다. 최신 고지본은 웹 문서에서 확인할 수 있습니다.'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await openAndAssert('이용약관', '이용약관');
    await openAndAssert('개인정보 처리방침', '개인정보 처리방침');
    await openAndAssert('환불 정책', '환불 정책');
  });
}
