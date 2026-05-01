// ============================================================
// FILE: graf_2_page.dart
// PURPOSE: Income Categories Pie Chart
// ADAPTED FOR: family_economy (Firebase version)
// Location: lib/presentation/screens/charts/graf_2_page.dart
// ✅ FIXED: Auto-updates when transactions change (online & offline)
// ============================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/core/utils/chart_helpers.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'dart:async';

class Graf2Page extends StatefulWidget {
  final String selectedPeriod;

  const Graf2Page({
    super.key,
    required this.selectedPeriod,
  });

  @override
  State<Graf2Page> createState() => _Graf2PageState();
}

class _Graf2PageState extends State<Graf2Page> {
  Timer? _debounceTimer;

  // ✅ ΔΙΟΡΘΩΣΗ 1: Track last announcement to avoid spam
  String? _lastAnnouncement;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPeriod();
      }
    });
  }

  @override
  void didUpdateWidget(covariant Graf2Page oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPeriod != widget.selectedPeriod) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(
        const Duration(milliseconds: 300),
        _loadPeriod,
      );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD PERIOD
  // ============================================================

  Future<void> _loadPeriod() async {
    if (!mounted) return;

    DebugConfig.print('GRAF2 ▶️ load start period=${widget.selectedPeriod}');

    try {
      final transactionsProvider = context.read<TransactionsProvider>();
      final categoriesProvider = context.read<CategoriesProvider>();

      DebugConfig.print('GRAF2 ✅ got providers: TP + Categories');

      // Περιμένουμε να φορτώσει το πρώτο snapshot κατηγοριών
      await categoriesProvider.firstLoad;
      if (!mounted) return;

      DebugConfig.print(
        'GRAF2 ✅ categories firstLoad done '
            'loading=${categoriesProvider.isLoading} '
            'err=${categoriesProvider.error} '
            'count=${categoriesProvider.allCategories.length}',
      );

      if (categoriesProvider.error != null) {
        DebugConfig.print('GRAF2 ❌ categories error: ${categoriesProvider.error}');
        _announceError();
        return;
      }

      // Get date range
      final dateRange = ChartHelpers.getDateRange(widget.selectedPeriod);
      DebugConfig.print('GRAF2 📅 dateRange=${dateRange['start']}..${dateRange['end']}');

      final startDate = DateTime.parse(dateRange['start']!);
      final endDate = DateTime.parse(dateRange['end']!);

      // Real-time: στήσε listener (αν δεν υπάρχει). Δεν κάνουμε setState εδώ.
      await transactionsProvider.loadPeriod(
        widget.selectedPeriod,
        startDate,
        endDate,
      );

      DebugConfig.print('GRAF2 ✅ TP.loadPeriod finished');

      // (Προαιρετικό) ανακοίνωση 1 φορά όταν στηθεί το listener
      final stats = _calculateStats(transactionsProvider, categoriesProvider);
      final totalIncome = stats['total'] as double;

      DebugConfig.print('GRAF2 💰 total income=${totalIncome.toStringAsFixed(2)}');

      if (mounted) {
        _announceDataUpdate(
          totalIncome,
          stats['categories'] as List<Map<String, dynamic>>,
        );
      }
    } catch (e) {
      DebugConfig.print('GRAF2 ❌ exception: $e');
      if (mounted) {
        _announceError();
      }
    }
  }

  // ============================================================
  // CALCULATE STATS
  // ============================================================

  Map<String, dynamic> _calculateStats(
      TransactionsProvider transactionsProvider,
      CategoriesProvider categoriesProvider,
      ) {
    try {
      // Income categories from provider
      final incomeCategories = categoriesProvider.getCategoriesByType('income');
      final Map<String, String> categoryNames = {
        for (final c in incomeCategories) c.uuid: c.name,
      };

      // Map to store category totals (init 0)
      final Map<String, double> categoryTotals = {
        for (final c in incomeCategories) c.uuid: 0.0,
      };

      // Sum amounts by category from provider transactions
      final transactions =
      transactionsProvider.getTransactionsForPeriod(widget.selectedPeriod);

      for (final t in transactions) {
        // Skip transfers
        if (t.isTransfer) continue;

        final categoryId = t.categoryId;
        if (categoryId == null || !categoryTotals.containsKey(categoryId)) {
          continue;
        }

        categoryTotals[categoryId] =
            (categoryTotals[categoryId] ?? 0.0) + t.amount.abs();
      }

      // Build result list (only categories with totals > 0)
      final List<Map<String, dynamic>> result = [];
      double totalIncome = 0.0;

      categoryTotals.forEach((categoryId, total) {
        if (total > 0) {
          result.add({
            'category': categoryNames[categoryId] ?? 'Unknown',
            'total': total,
          });
          totalIncome += total;
        }
      });

      // Sort by total descending
      result.sort((a, b) =>
          (b['total'] as double).compareTo((a['total'] as double)));

      return {
        'categories': result,
        'total': totalIncome,
      };
    } catch (e) {
      DebugConfig.print('GRAF2 ❌ Error calculating stats: $e');
      return {
        'categories': <Map<String, dynamic>>[],
        'total': 0.0,
      };
    }
  }


  // ============================================================
  // ACCESSIBILITY
  // ============================================================

  void _announceDataUpdate(double totalIncome, List<Map<String, dynamic>> categoryStats) {
    if (categoryStats.isEmpty) {
      final announcement = 'Δεν βρέθηκαν έσοδα για την περίοδο ${widget.selectedPeriod}';
      if (_lastAnnouncement != announcement) {
        _lastAnnouncement = announcement;
        AccessibilityService.announcePolite(announcement);
      }
      return;
    }

    final announcement =
        'Δεδομένα κατηγοριών εσόδων ενημερώθηκαν. '
        'Σύνολο: ${ChartHelpers.formatMoney(totalIncome)}. '
        '${categoryStats.length} κατηγορίες.';

    if (_lastAnnouncement != announcement) {
      _lastAnnouncement = announcement;
      AccessibilityService.announcePolite(announcement);
    }
  }

  void _announceError() {
    AccessibilityService.announceError(
      'Σφάλμα κατά τη φόρτωση των δεδομένων κατηγοριών',
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Rebuild όταν αλλάξουν transactions ή κατηγορίες
    final transactionsProvider = context.watch<TransactionsProvider>();
    final categoriesProvider = context.watch<CategoriesProvider>();

    final isLoading =
    transactionsProvider.isLoadingPeriod(widget.selectedPeriod);

    if (isLoading) {
      return Center(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: 'Φόρτωση δεδομένων κατηγοριών εσόδων',
          excludeSemantics: true,
          child: ExcludeSemantics(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Live stats
    final stats = _calculateStats(transactionsProvider, categoriesProvider);
    final categoryStats = stats['categories'] as List<Map<String, dynamic>>;
    final totalIncome = stats['total'] as double;

    return _buildContent(categoryStats, totalIncome);
  }


  Widget _buildContent(List<Map<String, dynamic>> categoryStats, double totalIncome) {
    final brightness = Theme.of(context).brightness;

    if (categoryStats.isEmpty || totalIncome <= 0.0) {
      return Semantics(
        container: true,
        label: 'Δεν υπάρχουν έσοδα για την περίοδο ${widget.selectedPeriod}',
        excludeSemantics: true,
        child: const Center(
          child: ExcludeSemantics(
            child: Text('Δεν βρέθηκαν έσοδα για την περίοδο'),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label:
      'Γράφημα πίτας κατηγοριών εσόδων. '
          'Σύνολο ${ChartHelpers.formatMoney(totalIncome)}. '
          '${categoryStats.length} κατηγορίες.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive sizing
          final chartHeight = constraints.maxHeight > 0
              ? constraints.maxHeight.clamp(140.0, 240.0)
              : 180.0;

          return Row(
            children: [
              // Pie chart (left)
              Expanded(
                flex: 1,
                child: Semantics(
                  label: 'Πίτα εσόδων με ${categoryStats.length} κατηγορίες',
                  child: ExcludeSemantics(
                    child: SizedBox(
                      height: chartHeight * 0.52,
                      child: PieChart(
                        PieChartData(
                          sections: categoryStats.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final cat = entry.value;
                            final double value = (cat['total'] as num).toDouble();
                            final percent =
                            totalIncome <= 0 ? 0 : (value / totalIncome) * 100;
                            final color = _pieColor(idx, brightness);
                            return PieChartSectionData(
                              value: value,
                              title: '${percent.toStringAsFixed(1)}%',
                              color: color,
                              radius: 45,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Legend (right)
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category items
                      ...categoryStats.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final cat = entry.value;
                        final value = (cat['total'] as num).toDouble();
                        final percent =
                        totalIncome <= 0 ? 0 : (value / totalIncome) * 100;

                        return Semantics(
                          label:
                          '${cat['category']}: ${ChartHelpers.formatMoney(value)}, ${percent.toStringAsFixed(1)} τοις εκατό',
                          child: ExcludeSemantics(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _pieColor(idx, brightness),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${cat['category']}',
                                      style: TypographyUI.bodySmall(brightness),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    ChartHelpers.formatMoney(value),
                                    style: TypographyUI.bodySmall(brightness).copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      // Divider
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: ExcludeSemantics(
                          child: Divider(height: 1, thickness: 1),
                        ),
                      ),

                      // Total row
                      Semantics(
                        label: 'Συνολικά έσοδα: ${ChartHelpers.formatMoney(totalIncome)}',
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: ColorsUI.getTextPrimary(brightness),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Σύνολο',
                                  style: TypographyUI.bodyMedium(brightness).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                ChartHelpers.formatMoney(totalIncome),
                                style: TypographyUI.bodyMedium(brightness).copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: ColorsUI.getIncomeColor(brightness),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Color palette for pie chart (dark mode aware)
  Color _pieColor(int idx, Brightness brightness) {
    final lightPalette = [
      const Color(0xFF2E7D32), // Green
      const Color(0xFF1976D2), // Blue
      const Color(0xFFED6C02), // Orange
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFC62828), // Red
      const Color(0xFF00838F), // Cyan
      const Color(0xFF689F38), // Light green
      const Color(0xFFF57F17), // Amber
      const Color(0xFF5D4037), // Brown
      const Color(0xFF455A64), // Blue grey
    ];

    final darkPalette = [
      const Color(0xFF81C784), // Light green
      const Color(0xFF64B5F6), // Light blue
      const Color(0xFFFFB74D), // Light orange
      const Color(0xFFBA68C8), // Light purple
      const Color(0xFFE57373), // Light red
      const Color(0xFF4DD0E1), // Light cyan
      const Color(0xFFAED581), // Lighter green
      const Color(0xFFF6D605), // Light yellow
      const Color(0xFFA1887F), // Light brown
      const Color(0xFF90A4AE), // Light blue grey
    ];

    final palette = brightness == Brightness.light ? lightPalette : darkPalette;
    return palette[idx % palette.length];
  }
}