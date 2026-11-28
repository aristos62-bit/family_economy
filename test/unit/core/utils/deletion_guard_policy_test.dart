// ============================================================
// FILE: deletion_guard_policy_test.dart
// Path: test/unit/core/utils/deletion_guard_policy_test.dart
// Ρόλος: Έλεγχος του κανόνα SEC-006a χωρίς Firestore.
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:family_economy/core/utils/deletion_guard_policy.dart';

void main() {
  group('DeletionGuardPolicy.decide — SEC-006a', () {
    test('cache snapshot → ignore ακόμα και με deleted:true', () {
      expect(
        DeletionGuardPolicy.decide(
          fromCache: true,
          hasPendingWrites: false,
          exists: true,
          deleted: true,
        ),
        DeletionGuardAction.ignore,
      );
    });

    test('cache snapshot χωρίς doc → ignore (offline πρώτη εκκίνηση)', () {
      expect(
        DeletionGuardPolicy.decide(
          fromCache: true,
          hasPendingWrites: false,
          exists: false,
          deleted: false,
        ),
        DeletionGuardAction.ignore,
      );
    });

    test('pending write → ignore (δική μας εγγραφή)', () {
      expect(
        DeletionGuardPolicy.decide(
          fromCache: false,
          hasPendingWrites: true,
          exists: true,
          deleted: true,
        ),
        DeletionGuardAction.ignore,
      );
    });

    test('server-confirmed missing doc → lock', () {
      expect(
        DeletionGuardPolicy.decide(
          fromCache: false,
          hasPendingWrites: false,
          exists: false,
          deleted: false,
        ),
        DeletionGuardAction.lock,
      );
    });

    test('server-confirmed deleted:true → lock', () {
      expect(
        DeletionGuardPolicy.decide(
          fromCache: false,
          hasPendingWrites: false,
          exists: true,
          deleted: true,
        ),
        DeletionGuardAction.lock,
      );
    });

    test('server-confirmed ενεργό doc → ignore', () {
      expect(
        DeletionGuardPolicy.decide(
          fromCache: false,
          hasPendingWrites: false,
          exists: true,
          deleted: false,
        ),
        DeletionGuardAction.ignore,
      );
    });

    test('cache + pending + deleted → ignore (καμία απόδειξη)', () {
      expect(
        DeletionGuardPolicy.decide(
          fromCache: true,
          hasPendingWrites: true,
          exists: true,
          deleted: true,
        ),
        DeletionGuardAction.ignore,
      );
    });
  });
}
