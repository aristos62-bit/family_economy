// ============================================================
// FILE: account_budget_usage_test.dart
// Path: test/unit/core/utils/account_budget_usage_test.dart
// Ρόλος: Έλεγχος του μετρητή budgets του gate διαγραφής (L26).
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:family_economy/core/utils/account_budget_usage.dart';

void main() {
  group('AccountBudgetUsage.count — L26', () {
    test('διαγραμμένο budget → εκτός', () {
      final usage = AccountBudgetUsage.count(
        [
          {'account_id': 'A', 'deleted': true, 'is_active': true},
        ],
        'A',
      );

      expect(usage.total, 0);
      expect(usage.inactive, 0);
      expect(usage.hasAny, isFalse);
    });

    test('μη διαγραμμένο budget → εντός', () {
      final usage = AccountBudgetUsage.count(
        [
          {'account_id': 'A', 'deleted': false, 'is_active': true},
        ],
        'A',
      );

      expect(usage.total, 1);
      expect(usage.inactive, 0);
    });

    test('λείπει το deleted → θεωρείται μη διαγραμμένο (legacy)', () {
      final usage = AccountBudgetUsage.count(
        [
          {'account_id': 'A', 'is_active': true},
        ],
        'A',
      );

      expect(usage.total, 1);
    });

    test('budget άλλου λογαριασμού → εκτός', () {
      final usage = AccountBudgetUsage.count(
        [
          {'account_id': 'B', 'deleted': false, 'is_active': true},
        ],
        'A',
      );

      expect(usage.total, 0);
    });

    test('budget «Όλοι» (account_id null) → εκτός', () {
      final usage = AccountBudgetUsage.count(
        [
          {'account_id': null, 'deleted': false, 'is_active': true},
        ],
        'A',
      );

      expect(usage.total, 0);
    });

    test('κενό/μη-string account_id → εκτός', () {
      final usage = AccountBudgetUsage.count(
        [
          {'account_id': '', 'deleted': false, 'is_active': true},
          {'account_id': 42, 'deleted': false, 'is_active': true},
        ],
        'A',
      );

      expect(usage.total, 0);
    });

    test('ανενεργό budget → μετριέται και σημαίνεται', () {
      final usage = AccountBudgetUsage.count(
        [
          {'account_id': 'A', 'deleted': false, 'is_active': false},
        ],
        'A',
      );

      expect(usage.total, 1);
      expect(usage.inactive, 1);
    });

    test('λείπει το is_active → ενεργό (όπως στο BudgetModel)', () {
      final usage = AccountBudgetUsage.count(
        [
          {'account_id': 'A', 'deleted': false},
        ],
        'A',
      );

      expect(usage.total, 1);
      expect(usage.inactive, 0);
    });

    test('μικτό σύνολο → σωστά πλήθη', () {
      final usage = AccountBudgetUsage.count(
        [
          {'account_id': 'A', 'deleted': false, 'is_active': true},
          {'account_id': 'A', 'deleted': false, 'is_active': false},
          {'account_id': 'A', 'is_active': false},
          {'account_id': 'A', 'deleted': true, 'is_active': true},
          {'account_id': 'B', 'deleted': false, 'is_active': true},
          {'account_id': null, 'deleted': false, 'is_active': true},
        ],
        'A',
      );

      expect(usage.total, 3);
      expect(usage.inactive, 2);
    });

    test('κενή λίστα → μηδέν', () {
      final usage = AccountBudgetUsage.count(
        const <Map<String, dynamic>>[],
        'A',
      );

      expect(usage, isA<AccountBudgetUsage>());
      expect(usage.total, 0);
      expect(usage.inactive, 0);
    });

    test('κενό accountUuid → μηδέν (αμυντικά)', () {
      final usage = AccountBudgetUsage.count(
        [
          {'account_id': 'A', 'deleted': false, 'is_active': true},
        ],
        '   ',
      );

      expect(usage.total, 0);
    });

    test('trim σε account_id και accountUuid', () {
      final usage = AccountBudgetUsage.count(
        [
          {'account_id': ' A ', 'deleted': false, 'is_active': true},
        ],
        'A',
      );

      expect(usage.total, 1);
    });

    test('το none είναι μηδενικό', () {
      expect(AccountBudgetUsage.none.total, 0);
      expect(AccountBudgetUsage.none.inactive, 0);
      expect(AccountBudgetUsage.none.hasAny, isFalse);
    });
  });
}
