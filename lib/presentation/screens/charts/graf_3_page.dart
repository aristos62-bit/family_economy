// ============================================================
// FILE: graf_3_page.dart
// PURPOSE: Expense Categories Pie Chart
// ADAPTED FOR: family_economy (Firebase version)
// Location: lib/presentation/screens/charts/graf_3_page.dart
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

class Graf3Page extends StatefulWidget {
  final String selectedPeriod;

  const Graf3Page({super.key, required this.selectedPeriod});

  @override
  State<Graf3Page> createState() => _Graf3PageState();
}

class _Graf3PageState extends State<Graf3Page> {
  Timer? _debounceTimer;

  // ✅ ΔΙΟΡΘΩΣΗ 1: Track last announcement to avoid spam
  String? _lastAnnouncement;

  // ✅ NEW: prevents repeat announcements for same stats
  String? _lastStatsKey;

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
  void didUpdateWidget(covariant Graf3Page oldWidget) {
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

  String _readablePeriod(String raw) {
    return ChartHelpers.formatPeriodLabel(raw);
  }

  // ============================================================
  // LOAD PERIOD
  // ============================================================

  Future<void> _loadPeriod() async {
    if (!mounted) return;

    DebugConfig.print('GRAF3 ▶️ load start period=${widget.selectedPeriod}');

    try {
      final transactionsProvider = context.read<TransactionsProvider>();
      final categoriesProvider = context.read<CategoriesProvider>();

      DebugConfig.print('GRAF3 ✅ got providers: TP + Categories');

      // Περιμένουμε να φορτώσει το πρώτο snapshot κατηγοριών
      await categoriesProvider.firstLoad;
      if (!mounted) return;

      DebugConfig.print(
        'GRAF3 ✅ categories firstLoad done '
            'loading=${categoriesProvider.isLoading} '
            'err=${categoriesProvider.error} '
            'count=${categoriesProvider.allCategories.length}',
      );

      if (categoriesProvider.error != null) {
        DebugConfig.print('GRAF3 ❌ categories error: ${categoriesProvider.error}');
        _announceError();
        return;
      }

      // Get date range
      final dateRange = ChartHelpers.getDateRange(widget.selectedPeriod);
      DebugConfig.print('GRAF3 📅 dateRange=${dateRange['start']}..${dateRange['end']}');

      final startStr = dateRange['start'];
      final endStr = dateRange['end'];

      if (startStr == null || endStr == null) {
        throw Exception('Μη έγκυρο εύρος ημερομηνιών: η αρχική ή η τελική ημερομηνία είναι κενή');
      }

      final startDate = DateTime.parse(startStr);
      final endDate = DateTime.parse(endStr);

      // Real-time: στήσε listener (αν δεν υπάρχει). Δεν κάνουμε setState εδώ.
      final currentPeriod = widget.selectedPeriod;

      await transactionsProvider.loadPeriod(
        widget.selectedPeriod,
        startDate,
        endDate,
      );

      if (!mounted || currentPeriod != widget.selectedPeriod) return;

      DebugConfig.print('GRAF3 ✅ TP.loadPeriod finished');

      // (Προαιρετικό) ανακοίνωση 1 φορά όταν στηθεί το listener
      final stats = _calculateStats(transactionsProvider, categoriesProvider);

      final totalExpense = stats['total'] as double;

      DebugConfig.print('GRAF3 💰 total expense=${totalExpense.toStringAsFixed(2)}');

      if (mounted) {
        final categoryStats = stats['categories'] as List<Map<String, dynamic>>;

        // ✅ Fingerprint: period + total + number of categories
        final statsKey =
            '${widget.selectedPeriod}|'
            '${totalExpense.toStringAsFixed(2)}|'
            '${categoryStats.map((e) => '${e['category']}:${e['total']}')}';

        if (_lastStatsKey != statsKey) {
          _lastStatsKey = statsKey;
          _announceDataUpdate(totalExpense, categoryStats);
        }
      }

    } catch (e) {
      DebugConfig.print('GRAF3 ❌ exception: $e');
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
      // Expense categories from provider
      final expenseCategories = categoriesProvider.getCategoriesByType('expense');
      final Map<String, String> categoryNames = {
        for (final c in expenseCategories) c.uuid: c.name,
      };

      // Map to store category totals (init 0)
      final Map<String, double> categoryTotals = {
        for (final c in expenseCategories) c.uuid: 0.0,
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
      double totalExpense = 0.0;

      categoryTotals.forEach((categoryId, total) {
        if (total > 0) {
          result.add({
            'category': categoryNames[categoryId] ?? 'Unknown',
            'total': total,
          });
          totalExpense += total;
        }
      });

      // Sort by total descending
      result.sort(
            (a, b) => (b['total'] as double).compareTo((a['total'] as double)),
      );

      return {
        'categories': result,
        'total': totalExpense,
      };
    } catch (e) {
      DebugConfig.print('GRAF3 ❌ Error calculating stats: $e');
      return {
        'categories': <Map<String, dynamic>>[],
        'total': 0.0,
      };
    }
  }

  // ============================================================
  // SEMANTIC SUMMARY
  // ============================================================

  String _buildSemanticSummary(List<Map<String, dynamic>> categoryStats, double totalExpense) {
    if (categoryStats.isEmpty || totalExpense <= 0) {
      return 'Δεν υπάρχουν έξοδα για την περίοδο ${_readablePeriod(widget.selectedPeriod)}.';
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Σύνοψη εξόδων για την περίοδο ${_readablePeriod(widget.selectedPeriod)}. '
          'Συνολικά έξοδα: ${ChartHelpers.formatMoney(totalExpense)}. '
          'Περιλαμβάνονται ${categoryStats.length} κατηγορίες.',
    );

    for (var item in categoryStats) {
      final name = item['category'];
      final value = (item['total'] as num).toDouble();
      final percent = totalExpense <= 0 ? 0 : (value / totalExpense) * 100;

      buffer.writeln(
        '$name: ${ChartHelpers.formatMoney(value)}, '
            '${percent.toStringAsFixed(1)} τοις εκατό.',
      );
    }

    return buffer.toString();
  }

  // ============================================================
  // ACCESSIBILITY
  // ============================================================

  void _announceDataUpdate(double totalExpense, List<Map<String, dynamic>> categoryStats) {
    if (categoryStats.isEmpty) {
      final announcement = 'Δεν βρέθηκαν έξοδα για την περίοδο ${widget.selectedPeriod}';
      if (_lastAnnouncement != announcement) {
        _lastAnnouncement = announcement;
        AccessibilityService.announcePolite(announcement);
      }
      return;
    }

    final announcement =
        'Δεδομένα κατηγοριών εξόδων ενημερώθηκαν. '
        'Σύνολο: ${ChartHelpers.formatMoney(totalExpense)}. '
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
  // SKELETON LOADER
  // ============================================================

  Widget _buildSkeleton(Brightness brightness) {
    final skeletonColor =
    brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300;

    return ExcludeSemantics(
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: skeletonColor,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Right skeleton (legend)
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(5, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: skeletonColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // ✅ "όνομα" (παίρνει ό,τι χώρο υπάρχει)
                      Expanded(
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: skeletonColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // ✅ "ποσό" (μικρό και σταθερό)
                      SizedBox(
                        width: 48,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: skeletonColor,
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
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Rebuild όταν αλλάξουν transactions ή κατηγορίες
    final transactionsProvider = context.watch<TransactionsProvider>();
    final categoriesProvider = context.watch<CategoriesProvider>();

    final isLoading =
    transactionsProvider.isLoadingPeriod(widget.selectedPeriod);

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Semantics(
              container: true,
              liveRegion: true,
              label: 'Φόρτωση δεδομένων κατηγοριών εξόδων',
              excludeSemantics: true,
              child: ExcludeSemantics(
                child: CircularProgressIndicator(),
              ),
            ),
            const SizedBox(height: 12),
            _buildSkeleton(brightness),
          ],
        ),
      );
    }

    // Live stats
    final stats = _calculateStats(transactionsProvider, categoriesProvider);
    final categoryStats = stats['categories'] as List<Map<String, dynamic>>;
    final totalExpense = stats['total'] as double;

    return _buildContent(categoryStats, totalExpense, brightness);
  }

  Widget _buildContent(
      List<Map<String, dynamic>> categoryStats,
      double totalExpense,
      Brightness brightness,
      ) {
    if (categoryStats.isEmpty || totalExpense <= 0.0) {
      return Semantics(
        container: true,
        label: 'Δεν υπάρχουν έξοδα για την περίοδο ${_readablePeriod(widget.selectedPeriod)}',
        child: const Center(
          child: ExcludeSemantics(
            child: Text('Δεν βρέθηκαν έξοδα για την περίοδο'),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: _buildSemanticSummary(categoryStats, totalExpense),
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
                  label: 'Πίτα εξόδων με ${categoryStats.length} κατηγορίες',
                  child: ExcludeSemantics(
                    child: SizedBox(
                      height: chartHeight * 0.52,
                      child: PieChart(
                        PieChartData(
                          sections: categoryStats.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final cat = entry.value;
                            final double value = (cat['total'] as num).toDouble();
                            final percent = totalExpense <= 0
                                ? 0
                                : (value / totalExpense) * 100;
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
                          centerSpaceRadius: 15,
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
                        final percent = totalExpense <= 0
                            ? 0
                            : (value / totalExpense) * 100;

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

                                  // ✅ Το όνομα να μην ξεχειλώνει
                                  Expanded(
                                    child: Text(
                                      '${cat['category']}',
                                      style: TypographyUI.bodySmall(brightness),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                    ),
                                  ),

                                  const SizedBox(width: 6),

                                  // ✅ Το ποσό να "χωράει" πάντα
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      ChartHelpers.formatMoney(value),
                                      style: TypographyUI.bodySmall(brightness)
                                          .copyWith(fontWeight: FontWeight.w600),
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
                        label: 'Συνολικά έξοδα: ${ChartHelpers.formatMoney(totalExpense)}',
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
                                  style: TypographyUI.bodyMedium(brightness)
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  ChartHelpers.formatMoney(totalExpense),
                                  style: TypographyUI.bodyMedium(brightness).copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: ColorsUI.getExpenseColor(brightness),
                                  ),
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
      const Color(0xFFE57373), // Red soft
      const Color(0xFFF06292), // Pink
      const Color(0xFFBA68C8), // Purple
      const Color(0xFF9575CD), // Deep purple
      const Color(0xFF7986CB), // Indigo
      const Color(0xFF64B5F6), // Light blue
      const Color(0xFF4FC3F7), // Sky blue
      const Color(0xFF4DD0E1), // Cyan
      const Color(0xFF4DB6AC), // Teal
      const Color(0xFF81C784), // Green
      const Color(0xFFAED581), // Light green
      const Color(0xFFFFF176), // Yellow
      const Color(0xFFFFD54F), // Amber
      const Color(0xFFFFB74D), // Orange
      const Color(0xFFFF8A65), // Deep orange
      const Color(0xFFA1887F), // Brown
      const Color(0xFFE0E0E0), // Grey
      const Color(0xFF90A4AE), // Blue grey
      const Color(0xFFCE93D8), // Lavender
      const Color(0xFFFFAB91), // Salmon
    ];

    final darkPalette = [
      const Color(0xFFEF9A9A), // Lighter red
      const Color(0xFFF48FB1), // Lighter pink
      const Color(0xFFCE93D8), // Lighter purple
      const Color(0xFFB39DDB), // Lighter deep purple
      const Color(0xFF9FA8DA), // Lighter indigo
      const Color(0xFF90CAF9), // Lighter blue
      const Color(0xFF81D4FA), // Lighter sky blue
      const Color(0xFF80DEEA), // Lighter cyan
      const Color(0xFF80CBC4), // Lighter teal
      const Color(0xFFA5D6A7), // Lighter green
      const Color(0xFFC5E1A5), // Lighter light green
      const Color(0xFFFFF59D), // Lighter yellow
      const Color(0xFFFFE082), // Lighter amber
      const Color(0xFFFFCC80), // Lighter orange
      const Color(0xFFFFAB91), // Lighter deep orange
      const Color(0xFFBCAAA4), // Lighter brown
      const Color(0xFFEEEEEE), // Lighter grey
      const Color(0xFFB0BEC5), // Lighter blue grey
      const Color(0xFFE1BEE7), // Lighter lavender
      const Color(0xFFFFCCBC), // Lighter salmon
    ];

    final palette = brightness == Brightness.light ? lightPalette : darkPalette;
    return palette[idx % palette.length];
  }
}