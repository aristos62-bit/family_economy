// ============================================================
// FILE: notification_edit_dialog_test.dart
// Path: test/unit/core/widgets/notification_edit_dialog_test.dart
// Ρόλος: Behavior test του διαλόγου υπενθύμισης (E91).
// ============================================================

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_economy/core/widgets/notification_edit_dialog.dart';

void main() {
  group('NotificationEditDialog — E91', () {
    const emptyError = 'Παρακαλώ γράψτε ένα μήνυμα υπενθύμισης';

    Future<Map<String, dynamic>? Function()> openDialog(
      WidgetTester tester,
    ) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => NotificationEditDialog(
                        selectedDate: DateTime.now().add(
                          const Duration(days: 1),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return () => result;
    }

    testWidgets('κενό μήνυμα → inline σφάλμα και ο διάλογος μένει ανοιχτός', (
      tester,
    ) async {
      await openDialog(tester);

      await tester.tap(find.text('Δημιουργία'));
      await tester.pumpAndSettle();

      expect(find.text(emptyError), findsOneWidget);
      expect(find.byType(NotificationEditDialog), findsOneWidget);
    });

    testWidgets('έγκυρο μήνυμα → κλείνει και επιστρέφει το μήνυμα', (
      tester,
    ) async {
      final result = await openDialog(tester);

      await tester.enterText(find.byType(TextField).first, 'Να πληρώσω ρεύμα');
      await tester.tap(find.text('Δημιουργία'));
      await tester.pumpAndSettle();

      expect(result(), isNotNull);
      expect(result()!['message'], 'Να πληρώσω ρεύμα');
      expect(find.byType(NotificationEditDialog), findsNothing);
    });

    testWidgets('μικρή οθόνη: το σφάλμα εμφανίζεται ορατό μετά το Save', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await openDialog(tester);

      // Ο χρήστης κάνει scroll στο κάτω μέρος και πατά Save.
      await tester.ensureVisible(find.text('Δημιουργία'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Δημιουργία'));
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.text(emptyError));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(500));
    });
  });
}
