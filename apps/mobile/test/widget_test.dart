import 'package:flutter_test/flutter_test.dart';

import 'package:fortune_log_mobile/main.dart';

void main() {
  testWidgets('shows init error without Supabase config', (WidgetTester tester) async {
    await tester.pumpWidget(const FortuneLogApp());
    expect(find.textContaining('서비스 연결에 실패했습니다'), findsOneWidget);
  });
}
