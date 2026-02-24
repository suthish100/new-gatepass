import 'package:e_gatepass/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders welcome shell', (WidgetTester tester) async {
    await tester.pumpWidget(const GatePassApp());
    expect(find.text('E-Gate Pass System'), findsOneWidget);
  });
}
