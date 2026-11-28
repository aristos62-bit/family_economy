// ============================================================
// FILE: account_password_dialog_test.dart
// Path: test/unit/core/widgets/account_password_dialog_test.dart
// Ρόλος: Behavior test του διαλόγου κωδικού (E90).
// ============================================================

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_economy/core/utils/account_deletion_policy.dart';
import 'package:family_economy/core/widgets/account_password_dialog.dart';

void main() {
  group('AccountPasswordDialog — E90', () {
    Future<String? Function()> openDialog(WidgetTester tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await AccountPasswordDialog.show(context);
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

    testWidgets('κενός κωδικός → inline σφάλμα και ο διάλογος μένει ανοιχτός', (
      tester,
    ) async {
      await openDialog(tester);

      await tester.tap(find.text(AccountDeletionPolicy.deleteAction));
      await tester.pumpAndSettle();

      expect(
        find.text(AccountDeletionPolicy.passwordEmptyMessage),
        findsOneWidget,
      );
      expect(find.byType(AccountPasswordDialog), findsOneWidget);
    });

    testWidgets('κωδικός με κενά → επιστρέφεται αυτούσιος (raw)', (
      tester,
    ) async {
      final result = await openDialog(tester);

      await tester.enterText(find.byType(TextField), '  secret  ');
      await tester.tap(find.text(AccountDeletionPolicy.deleteAction));
      await tester.pumpAndSettle();

      expect(result(), '  secret  ');
      expect(find.byType(AccountPasswordDialog), findsNothing);
    });

    testWidgets('Άκυρο → null', (tester) async {
      final result = await openDialog(tester);

      await tester.tap(find.text(AccountDeletionPolicy.cancelAction));
      await tester.pumpAndSettle();

      expect(result(), isNull);
      expect(find.byType(AccountPasswordDialog), findsNothing);
    });

    testWidgets('το σφάλμα καθαρίζει όταν αρχίσει η πληκτρολόγηση', (
      tester,
    ) async {
      await openDialog(tester);

      await tester.tap(find.text(AccountDeletionPolicy.deleteAction));
      await tester.pumpAndSettle();
      expect(
        find.text(AccountDeletionPolicy.passwordEmptyMessage),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'x');
      await tester.pumpAndSettle();

      expect(
        find.text(AccountDeletionPolicy.passwordEmptyMessage),
        findsNothing,
      );
    });
  });
}
