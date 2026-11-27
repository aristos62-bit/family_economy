// Smoke tests: η οθόνη σφάλματος αρχικοποίησης (ErrorApp) χτίζεται
// χωρίς Firebase/providers, το «Δοκιμή ξανά» δεν σκάει (L18), δεν
// πατιέται όσο τρέχει και λήγει με μήνυμα σε περίπτωση κολλήματος.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_economy/main.dart';

void main() {
  testWidgets('ErrorApp εμφανίζει γενικό μήνυμα χωρίς raw σφάλμα', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ErrorApp(onRetry: () async {}));

    expect(find.text('Σφάλμα Αρχικοποίησης'), findsOneWidget);
    expect(find.textContaining('Προσπάθειες:'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('ErrorApp δείχνει σταθερό μήνυμα όταν η επανάληψη αποτύχει', (
    WidgetTester tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      ErrorApp(
        onRetry: () async {
          calls++;
          throw Exception('second-error');
        },
      ),
    );

    await tester.tap(find.text('Δοκιμή ξανά'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.textContaining('Η επανάληψη απέτυχε.'), findsOneWidget);
    expect(find.textContaining('second-error'), findsNothing);
    expect(find.textContaining('Προσπάθειες: 1'), findsOneWidget);
  });

  testWidgets('ErrorApp ignores taps while a retry is running', (
    WidgetTester tester,
  ) async {
    var calls = 0;
    final completer = Completer<void>();
    await tester.pumpWidget(
      ErrorApp(
        onRetry: () {
          calls++;
          return completer.future;
        },
      ),
    );

    await tester.tap(find.text('Δοκιμή ξανά'));
    await tester.pump();
    expect(find.text('Νέα προσπάθεια…'), findsOneWidget);

    final runningButton = tester.widget<ElevatedButton>(
      find.byWidgetPredicate((w) => w is ElevatedButton),
    );
    expect(runningButton.onPressed, isNull);

    await tester.tap(find.text('Νέα προσπάθεια…'));
    await tester.pump();

    expect(calls, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Δοκιμή ξανά'), findsOneWidget);

    final idleButton = tester.widget<ElevatedButton>(
      find.byWidgetPredicate((w) => w is ElevatedButton),
    );
    expect(idleButton.onPressed, isNotNull);
  });

  testWidgets('ErrorApp λήγει με μήνυμα όταν η επανάληψη κολλήσει', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ErrorApp(onRetry: () => Completer<void>().future));

    await tester.tap(find.text('Δοκιμή ξανά'));
    await tester.pump();
    expect(find.text('Νέα προσπάθεια…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();

    expect(find.textContaining('20 δευτερόλεπτα'), findsOneWidget);
    expect(find.textContaining('Προσπάθειες: 1'), findsOneWidget);
    expect(find.text('Δοκιμή ξανά'), findsOneWidget);
  });
}
