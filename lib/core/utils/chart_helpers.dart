// ============================================================
// Chart Helpers - Currency & Number Formatting
// Location: lib/core/utils/chart_helpers.dart
// ============================================================
import 'package:family_economy/core/utils/currency_formatter.dart';

class ChartHelpers {
  /// Format amount as currency (Greek style: 1.234,56 €)
  static String formatMoney(double amount, {bool showSign = false}) {
    // Χρήση CurrencyFormatter για συνεπή μορφοποίηση 2 δεκαδικών
    return CurrencyFormatter.format(amount, decimalDigits: 2);
  }

  /// Format amount as compact (1.2K, 1.2M)
  static String formatCompact(double amount) {
    final absAmount = amount.abs();
    final isNegative = amount < 0;
    final sign = isNegative ? '-' : '';

    if (absAmount >= 1000000) {
      return '$sign${(absAmount / 1000000).toStringAsFixed(1)}M €';
    } else if (absAmount >= 1000) {
      return '$sign${(absAmount / 1000).toStringAsFixed(1)}K €';
    } else {
      return formatMoney(amount);
    }
  }

  /// Format percentage (e.g., 75.5%)
  static String formatPercent(double value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  /// Parse Greek-style number back to double
  /// Example: "1.234,56" → 1234.56
  static double? parseAmount(String text) {
    if (text.isEmpty) return null;

    try {
      // Remove currency symbols and spaces
      String clean = text
          .replaceAll('€', '')
          .replaceAll(' ', '')
          .trim();

      // Replace Greek decimal separator (,) with standard (.)
      // But first, remove thousands separators (.)
      if (clean.contains(',')) {
        clean = clean.replaceAll('.', ''); // Remove thousands separator
        clean = clean.replaceAll(',', '.'); // Replace decimal separator
      }

      return double.parse(clean);
    } catch (e) {
      return null;
    }
  }

  /// Get date range from period string
  /// Returns Map with 'start' and 'end' keys in YYYY-MM-DD format
  static Map<String, String> getDateRange(String period) {
    final now = DateTime.now();

    // Custom range: "Custom_YYYY-MM-DD_YYYY-MM-DD"
    if (period.startsWith('Custom_')) {
      final parts = period.split('_');
      if (parts.length == 3) {
        return {'start': parts[1], 'end': parts[2]};
      }
    }

    String start, end;

    switch (period) {
      case 'Σήμερα':
        start = end = DateTime(now.year, now.month, now.day)
            .toIso8601String()
            .split('T')[0];
        break;

      case 'Εβδομάδα':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(weekStart.year, weekStart.month, weekStart.day)
            .toIso8601String()
            .split('T')[0];
        end = DateTime(now.year, now.month, now.day)
            .toIso8601String()
            .split('T')[0];
        break;

      case 'Μήνας':
        start = DateTime(now.year, now.month, 1)
            .toIso8601String()
            .split('T')[0];
        end = DateTime(now.year, now.month + 1, 0)
            .toIso8601String()
            .split('T')[0];
        break;

      case 'Έτος':
        start = DateTime(now.year, 1, 1).toIso8601String().split('T')[0];
        end = DateTime(now.year, 12, 31).toIso8601String().split('T')[0];
        break;

      default:
        start = end = DateTime(now.year, now.month, now.day)
            .toIso8601String()
            .split('T')[0];
    }

    return {'start': start, 'end': end};
  }

  /// Format period label for display
  /// Converts "Custom_YYYY-MM-DD_YYYY-MM-DD" to readable format
  static String formatPeriodLabel(String raw) {
    if (!raw.startsWith('Custom_')) {
      return raw;
    }

    // raw format: Custom_YYYY-MM-DD_YYYY-MM-DD
    final parts = raw.split('_');
    if (parts.length != 3) return raw;

    final start = parts[1];
    final end = parts[2];

    return 'Custom ($start → $end)';
  }
}