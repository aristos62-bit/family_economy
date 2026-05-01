// ============================================================
// FILE: view_option_page.dart
// PURPOSE: Chart Layout Editor & Period Settings
// ADAPTED FOR: family_economy (Firebase version)
// Location: lib/presentation/screens/charts/view_option_page.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_economy/presentation/screens/charts/chart_registry.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:flutter/semantics.dart';

class ViewOptionPage extends StatefulWidget {
  const ViewOptionPage({super.key});

  @override
  State<ViewOptionPage> createState() => _ViewOptionPageState();
}

class _ViewOptionPageState extends State<ViewOptionPage> {
  late List<Map<String, dynamic>> charts;
  String? _userId;
  bool _preferencesLoaded = false;

  /// Metadata for charts (title & icon)
  final Map<String, Map<String, dynamic>> chartMeta = {
    'graf_1': {'title': 'Έσοδα / Έξοδα', 'icon': Icons.bar_chart},
    'graf_2': {'title': 'Κατηγορίες Εσόδων', 'icon': Icons.pie_chart},
    'graf_3': {'title': 'Κατηγορίες Εξόδων', 'icon': Icons.pie_chart_outline},
    'graf_4': {'title': 'Λογαριασμοί', 'icon': Icons.account_balance_wallet},
    'graf_5': {'title': 'Υποκατηγορίες Εξόδων', 'icon': Icons.donut_small},
    'graf_6': {'title': 'Αναλυτική Προβολή', 'icon': Icons.list_alt},
  };

  /// Colors per chart
  final Map<String, Color> chartColors = {
    'graf_1': Colors.blue,
    'graf_2': Colors.green,
    'graf_3': Colors.orange,
    'graf_4': Colors.purple,
    'graf_5': Colors.teal,
    'graf_6': Colors.deepPurple,
  };

  /// Default periods per chart
  final Map<String, String> _defaultPeriods = {
    'graf_1': 'Εβδομάδα',
    'graf_2': 'Μήνας',
    'graf_3': 'Εβδομάδα',
    'graf_4': 'Έτος',
    'graf_5': 'Μήνας',
    'graf_6': 'Μήνας',
  };

  /// Current saved period per chart
  final Map<String, String> _chartPeriods = {};

  /// Available period options
  final List<String> _periodOptions = const [
    'Σήμερα',
    'Εβδομάδα',
    'Μήνας',
    'Έτος',
  ];

  void _moveItem(int oldIndex, int newIndex) {
    setState(() {
      final item = charts.removeAt(oldIndex);
      charts.insert(newIndex, item);
    });

    // Αποθήκευση της νέας σειράς
    _saveOrderAndVisibilityOnly();

    // Φωνητική ενημέρωση για τη νέα θέση
    final chartName = chartMeta[charts[newIndex]['id']]?['title'] ?? 'Γράφημα';
    AccessibilityService.announcePolite(
      '$chartName μετακινήθηκε στη θέση ${newIndex + 1}',
    );
  }

  @override
  void initState() {
    super.initState();

    charts = availableCharts
        .map((c) => {'id': c.id, 'name': c.name, 'visible': true})
        .toList();

    AccessibilityService.announceAfterFirstFrame(
      context,
      'Σελίδα Διάταξης Γραφημάτων. Ρυθμίστε τη σειρά και ορατότητα των γραφημάτων.',
    );
  }

  // ✅ ΝΕΟΣ: Χρήση didChangeDependencies
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_preferencesLoaded) {
      final session = context.sessionOrNull;

      if (session != null) {
        _userId = session.userId;
        _preferencesLoaded = true;
        debugPrint('📊 VIEW_OPTION: Got userId = $_userId');

        // Asynchronous load
        _loadPreferences();
      } else {
        debugPrint('⚠️ VIEW_OPTION: SessionScope not available yet');
      }
    }
  }

  /// Map from chartId to prefix key used in SharedPreferences
  String? _periodKeyForChart(String chartId) {
    switch (chartId) {
      case 'graf_1':
        return 'graf1';
      case 'graf_2':
        return 'graf2';
      case 'graf_3':
        return 'graf3';
      case 'graf_5':
        return 'graf5';
      case 'graf_6':
        return 'graf6';
      default:
        return null; // graf_4 doesn't use period
    }
  }

  Future<void> _loadPreferences() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();

    // Load order & visibility
    final order = prefs.getStringList('chart_order_${_userId!}');
    final visibility = prefs.getStringList('chart_visibility_${_userId!}');

    if (order != null && visibility != null) {
      final Map<String, bool> visMap = {};
      for (int i = 0; i < order.length; i++) {
        visMap[order[i]] = visibility[i] == 'true';
      }

      setState(() {
        charts = availableCharts.map((c) {
          return {'id': c.id, 'name': c.name, 'visible': visMap[c.id] ?? true};
        }).toList();

        charts.sort(
          (a, b) => order.indexOf(a['id']).compareTo(order.indexOf(b['id'])),
        );
      });
    }

    // Load saved periods for each chart
    for (final c in availableCharts) {
      final chartId = c.id;
      final keyPrefix = _periodKeyForChart(chartId);
      if (keyPrefix == null) continue;

      final saved = prefs.getString('${keyPrefix}_period_${_userId!}');
      _chartPeriods[chartId] = saved ?? _defaultPeriods[chartId]!;
    }

    setState(() {});
  }

  Future<void> _savePreferences() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();

    final orderList = charts.map((c) => c['id'] as String).toList();
    final visibilityList = charts.map((c) => c['visible'].toString()).toList();

    await prefs.setStringList('chart_order_${_userId!}', orderList);
    await prefs.setStringList('chart_visibility_${_userId!}', visibilityList);

    // Save all periods
    for (final entry in _chartPeriods.entries) {
      final chartId = entry.key;
      final period = entry.value;
      await _saveChartPeriod(chartId, period);
    }
  }

  Future<void> _saveOrderAndVisibilityOnly() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();

    final orderList = charts.map((c) => c['id'] as String).toList();
    final visibilityList = charts.map((c) => c['visible'].toString()).toList();

    DebugConfig.print('VIEW_OPTION: orderList=$orderList');
    DebugConfig.print('VIEW_OPTION: visibilityList=$visibilityList');

    await prefs.setStringList('chart_order_${_userId!}', orderList);
    await prefs.setStringList('chart_visibility_${_userId!}', visibilityList);
  }

  Future<void> _saveChartPeriod(String chartId, String period) async {
    if (_userId == null) return;
    final keyPrefix = _periodKeyForChart(chartId);
    if (keyPrefix == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${keyPrefix}_period_${_userId!}', period);
  }

  Future<void> _showPeriodDialog(String chartId) async {
    final currentPeriod =
        _chartPeriods[chartId] ?? _defaultPeriods[chartId] ?? 'Μήνας';

    final brightness = Theme.of(context).brightness;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ColorsUI.getSurface(brightness),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Επιλογή Περιόδου',
          style: TypographyUI.titleMedium(brightness),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _periodOptions.map((p) {
            final isSelected = p == currentPeriod;
            return Semantics(
              button: true,
              label: 'Επιλογή περιόδου $p',
              selected: isSelected,
              child: InkWell(
                onTap: () => Navigator.pop(context, p),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ColorsUI.getPrimary(
                            brightness,
                          ).withValues(alpha: 0.15)
                        : ColorsUI.getSurface(brightness),
                    border: Border.all(
                      color: isSelected
                          ? ColorsUI.getPrimary(brightness)
                          : ColorsUI.getBorder(brightness),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? ColorsUI.getPrimary(brightness)
                              : ColorsUI.getTextSecondary(brightness),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        p,
                        style: TypographyUI.bodyMedium(brightness).copyWith(
                          color: isSelected
                              ? ColorsUI.getPrimary(brightness)
                              : ColorsUI.getTextPrimary(brightness),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Ακύρωση',
              style: TypographyUI.labelLarge(
                brightness,
              ).copyWith(color: ColorsUI.getPrimary(brightness)),
            ),
          ),
        ],
      ),
    );

    if (result != null && result != currentPeriod) {
      setState(() {
        _chartPeriods[chartId] = result;
      });
      await _saveChartPeriod(chartId, result);
      AccessibilityService.announceSuccess('Η περίοδος άλλαξε σε $result');
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Διάταξη Γραφημάτων',
          // Επιβάλλουμε το χρώμα απευθείας στο στυλ του κειμένου
          style: TextStyle(color: ColorsUI.getOnPrimary(brightness)),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: ColorsUI.getPrimary(brightness),

        // Επιβάλλουμε το χρώμα ρητά στο IconTheme για το back arrow
        iconTheme: IconThemeData(color: ColorsUI.getOnPrimary(brightness)),

        // Κρατάμε και αυτό για σιγουριά σε μελλοντικά στοιχεία
        foregroundColor: ColorsUI.getOnPrimary(brightness),
      ),
      backgroundColor: ColorsUI.getBackground(brightness),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: charts.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = charts.removeAt(oldIndex);
                  charts.insert(newIndex, item);
                });
                _saveOrderAndVisibilityOnly();
                AccessibilityService.announcePolite('Σειρά γραφημάτων άλλαξε');
              },
              itemBuilder: (context, index) {
                final chart = charts[index];
                final chartId = chart['id'] as String;
                final meta = chartMeta[chartId] ?? {};
                final color = chartColors[chartId] ?? Colors.grey;
                final hasPeriod = _periodKeyForChart(chartId) != null;
                final selectedPeriod = hasPeriod
                    ? _chartPeriods[chartId]
                    : null;

                return KeyedSubtree(
                  key: ValueKey(chartId),
                  child: Semantics(
                    container: true,
                    label: meta['title'] ?? chart['name'],
                    // ΔΙΟΡΘΩΣΗ: Χρησιμοποιούμε τη σωστή σύνταξη για το Map
                    customSemanticsActions: {
                      if (index > 0)
                        const CustomSemanticsAction(
                          label: 'Μετακίνηση πάνω',
                        ): () {
                          _moveItem(index, index - 1);
                        },
                      if (index < charts.length - 1)
                        const CustomSemanticsAction(
                          label: 'Μετακίνηση κάτω',
                        ): () {
                          _moveItem(index, index + 1);
                        },
                    },
                    child: Card(
                      color: ColorsUI.getSurface(brightness),
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: ColorsUI.getBorder(brightness)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 12,
                        ),
                        leading: Semantics(
                          button: false,
                          label: 'Λαβή μετακίνησης για ${meta['title']}',
                          hint: 'Σύρετε για αλλαγή σειράς',
                          child: ReorderableDragStartListener(
                            index: index,
                            child: Icon(
                              Icons.drag_handle,
                              color: color.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                meta['icon'] ?? Icons.insert_chart,
                                color: color.withValues(alpha: 0.8),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                meta['title'] ?? chart['name'],
                                style: TypographyUI.bodyLarge(
                                  brightness,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        subtitle: hasPeriod && selectedPeriod != null
                            ? Padding(
                                padding: const EdgeInsets.only(
                                  top: 4.0,
                                  left: 2.0,
                                ),
                                child: Text(
                                  'Προεπιλεγμένη περίοδος: $selectedPeriod',
                                  style: TypographyUI.bodySmall(brightness)
                                      .copyWith(
                                        color: ColorsUI.getTextSecondary(
                                          brightness,
                                        ),
                                      ),
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Visibility toggle
                            Semantics(
                              container: true,
                              label: 'Ορατότητα γραφήματος ${meta['title']}',
                              hint: chart['visible']
                                  ? 'Το γράφημα εμφανίζεται. Πατήστε για απενεργοποίηση.'
                                  : 'Το γράφημα είναι κρυφό. Πατήστε για ενεργοποίηση.',
                              child: Transform.scale(
                                scale: 0.85,
                                child: Switch.adaptive(
                                  value: chart['visible'],
                                  activeThumbColor: color.withValues(
                                    alpha: 0.9,
                                  ),
                                  activeTrackColor: color.withValues(
                                    alpha: 0.4,
                                  ),
                                  onChanged: (val) {
                                    setState(() => chart['visible'] = val);
                                    _saveOrderAndVisibilityOnly();

                                    AccessibilityService.announcePolite(
                                      val
                                          ? '${meta['title']} ενεργοποιήθηκε'
                                          : '${meta['title']} απενεργοποιήθηκε',
                                    );
                                  },
                                ),
                              ),
                            ),

                            // Period settings (if applicable)
                            if (hasPeriod) ...[
                              const SizedBox(width: 4),
                              Semantics(
                                button: true,
                                label: 'Ρυθμίσεις περιόδου για ${meta['title']}',
                                excludeSemantics: true,
                                child: IconButton(
                                  icon: const ExcludeSemantics(child: Icon(Icons.more_vert, size: 22)),
                                  onPressed: () => _showPeriodDialog(chartId),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Save button
          Padding(
            padding: EdgeInsets.only(
              bottom: 32.0 + MediaQuery.of(context).padding.bottom,
              top: 8,
            ),
            child: Semantics(
              button: true,
              label: 'Αποθήκευση και επιστροφή',
              hint: 'Αποθηκεύει τις ρυθμίσεις και επιστρέφει στην προηγούμενη σελίδα',
              excludeSemantics: true,
              child: ElevatedButton.icon(
                icon: const ExcludeSemantics(child: Icon(Icons.save)),
                label: const Text(
                  'Αποθήκευση & Επιστροφή',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorsUI.getPrimary(brightness),
                  foregroundColor: brightness == Brightness.light
                      ? Colors.white
                      : Colors.black,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                ),
                onPressed: () async {
                  DebugConfig.print('VIEW_OPTION: Save button pressed');

                  await _savePreferences();
                  DebugConfig.print('VIEW_OPTION: Preferences saved');

                  AccessibilityService.announceSuccess(
                    'Οι ρυθμίσεις αποθηκεύτηκαν',
                  );

                  await Future.delayed(const Duration(milliseconds: 250));

                  if (!context.mounted) {
                    DebugConfig.print(
                      'VIEW_OPTION: context not mounted, abort',
                    );
                    return;
                  }

                  DebugConfig.print('VIEW_OPTION: popping now...');
                  Navigator.pop(context, true);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
