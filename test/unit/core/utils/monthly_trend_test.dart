import 'package:flutter_test/flutter_test.dart';
import 'package:family_economy/core/utils/monthly_trend.dart';
import 'package:family_economy/providers/transactions_provider.dart';

TransactionModel _tx({
  String? categoryId,
  String? subcategoryId,
  String? transferGroupId,
  double amount = 100.0,
  int month = 1,
  int year = 2026,
}) {
  return TransactionModel(
    id: 'tx$month',
    userId: 'u1',
    accountId: 'a1',
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    transferGroupId: transferGroupId,
    amount: amount,
    date: DateTime(year, month, 10),
  );
}

List<MonthlyPoint> _run(List<TransactionModel> txs, {String? sub}) {
  return computeMonthlyTrend(
    transactions: txs,
    year: 2026,
    categoryId: 'c1',
    subcategoryId: sub,
  );
}

void main() {
  group('computeMonthlyTrend — basics', () {
    test('empty list gives 12 zeros with null pct', () {
      final m = _run([]);
      expect(m.length, 12);
      expect(m.every((p) => p.value == 0.0), isTrue);
      expect(m.every((p) => p.pct == null), isTrue);
    });

    test('null category gives 12 zeros', () {
      final m = computeMonthlyTrend(
        transactions: [_tx(categoryId: 'c1')],
        year: 2026,
        categoryId: null,
        subcategoryId: null,
      );
      expect(m.every((p) => p.value == 0.0), isTrue);
    });

    test('sums same-month transactions (abs)', () {
      final m = _run([
        _tx(categoryId: 'c1', amount: 100, month: 1),
        _tx(categoryId: 'c1', amount: -50, month: 1),
      ]);
      expect(m[0].value, 150.0);
      expect(m[0].pct, isNull); // Ιανουάριος: —
    });
  });

  group('computeMonthlyTrend — pct', () {
    test('100 → 150 gives +50%', () {
      final m = _run([
        _tx(categoryId: 'c1', amount: 100, month: 1),
        _tx(categoryId: 'c1', amount: 150, month: 2),
      ]);
      expect(m[1].pct, 50.0);
    });

    test('0 → X gives +100%', () {
      final m = _run([_tx(categoryId: 'c1', amount: 80, month: 3)]);
      expect(m[2].pct, 100.0);
    });

    test('X → 0 gives -100%', () {
      final m = _run([_tx(categoryId: 'c1', amount: 100, month: 1)]);
      expect(m[1].value, 0.0);
      expect(m[1].pct, -100.0);
    });

    test('0 → 0 stays null', () {
      final m = _run([]);
      expect(m[5].pct, isNull);
    });
  });

  group('computeMonthlyTrend — filters', () {
    test('skips transfers', () {
      final m = _run([_tx(categoryId: 'c1', transferGroupId: 'g1', month: 1)]);
      expect(m[0].value, 0.0);
    });

    test('skips other categories', () {
      final m = _run([_tx(categoryId: 'c2', month: 1)]);
      expect(m[0].value, 0.0);
    });

    test('skips other years', () {
      final m = _run([_tx(categoryId: 'c1', month: 1, year: 2025)]);
      expect(m[0].value, 0.0);
    });

    test('subcategory filter isolates sub', () {
      final txs = [
        _tx(categoryId: 'c1', subcategoryId: 's1', amount: 100, month: 1),
        _tx(categoryId: 'c1', subcategoryId: 's2', amount: 200, month: 1),
      ];
      expect(_run(txs)[0].value, 300.0);
      expect(_run(txs, sub: 's1')[0].value, 100.0);
    });
  });
}
