import 'package:flutter_test/flutter_test.dart';

import 'package:family_economy/core/utils/account_restore_policy.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';

Map<String, dynamic> _account({
  String name = 'Alfa',
  String currency = 'EUR',
  double initial = 1000.0,
  double current = 1000.0,
  bool deleted = true,
}) {
  return <String, dynamic>{
    'name': name,
    'currency': currency,
    'initial_balance': initial,
    'current_balance': current,
    'deleted': deleted,
  };
}

Map<String, dynamic> _leg({
  required String uuid,
  required String accountId,
  required double amount,
  String? groupId,
  bool deleted = false,
  String? marker,
  String? peerUuid,
  String? peerAccountId,
  String type = 'transfer',
  bool? isScheduled,
  bool? isExecuted,
}) {
  return <String, dynamic>{
    'uuid': uuid,
    'account_id': accountId,
    'amount': amount,
    'transaction_type': type,
    'transfer_group_id': groupId,
    'deleted': deleted,
    'annulled_by_account_deleted': ?marker,
    'transfer_peer_uuid': ?peerUuid,
    'transfer_peer_account_id': ?peerAccountId,
    'is_scheduled': ?isScheduled,
    'is_executed': ?isExecuted,
  };
}

Map<String, Map<String, dynamic>> _accounts() {
  return <String, Map<String, dynamic>>{
    'A': <String, dynamic>{'name': 'Alfa'},
    'B': <String, dynamic>{'name': 'Banca'},
    'C': <String, dynamic>{'name': 'Γamma'},
  };
}

List<Map<String, dynamic>> _pairLegs({
  String groupId = 'g1',
  double amount = 100.0,
  String marker = 'A',
  bool deleted = true,
  bool? isScheduled,
  bool? isExecuted,
}) {
  return <Map<String, dynamic>>[
    _leg(
      uuid: '${groupId}_a',
      accountId: 'A',
      amount: -amount,
      groupId: groupId,
      deleted: deleted,
      marker: marker,
      peerUuid: '${groupId}_b',
      peerAccountId: 'B',
      isScheduled: isScheduled,
      isExecuted: isExecuted,
    ),
    _leg(
      uuid: '${groupId}_b',
      accountId: 'B',
      amount: amount,
      groupId: groupId,
      deleted: deleted,
      marker: marker,
      peerUuid: '${groupId}_a',
      peerAccountId: 'A',
      isScheduled: isScheduled,
      isExecuted: isExecuted,
    ),
  ];
}

AccountRestorePlan _build({
  Map<String, dynamic>? account,
  List<Map<String, dynamic>> own = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> marked = const <Map<String, dynamic>>[],
  Set<String>? existing,
  Map<String, Map<String, dynamic>>? accountsById,
}) {
  return AccountRestorePolicy.build(
    accountUuid: 'A',
    accountData: account ?? _account(),
    ownTransactions: own,
    markedLegs: marked,
    existingAccountIds: existing ?? <String>{'A', 'B', 'C'},
    accountsById: accountsById ?? _accounts(),
  );
}

void main() {
  group('AccountRestorePolicy — χωρίς ιστορικό', () {
    test('λογαριασμός χωρίς κινήσεις → υπόλοιπο = αρχικό', () {
      final plan = _build();

      expect(plan.hasHistory, isFalse);
      expect(plan.targetBalance, 1000.0);
      expect(plan.balanceChanges, isFalse);
      expect(plan.chunks, isEmpty);
      expect(plan.peerDeltas, isEmpty);
      expect(plan.hiddenSummary, 'Όλες οι κινήσεις επιστρέφουν.');
    });

    test('κίνηση χωρίς marker μένει κρυφή (E19)', () {
      final own = <Map<String, dynamic>>[
        _leg(
          uuid: 'user1',
          accountId: 'A',
          amount: -50,
          type: 'expense',
          deleted: true,
        ),
      ];

      final plan = _build(own: own);

      expect(plan.hasHistory, isFalse);
      expect(plan.targetBalance, 1000.0);
      expect(plan.hiddenLegs, 1);
      expect(plan.userDeletedHidden, 1);
      expect(plan.hiddenSummary, 'Μένουν κρυφές: 1 κίνηση');
    });

    test('ορατή κίνηση μετράει στο υπόλοιπο αλλά δεν "επιστρέφει"', () {
      final own = <Map<String, dynamic>>[
        _leg(
          uuid: 'visible1',
          accountId: 'A',
          amount: 50,
          type: 'income',
        ),
      ];

      final plan = _build(own: own);

      expect(plan.targetBalance, 1050.0);
      expect(plan.restoredLegs, 0);
      expect(plan.hiddenLegs, 0);
      expect(plan.balanceChanges, isTrue);
    });
  });

  group('AccountRestorePolicy — ζεύγη μεταφορών', () {
    test('πλήρες ζεύγος → 2 legs + peer delta + σωστό υπόλοιπο', () {
      final legs = _pairLegs();
      final plan = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: legs,
      );

      expect(plan.restorablePairs, 1);
      expect(plan.restoredLegs, 2);
      expect(plan.peerDeltas, <String, double>{'B': 100.0});
      expect(plan.targetBalance, 900.0);
      expect(plan.hiddenLegs, 0);
      expect(plan.peerNames, <String>['Banca']);
      expect(plan.chunks.length, 1);
      expect(plan.chunks.first.writeCount, 3);
    });

    test('το delta του ίδιου λογαριασμού δεν μπαίνει στους peers', () {
      final legs = _pairLegs();
      final plan = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: legs,
      );

      expect(plan.peerDeltas.containsKey('A'), isFalse);
    });

    test('εκκρεμές ζεύγος δεν επανέρχεται (E25)', () {
      final legs = _pairLegs(isScheduled: true, isExecuted: false);
      final plan = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: legs,
      );

      expect(plan.restorablePairs, 0);
      expect(plan.pendingPairs, 1);
      expect(plan.chunks, isEmpty);
      expect(plan.peerDeltas, isEmpty);
      expect(plan.hiddenLegs, 1);
      expect(plan.skipNotes.first, contains('εκκρεμής'));
    });

    test('εκτελεσμένο scheduled θεωρείται ολοκληρωμένο', () {
      final legs = _pairLegs(isScheduled: true, isExecuted: true);
      final plan = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: legs,
      );

      expect(plan.restorablePairs, 1);
      expect(plan.targetBalance, 900.0);
    });

    test('legacy χωρίς is_scheduled/is_executed → ολοκληρωμένο', () {
      final legs = _pairLegs();
      final plan = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: legs,
      );

      expect(plan.restorablePairs, 1);
    });

    test('ημιτελές ζεύγος → καμία επαναφορά, αιτία στο μήνυμα', () {
      final legs = _pairLegs();
      final plan = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: <Map<String, dynamic>>[legs[0]],
      );

      expect(plan.restorablePairs, 0);
      expect(plan.incompletePairs, 1);
      expect(plan.hiddenLegs, 1);
      expect(plan.skipNotes.first, contains('λείπει το άλλο σκέλος'));
    });

    test('ασύμμετρο ζεύγος → invalid', () {
      final legs = <Map<String, dynamic>>[
        _leg(
          uuid: 'g_a',
          accountId: 'A',
          amount: -100,
          groupId: 'g',
          deleted: true,
          marker: 'A',
          peerUuid: 'g_b',
          peerAccountId: 'B',
        ),
        _leg(
          uuid: 'g_b',
          accountId: 'B',
          amount: -100,
          groupId: 'g',
          deleted: true,
          marker: 'A',
          peerUuid: 'g_a',
          peerAccountId: 'A',
        ),
      ];

      final plan = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: legs,
      );

      expect(plan.restorablePairs, 0);
      expect(plan.invalidPairs, 1);
      expect(plan.skipNotes.first, contains('δεν συμφωνούν'));
    });

    test('peer που δεν υπάρχει πλέον → παράλειψη', () {
      final legs = _pairLegs();
      final plan = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: legs,
        existing: <String>{'A'},
      );

      expect(plan.restorablePairs, 0);
      expect(plan.missingPeerPairs, 1);
      expect(plan.skipNotes.first, contains('δεν υπάρχει πλέον'));
    });

    test('peer διαγραμμένος αλλά υπαρκτός → επανέρχεται', () {
      final legs = _pairLegs();
      final plan = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: legs,
        existing: <String>{'A', 'B'},
        accountsById: <String, Map<String, dynamic>>{
          'A': <String, dynamic>{'name': 'Alfa'},
          'B': <String, dynamic>{'name': 'Banca', 'deleted': true},
        },
      );

      expect(plan.restorablePairs, 1);
      expect(plan.peerDeltas, <String, double>{'B': 100.0});
    });

    test('πολλά ζεύγη ίδιου peer → ένα aggregated delta', () {
      final g1 = _pairLegs(groupId: 'g1', amount: 100);
      final g2 = _pairLegs(groupId: 'g2', amount: 50);

      final plan = _build(
        own: <Map<String, dynamic>>[g1[0], g2[0]],
        marked: <Map<String, dynamic>>[...g1, ...g2],
      );

      expect(plan.restorablePairs, 2);
      expect(plan.peerDeltas, <String, double>{'B': 150.0});
      expect(plan.targetBalance, 850.0);
    });

    test('δύο peers → ταξινομημένα ονόματα', () {
      final g1 = _pairLegs(groupId: 'g1', amount: 100);
      final g2 = <Map<String, dynamic>>[
        _leg(
          uuid: 'g2_a',
          accountId: 'A',
          amount: -20,
          groupId: 'g2',
          deleted: true,
          marker: 'A',
          peerUuid: 'g2_c',
          peerAccountId: 'C',
        ),
        _leg(
          uuid: 'g2_c',
          accountId: 'C',
          amount: 20,
          groupId: 'g2',
          deleted: true,
          marker: 'A',
          peerUuid: 'g2_a',
          peerAccountId: 'A',
        ),
      ];

      final plan = _build(
        own: <Map<String, dynamic>>[g1[0], g2[0]],
        marked: <Map<String, dynamic>>[...g1, ...g2],
      );

      expect(plan.peerNames, <String>['Banca', 'Γamma']);
      expect(plan.peersSummary, 'Επιστρέφουν ποσά σε: Banca, Γamma');
    });
  });

  group('AccountRestorePolicy — chunks & cents', () {
    test('300 ζεύγη → chunks ≤499, κανένα σπασμένο ζεύγος', () {
      final own = <Map<String, dynamic>>[];
      final marked = <Map<String, dynamic>>[];

      for (var i = 0; i < 300; i++) {
        final legs = _pairLegs(groupId: 'g$i', amount: 1.0);
        own.add(legs[0]);
        marked.addAll(legs);
      }

      final plan = _build(own: own, marked: marked);

      expect(plan.restorablePairs, 300);
      expect(plan.chunks.length, greaterThan(1));
      for (final chunk in plan.chunks) {
        expect(chunk.writeCount, lessThanOrEqualTo(499));
        expect(chunk.units.length * 2, lessThanOrEqualTo(499));
      }
      final units = plan.chunks.fold<int>(
        0,
        (sum, chunk) => sum + chunk.units.length,
      );
      expect(units, 300);
      expect(plan.peerDeltas['B'], 300.0);
    });

    test('υπολογισμός σε cents (0,1 + 0,2)', () {
      final own = <Map<String, dynamic>>[
        _leg(
          uuid: 'v1',
          accountId: 'A',
          amount: 0.2,
          type: 'income',
        ),
      ];

      final plan = _build(
        account: _account(initial: 0.1, current: 0.1),
        own: own,
      );

      expect(plan.targetBalance, 0.3);
    });

    test('balanceChanges όταν το αποθηκευμένο υπόλοιπο διαφέρει', () {
      final plan = _build(
        account: _account(initial: 1000, current: 1000),
        own: <Map<String, dynamic>>[
          _leg(uuid: 'v1', accountId: 'A', amount: -100, type: 'expense'),
        ],
      );

      expect(plan.targetBalance, 900.0);
      expect(plan.storedBalance, 1000.0);
      expect(plan.balanceChanges, isTrue);
    });

    test('fingerprint αλλάζει όταν αλλάζουν τα legs', () {
      final legs = _pairLegs();
      final first = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: legs,
      );
      final second = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: <Map<String, dynamic>>[],
      );

      expect(first.fingerprint, isNot(second.fingerprint));
    });
  });

  group('AccountRestorePolicy — μηνύματα', () {
    test('επιτυχία με 1 μεταφορά (ενικός)', () {
      final legs = _pairLegs();
      final plan = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: legs,
      );

      final message = plan.successMessage();

      expect(message, contains('«Alfa» επανήλθε με 1 μεταφορά.'));
      expect(
        message,
        contains(
          '${CurrencyFormatter.format(1000)} → '
          '${CurrencyFormatter.format(900)}.',
        ),
      );
    });

    test('επιτυχία με πολλές μεταφορές + κρυφές κινήσεις', () {
      final g1 = _pairLegs(groupId: 'g1', amount: 100);
      final g2 = _pairLegs(groupId: 'g2', amount: 50);
      final plan = _build(
        own: <Map<String, dynamic>>[
          g1[0],
          g2[0],
          _leg(
            uuid: 'user1',
            accountId: 'A',
            amount: -10,
            type: 'expense',
            deleted: true,
          ),
        ],
        marked: <Map<String, dynamic>>[...g1, ...g2],
      );

      final message = plan.successMessage();

      expect(message, contains('2 μεταφορές'));
      expect(message, contains('1 κίνηση έμεινε κρυφή'));
    });

    test('χωρίς ιστορικό → σαφές μήνυμα', () {
      final plan = _build();

      final message = plan.successMessage();

      expect(message, contains('επανήλθε με υπόλοιπο ${CurrencyFormatter.format(1000)}'));
      expect(message, contains('Δεν βρέθηκε ιστορικό προς επαναφορά'));
    });

    test('πληθυντικός στις παραλείψεις', () {
      final p1 = _pairLegs(groupId: 'p1', amount: 10, isScheduled: true);
      final p2 = _pairLegs(groupId: 'p2', amount: 20, isScheduled: true);

      final plan = _build(
        own: <Map<String, dynamic>>[p1[0], p2[0]],
        marked: <Map<String, dynamic>>[...p1, ...p2],
      );

      expect(plan.pendingPairs, 2);
      expect(plan.skipNotes.first, contains('2 εκκρεμείς'));
    });

    test('νόμισμα ≠ EUR στο μήνυμα', () {
      final plan = _build(
        account: _account(currency: 'USD', initial: 1000, current: 1000),
      );

      final message = plan.successMessage();

      expect(
        message,
        contains(CurrencyFormatter.format(1000, currency: 'USD')),
      );
    });

    test('historySummary / hiddenSummary', () {
      final legs = _pairLegs();
      final plan = _build(
        own: <Map<String, dynamic>>[legs[0]],
        marked: legs,
      );

      expect(plan.historySummary, 'Επιστρέφουν: 1 μεταφορά (2 κινήσεις)');
      expect(plan.hiddenSummary, 'Όλες οι κινήσεις επιστρέφουν.');
      expect(
        plan.balanceSummary,
        'Υπόλοιπο: ${CurrencyFormatter.format(1000)} → '
        '${CurrencyFormatter.format(900)}',
      );
    });
  });
}
