// ============================================================
// Monthly Trend — pure aggregation για πορεία ανά μήνα
// Location: lib/core/utils/monthly_trend.dart
// Χωρίς Flutter/Firebase: testable με unit tests.
// ============================================================

import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/providers/transactions_provider.dart';

class MonthlyPoint {
  final int index; // 0..11
  final double value;
  final double? pct; // % vs προηγούμενο μήνα, null = —
  MonthlyPoint(this.index, this.value, this.pct);
}

/// Ομαδοποιεί συναλλαγές ανά μήνα (Ιαν→Δεκ) για το [year].
/// Αγνοεί μεταφορές. Ποσά σε απόλυτη τιμή, στρογγυλοποιημένα.
/// Κενή κατηγορία ([categoryId] null) → 12 μηδενικά.
List<MonthlyPoint> computeMonthlyTrend({
  required List<TransactionModel> transactions,
  required int year,
  required String? categoryId,
  required String? subcategoryId,
}) {
  final monthly = List<double>.filled(12, 0.0);
  if (categoryId != null) {
    for (final t in transactions) {
      if (t.isTransfer) continue;
      if (t.date.year != year) continue;
      if (t.categoryId != categoryId) continue;
      if (subcategoryId != null && t.subcategoryId != subcategoryId) continue;
      monthly[t.date.month - 1] = monthly[t.date.month - 1] + t.amount.abs();
    }
  }
  final out = <MonthlyPoint>[];
  for (var i = 0; i < 12; i++) {
    final cur = CurrencyFormatter.round(monthly[i]);
    double? pct;
    if (i > 0) {
      final prev = CurrencyFormatter.round(monthly[i - 1]);
      if (prev == 0 && cur > 0) {
        pct = 100.0;
      } else if (prev != 0) {
        pct = CurrencyFormatter.round((cur - prev) / prev * 100);
      }
    }
    out.add(MonthlyPoint(i, cur, pct));
  }
  return out;
}
