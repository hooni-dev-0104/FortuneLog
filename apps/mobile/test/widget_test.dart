import 'package:flutter_test/flutter_test.dart';

import 'package:fortune_log_mobile/main.dart';

void main() {
  testWidgets('renders dev test screen title', (WidgetTester tester) async {
    await tester.pumpWidget(const FortuneLogDevApp());
    expect(find.text('FortuneLog Dev Test'), findsOneWidget);
  });
}
