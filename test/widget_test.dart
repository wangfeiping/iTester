import 'package:flutter_test/flutter_test.dart';

import 'package:itester/main.dart';

void main() {
  testWidgets('显示中文、日文、英文的“你好”', (WidgetTester tester) async {
    await tester.pumpWidget(const ITesterApp());

    expect(find.text('你好'), findsOneWidget);
    expect(find.text('こんにちは'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });
}
