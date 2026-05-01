// ============================================================
// FILE: graf_5_page.dart
// PURPOSE: Expense Subcategories Pie Chart with Category Dropdown
// ADAPTED FOR: family_economy (Firebase version)
// Location: lib/presentation/screens/charts/graf_5_page.dart
// ✅ FIXED: Auto-updates when transactions change (online & offline)
// ============================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';
import 'package:family_economy/core/utils/chart_helpers.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'dart:async';

class Graf5Page extends StatefulWidget {
  final String selectedPeriod;

  const Graf5Page({super.key, required this.selectedPeriod});

  @override
  State<Graf5Page> createState() => _Graf5PageState();
}

class _Graf5PageState extends State<Graf5Page> {
  Timer? _debounceTimer;

  // ✅ ΔΙΟΡΘΩΣΗ 1: Track last announcement
  String? _lastAnnouncement;

  // ✅ ΔΙΟΡΘΩΣΗ 2: Dropdown selection state (μόνο αυτό κρατάμε)
  String? _selectedCategoryUuid;
  String _selectedCategoryName = '';
  bool _didInitDefaultCategory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _bootstrap();
      }
    });
  }

  @override
  void didUpdateWidget(covariant Graf5Page oldWidget) {
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

  Future<void> _bootstrap() async {
    if (!mounted) return;

    final categoriesProvider = context.read<CategoriesProvider>();

    // ✅ Περιμένουμε να έρθει το πρώτο snapshot κατηγοριών
    await categoriesProvider.firstLoad;
    if (!mounted) return;

    // ✅ Τώρα μπορούμε να διαλέξουμε default category σωστά
    _initializeDefaultCategory();

    // ✅ Και μετά φορτώνουμε τα transactions για την περίοδο
    await _loadPeriod();
  }


  // ============================================================
  // INITIALIZE DEFAULT CATEGORY
  // ============================================================

  void _initializeDefaultCategory() {
    if (_didInitDefaultCategory) return;

    final categoriesProvider = context.read<CategoriesProvider>();

    final expenseCategories = categoriesProvider.getCategoriesByType('expense');

    if (expenseCategories.isEmpty) {
      _didInitDefaultCategory = true;
      return;
    }

    // 1) Προσπάθησε να βρεις κατηγορία με όνομα "Διατροφή"
    CategoryModel? defaultCategory;
    try {
      defaultCategory = expenseCategories.firstWhere(
            (cat) => cat.name.toLowerCase() == 'διατροφή',
      );
    } catch (_) {
      defaultCategory = null;
    }

    // 2) Αν δεν βρεθεί, πάρε την πρώτη με subcategories
    defaultCategory ??= expenseCategories.firstWhere(
          (cat) => categoriesProvider.getSubcategoriesForCategory(cat.uuid).isNotEmpty,
      orElse: () => expenseCategories.first,
    );

    _didInitDefaultCategory = true;

    setState(() {
      _selectedCategoryUuid = defaultCategory!.uuid;
      _selectedCategoryName = defaultCategory.name;
    });

    DebugConfig.print('GRAF5 ✅ default category: $_selectedCategoryName');
  }

  // ============================================================
  // LOAD PERIOD
  // ============================================================

  Future<void> _loadPeriod() async {
    if (!mounted) return;
    if (_selectedCategoryUuid == null) {
      _initializeDefaultCategory();
      if (_selectedCategoryUuid == null) return;
    }

    DebugConfig.print('GRAF5 ▶️ load start period=${widget.selectedPeriod}');

    try {
      final transactionsProvider = context.read<TransactionsProvider>();
      final categoriesProvider = context.read<CategoriesProvider>();

      // Περιμένουμε να φορτώσει το πρώτο snapshot
      await categoriesProvider.firstLoad;
      if (!mounted) return;

      if (categoriesProvider.error != null) {
        DebugConfig.print('GRAF5 ❌ categories error: ${categoriesProvider.error}');
        _announceError();
        return;
      }

      // Get date range
      final dateRange = ChartHelpers.getDateRange(widget.selectedPeriod);
      DebugConfig.print('GRAF5 📅 dateRange=${dateRange['start']}..${dateRange['end']}');

      final startDate = DateTime.parse(dateRange['start']!);
      final endDate = DateTime.parse(dateRange['end']!);

      // Real-time: στήσε listener
      await transactionsProvider.loadPeriod(
        widget.selectedPeriod,
        startDate,
        endDate,
      );

      DebugConfig.print('GRAF5 ✅ TP.loadPeriod finished');

      // Ανακοίνωση 1 φορά
      if (mounted) {
        final stats = _calculateStats(transactionsProvider, categoriesProvider);
        final totalExpense = stats['total'] as double;
        DebugConfig.print('GRAF5 💰 total expense=${totalExpense.toStringAsFixed(2)}');
        _announceDataUpdate(totalExpense, stats['subcategories'] as List<Map<String, dynamic>>);
      }
    } catch (e) {
      DebugConfig.print('GRAF5 ❌ exception: $e');
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
      if (_selectedCategoryUuid == null) {
        return {
          'subcategories': <Map<String, dynamic>>[],
          'total': 0.0,
        };
      }

      // Subcategories για την επιλεγμένη κατηγορία
      final subcategories = categoriesProvider.getSubcategoriesForCategory(
        _selectedCategoryUuid!,
      );

      final Map<String, double> subcategoryTotals = {};
      final Map<String, String> subcategoryNames = {};

      for (final subcat in subcategories) {
        subcategoryTotals[subcat.uuid] = 0.0;
        subcategoryNames[subcat.uuid] = subcat.name;
      }

      // Sum amounts από provider transactions
      final transactions =
      transactionsProvider.getTransactionsForPeriod(widget.selectedPeriod);

      for (final t in transactions) {
        if (t.isTransfer) continue;

        // Μόνο για την επιλεγμένη κατηγορία
        if (t.categoryId != _selectedCategoryUuid) continue;

        final subcategoryId = t.subcategoryId;
        if (subcategoryId == null || !subcategoryTotals.containsKey(subcategoryId)) {
          continue;
        }

        subcategoryTotals[subcategoryId] =
            (subcategoryTotals[subcategoryId] ?? 0.0) + t.amount.abs();
      }

      // Build result list
      final List<Map<String, dynamic>> result = [];
      double totalExpense = 0.0;

      subcategoryTotals.forEach((subcategoryId, total) {
        if (total > 0) {
          result.add({
            'subcategory_id': subcategoryId,
            'subcategory': subcategoryNames[subcategoryId] ?? 'Unknown',
            'total': total,
          });
          totalExpense += total;
        }
      });

      // Sort by total descending
      result.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

      return {
        'subcategories': result,
        'total': totalExpense,
      };
    } catch (e) {
      DebugConfig.print('GRAF5 ❌ Error calculating stats: $e');
      return {
        'subcategories': <Map<String, dynamic>>[],
        'total': 0.0,
      };
    }
  }

  // ============================================================
  // SEMANTIC SUMMARY
  // ============================================================

  String _buildSemanticSummary(List<Map<String, dynamic>> subcategoryStats, double totalExpense) {
    if (subcategoryStats.isEmpty || totalExpense <= 0) {
      return 'Δεν υπάρχουν έξοδα σε υποκατηγορίες για $_selectedCategoryName '
          'στην περίοδο ${ChartHelpers.formatPeriodLabel(widget.selectedPeriod)}.';
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Υποκατηγορίες εξόδων για $_selectedCategoryName. '
          'Περίοδος: ${ChartHelpers.formatPeriodLabel(widget.selectedPeriod)}. '
          'Συνολικά έξοδα: ${ChartHelpers.formatMoney(totalExpense)}. '
          'Περιλαμβάνονται ${subcategoryStats.length} υποκατηγορίες.',
    );

    for (var item in subcategoryStats) {
      final name = item['subcategory'];
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

  void _announceDataUpdate(double totalExpense, List<Map<String, dynamic>> subcategoryStats) {
    if (subcategoryStats.isEmpty) {
      final announcement =
          'Δεν βρέθηκαν υποκατηγορίες για $_selectedCategoryName στην περίοδο ${widget.selectedPeriod}';
      if (_lastAnnouncement != announcement) {
        _lastAnnouncement = announcement;
        AccessibilityService.announcePolite(announcement);
      }
      return;
    }

    final announcement =
        'Δεδομένα υποκατηγοριών ενημερώθηκαν. '
        'Σύνολο: ${ChartHelpers.formatMoney(totalExpense)}. '
        '${subcategoryStats.length} υποκατηγορίες.';

    if (_lastAnnouncement != announcement) {
      _lastAnnouncement = announcement;
      AccessibilityService.announcePolite(announcement);
    }
  }

  void _announceError() {
    AccessibilityService.announceError(
      'Σφάλμα κατά τη φόρτωση των δεδομένων υποκατηγοριών',
    );
  }

  // ============================================================
  // CATEGORY DROPDOWN
  // ============================================================

  Widget _buildCategoryDropdown(Brightness brightness) {
    final categoriesProvider = context.watch<CategoriesProvider>();
    final expenseCategories = categoriesProvider.getCategoriesByType('expense');

    if (expenseCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Semantics(
        label: 'Επιλογή κατηγορίας εξόδων. Τρέχουσα: $_selectedCategoryName',
        hint: 'Πατήστε για αλλαγή κατηγορίας',
        child: SizedBox(                      // ← αυτό εδώ είναι το κλειδί
          width: 200,                         // ← δοκίμασε 260–320
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ColorsUI.getSurface(brightness),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorsUI.getBorder(brightness)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategoryUuid,
                // isExpanded: true,               // ← μένει true, τώρα περιορίζεται από το SizedBox
                icon: ExcludeSemantics(
                  child: Icon(Icons.arrow_drop_down, color: ColorsUI.getPrimary(brightness)),
                ),
                style: TypographyUI.bodyMedium(brightness),
                dropdownColor: ColorsUI.getSurface(brightness),
                items: expenseCategories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category.uuid,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (String? newValue) {
              if (newValue != null && newValue != _selectedCategoryUuid) {
                setState(() {
                  _selectedCategoryUuid = newValue;
                  _selectedCategoryName = expenseCategories
                      .firstWhere((c) => c.uuid == newValue)
                      .name;
                });

                // Ανακοίνωση αλλαγής
                AccessibilityService.announcePolite(
                  'Επιλέχθηκε κατηγορία $_selectedCategoryName',
                );

                DebugConfig.print('GRAF5 🔄 category changed to: $_selectedCategoryName');
              }
            },
          ),
        ),
      ),
        ),
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

  Widget _buildEmptyState(Brightness brightness) {
    return Semantics(
      label: 'Δεν υπάρχουν δεδομένα υποκατηγοριών',
      child: Container(
        constraints: const BoxConstraints(minHeight: 200),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.pie_chart_outline,
                  size: 64,
                  color: ColorsUI.getTextSecondary(brightness),
                ),
          ),
                const SizedBox(height: 16),
            ExcludeSemantics(
              child: Text(
                  'Δεν βρέθηκαν υποκατηγορίες',
                  style: TypographyUI.titleMedium(brightness),
                ),
            ),
                const SizedBox(height: 8),
              ExcludeSemantics(
                child: Text(
                  'Δεν υπάρχουν έξοδα σε υποκατηγορίες\nγια την επιλεγμένη κατηγορία',
                  style: TypographyUI.bodyMedium(brightness).copyWith(
                    color: ColorsUI.getTextSecondary(brightness),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Rebuild όταν αλλάξουν transactions ή κατηγορίες
    final transactionsProvider = context.watch<TransactionsProvider>();
    context.watch<CategoriesProvider>(); // μόνο για rebuild όταν αλλάζουν categories
    final isLoading =
    transactionsProvider.isLoadingPeriod(widget.selectedPeriod);

    return Semantics(
      container: true,
      label: 'Γράφημα υποκατηγοριών εξόδων',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _buildCategoryDropdown(brightness),
          ),
          const SizedBox(height: 8),

          // Content
          if (isLoading)
            Semantics(
              label: 'Φόρτωση δεδομένων υποκατηγοριών εξόδων',
              liveRegion: true,
              excludeSemantics: true,
              child: SizedBox(
                height: 300,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildSkeleton(brightness),
                      const SizedBox(height: 12),
                      ExcludeSemantics(
                        child: Text(
                          'Φόρτωση...',
                          style: TypographyUI.bodySmall(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            _buildContentWithData(brightness),
        ],
      ),
    );
  }

  Widget _buildContentWithData(Brightness brightness) {
    final transactionsProvider = context.watch<TransactionsProvider>();
    final categoriesProvider = context.watch<CategoriesProvider>();

    // Live stats
    final stats = _calculateStats(transactionsProvider, categoriesProvider);
    final subcategoryStats = stats['subcategories'] as List<Map<String, dynamic>>;
    final totalExpense = stats['total'] as double;

    if (subcategoryStats.isEmpty || totalExpense <= 0.0) {
      return _buildEmptyState(brightness);
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: _buildChartWithLegend(brightness, subcategoryStats, totalExpense),
    );
  }

  Widget _buildChartWithLegend(
      Brightness brightness,
      List<Map<String, dynamic>> subcategoryStats,
      double totalExpense,
      ) {
    return Semantics(
      label: _buildSemanticSummary(subcategoryStats, totalExpense),
      child: LayoutBuilder(
        builder: (context, constraints) {

          // Pie chart
          final pie = Semantics(
            label: 'Πίτα υποκατηγοριών με ${subcategoryStats.length} τμήματα',
            child: ExcludeSemantics(
              child: SizedBox(
                height: 160, // ✅ ίδιο “οπτικό βάρος” με το πάνω γράφημα
                child: PieChart(
                  PieChartData(
                    sections: subcategoryStats.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final double value = (item['total'] as num).toDouble();
                      final percent = totalExpense <= 0 ? 0 : (value / totalExpense) * 100;
                      final color = _pieColor(idx, brightness);

                      return PieChartSectionData(
                        value: value,
                        title: '${percent.toStringAsFixed(1)}%',
                        color: color,
                        radius: 45, // ✅ ίδια “γεμάτη” πίτα
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 15, // ✅ ίδια τρύπα όπως πάνω
                  ),
                ),
              ),

            ),
          );

          // Legend (✅ grows with content; card height increases, nothing gets cut)
          final legend = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subcategory items
              ...subcategoryStats.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final subcategory = item['subcategory'] as String;
                final value = (item['total'] as num).toDouble();
                final percent = totalExpense <= 0 ? 0 : (value / totalExpense) * 100;

                return Semantics(
                  label: '$subcategory: ${ChartHelpers.formatMoney(value)}, '
                      '${percent.toStringAsFixed(1)} τοις εκατό',
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
                              subcategory,
                              style: TypographyUI.bodySmall(brightness),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                          const SizedBox(width: 1),
                          SizedBox(
                            width: 55,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  ChartHelpers.formatMoney(value),
                                  style: TypographyUI.bodySmall(brightness).copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
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
                label:
                'Συνολικά έξοδα σε υποκατηγορίες: ${ChartHelpers.formatMoney(totalExpense)}',
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
                          style: TypographyUI.bodySmall(brightness).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),

                      const SizedBox(width: 6),
                      const SizedBox(width: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          ChartHelpers.formatMoney(totalExpense),
                          style: TypographyUI.bodySmall(brightness).copyWith(
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
          );



          return Row(
            children: [
              // Pie chart (left)
              Expanded(
                flex: 1,
                child: pie,
              ),

              const SizedBox(width: 16),

              // Legend (right)
              Expanded(
                flex: 1,
                child: legend,
              ),
            ],
          );


        },
      ),
    );
  }

  // ============================================================
  // COLOR PALETTE
  // ============================================================

  Color _pieColor(int idx, Brightness brightness) {
    final lightPalette = [
      const Color(0xFFE57373),
      const Color(0xFFF06292),
      const Color(0xFFBA68C8),
      const Color(0xFF9575CD),
      const Color(0xFF7986CB),
      const Color(0xFF64B5F6),
      const Color(0xFF4FC3F7),
      const Color(0xFF4DD0E1),
      const Color(0xFF4DB6AC),
      const Color(0xFF81C784),
      const Color(0xFFAED581),
      const Color(0xFFFFF176),
      const Color(0xFFFFD54F),
      const Color(0xFFFFB74D),
      const Color(0xFFFF8A65),
      const Color(0xFFA1887F),
      const Color(0xFFE0E0E0),
      const Color(0xFF90A4AE),
      const Color(0xFFCE93D8),
      const Color(0xFFFFAB91),
      const Color(0xFF80CBC4),
      const Color(0xFFB0BEC5),
      const Color(0xFFE1BEE7),
      const Color(0xFFFFCDD2),
      const Color(0xFFFFF9C4),
    ];

    final darkPalette = [
      const Color(0xFFDE4C4C),
      const Color(0xFFEC7BA1),
      const Color(0xFFCE93D8),
      const Color(0xFF8859DC),
      const Color(0xFF9FA8DA),
      const Color(0xFF90CAF9),
      const Color(0xFF36AEE5),
      const Color(0xFF48828A),
      const Color(0xFF80CBC4),
      const Color(0xFFA5D6A7),
      const Color(0xFFC5E1A5),
      const Color(0xFFFFF59D),
      const Color(0xFFFFE082),
      const Color(0xFFFFCC80),
      const Color(0xFFFFAB91),
      const Color(0xFFBCAAA4),
      const Color(0xFFEEEEEE),
      const Color(0xFFB0BEC5),
      const Color(0xFFE1BEE7),
      const Color(0xFFFFCCBC),
      const Color(0xFFB2DFDB),
      const Color(0xFFCFD8DC),
      const Color(0xFFF3E5F5),
      const Color(0xFFFFEBEE),
      const Color(0xFFFFFDE7),
    ];

    final palette = brightness == Brightness.light ? lightPalette : darkPalette;
    return palette[idx % palette.length];
  }
}