// ============================================================
// FILE: graf_7_monthly_trend_page.dart
// PURPOSE: Πορεία ανά μήνα (1/1 τρέχοντος έτους) — μία μπλε γραμμή
// Location: lib/presentation/screens/charts/graf_7_monthly_trend_page.dart
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';
import 'package:family_economy/core/utils/chart_helpers.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/core/utils/monthly_trend.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';

class Graf7MonthlyTrendPage extends StatefulWidget {
  const Graf7MonthlyTrendPage({super.key});

  @override
  State<Graf7MonthlyTrendPage> createState() => _Graf7MonthlyTrendPageState();
}

class _Graf7MonthlyTrendPageState extends State<Graf7MonthlyTrendPage> {
  static const String _periodKey = 'YEAR_TREND';

  String _movementType = 'expense'; // 'income' | 'expense'
  String? _selectedCategoryUuid;
  String _selectedCategoryName = '';
  String? _selectedSubcategoryUuid;
  Timer? _debounceTimer;
  String? _lastAnnouncement;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final categoriesP = context.read<CategoriesProvider>();
    await categoriesP.firstLoad;
    if (!mounted) return;
    _initDefaultCategory();
    await _loadYear();
  }

  void _initDefaultCategory() {
    final categoriesP = context.read<CategoriesProvider>();
    final list = categoriesP.getCategoriesByType(_movementType);
    if (list.isEmpty) {
      setState(() {
        _selectedCategoryUuid = null;
        _selectedCategoryName = '';
        _selectedSubcategoryUuid = null;
      });
      return;
    }
    CategoryModel? def;
    if (_movementType == 'expense') {
      try {
        def = list.firstWhere((c) => c.name.toLowerCase() == 'διατροφή');
      } catch (_) {
        def = null;
      }
    }
    def ??= list.firstWhere(
      (c) => categoriesP.getSubcategoriesForCategory(c.uuid).isNotEmpty,
      orElse: () => list.first,
    );
    setState(() {
      _selectedCategoryUuid = def!.uuid;
      _selectedCategoryName = def.name;
      _selectedSubcategoryUuid = null;
    });
    DebugConfig.print('GRAF7 ✅ default category: $_selectedCategoryName ($_movementType)');
  }

  Future<void> _loadYear() async {
    if (!mounted) return;
    if (_selectedCategoryUuid == null) {
      _initDefaultCategory();
      if (_selectedCategoryUuid == null) return;
    }
    DebugConfig.print('GRAF7 ▶️ load start YEAR_TREND type=$_movementType');
    try {
      final tp = context.read<TransactionsProvider>();
      final cp = context.read<CategoriesProvider>();
      await cp.firstLoad;
      if (!mounted) return;
      if (cp.error != null) {
        DebugConfig.print('GRAF7 ❌ categories error: ${cp.error}');
        _announceError();
        return;
      }
      final range = ChartHelpers.getDateRange('Έτος');
      final start = DateTime.parse(range['start']!);
      final end = DateTime.parse(range['end']!);
      DebugConfig.print('GRAF7 📅 yearRange=${range['start']}..${range['end']}');
      await tp.loadPeriod(_periodKey, start, end);
      DebugConfig.print('GRAF7 ✅ TP.loadPeriod finished docs=${tp.getTransactionsForPeriod(_periodKey).length}');
      if (mounted) {
        final m = _computeMonthly(tp);
        final total = m.fold(0.0, (a, b) => a + b.value);
        DebugConfig.print('GRAF7 💰 total=${total.toStringAsFixed(2)} cat=$_selectedCategoryName sub=$_selectedSubcategoryUuid');
        _announceDataUpdate(total);
      }
    } catch (e) {
      DebugConfig.print('GRAF7 ❌ exception: $e');
      if (mounted) _announceError();
    }
  }

  void _onMovementChanged(String v) {
    if (v == _movementType) return;
    setState(() {
      _movementType = v;
      _selectedCategoryUuid = null;
      _selectedSubcategoryUuid = null;
    });
    AccessibilityService.announcePolite(v == 'income' ? 'Επιλέχθηκαν έσοδα' : 'Επιλέχθηκαν έξοδα');
    DebugConfig.print('GRAF7 🔄 movement changed to: $v');
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _initDefaultCategory();
      _loadYear();
    });
  }

  void _onCategoryChanged(String? uuid) {
    if (uuid == null || uuid == _selectedCategoryUuid) return;
    final cp = context.read<CategoriesProvider>();
    final cat = cp.getCategoryByUuid(uuid);
    setState(() {
      _selectedCategoryUuid = uuid;
      _selectedCategoryName = cat?.name ?? '';
      _selectedSubcategoryUuid = null;
    });
    AccessibilityService.announcePolite('Επιλέχθηκε κατηγορία $_selectedCategoryName');
    DebugConfig.print('GRAF7 🔄 category changed to: $_selectedCategoryName');
  }

  void _onSubChanged(String? uuidOrNull) {
    setState(() => _selectedSubcategoryUuid = uuidOrNull);
    DebugConfig.print('GRAF7 🔄 subcategory changed to: $uuidOrNull');
  }

  List<MonthlyPoint> _computeMonthly(TransactionsProvider tp) {
    return computeMonthlyTrend(
      transactions: tp.getTransactionsForPeriod(_periodKey),
      year: DateTime.now().year,
      categoryId: _selectedCategoryUuid,
      subcategoryId: _selectedSubcategoryUuid,
    );
  }

  void _announceDataUpdate(double total) {
    if (total <= 0) {
      final a = 'Δεν βρέθηκαν κινήσεις για $_selectedCategoryName από την αρχή του έτους';
      if (_lastAnnouncement != a) {
        _lastAnnouncement = a;
        AccessibilityService.announcePolite(a);
      }
      return;
    }
    final a = 'Πορεία ενημερώθηκε. Σύνολο έτους: ${ChartHelpers.formatMoney(total)}.';
    if (_lastAnnouncement != a) {
      _lastAnnouncement = a;
      AccessibilityService.announcePolite(a);
    }
  }

  void _announceError() {
    AccessibilityService.announceError('Σφάλμα φόρτωσης πορείας');
  }

  String _pctText(double? pct) => pct == null ? '—' : '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
  Color _pctColor(double? pct, Brightness b) {
    final up = (pct ?? 0) >= 0;
    if (_movementType == 'expense') return up ? ColorsUI.getError(b) : ColorsUI.getSuccess(b);
    return up ? ColorsUI.getSuccess(b) : ColorsUI.getError(b);
  }

  static const _months = ['Ιαν', 'Φεβ', 'Μαρ', 'Απρ', 'Μάι', 'Ιουν', 'Ιουλ', 'Αυγ', 'Σεπ', 'Οκτ', 'Νοε', 'Δεκ'];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tp = context.watch<TransactionsProvider>();
    context.watch<CategoriesProvider>();
    if (tp.isLoadingPeriod(_periodKey)) {
      return Semantics(
        label: 'Φόρτωση πορείας ανά μήνα',
        liveRegion: true,
        excludeSemantics: true,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: ExcludeSemantics(child: CircularProgressIndicator())),
        ),
      );
    }
    final monthly = _computeMonthly(tp);
    final total = monthly.fold(0.0, (a, b) => a + b.value);
    final hasData = total > 0;
    return Semantics(
      container: true,
      label: 'Πορεία ανά μήνα για $_selectedCategoryName',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggle(brightness),
          const SizedBox(height: 8),
          _buildDropdowns(brightness),
          const SizedBox(height: 8),
          if (!hasData) _buildEmpty(brightness) else _buildChart(brightness, monthly, total),
        ],
      ),
    );
  }

  Widget _buildToggle(Brightness b) {
    return Semantics(
      label: 'Επιλογή τύπου πορείας. Τρέχον: ${_movementType == 'income' ? 'Έσοδα' : 'Έξοδα'}',
      child: Center(
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'income', label: Text('Έσοδα'), icon: Icon(Icons.trending_up, size: 16)),
            ButtonSegment(value: 'expense', label: Text('Έξοδα'), icon: Icon(Icons.trending_down, size: 16)),
          ],
          selected: {_movementType},
          onSelectionChanged: (s) => _onMovementChanged(s.first),
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ),
    );
  }

  Widget _buildDropdowns(Brightness b) {
    final cp = context.watch<CategoriesProvider>();
    final cats = cp.getCategoriesByType(_movementType);
    final subs = _selectedCategoryUuid == null ? <SubcategoryModel>[] : cp.getSubcategoriesForCategory(_selectedCategoryUuid!);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Επιλογή κατηγορίας. Τρέχουσα: $_selectedCategoryName',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ColorsUI.getSurface(b),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorsUI.getBorder(b)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategoryUuid,
                  isExpanded: true,
                  hint: const Text('Κατηγορία'),
                  items: cats.map((c) => DropdownMenuItem(value: c.uuid, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _onCategoryChanged,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            label: 'Επιλογή υποκατηγορίας',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ColorsUI.getSurface(b),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorsUI.getBorder(b)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedSubcategoryUuid,
                  isExpanded: true,
                  hint: const Text('Καμία'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Καμία')),
                    ...subs.map((s) => DropdownMenuItem<String?>(value: s.uuid, child: Text(s.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: cats.isEmpty ? null : _onSubChanged,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(Brightness b) {
    return Semantics(
      label: 'Δεν υπάρχουν κινήσεις',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: Icon(Icons.show_chart, size: 48, color: ColorsUI.getTextSecondary(b))),
              const SizedBox(height: 8),
              ExcludeSemantics(child: Text('Δεν βρέθηκαν κινήσεις για $_selectedCategoryName από την αρχή του έτους', style: TypographyUI.bodyMedium(b), textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(Brightness b, List<MonthlyPoint> monthly, double total) {
    final lineColor = ColorsUI.getInfo(b);
    final spots = [for (final m in monthly) FlSpot(m.index.toDouble(), m.value)];
    final maxV = monthly.map((m) => m.value).fold(0.0, (a, v) => v > a ? v : a);
    final maxY = maxV <= 0 ? 100.0 : maxV * 1.7;
    final curIdx = DateTime.now().month - 1;
    final amountColor = ColorsUI.getTextPrimary(b);
    final barData = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      barWidth: 3,
      color: lineColor,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, _, bar, index) => _LabelDotPainter(
          lineColor, monthly[index].value, monthly[index].pct,
          _pctColor(monthly[index].pct, b), amountColor, index <= curIdx,
        ),
      ),
      belowBarData: BarAreaData(show: true, color: lineColor.withValues(alpha: 0.15)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxWidth < 400 ? 240.0 : 280.0;
        final w = constraints.maxWidth <= 0 ? 600.0 : (constraints.maxWidth < 600 ? 600.0 : constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Γράφημα πορείας. Σύνολο έτους ${ChartHelpers.formatMoney(total)}.',
              child: ExcludeSemantics(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: LineChart(
                      LineChartData(
                        clipData: const FlClipData.none(),
                        minX: 0,
                        maxX: 11,
                        minY: 0,
                        maxY: maxY,
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 56,
                              getTitlesWidget: (v, _) => Text(CurrencyFormatter.formatCompact(v), style: TypographyUI.labelSmall(b)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                final i = v.round();
                                if (i < 0 || i > 11) return const SizedBox.shrink();
                                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(_months[i], style: TypographyUI.labelSmall(b)));
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [barData],
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            maxContentWidth: 140,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItems: (touched) => touched.map((s) {
                              final m = monthly[s.spotIndex];
                              final pct = _pctText(m.pct);
                              return LineTooltipItem(
                                '${ChartHelpers.formatMoney(m.value)}\n',
                                TypographyUI.labelSmall(b).copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                children: [TextSpan(text: pct, style: TextStyle(color: _pctColor(m.pct, b), fontSize: 11, fontWeight: FontWeight.w600))],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: lineColor, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Σύνολο έτους: ${ChartHelpers.formatMoney(total)}', style: TypographyUI.bodySmall(b).copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LabelDotPainter extends FlDotPainter {
  final Color dotColor;
  final double value;
  final double? pct;
  final Color pctColor;
  final Color amountColor;
  final bool showLabel;
  const _LabelDotPainter(this.dotColor, this.value, this.pct, this.pctColor, this.amountColor, this.showLabel);
  @override
  void draw(Canvas canvas, FlSpot spot, Offset o) {
    canvas.drawCircle(o, 3.5, Paint()..color = dotColor);
    if (!showLabel) return;
    final tp = TextPainter(
      text: TextSpan(
        text: '${ChartHelpers.formatMoney(value)}\n',
        style: TextStyle(fontSize: 10, color: amountColor),
        children: [TextSpan(text: _s(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pctColor))],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy - tp.height - 8));
  }
  String _s() => pct == null ? '—' : '${pct! >= 0 ? '+' : ''}${pct!.toStringAsFixed(1)}%';
  @override
  Size getSize(FlSpot spot) => const Size(48, 44);
  @override
  Color get mainColor => dotColor;
  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;
  @override
  List<Object?> get props => [dotColor, value, pct, pctColor, showLabel];
}
