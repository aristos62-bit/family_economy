// ============================================================
// FILE: account_deletion_policy_test.dart
// Path: test/unit/core/utils/account_deletion_policy_test.dart
// Ρόλος: Έλεγχος του κανόνα SEC-005 χωρίς Firestore.
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:family_economy/core/utils/account_deletion_policy.dart';

void main() {
  group('AccountDeletionPolicy.collections — SEC-005', () {
    test('ακριβώς 12 συλλογές, χωρίς διπλότυπα', () {
      expect(AccountDeletionPolicy.collections.length, 12);
      expect(
        AccountDeletionPolicy.collections.toSet().length,
        AccountDeletionPolicy.collections.length,
      );
    });

    test('περιέχει όλες τις συλλογές κάτω από users/{uid}', () {
      expect(
        AccountDeletionPolicy.collections,
        containsAll(<String>[
          'notifications',
          'transactions',
          'budgets',
          'accounts',
          'oil_purchases',
          'tags',
          'categories',
          'settings',
          'account_snapshots',
          'attachments',
          'transaction_splits',
          'transaction_tags',
        ]),
      );
    });

    test('το categories είναι τελευταίο (μετά τις υποκατηγορίες)', () {
      expect(
        AccountDeletionPolicy.collections.last,
        AccountDeletionPolicy.categoriesCollection,
      );
    });

    test('οι υποκατηγορίες δεν είναι αυτόνομη συλλογή', () {
      expect(
        AccountDeletionPolicy.collections,
        isNot(contains(AccountDeletionPolicy.subcategoriesCollection)),
      );
    });

    test('το exchange_rates μένει εκτός (global, read-only)', () {
      expect(
        AccountDeletionPolicy.collections,
        isNot(contains('exchange_rates')),
      );
    });
  });

  group('AccountDeletionPolicy.isDeletionPending — SEC-005', () {
    test('deleted: true → εκκρεμεί διαγραφή', () {
      expect(
        AccountDeletionPolicy.isDeletionPending(<String, dynamic>{
          'deleted': true,
        }),
        isTrue,
      );
    });

    test('deleted: false → κανονικός λογαριασμός', () {
      expect(
        AccountDeletionPolicy.isDeletionPending(<String, dynamic>{
          'deleted': false,
        }),
        isFalse,
      );
    });

    test('χωρίς πεδίο ή null doc → όχι εκκρεμής διαγραφή', () {
      expect(
        AccountDeletionPolicy.isDeletionPending(<String, dynamic>{}),
        isFalse,
      );
      expect(AccountDeletionPolicy.isDeletionPending(null), isFalse);
    });

    test('τιμή άλλου τύπου δεν θεωρείται marker', () {
      expect(
        AccountDeletionPolicy.isDeletionPending(<String, dynamic>{
          'deleted': 'true',
        }),
        isFalse,
      );
    });
  });

  group('AccountDeletionPolicy.chunk — SEC-005', () {
    test('κενή λίστα → κανένα chunk', () {
      expect(AccountDeletionPolicy.chunk(<int>[]), isEmpty);
    });

    test('499 στοιχεία → ένα chunk', () {
      final chunks = AccountDeletionPolicy.chunk(
        List<int>.generate(499, (i) => i),
      );
      expect(chunks.length, 1);
      expect(chunks.first.length, 499);
    });

    test('500 στοιχεία → 499 + 1 (νέο batch ανά chunk)', () {
      final chunks = AccountDeletionPolicy.chunk(
        List<int>.generate(500, (i) => i),
      );
      expect(chunks.length, 2);
      expect(chunks[0].length, 499);
      expect(chunks[1].length, 1);
    });

    test('1000 στοιχεία → 499 + 499 + 2', () {
      final chunks = AccountDeletionPolicy.chunk(
        List<int>.generate(1000, (i) => i),
      );
      expect(chunks.map((chunk) => chunk.length), <int>[499, 499, 2]);
    });

    test('προσαρμοσμένο όριο', () {
      final chunks = AccountDeletionPolicy.chunk(
        List<int>.generate(5, (i) => i),
        maxWrites: 2,
      );
      expect(chunks.map((chunk) => chunk.length), <int>[2, 2, 1]);
    });

    test('μη έγκυρο όριο → 1 write ανά chunk', () {
      final chunks = AccountDeletionPolicy.chunk(
        List<int>.generate(3, (i) => i),
        maxWrites: 0,
      );
      expect(chunks.map((chunk) => chunk.length), <int>[1, 1, 1]);
    });
  });

  group('AccountDeletionPolicy σταθερές — SEC-005', () {
    test('όριο batch 499 (Firestore 500)', () {
      expect(AccountDeletionPolicy.maxWritesPerBatch, 499);
    });

    test('timeout 20s ανά ανάγνωση/batch', () {
      expect(
        AccountDeletionPolicy.operationTimeout,
        const Duration(seconds: 20),
      );
    });

    test('marker fields σταθερά', () {
      expect(AccountDeletionPolicy.markerField, 'deleted');
      expect(AccountDeletionPolicy.markerTimestampField, 'deleted_at');
    });

    test('μηνύματα έτοιμα για UI (χωρίς raw σφάλμα)', () {
      expect(AccountDeletionPolicy.pendingStartupMessage, isNotEmpty);
      expect(AccountDeletionPolicy.pendingLoginMessage, isNotEmpty);
      expect(AccountDeletionPolicy.partialMessage, isNotEmpty);
      expect(AccountDeletionPolicy.failedMessage, isNotEmpty);
      expect(AccountDeletionPolicy.passwordEmptyMessage, isNotEmpty);
      expect(AccountDeletionPolicy.authPendingTitle, isNotEmpty);
      expect(AccountDeletionPolicy.authPendingMessage, isNotEmpty);
      expect(AccountDeletionPolicy.authPendingClosedMessage, isNotEmpty);
    });
  });
}
