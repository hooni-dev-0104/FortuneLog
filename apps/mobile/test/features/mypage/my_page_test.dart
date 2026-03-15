import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fortune_log_mobile/features/mypage/my_page.dart';

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
}
