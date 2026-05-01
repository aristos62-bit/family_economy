// ============================================================
// FILE: graf_4_page.dart
// PURPOSE: Account Balances Bar Chart
// ADAPTED FOR: family_economy (Firebase version)
// Location: lib/presentation/screens/charts/graf_4_page.dart
// ✅ OPTIMIZED: Already uses real-time AccountsProvider
// ============================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/core/utils/chart_helpers.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';

class Graf4Page extends StatefulWidget {
  const Graf4Page({super.key});

  @override
  State<Graf4Page> createState() => _Graf4PageState();
}

class _Graf4PageState extends State<Graf4Page> {
  // ✅ Track last announcement to avoid spam
  String? _lastStatsKey;

  @override
  void initState() {
    super.initState();
    DebugConfig.print(
      'GRAF4 ▶️ init - AccountsProvider already has real-time listener',
    );
  }

  // ============================================================
  // SEMANTIC SUMMARY
  // ============================================================

  String _buildSemanticSummary(
    List<AccountModel> accounts,
    double totalBalance,
  ) {
    if (accounts.isEmpty) {
      return 'Δεν υπάρχουν λογαριασμοί.';
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Σύνοψη λογαριασμών. '
      'Συνολικό υπόλοιπο: ${ChartHelpers.formatMoney(totalBalance)}. '
      '${accounts.length} λογαριασμοί.',
    );

    for (var acc in accounts) {
      buffer.writeln(
        '${acc.name}: ${ChartHelpers.formatMoney(acc.currentBalance)}, '
        '${acc.currentBalance >= 0 ? "Θετικό" : "Αρνητικό"} υπόλοιπο.',
      );
    }

    return buffer.toString();
  }

  // ============================================================
  // ACCESSIBILITY
  // ============================================================


  // ============================================================
  // SKELETON LOADER
  // ============================================================

  Widget _buildSkeletonLoader(Brightness brightness) {
    final baseColor = ColorsUI.byBrightness(
      brightness: brightness,
      light: const Color(0xFFE0E0E0),
      dark: const Color(0xFF424242),
    );
    final itemColor = ColorsUI.byBrightness(
      brightness: brightness,
      light: const Color(0xFFEEEEEE),
      dark: const Color(0xFF616161),
    );

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(5, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: itemColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: itemColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // ✅ context.watch για auto-rebuild (AccountsProvider ήδη έχει listener)
    final accountsProvider = context.watch<AccountsProvider>();

    if (accountsProvider.isLoading) {
      return Semantics(
        label: 'Φόρτωση δεδομένων λογαριασμών',
        liveRegion: true,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const ExcludeSemantics(
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 12),
              _buildSkeletonLoader(brightness),
            ],
          ),
        ),
      );
    }

    // Live data από provider
    final accounts = accountsProvider.accounts;

    if (accounts.isEmpty) {
      return Semantics(
        label: 'Δεν υπάρχουν λογαριασμοί',
        excludeSemantics: true,
        child: Center(
          child: ExcludeSemantics(
            child: Text(
              'Δεν υπάρχουν λογαριασμοί',
              style: TypographyUI.bodyMedium(brightness),
            ),
          ),
        ),
      );
    }

    // Calculate total balance
    final totalBalance = accounts.fold<double>(
      0.0,
      (sum, acc) => sum + acc.currentBalance,
    );

    // Sort by balance descending
    final sortedAccounts = List<AccountModel>.from(accounts);
    sortedAccounts.sort((a, b) => b.currentBalance.compareTo(a.currentBalance));

    // Announce updates (stable deduplication)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (accountsProvider.isLoading) return;
      final top = sortedAccounts.isNotEmpty ? sortedAccounts.first : null;
      final statsKey =
          '${accounts.length}|${totalBalance.toStringAsFixed(2)}|'
          '${top?.uuid ?? ""}|${top?.currentBalance.toStringAsFixed(2) ?? ""}';
      if (_lastStatsKey != statsKey) {
        _lastStatsKey = statsKey;
        final totalType = totalBalance >= 0 ? "Θετικό" : "Αρνητικό";
        final announcement =
            'Τα δεδομένα λογαριασμών ενημερώθηκαν. ${accounts.length} λογαριασμοί. '
            'Συνολικό υπόλοιπο: ${ChartHelpers.formatMoney(totalBalance)} ($totalType).';
        AccessibilityService.announcePolite(announcement);
      }
    });
    return _buildContent(sortedAccounts, totalBalance, brightness);
  }

  Widget _buildContent(
    List<AccountModel> sortedAccounts,
    double totalBalance,
    Brightness brightness,
  ) {
    // Calculate min/max for scaling (supports both positive & negative balances)
    double maxPositive = 0.0;
    double minNegative = 0.0;

    for (final acc in sortedAccounts) {
      final b = acc.currentBalance;
      if (b > maxPositive) maxPositive = b;
      if (b < minNegative) minNegative = b;
    }

// Add padding
    final paddedMaxY = maxPositive == 0.0 ? 100.0 : maxPositive * 1.25;
    final paddedMinY = minNegative == 0.0 ? 0.0 : minNegative * 1.25;


    return Semantics(
      container: true,
      label: _buildSemanticSummary(sortedAccounts, totalBalance),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final chartHeight = w < 400
              ? 120.0
              : w < 600
              ? 140.0
              : 160.0;

          return Row(
            children: [
              // Bar chart (left)
              Expanded(
                flex: 1,
                child: Semantics(
                  label: 'Ραβδόγραμμα ${sortedAccounts.length} λογαριασμών. '
                      'Υψηλότερο υπόλοιπο: ${ChartHelpers.formatMoney(sortedAccounts.first.currentBalance)}',
                  child: ExcludeSemantics(
                    child: SizedBox(
                      height: chartHeight,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.center,
                          maxY: paddedMaxY,
                          minY: paddedMinY,

                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipPadding: const EdgeInsets.all(8),
                              tooltipMargin: 8,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                if (groupIndex >= sortedAccounts.length) {
                                  return null;
                                }

                                final account = sortedAccounts[groupIndex];
                                return BarTooltipItem(
                                  '${account.name}\n${ChartHelpers.formatMoney(account.currentBalance)}',
                                  TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: constraints.maxWidth < 400 ? 10 : 12,
                                  ),
                                );
                              },

                            ),
                          ),
                          titlesData: const FlTitlesData(
                            show: false,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(sortedAccounts.length, (
                            index,
                          ) {
                            final balance =
                                sortedAccounts[index].currentBalance;

                            // ✅ Σωστό round στο "εξωτερικό" άκρο
                            final BorderRadius br = balance >= 0
                                ? const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  )
                                : const BorderRadius.vertical(
                                    bottom: Radius.circular(6),
                                  );

                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: balance,
                                  color: balance >= 0
                                      ? ColorsUI.getSuccess(brightness)
                                      : ColorsUI.getError(brightness),
                                  width: constraints.maxWidth < 400 ? 12 : 16,
                                  borderRadius: br,
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Account list (right)
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Accounts
                    ...sortedAccounts.map((account) {
                      final balance = account.currentBalance;
                      return Semantics(
                        label:
                        '${account.name}: ${ChartHelpers.formatMoney(balance)}. ${balance >= 0 ? "Θετικό υπόλοιπο" : "Αρνητικό υπόλοιπο"}',
                        header: false,
                        textDirection: TextDirection.ltr,
                        child: ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _buildAccountRow(
                              account.name,
                              balance,
                              balance >= 0
                                  ? ColorsUI.getSuccess(brightness)
                                  : ColorsUI.getError(brightness),
                              brightness,
                            ),
                          ),
                        ),
                      );
                    }),

                    // Divider
                    ExcludeSemantics(
                      child: Divider(
                        color: ColorsUI.getDivider(brightness),
                        thickness: 1,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Total
                    Semantics(
                      label: 'Συνολικό υπόλοιπο: ${ChartHelpers.formatMoney(totalBalance)}. ${totalBalance >= 0 ? "Θετικό" : "Αρνητικό"}',
                      header: true,
                      child: ExcludeSemantics(
                        child: _buildAccountRow(
                          'Σύνολο',
                          totalBalance,
                          totalBalance >= 0
                              ? ColorsUI.getSuccess(brightness)
                              : ColorsUI.getError(brightness),
                          brightness,
                          isBold: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountRow(
    String label,
    double amount,
    Color color,
    Brightness brightness, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TypographyUI.bodySmall(brightness).copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          ChartHelpers.formatMoney(amount),
          style: TypographyUI.bodySmall(brightness).copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
