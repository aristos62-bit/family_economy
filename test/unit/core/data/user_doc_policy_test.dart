// ============================================================
// FILE: user_doc_policy_test.dart
// Path: test/unit/core/data/user_doc_policy_test.dart
// Ρόλος: Έλεγχος του κανόνα E64 χωρίς Firestore.
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:family_economy/core/data/user_doc_policy.dart';

void main() {
  group('UserDocPolicy.afterCache — E64', () {
    test('cache hit → cacheHit ακόμα και επιβεβαιωμένα offline', () {
      expect(
        UserDocPolicy.afterCache(cacheExists: true, confirmedOffline: true),
        UserDocAction.cacheHit,
      );
    });

    test('cache miss + επιβεβαιωμένα offline → skipOffline', () {
      expect(
        UserDocPolicy.afterCache(cacheExists: false, confirmedOffline: true),
        UserDocAction.skipOffline,
      );
    });

    test('cache miss + online → readServer', () {
      expect(
        UserDocPolicy.afterCache(cacheExists: false, confirmedOffline: false),
        UserDocAction.readServer,
      );
    });
  });

  group('UserDocPolicy.afterServer — E64', () {
    test('ο server βρήκε το doc → exists (καμία εγγραφή)', () {
      expect(
        UserDocPolicy.afterServer(serverExists: true),
        UserDocAction.exists,
      );
    });

    test('ο server επιβεβαίωσε ότι λείπει → create', () {
      expect(
        UserDocPolicy.afterServer(serverExists: false),
        UserDocAction.create,
      );
    });
  });

  group('UserDocPolicy.afterFailure — E64', () {
    test('timeout → skipOffline', () {
      expect(
        UserDocPolicy.afterFailure(timedOut: true, code: null),
        UserDocAction.skipOffline,
      );
    });

    test('unavailable → skipOffline', () {
      expect(
        UserDocPolicy.afterFailure(timedOut: false, code: 'unavailable'),
        UserDocAction.skipOffline,
      );
    });

    test('deadline-exceeded → skipOffline', () {
      expect(
        UserDocPolicy.afterFailure(timedOut: false, code: 'deadline-exceeded'),
        UserDocAction.skipOffline,
      );
    });

    test('network-request-failed → skipOffline', () {
      expect(
        UserDocPolicy.afterFailure(
          timedOut: false,
          code: 'network-request-failed',
        ),
        UserDocAction.skipOffline,
      );
    });

    test('permission-denied → skipError (καμία εγγραφή)', () {
      expect(
        UserDocPolicy.afterFailure(timedOut: false, code: 'permission-denied'),
        UserDocAction.skipError,
      );
    });

    test('άγνωστος κωδικός → skipError', () {
      expect(
        UserDocPolicy.afterFailure(timedOut: false, code: 'internal'),
        UserDocAction.skipError,
      );
    });

    test('χωρίς κωδικό → skipError', () {
      expect(
        UserDocPolicy.afterFailure(timedOut: false, code: null),
        UserDocAction.skipError,
      );
    });
  });

  group('UserDocPolicy σταθερές — E64', () {
    test('timeout 8s (ίδιο με E5)', () {
      expect(UserDocPolicy.serverTimeout, const Duration(seconds: 8));
    });

    test('ακριβώς 3 offline κωδικοί', () {
      expect(UserDocPolicy.offlineCodes.length, 3);
      expect(UserDocPolicy.isOfflineCode('unavailable'), isTrue);
      expect(UserDocPolicy.isOfflineCode('permission-denied'), isFalse);
      expect(UserDocPolicy.isOfflineCode(null), isFalse);
    });
  });

  group('UserDocPolicy.isDeletionPending — SEC-005', () {
    test('deleted: true → true (ημιτελής διαγραφή)', () {
      expect(
        UserDocPolicy.isDeletionPending(<String, dynamic>{'deleted': true}),
        isTrue,
      );
    });

    test('deleted: false ή χωρίς πεδίο → false', () {
      expect(
        UserDocPolicy.isDeletionPending(<String, dynamic>{'deleted': false}),
        isFalse,
      );
      expect(UserDocPolicy.isDeletionPending(<String, dynamic>{}), isFalse);
      expect(UserDocPolicy.isDeletionPending(null), isFalse);
    });

    test('το deletionPending είναι ξεχωριστό outcome', () {
      expect(UserDocOutcome.values, contains(UserDocOutcome.deletionPending));
      expect(
        UserDocOutcome.values.where(
          (outcome) => outcome == UserDocOutcome.deletionPending,
        ),
        hasLength(1),
      );
    });
  });
}
