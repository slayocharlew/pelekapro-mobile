import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/app/app.dart';

void main() {
  testWidgets('starter screen reports Android and API configuration status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PelekaProApp());

    expect(find.text('PelekaPro Mobile'), findsOneWidget);
    expect(find.text('Driver Delivery Application'), findsOneWidget);
    expect(find.text('Android environment ready'), findsOneWidget);
    expect(find.text('Backend integration is the next phase.'), findsOneWidget);
    expect(find.text('API base URL'), findsOneWidget);
    expect(find.text('Not configured'), findsOneWidget);
  });
}
