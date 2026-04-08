import 'package:flutter_test/flutter_test.dart';
import 'package:zit_app/main.dart';

void main() {
  testWidgets('OilTrade smoke test — splash screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const OilTrade());
    expect(find.text('OilTrade'), findsOneWidget);
  });
}
