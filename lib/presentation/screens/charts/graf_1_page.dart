// ============================================================
// FILE: graf_1_page.dart
// PURPOSE: Income vs Expense Bar Chart
// ADAPTED FOR: family_economy (Firebase version)
// Location: lib/presentation/screens/charts/graf_1_page.dart
// ✅ FIXED: Auto-updates when transactions change (online & offline)
// ============================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/utils/chart_helpers.dart';
import 'dart:async';
import 'package:family_economy/core/utils/debug_config.dart';

class Graf1Page extends StatefulWidget {
  final String selectedPeriod;

  const Graf1Page({super.key, required this.selectedPeriod});

  @override
  State<Graf1Page> createState() => _Graf1PageState();
}

class _Graf1PageState extends State<Graf1Page> {
  Timer? _debounceTimer;

  // // ✅ ΔΙΟΡΘΩΣΗ 1: Track last announcement to avoid spam
  // String? _lastAnnouncement;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadStatisticsFromProvider();
      }
    });
  }

  @override
  void didUpdateWidget(covariant Graf1Page oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPeriod != widget.selectedPeriod) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(
        const Duration(milliseconds: 300),
        _loadStatisticsFromProvider,
      );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD STATISTICS FROM PROVIDER
  // ============================================================

  Future<void> _loadStatisticsFromProvider() async {
    if (!mounted) return;

    DebugConfig.print('GRAF1 ▶️ load start period=${widget.selectedPeriod}');

    try {
      final transactionsProvider = context.read<TransactionsProvider>();
      final categoriesProvider = context.read<CategoriesProvider>();

      DebugConfig.print('GRAF1 ✅ got providers: TP + Categories');

      // Περιμένουμε να φορτώσει το πρώτο snapshot κατηγοριών
      await categoriesProvider.firstLoad;
      if (!mounted) return;

      DebugConfig.print(
        'GRAF1 ✅ categories firstLoad done '
        'loading=${categoriesProvider.isLoading} '
        'err=${categoriesProvider.error} '
        'count=${categoriesProvider.allCategories.length}',
      );

      if (categoriesProvider.error != null) {
        DebugConfig.print(
          'GRAF1 ❌ categories error: ${categoriesProvider.error}',
        );
        _announceError();
        return;
      }

      // Get date range
      final dateRange = ChartHelpers.getDateRange(widget.selectedPeriod);
      DebugConfig.print(
        'GRAF1 📅 dateRange=${dateRange['start']}..${dateRange['end']}',
      );

      final startDate = DateTime.parse(dateRange['start']!);
      final endDate = DateTime.parse(dateRange['end']!);

      // Real-time: στήσε listener (αν δεν υπάρχει). Δεν κάνουμε setState εδώ.
      await transactionsProvider.loadPeriod(
        widget.selectedPeriod,
        startDate,
        endDate,
      );

      DebugConfig.print('GRAF1 ✅ TP.loadPeriod finished');

      // (Προαιρετικό) ανακοίνωση 1 φορά όταν στηθεί το listener
      final categoryTypes = <String, String>{};
      for (final cat in categoriesProvider.allCategories) {
        categoryTypes[cat.uuid] = cat.type;
      }

      final income = transactionsProvider.getTotalIncome(
        widget.selectedPeriod,
        categoryTypes,
      );
      final expense = transactionsProvider
          .getTotalExpense(widget.selectedPeriod, categoryTypes)
          .abs();

      DebugConfig.print('GRAF1 💰 totals income=${income.toStringAsFixed(2)} expense=${expense.toStringAsFixed(2)}');

      if (mounted) {
        _announceDataUpdate(income, expense);
      }
    } catch (e) {
      DebugConfig.print('GRAF1 ❌ exception: $e');
      if (mounted) {
        _announceError();
      }
    }
  }

  // ============================================================
  // ACCESSIBILITY
  // ============================================================

  void _announceDataUpdate(double income, double expense) {
    if (income == 0 && expense == 0) return;

    final total = income - expense;
    final totalLabel = total >= 0
        ? 'Πλεόνασμα: ${AccessibilityService.currencyLabel(total, 'EUR')}'
        : 'Έλλειμμα: ${AccessibilityService.currencyLabel(total.abs(), 'EUR')}';

    final announcement =
        'Δεδομένα ενημερώθηκαν. '
        'Έσοδα: ${AccessibilityService.currencyLabel(income, 'EUR')}. '
        'Έξοδα: ${AccessibilityService.currencyLabel(expense, 'EUR')}. '
        '$totalLabel.';

    AccessibilityService.announcePolite(announcement);
  }

  void _announceError() {
    AccessibilityService.announceError('Σφάλμα κατά τη φόρτωση των δεδομένων.');
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Rebuild όταν αλλάξουν transactions ή κατηγορίες
    final transactionsProvider = context.watch<TransactionsProvider>();
    final categoriesProvider = context.watch<CategoriesProvider>();

    final isLoading = transactionsProvider.isLoadingPeriod(
      widget.selectedPeriod,
    );

    // Build category types map
    final categoryTypes = <String, String>{};
    for (final cat in categoriesProvider.allCategories) {
      categoryTypes[cat.uuid] = cat.type;
    }

    // Live totals
    final income = transactionsProvider.getTotalIncome(
      widget.selectedPeriod,
      categoryTypes,
    );

    final expense = transactionsProvider
        .getTotalExpense(widget.selectedPeriod, categoryTypes)
        .abs();

    return isLoading ? _buildLoadingState() : _buildContent(income, expense);
  }

  // ✅ ΔΙΟΡΘΩΣΗ 6: Extract data update logic

  Widget _buildLoadingState() {
    return Center(
      child: Semantics(
        container: true,
        label: 'Φόρτωση δεδομένων',
        liveRegion: true,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ExcludeSemantics(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildContent(double income, double expense) {
    final brightness = Theme.of(context).brightness;
    final size = MediaQuery.of(context).size;

    // Responsive sizing
    final isCompact = size.width < 400;
    final chartHeight = isCompact ? 80.0 : 110.0;

    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bar Chart
            Expanded(
              flex: 5,
              child: _buildBarChart(chartHeight, brightness, income, expense),
            ),

            const SizedBox(width: 16),

            // Statistics
            Expanded(
              flex: 5,
              child: ExcludeSemantics(
                child: _buildStatistics(
                  brightness,
                  chartHeight,
                  income,
                  expense,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(
    double height,
    Brightness brightness,
    double income,
    double expense,
  ) {
    final rawMax = income > expense ? income : expense;
    final maxValue = rawMax <= 0 ? 100.0 : rawMax * 1.25;
    final total = income - expense;
    return SizedBox(
      height: height,
      child: Semantics(
        label:
            'Γράφημα εσόδων και εξόδων. '
            'Έσοδα ${AccessibilityService.currencyLabel(income, 'EUR')}. '
            'Έξοδα ${AccessibilityService.currencyLabel(expense, 'EUR')}. '
            '${total >= 0 ? 'Πλεόνασμα' : 'Έλλειμμα'}: ${AccessibilityService.currencyLabel(total.abs(), 'EUR')}.',
        hint:
            'Σύγκριση συνολικών εσόδων και εξόδων για την επιλεγμένη περίοδο.',
        child: ExcludeSemantics(
          child: BarChart(
            BarChartData(
              maxY: maxValue,
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [
                    BarChartRodData(
                      toY: income,
                      color: ColorsUI.getIncomeColor(brightness),
                      width: 15,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 1,
                  barRods: [
                    BarChartRodData(
                      toY: expense,
                      color: ColorsUI.getExpenseColor(brightness),
                      width: 15,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                  ],
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) => Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        value == 0 ? 'Έσοδα' : 'Έξοδα',
                        style: TypographyUI.bodySmall(
                          brightness,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final type = group.x == 0 ? 'Έσοδα' : 'Έξοδα';
                    return BarTooltipItem(
                      '$type\n${ChartHelpers.formatMoney(rod.toY)}',
                      TypographyUI.bodySmall(brightness).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatistics(
    Brightness brightness,
    double height,
    double income,
    double expense,
  ) {
    final total = income - expense;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(left: 2.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            _buildStatRow(
              'Έσοδα',
              income,
              ColorsUI.getIncomeColor(brightness),
              brightness,
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              'Έξοδα',
              expense,
              ColorsUI.getExpenseColor(brightness),
              brightness,
            ),
            const SizedBox(height: 6),
            ExcludeSemantics(
              child: Divider(color: ColorsUI.getDivider(brightness), height: 1),
            ),
            const SizedBox(height: 6),
            _buildStatRow(
              'Διαφορά',
              total,
              total >= 0
                  ? ColorsUI.getIncomeColor(brightness)
                  : ColorsUI.getExpenseColor(brightness),
              brightness,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    double amount,
    Color color,
    Brightness brightness, {
    bool isBold = false,
  }) {
    return Semantics(
      label: '$label: ${ChartHelpers.formatMoney(amount)}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TypographyUI.bodySmall(brightness).copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 1),
            Flexible(
              child: Text(
                ChartHelpers.formatMoney(amount),
                style: TypographyUI.bodySmall(brightness).copyWith(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
