import 'package:flutter_test/flutter_test.dart';
import 'package:family_economy/models/budget_model.dart';
import 'package:family_economy/providers/transactions_provider.dart';

BudgetModel _budget({
  required String budgetType,
  String? categoryId,
  String? subcategoryId,
  String? accountId,
}) {
  return BudgetModel(
    uuid: 'b1',
    userId: 'u1',
    budgetType: budgetType,
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    accountId: accountId,
    periodType: 'monthly',
    startDate: DateTime(2026, 5, 1),
    endDate: DateTime(2026, 5, 31),
    amount: 500.0,
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
  );
}

TransactionModel _tx({
  String? categoryId,
  String? subcategoryId,
  String accountId = 'a1',
  DateTime? date,
}) {
  return TransactionModel(
    id: 'tx1',
    userId: 'u1',
    accountId: accountId,
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    amount: 25.0,
    date: date ?? DateTime(2026, 5, 10),
  );
}

void main() {
  group('BudgetModel.matchesTransaction — category', () {
    test('matches same category', () {
      final b = _budget(budgetType: 'category', categoryId: 'c1');
      expect(b.matchesTransaction(_tx(categoryId: 'c1', subcategoryId: 's1')), isTrue);
    });

    test('rejects other category', () {
      final b = _budget(budgetType: 'category', categoryId: 'c1');
      expect(b.matchesTransaction(_tx(categoryId: 'c2')), isFalse);
    });
  });

  group('BudgetModel.matchesTransaction — subcategory', () {
    test('matches exact category+subcategory', () {
      final b = _budget(budgetType: 'subcategory', categoryId: 'c1', subcategoryId: 's1');
      expect(b.matchesTransaction(_tx(categoryId: 'c1', subcategoryId: 's1')), isTrue);
    });

    test('rejects same category without subcategory', () {
      final b = _budget(budgetType: 'subcategory', categoryId: 'c1', subcategoryId: 's1');
      expect(b.matchesTransaction(_tx(categoryId: 'c1')), isFalse);
    });
  });

  group('BudgetModel.matchesTransaction — total/account/date', () {
    test('total matches any category', () {
      final b = _budget(budgetType: 'total');
      expect(b.matchesTransaction(_tx(categoryId: 'whatever')), isTrue);
    });

    test('respects account filter', () {
      final b = _budget(budgetType: 'total', accountId: 'a1');
      expect(b.matchesTransaction(_tx(accountId: 'a1')), isTrue);
      expect(b.matchesTransaction(_tx(accountId: 'a2')), isFalse);
    });

    test('boundaries are inclusive', () {
      final b = _budget(budgetType: 'total');
      expect(b.matchesTransaction(_tx(date: DateTime(2026, 5, 1))), isTrue);
      expect(b.matchesTransaction(_tx(date: DateTime(2026, 5, 31))), isTrue);
    });

    test('rejects out-of-range dates', () {
      final b = _budget(budgetType: 'total');
      expect(b.matchesTransaction(_tx(date: DateTime(2026, 4, 30))), isFalse);
      expect(b.matchesTransaction(_tx(date: DateTime(2026, 6, 1))), isFalse);
    });
  });
}
