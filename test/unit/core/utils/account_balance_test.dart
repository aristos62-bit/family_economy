// ============================================================
// FILE: account_balance_test.dart
// Path: test/unit/core/utils/account_balance_test.dart
// Ρόλος: Έλεγχος του κανόνα/υπολογισμού υπολοίπου (E20).
// Καθαρό Dart — χωρίς Firebase.
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:family_economy/core/utils/account_balance.dart';

Map<String, dynamic> _tx({
  double amount = 0.0,
  bool? scheduled,
  bool? executed,
  bool? deleted,
}) {
  return <String, dynamic>{
    'amount': amount,
    'is_scheduled': ?scheduled,
    'is_executed': ?executed,
    'deleted': ?deleted,
  };
}

void main() {
  group('AccountBalanceRules.isPendingScheduled — E20', () {
    test('κανονική κίνηση (χωρίς πεδία) δεν είναι εκκρεμής', () {
      expect(AccountBalanceRules.isPendingScheduled(_tx(amount: -10)), isFalse);
    });

    test('is_scheduled=true χωρίς is_executed → εκκρεμής (legacy)', () {
      expect(
        AccountBalanceRules.isPendingScheduled(_tx(scheduled: true)),
        isTrue,
      );
    });

    test('is_scheduled=true + is_executed=true → δεν είναι εκκρεμής', () {
      expect(
        AccountBalanceRules.isPendingScheduled(
          _tx(scheduled: true, executed: true),
        ),
        isFalse,
      );
    });

    test('is_scheduled=false + is_executed=false → δεν είναι εκκρεμής', () {
      expect(
        AccountBalanceRules.isPendingScheduled(
          _tx(scheduled: false, executed: false),
        ),
        isFalse,
      );
    });
  });

  group('AccountBalanceRules.countsInBalance — E20', () {
    test('μελλοντική «Άμεση» κίνηση μετράει (regression)', () {
      // Μελλοντική ημερομηνία δεν σημαίνει «δεν εφαρμόστηκε».
      expect(AccountBalanceRules.countsInBalance(_tx(amount: -300)), isTrue);
    });

    test('εκκρεμής προγραμματισμένη δεν μετράει', () {
      expect(
        AccountBalanceRules.countsInBalance(_tx(amount: -100, scheduled: true)),
        isFalse,
      );
    });

    test('εκτελεσμένη προγραμματισμένη μετράει', () {
      expect(
        AccountBalanceRules.countsInBalance(
          _tx(amount: -100, scheduled: true, executed: true),
        ),
        isTrue,
      );
    });

    test('διαγραμμένη δεν μετράει', () {
      expect(
        AccountBalanceRules.countsInBalance(_tx(amount: -50, deleted: true)),
        isFalse,
      );
    });
  });

  group('AccountBalanceRules.compute', () {
    test('κενή λίστα → αρχικό υπόλοιπο', () {
      final result = AccountBalanceRules.compute(
        initialBalance: 500.0,
        transactions: const [],
      );

      expect(result.newBalance, closeTo(500.0, 0.001));
      expect(result.countedCount, 0);
      expect(result.pendingExcludedCount, 0);
      expect(result.deletedSkippedCount, 0);
    });

    test('έσοδο + έξοδο αθροίζονται σωστά', () {
      final result = AccountBalanceRules.compute(
        initialBalance: 1000.0,
        transactions: [
          _tx(amount: 200.0),
          _tx(amount: -150.0),
        ],
      );

      expect(result.newBalance, closeTo(1050.0, 0.001));
      expect(result.countedCount, 2);
    });

    test('εκκρεμείς εξαιρούνται και καταγράφονται', () {
      final result = AccountBalanceRules.compute(
        initialBalance: 800.0,
        transactions: [
          _tx(amount: -300.0),
          _tx(amount: -100.0, scheduled: true),
          _tx(amount: -50.0, scheduled: true, executed: true),
        ],
      );

      expect(result.newBalance, closeTo(450.0, 0.001));
      expect(result.countedCount, 2);
      expect(result.pendingExcludedCount, 1);
      expect(result.pendingExcludedAmount, closeTo(-100.0, 0.001));
      expect(result.hasPendingExcluded, isTrue);
    });

    test('διαγραμμένες αγνοούνται (και μετριούνται για debug)', () {
      final result = AccountBalanceRules.compute(
        initialBalance: 100.0,
        transactions: [
          _tx(amount: -40.0, deleted: true),
          _tx(amount: -10.0),
        ],
      );

      expect(result.newBalance, closeTo(90.0, 0.001));
      expect(result.countedCount, 1);
      expect(result.deletedSkippedCount, 1);
    });

    test('ζεύγος μεταφοράς: κάθε σκέλος στο δικό του λογαριασμό', () {
      final source = AccountBalanceRules.compute(
        initialBalance: 500.0,
        transactions: [_tx(amount: -50.0)],
      );
      final target = AccountBalanceRules.compute(
        initialBalance: 100.0,
        transactions: [_tx(amount: 50.0)],
      );

      expect(source.newBalance, closeTo(450.0, 0.001));
      expect(target.newBalance, closeTo(150.0, 0.001));
    });

    test('ακυρωμένο ζεύγος (deleted=true) δεν επηρεάζει', () {
      final result = AccountBalanceRules.compute(
        initialBalance: 500.0,
        transactions: [
          _tx(amount: -50.0, deleted: true),
          _tx(amount: 50.0, deleted: true),
        ],
      );

      expect(result.newBalance, closeTo(500.0, 0.001));
      expect(result.countedCount, 0);
    });

    test('float dust δεν συσσωρεύεται (0,1 + 0,2)', () {
      final result = AccountBalanceRules.compute(
        initialBalance: 0.0,
        transactions: [
          _tx(amount: 0.1),
          _tx(amount: 0.2),
        ],
      );

      expect(result.newBalance, 0.3);
    });

    test('αρχικό υπόλοιπο με dust στρογγυλοποιείται σε cents', () {
      final result = AccountBalanceRules.compute(
        initialBalance: 100.006,
        transactions: const [],
      );

      expect(result.newBalance, 100.01);
    });
  });

  group('AccountBalanceRecalcOutcome.message', () {
    test('επιτυχία με αλλαγή και εκκρεμείς (πληθυντικός)', () {
      const outcome = AccountBalanceRecalcOutcome(
        failure: AccountBalanceRecalcFailure.none,
        beforeBalance: 800.0,
        afterBalance: 500.0,
        countedCount: 12,
        pendingExcludedCount: 2,
        pendingExcludedAmount: -300.0,
        changed: true,
      );

      final message = outcome.message(currency: '€');

      expect(message, contains('800,00'));
      expect(message, contains('500,00'));
      expect(message, contains('12 κινήσεις'));
      expect(message, contains('2 εκκρεμείς'));
      expect(message, contains('300,00'));
    });

    test('επιτυχία χωρίς αλλαγή', () {
      const outcome = AccountBalanceRecalcOutcome(
        failure: AccountBalanceRecalcFailure.none,
        beforeBalance: 500.0,
        afterBalance: 500.0,
        countedCount: 3,
      );

      final message = outcome.message(currency: '€');

      expect(message, contains('ήδη σωστό'));
      expect(message, contains('500,00'));
    });

    test('ενικός για μία εκκρεμή και μία κίνηση', () {
      const outcome = AccountBalanceRecalcOutcome(
        failure: AccountBalanceRecalcFailure.none,
        beforeBalance: 100.0,
        afterBalance: 90.0,
        countedCount: 1,
        pendingExcludedCount: 1,
        pendingExcludedAmount: -10.0,
        changed: true,
      );

      final message = outcome.message(currency: '€');

      expect(message, contains('1 κίνηση'));
      expect(message, contains('1 εκκρεμής'));
      expect(message, isNot(contains('1 κινήσεις')));
      expect(message, isNot(contains('1 εκκρεμείς')));
    });

    test('μηνύματα αποτυχίας', () {
      expect(
        const AccountBalanceRecalcOutcome(
          failure: AccountBalanceRecalcFailure.accountMissing,
        ).message(currency: '€'),
        contains('δεν υπάρχει πλέον'),
      );

      expect(
        const AccountBalanceRecalcOutcome(
          failure: AccountBalanceRecalcFailure.failed,
        ).message(currency: '€'),
        contains('Δεν άλλαξε κανένα υπόλοιπο'),
      );

      expect(
        const AccountBalanceRecalcOutcome(
          failure: AccountBalanceRecalcFailure.missingUser,
        ).isSuccess,
        isFalse,
      );
    });
  });
}
