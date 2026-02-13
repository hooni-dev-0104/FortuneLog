import 'package:flutter_test/flutter_test.dart';

import 'package:fortune_log_mobile/main.dart';

void main() {
  testWidgets('renders onboarding title', (WidgetTester tester) async {
    await tester.pumpWidget(const FortuneLogApp());
    expect(find.text('FortuneLog'), findsOneWidget);
  });
}
