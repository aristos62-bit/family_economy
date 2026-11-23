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

  group('AccountDeleteGuard.buildPlan — ζεύγη μεταφορών', () {
    test('ολοκληρωμένο ζεύγος → 2 legs + αντιστροφή υπολοίπων', () {
      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: [
          _leg(
            uuid: 'l1',
            accountId: 'A',
            amount: -100,
            groupId: 'g1',
            peerUuid: 'l2',
            peerAccountId: 'B',
          ),
        ],
      );

      expect(plan.annulledPairs, hasLength(1));
      expect(plan.annulledPairs.single.state, TransferPairState.complete);
      expect(plan.annulledPairs.single.peerUuid, 'l2');
      expect(plan.annulledPairs.single.peerAccountId, 'B');
      expect(plan.deltasByAccount['A'], closeTo(100, 1e-9));
      expect(plan.deltasByAccount['B'], closeTo(-100, 1e-9));
      expect(plan.plainLegUuids, isEmpty);
      expect(plan.completedPairs, 1);
      expect(plan.pendingPairs, 0);
      expect(plan.totalWrites, 5); // 2 legs + 2 deltas + λογαριασμός
    });

    test('εκκρεμές ζεύγος → κρύβεται χωρίς deltas', () {
      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: [
          _leg(
            uuid: 'p1',
            accountId: 'A',
            amount: -40,
            groupId: 'g2',
            peerUuid: 'p2',
            peerAccountId: 'B',
            scheduled: true,
          ),
        ],
      );

      expect(plan.annulledPairs, hasLength(1));
      expect(plan.annulledPairs.single.state, TransferPairState.pending);
      expect(plan.deltasByAccount, isEmpty);
      expect(plan.pendingPairs, 1);
      expect(plan.totalWrites, 3); // 2 legs + 0 deltas + λογαριασμός
    });

    test('μη-μεταφορά → απλό κρύψιμο', () {
      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: [
          _leg(
            uuid: 'e1',
            accountId: 'A',
            amount: -12,
            type: 'expense',
          ),
        ],
      );

      expect(plan.annulledPairs, isEmpty);
      expect(plan.plainLegUuids, ['e1']);
      expect(plan.deltasByAccount, isEmpty);
      expect(plan.totalWrites, 2);
    });

    test('εκκρεμές χωρίς peer πεδία → βρίσκεται από την ομάδα', () {
      final scheduledLeg = _leg(
        uuid: 's1',
        accountId: 'A',
        amount: -50,
        groupId: 'g3',
        scheduled: true,
      );
      final peerLeg = _leg(
        uuid: 's2',
        accountId: 'B',
        amount: 50,
        groupId: 'g3',
        scheduled: true,
      );

      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: [scheduledLeg],
        peerLegsByGroup: {
          'g3': [scheduledLeg, peerLeg],
        },
      );

      expect(plan.annulledPairs, hasLength(1));
      expect(plan.annulledPairs.single.peerUuid, 's2');
      expect(plan.annulledPairs.single.peerAccountId, 'B');
      expect(plan.deltasByAccount, isEmpty);
      expect(plan.pendingPairs, 1);
    });

    test('ομάδα χωρίς άλλο ενεργό σκέλος → μερικό, μόνο κρύψιμο', () {
      final leg = _leg(
        uuid: 's1',
        accountId: 'A',
        amount: -50,
        groupId: 'g4',
        scheduled: true,
      );

      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: [leg],
        peerLegsByGroup: {
          'g4': [leg],
        },
      );

      expect(plan.annulledPairs, isEmpty);
      expect(plan.plainLegUuids, ['s1']);
      expect(plan.partialPairs, 1);
      expect(plan.deltasByAccount, isEmpty);
    });

    test('ομάδα με 2 άλλα ενεργά σκέλη → ασυνεπές, μερικό', () {
      final leg = _leg(
        uuid: 's1',
        accountId: 'A',
        amount: -50,
        groupId: 'g5',
        scheduled: true,
      );

      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: [leg],
        peerLegsByGroup: {
          'g5': [
            leg,
            _leg(uuid: 's2', accountId: 'B', amount: 50, groupId: 'g5'),
            _leg(uuid: 's3', accountId: 'C', amount: 50, groupId: 'g5'),
          ],
        },
      );

      expect(plan.annulledPairs, isEmpty);
      expect(plan.plainLegUuids, ['s1']);
      expect(plan.partialPairs, 1);
    });

    test('ομαδοποίηση deltas ανά λογαριασμό (άθροισμα)', () {
      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: [
          _leg(
            uuid: 'l1',
            accountId: 'A',
            amount: -30,
            groupId: 'g1',
            peerUuid: 'l2',
            peerAccountId: 'B',
          ),
          _leg(
            uuid: 'l3',
            accountId: 'A',
            amount: -20,
            groupId: 'g2',
            peerUuid: 'l4',
            peerAccountId: 'B',
          ),
        ],
      );

      expect(plan.deltasByAccount['A'], closeTo(50, 1e-9));
      expect(plan.deltasByAccount['B'], closeTo(-50, 1e-9));
    });
  });

  group('AccountDeletePlan — chunks', () {
    test('κανένα ζεύγος δεν σπάει σε δύο chunks', () {
      final legs = <Map<String, dynamic>>[];
      for (var i = 0; i < 10; i++) {
        legs.add(
          _leg(
            uuid: 'l$i',
            accountId: 'A',
            amount: -10,
            groupId: 'g$i',
            peerUuid: 'p$i',
            peerAccountId: 'B$i',
          ),
        );
      }

      final plan =
          AccountDeleteGuard.buildPlan(accountUuid: 'A', activeLegs: legs);
      final chunks = plan.buildPairChunks(maxWrites: 5);

      expect(chunks, hasLength(10));
      for (final chunk in chunks) {
        expect(chunk.pairs, hasLength(1));
        expect(chunk.writeCount, lessThanOrEqualTo(5));
      }
    });

    test('deltas υπολογίζονται ανά chunk (σωστό retry)', () {
      final legs = <Map<String, dynamic>>[];
      for (var i = 0; i < 3; i++) {
        legs.add(
          _leg(
            uuid: 'l$i',
            accountId: 'A',
            amount: -10,
            groupId: 'g$i',
            peerUuid: 'p$i',
            peerAccountId: 'B',
          ),
        );
      }

      final plan =
          AccountDeleteGuard.buildPlan(accountUuid: 'A', activeLegs: legs);
      final chunks = plan.buildPairChunks(maxWrites: 6);

      expect(chunks, hasLength(2));
      expect(chunks[0].pairs, hasLength(2));
      expect(chunks[0].deltasByAccount['A'], closeTo(20, 1e-9));
      expect(chunks[0].deltasByAccount['B'], closeTo(-20, 1e-9));
      expect(chunks[1].pairs, hasLength(1));
      expect(chunks[1].deltasByAccount['A'], closeTo(10, 1e-9));
      expect(chunks[1].deltasByAccount['B'], closeTo(-10, 1e-9));
    });

    test('buildPlainChunks σέβεται το όριο', () {
      final legs = <Map<String, dynamic>>[
        for (var i = 0; i < 7; i++)
          _leg(uuid: 'e$i', accountId: 'A', amount: -1, type: 'expense'),
      ];

      final plan =
          AccountDeleteGuard.buildPlan(accountUuid: 'A', activeLegs: legs);
      final chunks = plan.buildPlainChunks(maxWrites: 3);

      expect(chunks, hasLength(3));
      expect(chunks[0], hasLength(3));
      expect(chunks[1], hasLength(3));
      expect(chunks[2], hasLength(1));
    });

    test('fitsSingleBatch όταν τα writes ≤ 499', () {
      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: [
          _leg(
            uuid: 'l1',
            accountId: 'A',
            amount: -10,
            groupId: 'g1',
            peerUuid: 'l2',
            peerAccountId: 'B',
          ),
        ],
      );

      expect(plan.fitsSingleBatch, isTrue);
      expect(plan.totalWrites, lessThanOrEqualTo(499));
    });
  });

  group('AccountDeleteGuard.buildRestoreUnits', () {
    test('έγκυρο ζεύγος → επαναφορά και των δύο σκελών με deltas', () {
      final units = AccountDeleteGuard.buildRestoreUnits(
        accountUuid: 'A',
        markedLegs: [
          _leg(
            uuid: 'a1',
            accountId: 'A',
            amount: -100,
            groupId: 'g1',
            deleted: true,
            marker: 'A',
            peerUuid: 'b1',
            peerAccountId: 'B',
          ),
          _leg(
            uuid: 'b1',
            accountId: 'B',
            amount: 100,
            groupId: 'g1',
            deleted: true,
            marker: 'A',
            peerUuid: 'a1',
            peerAccountId: 'A',
          ),
        ],
      );

      final unit = units.single;
      expect(unit.canRestore, isTrue);
      expect(unit.legUuids, containsAll(<String>['a1', 'b1']));
      expect(unit.appliesBalance, isTrue);
      expect(unit.deltasByAccount['A'], closeTo(-100, 1e-9));
      expect(unit.deltasByAccount['B'], closeTo(100, 1e-9));
      expect(unit.skipReason, isNull);
    });

    test('εκκρεμές ζεύγος → επαναφορά χωρίς deltas', () {
      final units = AccountDeleteGuard.buildRestoreUnits(
        accountUuid: 'A',
        markedLegs: [
          _leg(
            uuid: 'a1',
            accountId: 'A',
            amount: -100,
            groupId: 'g2',
            deleted: true,
            marker: 'A',
            peerUuid: 'b1',
            peerAccountId: 'B',
            scheduled: true,
          ),
          _leg(
            uuid: 'b1',
            accountId: 'B',
            amount: 100,
            groupId: 'g2',
            deleted: true,
            marker: 'A',
            peerUuid: 'a1',
            peerAccountId: 'A',
            scheduled: true,
          ),
        ],
      );

      final unit = units.single;
      expect(unit.canRestore, isTrue);
      expect(unit.appliesBalance, isFalse);
      expect(unit.deltasByAccount, isEmpty);
    });

    test('ένα μόνο σκέλος με marker → δεν επανέρχεται', () {
      final units = AccountDeleteGuard.buildRestoreUnits(
        accountUuid: 'A',
        markedLegs: [
          _leg(
            uuid: 'a1',
            accountId: 'A',
            amount: -100,
            groupId: 'g3',
            deleted: true,
            marker: 'A',
          ),
        ],
      );

      expect(units.single.canRestore, isFalse);
      expect(units.single.skipReason, 'incomplete_pair');
    });

    test('marker άλλου λογαριασμού → δεν επανέρχεται', () {
      final units = AccountDeleteGuard.buildRestoreUnits(
        accountUuid: 'A',
        markedLegs: [
          _leg(
            uuid: 'a1',
            accountId: 'A',
            amount: -100,
            groupId: 'g4',
            deleted: true,
            marker: 'X',
          ),
          _leg(
            uuid: 'b1',
            accountId: 'B',
            amount: 100,
            groupId: 'g4',
            deleted: true,
            marker: 'X',
          ),
        ],
      );

      expect(units.single.canRestore, isFalse);
    });

    test('μη έγκυρο σχήμα (ίδιος λογαριασμός) → δεν επανέρχεται', () {
      final units = AccountDeleteGuard.buildRestoreUnits(
        accountUuid: 'A',
        markedLegs: [
          _leg(
            uuid: 'a1',
            accountId: 'A',
            amount: -100,
            groupId: 'g5',
            deleted: true,
            marker: 'A',
          ),
          _leg(
            uuid: 'a2',
            accountId: 'A',
            amount: 100,
            groupId: 'g5',
            deleted: true,
            marker: 'A',
          ),
        ],
      );

      expect(units.single.canRestore, isFalse);
      expect(units.single.skipReason, 'invalid_shape');
    });

    test('ανενεργός peer λογαριασμός → δεν επανέρχεται', () {
      final units = AccountDeleteGuard.buildRestoreUnits(
        accountUuid: 'A',
        markedLegs: [
          _leg(
            uuid: 'a1',
            accountId: 'A',
            amount: -100,
            groupId: 'g6',
            deleted: true,
            marker: 'A',
          ),
          _leg(
            uuid: 'b1',
            accountId: 'B',
            amount: 100,
            groupId: 'g6',
            deleted: true,
            marker: 'A',
          ),
        ],
        activeAccountIds: <String>{'A'},
      );

      expect(units.single.canRestore, isFalse);
      expect(units.single.skipReason, 'peer_inactive');
    });

    test('επαναφορά αντιστρέφει ακριβώς τα deltas της διαγραφής', () {
      final leg = _leg(
        uuid: 'a1',
        accountId: 'A',
        amount: -100,
        groupId: 'g7',
        peerUuid: 'b1',
        peerAccountId: 'B',
      );

      final plan =
          AccountDeleteGuard.buildPlan(accountUuid: 'A', activeLegs: [leg]);

      final units = AccountDeleteGuard.buildRestoreUnits(
        accountUuid: 'A',
        markedLegs: [
          _leg(
            uuid: 'a1',
            accountId: 'A',
            amount: -100,
            groupId: 'g7',
            deleted: true,
            marker: 'A',
          ),
          _leg(
            uuid: 'b1',
            accountId: 'B',
            amount: 100,
            groupId: 'g7',
            deleted: true,
            marker: 'A',
          ),
        ],
      );

      final restored = units.single.deltasByAccount;
      for (final entry in plan.deltasByAccount.entries) {
        expect(restored[entry.key], closeTo(-entry.value, 1e-9));
      }
    });
  });

  group('AccountDeleteGuard.decide — E26', () {
    test('καθαρός λογαριασμός (χωρίς κινήσεις/budgets) → διαγραφή', () {
      final decision = AccountDeleteGuard.decide(
        activeAccountCount: 2,
        hasAnyTransaction: false,
        budgetsCount: 0,
      );

      expect(decision.action, AccountAction.delete);
      expect(decision.canDelete, isTrue);
      expect(decision.canArchive, isFalse);
      expect(decision.isBlocked, isFalse);
    });

    test('λογαριασμός με κινήσεις → αρχειοθέτηση με κενό μήνυμα', () {
      final decision = AccountDeleteGuard.decide(
        activeAccountCount: 2,
        hasAnyTransaction: true,
        budgetsCount: 0,
      );

      expect(decision.action, AccountAction.archive);
      expect(decision.canArchive, isTrue);
      expect(decision.canDelete, isFalse);
      expect(decision.message, isEmpty);
    });

    test('λογαριασμός με budgets και χωρίς κινήσεις → αρχειοθέτηση', () {
      final decision = AccountDeleteGuard.decide(
        activeAccountCount: 3,
        hasAnyTransaction: false,
        budgetsCount: 2,
      );

      expect(decision.action, AccountAction.archive);
    });

    test('τελευταίος ενεργός → φραγή (και για αρχειοθέτηση)', () {
      final decision = AccountDeleteGuard.decide(
        activeAccountCount: 1,
        hasAnyTransaction: true,
        budgetsCount: 0,
      );

      expect(decision.action, AccountAction.blockLast);
      expect(decision.isBlocked, isTrue);
      expect(decision.message, contains('τελευταίος'));
    });

    test('εκκρεμείς προγραμματισμένες → φραγή με πλήθος', () {
      final decision = AccountDeleteGuard.decide(
        activeAccountCount: 2,
        hasAnyTransaction: true,
        budgetsCount: 0,
        pendingCount: 2,
      );

      expect(decision.action, AccountAction.blockPending);
      expect(decision.message, contains('2 εκκρεμείς'));
      expect(decision.message, contains('Προγραμματισμένες'));
    });

    test('μία εκκρεμής → ενικός αριθμός στο μήνυμα', () {
      final decision = AccountDeleteGuard.decide(
        activeAccountCount: 2,
        hasAnyTransaction: true,
        budgetsCount: 0,
        pendingCount: 1,
      );

      expect(decision.action, AccountAction.blockPending);
      expect(decision.message, startsWith('Υπάρχει 1 εκκρεμής'));
      expect(decision.message, contains('Ακυρώστε την πρώτα'));
    });

    test('αρχειοθετημένος στόχος + 1 ενεργός → επιτρέπεται (E32)', () {
      final decision = AccountDeleteGuard.decide(
        activeAccountCount: 1,
        hasAnyTransaction: false,
        budgetsCount: 0,
        targetIsVisible: false,
      );

      expect(decision.action, AccountAction.delete);
      expect(decision.isBlocked, isFalse);
    });

    test('ορατός στόχος παραμένει «τελευταίος» (E32)', () {
      final decision = AccountDeleteGuard.decide(
        activeAccountCount: 1,
        hasAnyTransaction: false,
        budgetsCount: 0,
        targetIsVisible: true,
      );

      expect(decision.action, AccountAction.blockLast);
    });

    test('μηδέν ενεργοί → φραγή', () {
      final decision = AccountDeleteGuard.decide(
        activeAccountCount: 0,
        hasAnyTransaction: false,
        budgetsCount: 0,
      );

      expect(decision.action, AccountAction.blockNone);
      expect(decision.isBlocked, isTrue);
    });
  });

  group('AccountDeletePlan — E26 μετρήσεις', () {
    test('activeLegCount μετρά όλες τις μη διαγραμμένες κινήσεις', () {
      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: [
          _leg(uuid: 'e1', accountId: 'A', amount: -10, type: 'expense'),
          _leg(uuid: 'i1', accountId: 'A', amount: 50, type: 'income'),
        ],
      );

      expect(plan.activeLegCount, 2);
      expect(plan.hasAnyTransaction, isTrue);
      expect(plan.hasPendingScheduled, isFalse);
      expect(plan.pendingLegUuids, isEmpty);
    });

    test('pendingLegUuids κρατά μόνο scheduled && !executed', () {
      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: [
          _leg(
            uuid: 's1',
            accountId: 'A',
            amount: -20,
            type: 'expense',
            scheduled: true,
          ),
          _leg(
            uuid: 'x1',
            accountId: 'A',
            amount: -30,
            type: 'expense',
            scheduled: true,
            executed: true,
          ),
        ],
      );

      expect(plan.pendingLegUuids, ['s1']);
      expect(plan.hasPendingScheduled, isTrue);
      expect(plan.activeLegCount, 2);
    });

    test('άδειο πλάνο → καμία κίνηση', () {
      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: const <Map<String, dynamic>>[],
      );

      expect(plan.hasAnyTransaction, isFalse);
      expect(plan.activeLegCount, 0);
      expect(plan.hasPendingScheduled, isFalse);
    });

    // L26 — τα budgets περνούν από το preflight στο πλάνο.
    test('προεπιλογή: 0 budgets, 0 ανενεργά, γνωστά', () {
      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: const <Map<String, dynamic>>[],
      );

      expect(plan.budgetsCount, 0);
      expect(plan.inactiveBudgetsCount, 0);
      expect(plan.budgetsUnknown, isFalse);
    });

    test('το πλάνο κουβαλά τα πλήθη budgets', () {
      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: const <Map<String, dynamic>>[],
        budgetsCount: 3,
        inactiveBudgetsCount: 1,
        budgetsUnknown: true,
      );

      expect(plan.budgetsCount, 3);
      expect(plan.inactiveBudgetsCount, 1);
      expect(plan.budgetsUnknown, isTrue);
    });

    test('budgets μόνο (χωρίς κινήσεις) → το gate αρχειοθετεί', () {
      final plan = AccountDeleteGuard.buildPlan(
        accountUuid: 'A',
        activeLegs: const <Map<String, dynamic>>[],
        budgetsCount: 1,
        inactiveBudgetsCount: 1,
      );
      final decision = AccountDeleteGuard.decide(
        activeAccountCount: 2,
        hasAnyTransaction: plan.hasAnyTransaction,
        budgetsCount: plan.budgetsCount,
        pendingCount: plan.pendingLegUuids.length,
        targetIsVisible: true,
      );

      expect(plan.hasAnyTransaction, isFalse);
      expect(decision.action, AccountAction.archive);
    });
  });
}

/// Βοηθητικό: χτίζει map κίνησης όπως το διαβάζει το πλάνο.
Map<String, dynamic> _leg({
  required String uuid,
  required String accountId,
  required double amount,
  String type = 'transfer',
  String? groupId,
  String? peerUuid,
  String? peerAccountId,
  bool deleted = false,
  bool scheduled = false,
  bool executed = false,
  String? marker,
}) {
  return <String, dynamic>{
    'uuid': uuid,
    'account_id': accountId,
    'amount': amount,
    'transaction_type': type,
    'deleted': deleted,
    'is_scheduled': scheduled,
    'is_executed': executed,
    'transfer_group_id': ?groupId,
    'transfer_peer_uuid': ?peerUuid,
    'transfer_peer_account_id': ?peerAccountId,
    'annulled_by_account_deleted': ?marker,
  };
}

