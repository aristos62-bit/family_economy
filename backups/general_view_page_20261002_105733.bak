// ============================================================
// FILE: general_view_page.dart
// PURPOSE: General overview page with charts & period selection
// ADAPTED FOR: family_economy (Firebase version)
// Location: lib/presentation/screens/charts/general_view_page.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_economy/presentation/screens/charts/chart_registry.dart';
import 'package:family_economy/presentation/screens/charts/view_option_page.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/session/session_scope.dart';

class GeneralViewPage extends StatefulWidget {
  const GeneralViewPage({super.key});

  @override
  State<GeneralViewPage> createState() => GeneralViewPageState();
}

class GeneralViewPageState extends State<GeneralViewPage> {
  String _selectedPeriodGraf1 = 'Εβδομάδα';
  String _selectedPeriodGraf2 = 'Μήνας';
  String _selectedPeriodGraf3 = 'Εβδομάδα';
  String _selectedPeriodGraf5 = 'Μήνας';
  String _selectedPeriodGraf6 = 'Μήνας';

  final Map<String, Widget> _chartCache = {};
  List<String> chartOrder = [];
  List<bool> chartVisibility = [];
  bool _isFirstLoad = true;
  bool _loadingPrefs = false;

  @override
  void initState() {
    super.initState();
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Γενική εικόνα οικονομικών. Προβολή γραφημάτων.',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Load preferences when page is first built or when returning
    if ((_isFirstLoad || chartOrder.isEmpty) && !_loadingPrefs) {
      _loadingPrefs = true;
      _loadChartPreferences().whenComplete(() {
        _loadingPrefs = false;
      });
      _isFirstLoad = false;
    }
  }

  // ============================================================
  // CUSTOM DATE RANGE PICKER
  // ============================================================

  Future<Map<String, String>?> _pickCustomRange() async {
    final now = DateTime.now();
    final brightness = Theme.of(context).brightness;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      helpText: 'Επιλογή Προσαρμοσμένου Διαστήματος',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: ColorsUI.getPrimary(brightness),
              brightness: brightness,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return null;

    final start = picked.start.toIso8601String().split('T')[0];
    final end = picked.end.toIso8601String().split('T')[0];

    AccessibilityService.announcePolite(
      'Επιλέχθηκε περίοδος από $start έως $end',
    );

    return {'start': start, 'end': end};
  }

  // ============================================================
  // PREFERENCES MANAGEMENT
  // ============================================================

  void refresh() {
    if (_loadingPrefs) return;
    _loadingPrefs = true;
    _loadChartPreferences().whenComplete(() {
      _loadingPrefs = false;
    });
  }
  Future<void> _loadChartPreferences() async {
    if (!mounted) return;

    final userId = context.session.userId;
    final prefs = await SharedPreferences.getInstance();

    // Load order & visibility
    final savedOrder = prefs.getStringList('chart_order_$userId');
    final savedVisibility = prefs.getStringList('chart_visibility_$userId');

    final defaultOrder = availableCharts.map((c) => c.id).toList();
    final defaultVisibility = List.filled(availableCharts.length, true);

    // Load periods for each chart
    final period1 = prefs.getString('graf1_period_$userId') ?? 'Εβδομάδα';
    final period2 = prefs.getString('graf2_period_$userId') ?? 'Μήνας';
    final period3 = prefs.getString('graf3_period_$userId') ?? 'Εβδομάδα';
    final period5 = prefs.getString('graf5_period_$userId') ?? 'Μήνας';
    final period6 = prefs.getString('graf6_period_$userId') ?? 'Μήνας';

    // Migration: Add new charts to existing installations
    List<String> finalOrder;
    List<bool> finalVisibility;

    if (savedOrder != null) {
      finalOrder = List<String>.from(savedOrder);

      // Find missing charts
      for (final chartId in defaultOrder) {
        if (!finalOrder.contains(chartId)) {
          finalOrder.add(chartId); // Add new chart at the end
        }
      }

      await prefs.setStringList('chart_order_$userId', finalOrder);
    } else {
      finalOrder = defaultOrder;
    }

    if (savedVisibility != null) {
      finalVisibility = savedVisibility.map((v) => v == 'true').toList();

      // Add visibility for new charts
      while (finalVisibility.length < finalOrder.length) {
        finalVisibility.add(true); // New charts visible by default
      }

      final visibilityStrings =
      finalVisibility.map((v) => v.toString()).toList();
      await prefs.setStringList(
        'chart_visibility_$userId',
        visibilityStrings,
      );
    } else {
      finalVisibility = defaultVisibility;
    }

    if (mounted) {
      setState(() {
        // Έλεγχος αν άλλαξε κάτι που επηρεάζει τα γραφήματα
        final somethingChanged =
            _selectedPeriodGraf1 != period1 ||
                _selectedPeriodGraf2 != period2 ||
                _selectedPeriodGraf3 != period3 ||
                _selectedPeriodGraf5 != period5 ||
                _selectedPeriodGraf6 != period6 ||
                !_listEquals(chartOrder, finalOrder) ||
                !_listEquals(chartVisibility, finalVisibility);

        chartOrder = finalOrder;
        chartVisibility = finalVisibility;
        _selectedPeriodGraf1 = period1;
        _selectedPeriodGraf2 = period2;
        _selectedPeriodGraf3 = period3;
        _selectedPeriodGraf5 = period5;
        _selectedPeriodGraf6 = period6;

        // ✅ Καθαρισμός cache ΜΟΝΟ αν άλλαξε κάτι
        if (somethingChanged) {
          _chartCache.clear();
        }
      });
    }
  }

  Future<void> _savePeriod(String chartKey, String period) async {
    final userId = context.session.userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${chartKey}_period_$userId', period);
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _buildPeriodOption(String period, String current) {
    final isSelected = current == period;
    final brightness = Theme.of(context).brightness;

    return Semantics(
      button: true,
      label: 'Επιλογή περιόδου $period',
      selected: isSelected,
      child: InkWell(
        onTap: () => Navigator.pop(context, period),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? context.cPrimary.withValues(alpha: 0.15)
                : context.cSurface,
            border: Border.all(
              color: isSelected
                  ? context.cPrimary
                  : ColorsUI.getBorder(brightness),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (isSelected)
                ExcludeSemantics(
                  child: Icon(
                    Icons.check_circle,
                    color: context.cPrimary,
                    size: 20,
                  ),
                ),
              if (isSelected) const SizedBox(width: 8),
              Text(
                period,
                style: context.bodyMd.copyWith(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? context.cPrimary : context.cText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPeriodLabel(String raw) {
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

  // ============================================================
  // CHART CARD BUILDER
  // ============================================================

  Widget _buildCard({
    required String title,
    required String selectedPeriod,
    required Function(String) onPeriodChanged,
    required Widget chartWidget,
    bool showPeriodSelector = true,
  }) {
    final brightness = Theme.of(context).brightness;

    Future<void> showPeriodDialog() async {
      final options = ['Σήμερα', 'Εβδομάδα', 'Μήνας', 'Έτος', 'Προσαρμοσμένο'];

      AccessibilityService.announcePolite(
        'Άνοιξε διάλογος επιλογής περιόδου. Τρέχουσα: ${_formatPeriodLabel(selectedPeriod)}',
      );

      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Semantics(
            header: true,
            child: Text(
              'Επιλογή Περιόδου',
              style: context.titleMd,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...options.map((opt) {
                  if (opt == 'Προσαρμοσμένο') {
                    return Semantics(
                      button: true,
                      label: 'Επιλογή προσαρμοσμένης περιόδου',
                      hint: 'Ανοίγει επιλογή ημερομηνιών για προσαρμοσμένη περίοδο',
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(ctx);
                          final customRange = await _pickCustomRange();
                          if (customRange != null) {
                            final customPeriod =
                                'Custom_${customRange['start']}_${customRange['end']}';
                            onPeriodChanged(customPeriod);
                            AccessibilityService.announcePolite(
                              'Επιλέχθηκε προσαρμοσμένη περίοδος: ${_formatPeriodLabel(customPeriod)}',
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: context.cSurface,
                            border: Border.all(
                              color: ColorsUI.getBorder(brightness),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.calendar_month,
                                  color: context.cPrimary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                opt,
                                style: context.bodyMd.copyWith(
                                  fontSize: 16,
                                  color: context.cText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return _buildPeriodOption(opt, selectedPeriod);
                }),
              ],
            ),
          ),
          actions: [
            Semantics(
              button: true,
              label: 'Κλείσιμο χωρίς αλλαγή',
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Ακύρωση',
                  style: context.bodyMd.copyWith(color: context.cPrimary),
                ),
              ),
            ),
          ],
        ),
      );

      if (result != null && result != selectedPeriod) {
        onPeriodChanged(result);
        AccessibilityService.announcePolite(
          'Η περίοδος άλλαξε σε ${_formatPeriodLabel(result)}',
        );
      }
    }

    return Semantics(
      container: true,
      label: 'Κάρτα γραφήματος: $title',
      hint: 'Πατήστε το κουμπί ημερομηνίας για αλλαγή περιόδου',
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: context.cSurface,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: context.titleMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  if (showPeriodSelector) ...[
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Αλλαγή περιόδου. Τρέχουσα: ${_formatPeriodLabel(selectedPeriod)}',
                      excludeSemantics: true,
                      child: TextButton.icon(
                        onPressed: showPeriodDialog,
                        icon: ExcludeSemantics(
                          child: Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: context.cPrimary,
                          ),
                        ),
                        label: Text(
                          _formatPeriodLabel(selectedPeriod),
                          style: context.bodySm.copyWith(
                            color: context.cPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),
              chartWidget,
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final List<Widget> chartCards = [];

    for (int i = 0; i < chartOrder.length; i++) {
      final String chartId = chartOrder[i];
      if (i >= chartVisibility.length || !chartVisibility[i]) continue;

      final chartItem = availableCharts.firstWhere(
            (c) => c.id == chartId,
        orElse: () => availableCharts[0],
      );

      late Widget chartWidget;
      late String title;
      late String period;
      late Function(String) onChanged;

      switch (chartId) {
        case 'graf_1':
          title = 'Έσοδα / Έξοδα';
          period = _selectedPeriodGraf1;
          onChanged = (p) {
            setState(() {
              _selectedPeriodGraf1 = p;
              _chartCache.removeWhere((k, _) => k.startsWith('$chartId|'));
            });
            _savePeriod('graf1', p);
          };
          final cacheKey = '$chartId|$period';
          chartWidget = _chartCache.putIfAbsent(
            cacheKey,
                () => chartItem.builder(period),
          );
          break;

        case 'graf_2':
          title = 'Κατηγορίες Εσόδων';
          period = _selectedPeriodGraf2;
          onChanged = (p) {
            setState(() {
              _selectedPeriodGraf2 = p;
              _chartCache.removeWhere((k, _) => k.startsWith('$chartId|'));
            });
            _savePeriod('graf2', p);
          };

          final cacheKey = '$chartId|$period';
          chartWidget = _chartCache.putIfAbsent(
            cacheKey,
                () => chartItem.builder(period),
          );
          break;

        case 'graf_3':
          title = 'Κατηγορίες Εξόδων';
          period = _selectedPeriodGraf3;
          onChanged = (p) {
            setState(() {
              _selectedPeriodGraf3 = p;
              _chartCache.removeWhere((k, _) => k.startsWith('$chartId|'));
            });
            _savePeriod('graf3', p);
          };

          final cacheKey = '$chartId|$period';
          chartWidget = _chartCache.putIfAbsent(
            cacheKey,
                () => chartItem.builder(period),
          );
          break;

        case 'graf_4':
          title = 'Υπόλοιπα Λογαριασμών';
          period = '';
          onChanged = (_) {};
          const cacheKey = 'graf_4';
          chartWidget = _chartCache.putIfAbsent(
            cacheKey,
                () => chartItem.builder(''),
          );
          break;

        case 'graf_5':
          title = 'Υποκατηγορίες Εξόδων';
          period = _selectedPeriodGraf5;
          onChanged = (p) {
            setState(() {
              _selectedPeriodGraf5 = p;
              _chartCache.removeWhere((k, _) => k.startsWith('$chartId|'));
            });
            _savePeriod('graf5', p);
          };

          final cacheKey = '$chartId|$period';
          chartWidget = _chartCache.putIfAbsent(
            cacheKey,
                () => chartItem.builder(period),
          );
          break;


        case 'graf_6':
          title = 'Προβολή Κινήσεων';
          period = _selectedPeriodGraf6;
          onChanged = (p) {
            setState(() {
              _selectedPeriodGraf6 = p;
              _chartCache.removeWhere((k, _) => k.startsWith('$chartId|'));
            });
            _savePeriod('graf6', p);
          };

          final cacheKey = '$chartId|$period';
          chartWidget = _chartCache.putIfAbsent(
            cacheKey,
                () => chartItem.builder(period),
          );
          break;


        default:
          continue;
      }

      chartCards.add(
        _buildCard(
          title: title,
          selectedPeriod: period,
          onPeriodChanged: onChanged,
          chartWidget: chartWidget,
          showPeriodSelector: chartId != 'graf_4',
        ),
      );
    }

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Γενική εικόνα οικονομικών',
      child: Scaffold(
        backgroundColor: context.cBg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                const SizedBox(height: 16),

                // Chart cards
                ...chartCards,

                const SizedBox(height: 20),

                // Edit layout button
                Center(
                  child: Semantics(
                    button: true,
                    label: 'Επεξεργασία διάταξης των γραφημάτων',
                    hint: 'Πατήστε για να αλλάξετε σειρά ή να αποκρύψετε γραφήματα',
                    excludeSemantics: true,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final session = context.session; // ΠΑΡΕ το session από το ΣΩΣΤΟ context (εδώ δουλεύει)

                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SessionScope(
                              session: session,
                              child: const ViewOptionPage(),
                            ),
                          ),
                        );


                        if (!mounted) return;
                        if (result == true) {
                          refresh();
                          AccessibilityService.announceSuccess('Η διάταξη ενημερώθηκε');
                        }
                      },
                      icon: ExcludeSemantics(
                        child: Icon(
                          Icons.tune,
                          color: context.cPrimary,
                        ),
                      ),
                      label: Text(
                        'Επεξεργασία Διάταξης Σελίδας',
                        style: context.bodyMd.copyWith(
                          color: context.cPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: context.cPrimary,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}