// Smoke test: η οθόνη σφάλματος αρχικοποίησης (ErrorApp) χτίζεται
// χωρίς Firebase/providers. Δεν πατάμε «Επανεκκίνηση» γιατί το
// Phoenix.rebirth θέλει Phoenix ancestor (υπάρχει μόνο στο MyApp).
import 'package:flutter_test/flutter_test.dart';
import 'package:family_economy/main.dart';

void main() {
  testWidgets('ErrorApp shows init error', (WidgetTester tester) async {
    await tester.pumpWidget(const ErrorApp(error: 'test-error'));

    expect(find.text('Σφάλμα Αρχικοποίησης'), findsOneWidget);
    expect(find.textContaining('test-error'), findsOneWidget);
  });
}
