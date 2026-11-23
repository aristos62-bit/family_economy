// ============================================================
// FILE: database_cleanup_policy_test.dart
// Path: test/unit/core/utils/database_cleanup_policy_test.dart
// Ρόλος: Έλεγχοι του καθαρού κανόνα καθαρισμού (E34).
// Καμία εξάρτηση από Firebase runtime — μόνο Timestamp ως τιμή.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_economy/core/utils/database_cleanup_policy.dart';

void main() {
  final now = DateTime(2026, 11, 23, 12);
  final old = now.subtract(const Duration(days: 100));
  final recent = now.subtract(const Duration(days: 10));

  Timestamp ts(DateTime value) => Timestamp.fromDate(value);

  group('CleanupPolicy — chunking (E34)', () {
    test('κενή λίστα → κανένα chunk', () {
      expect(CleanupPolicy.chunk<int>(const []), isEmpty);
    });

    test('499 στοιχεία → 1 chunk', () {
      final chunks = CleanupPolicy.chunk<int>(
        List<int>.generate(499, (i) => i),
      );
      expect(chunks.length, 1);
      expect(chunks.first.length, 499);
    });

    test('500 στοιχεία → 2 chunks (499 + 1)', () {
      final chunks = CleanupPolicy.chunk<int>(
        List<int>.generate(500, (i) => i),
      );
      expect(chunks.length, 2);
      expect(chunks[0].length, 499);
      expect(chunks[1].length, 1);
    });

    test('1000 στοιχεία → 499 + 499 + 2', () {
      final chunks = CleanupPolicy.chunk<int>(
        List<int>.generate(1000, (i) => i),
      );
      expect(chunks.map((c) => c.length).toList(), <int>[499, 499, 2]);
    });

    test('κανένα chunk δεν ξεπερνά το όριο', () {
      final chunks = CleanupPolicy.chunk<int>(
        List<int>.generate(1234, (i) => i),
        maxWrites: 100,
      );
      expect(chunks.every((c) => c.length <= 100), isTrue);
      expect(chunks.fold<int>(0, (acc, c) => acc + c.length), 1234);
    });

    test('maxWrites < 1 → 1 στοιχείο ανά chunk (ασφαλές)', () {
      final chunks = CleanupPolicy.chunk<int>(
        const <int>[1, 2, 3],
        maxWrites: 0,
      );
      expect(chunks.length, 3);
    });
  });

  group('CleanupPolicy — όρια ημερών', () {
    test('clampDays κάτω από 7 → 7', () {
      expect(CleanupPolicy.clampDays(0), 7);
      expect(CleanupPolicy.clampDays(6), 7);
    });

    test('clampDays πάνω από 365 → 365', () {
      expect(CleanupPolicy.clampDays(500), 365);
    });

    test('clampDays εντός ορίων μένει ως έχει', () {
      expect(CleanupPolicy.clampDays(90), 90);
      expect(CleanupPolicy.clampDays(365), 365);
    });

    test('cutoff = now - ημέρες', () {
      expect(
        CleanupPolicy.cutoff(now, 30),
        now.subtract(const Duration(days: 30)),
      );
    });

    test('cutoff σέβεται το clamp', () {
      expect(
        CleanupPolicy.cutoff(now, 1),
        now.subtract(const Duration(days: 7)),
      );
    });
  });

  group('CleanupPolicy — parseTimestamp', () {
    test('null → null', () {
      expect(CleanupPolicy.parseTimestamp(null), isNull);
    });

    test('Timestamp → DateTime', () {
      expect(CleanupPolicy.parseTimestamp(ts(old)), old);
    });

    test('int millis → DateTime', () {
      expect(
        CleanupPolicy.parseTimestamp(old.millisecondsSinceEpoch),
        old,
      );
    });

    test('ISO string → DateTime', () {
      expect(
        CleanupPolicy.parseTimestamp('2026-05-25T10:00:00.000'),
        DateTime(2026, 5, 25, 10),
      );
    });

    test('DateTime → DateTime', () {
      expect(CleanupPolicy.parseTimestamp(old), old);
    });

    test('άκυρο string → null', () {
      expect(CleanupPolicy.parseTimestamp('not-a-date'), isNull);
      expect(CleanupPolicy.parseTimestamp('   '), isNull);
    });
  });

  group('CleanupPolicy — υπενθυμίσεις', () {
    test('διαβασμένη και παλιά → διαγραφή', () {
      expect(
        CleanupPolicy.shouldDeleteNotification(
          <String, dynamic>{
            'deleted': false,
            'delivered_at': ts(old),
            'read_at': ts(old),
          },
          now,
          90,
        ),
        isTrue,
      );
    });

    test('απορριφθείσα και παλιά → διαγραφή', () {
      expect(
        CleanupPolicy.shouldDeleteNotification(
          <String, dynamic>{'deleted': false, 'dismissed_at': ts(old)},
          now,
          90,
        ),
        isTrue,
      );
    });

    test('παραδοθείσα και παλιά → διαγραφή', () {
      expect(
        CleanupPolicy.shouldDeleteNotification(
          <String, dynamic>{'deleted': false, 'delivered_at': ts(old)},
          now,
          90,
        ),
        isTrue,
      );
    });

    test('ληγμένη επαναλαμβανόμενη → διαγραφή', () {
      expect(
        CleanupPolicy.shouldDeleteNotification(
          <String, dynamic>{
            'deleted': false,
            'is_recurring': true,
            'recurring_end_at': ts(now.subtract(const Duration(days: 1))),
          },
          now,
          365,
        ),
        isTrue,
      );
    });

    test('προγραμματισμένη στο παρελθόν χωρίς παράδοση → διαγραφή', () {
      expect(
        CleanupPolicy.shouldDeleteNotification(
          <String, dynamic>{'deleted': false, 'scheduled_for': ts(old)},
          now,
          90,
        ),
        isTrue,
      );
    });

    test('μελλοντική προγραμματισμένη → παραμένει', () {
      expect(
        CleanupPolicy.shouldDeleteNotification(
          <String, dynamic>{
            'deleted': false,
            'scheduled_for': ts(now.add(const Duration(days: 3))),
          },
          now,
          90,
        ),
        isFalse,
      );
    });

    test('πρόσφατη παραδοθείσα → παραμένει', () {
      expect(
        CleanupPolicy.shouldDeleteNotification(
          <String, dynamic>{'deleted': false, 'delivered_at': ts(recent)},
          now,
          90,
        ),
        isFalse,
      );
    });

    test('soft-deleted με παλιό updated_at → διαγραφή (E39)', () {
      expect(
        CleanupPolicy.shouldDeleteNotification(
          <String, dynamic>{'deleted': true, 'updated_at': ts(old)},
          now,
          90,
        ),
        isTrue,
      );
    });

    test('soft-deleted πρόσφατη → παραμένει', () {
      expect(
        CleanupPolicy.shouldDeleteNotification(
          <String, dynamic>{'deleted': true, 'updated_at': ts(recent)},
          now,
          90,
        ),
        isFalse,
      );
    });

    test('soft-deleted χωρίς ημερομηνίες → παραμένει (συντηρητικό)', () {
      expect(
        CleanupPolicy.shouldDeleteNotification(
          <String, dynamic>{'deleted': true},
          now,
          90,
        ),
        isFalse,
      );
    });

    test('κενό doc → παραμένει', () {
      expect(
        CleanupPolicy.shouldDeleteNotification(<String, dynamic>{}, now, 90),
        isFalse,
      );
    });
  });

  group('CleanupPolicy — προϋπολογισμοί', () {
    test('λήξη παλιά → διαγραφή', () {
      expect(
        CleanupPolicy.shouldDeleteBudget(
          <String, dynamic>{
            'deleted': false,
            'end_date': '2025-01-01',
            'is_active': true,
          },
          now,
          365,
        ),
        isTrue,
      );
    });

    test('λήξη πρόσφατη → παραμένει', () {
      expect(
        CleanupPolicy.shouldDeleteBudget(
          <String, dynamic>{
            'deleted': false,
            'end_date': '2026-11-01',
            'is_active': true,
          },
          now,
          365,
        ),
        isFalse,
      );
    });

    test('ανενεργός με ληγμένη λήξη → διαγραφή', () {
      expect(
        CleanupPolicy.shouldDeleteBudget(
          <String, dynamic>{
            'deleted': false,
            'end_date': ts(now.subtract(const Duration(days: 1))),
            'is_active': false,
          },
          now,
          365,
        ),
        isTrue,
      );
    });

    test('χωρίς λήξη και ενεργός → παραμένει', () {
      expect(
        CleanupPolicy.shouldDeleteBudget(
          <String, dynamic>{'deleted': false, 'is_active': true},
          now,
          365,
        ),
        isFalse,
      );
    });

    test('soft-deleted με παλιό updated_at → διαγραφή (E39)', () {
      expect(
        CleanupPolicy.shouldDeleteBudget(
          <String, dynamic>{'deleted': true, 'updated_at': ts(old)},
          now,
          90,
        ),
        isTrue,
      );
    });

    test('soft-deleted πρόσφατος → παραμένει', () {
      expect(
        CleanupPolicy.shouldDeleteBudget(
          <String, dynamic>{'deleted': true, 'updated_at': ts(recent)},
          now,
          90,
        ),
        isFalse,
      );
    });
  });

  group('CleanupPolicy — aged docs', () {
    test('updated_at παλιό → διαγραφή', () {
      expect(
        CleanupPolicy.shouldDeleteAged(
          <String, dynamic>{'updated_at': ts(old)},
          now.subtract(const Duration(days: 30)),
        ),
        isTrue,
      );
    });

    test('updated_at πρόσφατο → παραμένει', () {
      expect(
        CleanupPolicy.shouldDeleteAged(
          <String, dynamic>{'updated_at': ts(recent)},
          now.subtract(const Duration(days: 30)),
        ),
        isFalse,
      );
    });

    test('χωρίς updated_at → παραμένει (συντηρητικό)', () {
      expect(
        CleanupPolicy.shouldDeleteAged(
          <String, dynamic>{'created_at': ts(old)},
          now.subtract(const Duration(days: 30)),
        ),
        isFalse,
      );
    });

    test('int millis παλιό → διαγραφή', () {
      expect(
        CleanupPolicy.shouldDeleteAged(
          <String, dynamic>{'updated_at': old.millisecondsSinceEpoch},
          now.subtract(const Duration(days: 30)),
        ),
        isTrue,
      );
    });
  });

  group('CleanupPolicy — μηνύματα', () {
    test('τίτλοι ανά κατάσταση', () {
      expect(
        CleanupPolicy.titleOf(CleanupOutcome.complete),
        CleanupPolicy.completeTitle,
      );
      expect(
        CleanupPolicy.titleOf(CleanupOutcome.partial),
        CleanupPolicy.partialTitle,
      );
      expect(
        CleanupPolicy.titleOf(CleanupOutcome.cancelled),
        CleanupPolicy.cancelledTitle,
      );
    });

    test('countLine μορφή', () {
      expect(CleanupPolicy.countLine('Συναλλαγές', 5), '• Συναλλαγές: 5');
    });
  });
}
