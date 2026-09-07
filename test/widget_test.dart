import 'package:flutter_test/flutter_test.dart';
import 'package:irancurrency/main.dart';

void main() {
  testWidgets('Irancurrency app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('Irancurrency'), findsOneWidget);
    expect(find.text('نقدی'), findsWidgets);
    expect(find.text('حواله'), findsWidgets);
  });
}
