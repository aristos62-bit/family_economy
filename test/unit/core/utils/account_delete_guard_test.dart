// ============================================================
// FILE: account_delete_guard_test.dart
// Path: test/unit/core/utils/account_delete_guard_test.dart
// Ρόλος: Έλεγχος της καθαρής απόφασης διαγραφής λογαριασμού (E7).
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:family_economy/core/utils/account_delete_guard.dart';

void main() {
  group('AccountDeleteGuard.evaluate', () {
    test('μηδέν ενεργοί λογαριασμοί → φραγή', () {
      final decision = AccountDeleteGuard.evaluate(0);

      expect(decision.canDelete, isFalse);
      expect(decision.block, AccountDeleteBlock.noActiveAccount);
      expect(decision.message, isNotEmpty);
    });

    test('αρνητικό πλήθος → φραγή (αμυντικά)', () {
      final decision = AccountDeleteGuard.evaluate(-3);

      expect(decision.canDelete, isFalse);
      expect(decision.block, AccountDeleteBlock.noActiveAccount);
    });

    test('ένας ενεργός λογαριασμός → φραγή τελευταίου', () {
      final decision = AccountDeleteGuard.evaluate(1);

      expect(decision.canDelete, isFalse);
      expect(decision.block, AccountDeleteBlock.lastActiveAccount);
      expect(decision.message, contains('τελευταίος'));
    });

    test('δύο ενεργοί λογαριασμοί → επιτρέπεται', () {
      final decision = AccountDeleteGuard.evaluate(2);

      expect(decision.canDelete, isTrue);
      expect(decision.block, AccountDeleteBlock.none);
    });

    test('πολλοί ενεργοί λογαριασμοί → επιτρέπεται', () {
      final decision = AccountDeleteGuard.evaluate(25);

      expect(decision.canDelete, isTrue);
      expect(decision.block, AccountDeleteBlock.none);
    });

    test('επιτρεπόμενη απόφαση δεν κουβαλά μήνυμα', () {
      final decision = AccountDeleteGuard.evaluate(2);

      expect(decision.message, isEmpty);
    });

    test('τα μηνύματα φραγής δεν ξεκινούν με πρόθεμα σφάλματος', () {
      final empty = AccountDeleteGuard.evaluate(0);
      final last = AccountDeleteGuard.evaluate(1);

      expect(empty.message.startsWith('Σφάλμα'), isFalse);
      expect(last.message.startsWith('Σφάλμα'), isFalse);
    });

    test('η φραγή του τελευταίου εξηγεί την επόμενη ενέργεια', () {
      final decision = AccountDeleteGuard.evaluate(1);

      expect(decision.message, contains('Δημιουργήστε'));
    });
  });
}
