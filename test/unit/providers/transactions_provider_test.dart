import 'package:flutter_test/flutter_test.dart';
import 'package:family_economy/providers/transactions_provider.dart';

TransactionModel _tx({
  String? categoryId,
  String? subcategoryId,
  String? transferGroupId,
  double amount = 10.0,
}) {
  return TransactionModel(
    id: 'tx1',
    userId: 'u1',
    accountId: 'a1',
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    transferGroupId: transferGroupId,
    amount: amount,
    date: DateTime(2026, 5, 10),
  );
}

void main() {
  group('TransactionModel.isTransfer', () {
    test('true with transfer_group_id', () {
      expect(_tx(transferGroupId: 'g1').isTransfer, isTrue);
    });

    test('false without transfer_group_id', () {
      expect(_tx(categoryId: 'c1').isTransfer, isFalse);
    });
  });

  group('TransactionModel.isIncome/isExpense', () {
    test('income needs income type and no transfer', () {
      expect(_tx(categoryId: 'c1').isIncome('income'), isTrue);
      expect(_tx(categoryId: 'c1').isIncome('expense'), isFalse);
    });

    test('expense needs expense type and no transfer', () {
      expect(_tx(categoryId: 'c1').isExpense('expense'), isTrue);
      expect(_tx(categoryId: 'c1').isExpense('income'), isFalse);
    });

    test('transfers are neither income nor expense', () {
      final t = _tx(categoryId: 'c1', transferGroupId: 'g1');
      expect(t.isIncome('income'), isFalse);
      expect(t.isExpense('expense'), isFalse);
    });

    test('null resolved type is neither (missing category)', () {
      final t = _tx();
      expect(t.isIncome(null), isFalse);
      expect(t.isExpense(null), isFalse);
    });
  });
}
