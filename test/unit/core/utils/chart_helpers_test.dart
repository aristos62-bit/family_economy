import 'package:flutter_test/flutter_test.dart';
import 'package:family_economy/core/utils/chart_helpers.dart';

void main() {
  group('ChartHelpers.getDateRange', () {
    test('Έτος covers Jan 1 to Dec 31', () {
      final now = DateTime.now();
      final r = ChartHelpers.getDateRange('Έτος');
      expect(r['start'], '${now.year}-01-01');
      expect(r['end'], '${now.year}-12-31');
    });

    test('Μήνας starts on the 1st', () {
      final now = DateTime.now();
      final r = ChartHelpers.getDateRange('Μήνας');
      expect(r['start'], '${now.year}-${now.month.toString().padLeft(2, '0')}-01');
    });

    test('Custom range passes through', () {
      final r = ChartHelpers.getDateRange('Custom_2024-01-01_2024-12-31');
      expect(r['start'], '2024-01-01');
      expect(r['end'], '2024-12-31');
    });
  });

  group('ChartHelpers formatting', () {
    test('formatMoney delegates to currency formatter', () {
      expect(ChartHelpers.formatMoney(1500.5).contains('1.500'), isTrue);
    });

    test('formatPercent defaults to 1 decimal', () {
      expect(ChartHelpers.formatPercent(75.5), '75.5%');
    });

    test('parseAmount handles Greek decimals', () {
      expect(ChartHelpers.parseAmount('1.234,56'), 1234.56);
    });

    test('parseAmount returns null for empty', () {
      expect(ChartHelpers.parseAmount(''), isNull);
    });
  });

  group('ChartHelpers.formatPeriodLabel', () {
    test('keeps simple periods as-is', () {
      expect(ChartHelpers.formatPeriodLabel('Μήνας'), 'Μήνας');
    });

    test('expands custom range', () {
      final l = ChartHelpers.formatPeriodLabel('Custom_2024-01-01_2024-12-31');
      expect(l.contains('2024-01-01'), isTrue);
      expect(l.contains('2024-12-31'), isTrue);
    });
  });
}
