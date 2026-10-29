import 'package:intl/intl.dart';

/// Currency Formatter
/// Greek/European format: € 1.500,20
class CurrencyFormatter {
  // ============================================================
  // CONFIG
  // ============================================================

  static const String defaultCurrency = '€';

  static const Map<String, String> _currencySymbols = {
    'EUR': '€',
    'USD': '\$',
    'GBP': '£',
  };

  // Cache formatters for performance (symbol + decimals)
  static final Map<String, NumberFormat> _currencyFormatCache = {};

  static String _resolveCurrencySymbol(String currency) {
    final c = currency.trim();
    return _currencySymbols[c] ?? c;
  }

  static NumberFormat _currencyFormatter({
    required String symbol,
    required int decimalDigits,
  }) {
    final key = '$symbol|$decimalDigits';
    return _currencyFormatCache.putIfAbsent(
      key,
          () => NumberFormat.currency(
        locale: 'el_GR',
        symbol: symbol,
        decimalDigits: decimalDigits,
      ),
    );
  }


  // ============================================================
  // FORMAT
  // ============================================================

  /// Format amount with European style.
  /// Example: 1500.50 → € 1.500,50
  static String format(
      double amount, {
        String currency = defaultCurrency,
        bool showCurrency = true,
        int decimalDigits = 2,
      }) {
    final resolved = _resolveCurrencySymbol(currency);
    final symbol = showCurrency ? resolved : '';
    final fmt = _currencyFormatter(symbol: symbol, decimalDigits: decimalDigits);
    final formatted = fmt.format(amount);

    // Extra safety: if showCurrency=false and intl leaves spacing, trim it.
    return showCurrency ? formatted : formatted.trim();
  }

  /// Example: 1500.50 → 1.500,50
  static String formatWithoutSymbol(double amount, {int decimalDigits = 2}) {
    // Using currency formatter with empty symbol gives correct separators for el_GR.
    return format(amount, showCurrency: false, decimalDigits: decimalDigits);
  }

  /// Format compact in Greek:
  /// - 1500 -> € 1,5 χιλ.
  /// - 2_400_000 -> € 2,4 εκ.
  /// - 3_200_000_000 -> € 3,2 δισ.
  static String formatCompact(
      double amount, {
        String currency = defaultCurrency,
        int fractionDigits = 1,
      }) {
    final absAmount = amount.abs();
    String suffix;
    double scaled;

    if (absAmount >= 1000000000) {
      scaled = absAmount / 1000000000;
      suffix = 'δισ.';
    } else if (absAmount >= 1000000) {
      scaled = absAmount / 1000000;
      suffix = 'εκ.';
    } else if (absAmount >= 1000) {
      scaled = absAmount / 1000;
      suffix = 'χιλ.';
    } else {
      // κάτω από 1000: δείξε ακέραιο χωρίς suffix
      final base = absAmount.toStringAsFixed(0);
      final localized = base.replaceAll('.', ',');
      final sign = amount < 0 ? '-' : '';
      return '$currency $sign$localized';
    }

    // format with comma decimal (Greek style)
    final s = scaled.toStringAsFixed(fractionDigits).replaceAll('.', ',');

    final sign = amount < 0 ? '-' : '';
    return '$currency $sign$s $suffix';
  }

  // ============================================================
  // PARSING
  // ============================================================

  /// Parse amount from string to double.
  /// Handles both European (1.500,20) and US (1,500.20) formats.
  static double? parseAmount(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    try {
      // Remove currency symbols and spaces
      String cleaned = raw.replaceAll(RegExp(r'[€$£¥\s]'), '');

      // Keep only digits, comma, dot and minus
      cleaned = cleaned.replaceAll(RegExp(r'[^\d,\.\-]'), '');

      // Normalize minus: allow only one '-' at the beginning
      final isNegative = cleaned.startsWith('-');
      cleaned = cleaned.replaceAll('-', '');
      if (isNegative) cleaned = '-$cleaned';

      final lastComma = cleaned.lastIndexOf(',');
      final lastDot = cleaned.lastIndexOf('.');

      if (lastComma > lastDot) {
        // European: '.' thousands, ',' decimals
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // US-ish: ',' thousands, '.' decimals
        cleaned = cleaned.replaceAll(',', '');
      }

      // Edge cases: "-" or "-." etc.
      if (cleaned == '-' || cleaned == '-.' || cleaned == '.' || cleaned == ',') return null;

      return double.parse(cleaned);
    } catch (_) {
      return null;
    }
  }

  /// Parse amount from input field.
  /// NOTE: returning null for empty input is safer than 0.0 (empty ≠ zero).
  static double? parseInput(String input) {
    if (input.trim().isEmpty) return null;
    return parseAmount(input);
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  static bool isValidAmount(String input) => parseAmount(input) != null;

  static bool isInRange(double amount, {double? min, double? max}) {
    if (min != null && amount < min) return false;
    if (max != null && amount > max) return false;
    return true;
  }

  static String? getValidationError(
      String input, {
        bool required = true,
        double? min,
        double? max,
        bool allowNegative = false,
      }) {
    final trimmed = input.trim();

    if (trimmed.isEmpty && required) return 'Το ποσό είναι υποχρεωτικό';
    if (trimmed.isEmpty && !required) return null;

    final amount = parseAmount(trimmed);
    if (amount == null) return 'Μη έγκυρη μορφή ποσού';
    if (!allowNegative && amount < 0) return 'Το ποσό πρέπει να είναι θετικό';
    if (min != null && amount < min) return 'Ελάχιστο: ${format(min)}';
    if (max != null && amount > max) return 'Μέγιστο: ${format(max)}';

    return null;
  }

  // ============================================================
  // ARITHMETIC (basic rounding for currency)
  // ============================================================

  static double add(double a, double b) => round(a + b);
  static double subtract(double a, double b) => round(a - b);
  static double multiply(double amount, double multiplier) => round(amount * multiplier);

  static double divide(double amount, double divisor) {
    if (divisor == 0) return 0.0;
    return round(amount / divisor);
  }

  static double percentage(double amount, double percent) => multiply(amount, percent / 100);

  // ============================================================
  // HELPERS
  // ============================================================

  static double round(double amount, {int decimalDigits = 2}) =>
      double.parse(amount.toStringAsFixed(decimalDigits));

  static double roundUp(double amount) => (amount * 100).ceil() / 100;
  static double roundDown(double amount) => (amount * 100).floor() / 100;
  static double abs(double amount) => amount.abs();
  static int sign(double amount) => amount < 0 ? -1 : (amount > 0 ? 1 : 0);
}

// ============================================================
// EXTENSIONS
// ============================================================

extension CurrencyExtension on double {
  String toCurrency({String currency = CurrencyFormatter.defaultCurrency}) {
    return CurrencyFormatter.format(this, currency: currency);
  }

  String toCurrencyWithoutSymbol() {
    return CurrencyFormatter.formatWithoutSymbol(this);
  }

  String toCurrencyCompact({String currency = CurrencyFormatter.defaultCurrency}) {
    return CurrencyFormatter.formatCompact(this, currency: currency);
  }

  double roundCurrency() {
    return CurrencyFormatter.round(this);
  }
}

extension StringCurrencyExtension on String {
  double? toCurrencyAmount() => CurrencyFormatter.parseAmount(this);
  bool get isValidCurrency => CurrencyFormatter.isValidAmount(this);
}
