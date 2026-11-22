// ============================================================
// FILE: account_totals_test.dart
// Path: test/unit/core/utils/account_totals_test.dart
// Ρόλος: Έλεγχος του ενιαίου υπολογισμού συνόλου (E26).
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:family_economy/core/utils/account_totals.dart';
import 'package:family_economy/providers/accounts_provider.dart';

void main() {
  group('AccountTotals — E26', () {
    test('ενεργοί λογαριασμοί μετράνε', () {
      final accounts = <AccountModel>[
        _account(uuid: 'a', balance: 1500),
        _account(uuid: 'b', balance: 2000),
      ];

      expect(AccountTotals.sum(accounts), closeTo(3500, 0.001));
      expect(AccountTotals.counted(accounts).length, 2);
    });

    test('αρχειοθετημένος μετράει (ιστορικό διατηρείται)', () {
      final accounts = <AccountModel>[
        _account(uuid: 'a', balance: 1500, archived: true),
        _account(uuid: 'b', balance: 2000),
      ];

      expect(AccountTotals.sum(accounts), closeTo(3500, 0.001));
      expect(AccountTotals.counted(accounts).length, 2);
    });

    test('legacy is_active=false χωρίς archived_at μένει εκτός', () {
      final accounts = <AccountModel>[
        _account(uuid: 'a', balance: 1500),
        _account(uuid: 'legacy', balance: 999, active: false),
      ];

      expect(AccountTotals.sum(accounts), closeTo(1500, 0.001));
      expect(AccountTotals.counted(accounts).single.uuid, 'a');
    });

    test('εξαιρέσεις χρήστη αφαιρούνται από σύνολο και λίστα', () {
      final accounts = <AccountModel>[
        _account(uuid: 'a', balance: 1500),
        _account(uuid: 'b', balance: 2000),
        _account(uuid: 'c', balance: 500, archived: true),
      ];

      final excluded = <String>{'b', 'c'};

      expect(
        AccountTotals.sum(accounts, excluded: excluded),
        closeTo(1500, 0.001),
      );
      expect(
        AccountTotals.counted(accounts, excluded: excluded).single.uuid,
        'a',
      );
    });

    test('όλοι εξαιρεμένοι → κενή λίστα και σύνολο μηδέν', () {
      final accounts = <AccountModel>[
        _account(uuid: 'a', balance: 1500),
        _account(uuid: 'b', balance: 2000),
      ];

      final excluded = <String>{'a', 'b'};

      expect(AccountTotals.sum(accounts, excluded: excluded), 0);
      expect(AccountTotals.counted(accounts, excluded: excluded), isEmpty);
    });

    test('αρνητικά υπόλοιπα αθροίζονται σωστά', () {
      final accounts = <AccountModel>[
        _account(uuid: 'a', balance: -200),
        _account(uuid: 'b', balance: 100, archived: true),
      ];

      expect(AccountTotals.sum(accounts), closeTo(-100, 0.001));
    });

    test('κενή λίστα → μηδέν', () {
      expect(AccountTotals.sum(const <AccountModel>[]), 0);
      expect(AccountTotals.counted(const <AccountModel>[]), isEmpty);
    });
  });
}

AccountModel _account({
  required String uuid,
  required double balance,
  bool active = true,
  bool archived = false,
}) {
  final now = DateTime(2026, 11, 21);

  return AccountModel(
    uuid: uuid,
    userId: 'user',
    name: 'Λογαριασμός $uuid',
    initialBalance: 0,
    currentBalance: balance,
    currency: 'EUR',
    accountType: 'cash',
    isActive: active,
    displayOrder: 0,
    createdAt: now,
    updatedAt: now,
    deleted: false,
    archivedAt: archived ? now : null,
  );
}
