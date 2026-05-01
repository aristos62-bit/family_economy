// ============================================================
// FILE: stats3_page.dart
// Path: lib/presentation/screens/stats/stats3_page.dart
// Συνολικά Έσοδα / Έξοδα ανά Μήνα (πίνακας έτους)
// ✅ UTF-8 | Providers | Offline-safe | Accessibility | Dark mode
// ✅ Export Excel + PDF | Responsive | SessionScope
// ============================================================

import 'dart:async';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';

import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';

// ─────────────────────────────────────────────
// Data model για κάθε μήνα
// ─────────────────────────────────────────────
class _MonthRow {
  final int month; // 1..12
  final double expenses; // ΕΞΟΔΑ
  final double income; // ΕΣΟΔΑ

  const _MonthRow({
    required this.month,
    required this.expenses,
    required this.income,
  });

  /// Διαφορά = ΕΣΟΔΑ − ΕΞΟΔΑ  (θετικό = καλό, income > expenses)
  double get diff => income - expenses;

  /// Ποσοστό = (ΕΞΟΔΑ − ΕΣΟΔΑ) / ΕΣΟΔΑ × 100
  /// αρνητικό  → income > expenses (καλό) → εμφανίζεται κόκκινο
  /// θετικό    → expenses > income (κακό) → εμφανίζεται πράσινο (highlight)
  double get pct => income == 0 ? 0 : (income - expenses) / income * 100;

  /// Υπερβαίνουν τα έξοδα τα έσοδα;
  bool get isOverBudget => expenses > income;
}

// ─────────────────────────────────────────────
// Ελληνικά ονόματα μηνών (ΚΕΦΑΛΑΙΑ)
// ─────────────────────────────────────────────
const List<String> _kMonthNames = [
  'Ιανουάριος',
  'Φεβρουάριος',
  'Μάρτιος',
  'Απρίλιος',
  'Μάϊος',
  'Ιούνιος',
  'Ιούλιος',
  'Αύγουστος',
  'Σεπτέμβριος',
  'Οκτώβριος',
  'Νοέμβριος',
  'Δεκέμβριος',
];

// ─────────────────────────────────────────────
// Σελίδα
// ─────────────────────────────────────────────
class Stats3Page extends StatefulWidget {
  const Stats3Page({super.key});

  @override
  State<Stats3Page> createState() => _Stats3PageState();
}

class _Stats3PageState extends State<Stats3Page> {
  // ── STATE ──────────────────────────────────
  int _selectedYear = DateTime.now().year;

  static const String _periodKeyPrefix = 'STATS3_YEAR_';
  String get _periodKey => '$_periodKeyPrefix$_selectedYear';

  bool _loadScheduled = false;
  int? _loadedYear;

  // Τελευταίοι υπολογισμοί (για export)
  List<_MonthRow> _lastRows = [];
  int? _lastExportYear;

  // ── INIT ──────────────────────────────────
  @override
  void initState() {
    super.initState();
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Συνολικά Έσοδα και Έξοδα ανά Μήνα. '
      'Πίνακας ετήσιων στοιχείων.',
    );
  }

  // ── HELPERS: date range for full year ─────
  DateTime get _yearStart => DateTime(_selectedYear, 1, 1, 0, 0, 0);
  DateTime get _yearEnd => DateTime(_selectedYear, 12, 31, 23, 59, 59);

  // ── OFFLINE-SAFE: ensure listener ──────────
  // ── OFFLINE-SAFE: ensure listener for selected year ──────────
  void _ensureListener(TransactionsProvider transactionsP) {
    final yearChanged = _loadedYear != _selectedYear;
    if (!yearChanged || _loadScheduled) return;

    _loadScheduled = true;
    _loadedYear = _selectedYear;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!mounted) return;
      transactionsP.loadPeriod(_periodKey, _yearStart, _yearEnd);
    });
  }

  // ── YEAR NAV ──────────────────────────────
  void _prevYear() {
    setState(() {
      _selectedYear--;
      _loadedYear = null; // force reload
    });
  }

  void _nextYear() {
    final now = DateTime.now();
    if (_selectedYear >= now.year) return;
    setState(() {
      _selectedYear++;
      _loadedYear = null;
    });
  }

  // ── COMPUTE per-month rows ─────────────────
  List<_MonthRow> _computeRows(
      TransactionsProvider transP,
      CategoriesProvider catP,
      ) {
    final allTxs = transP.getTransactionsForPeriod(_periodKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); // μηδενίζει την ώρα

    final rows = <_MonthRow>[];
    for (int m = 1; m <= 12; m++) {
      double totalExpenses = 0;
      double totalIncome = 0;

      for (final t in allTxs) {
        if (t.date.year != _selectedYear || t.date.month != m) continue;

        // ---------- ΠΡΟΣΘΗΚΗ: Εξαίρεση μελλοντικών κινήσεων ----------
        if (t.date.isAfter(today)) continue;
        // -----------------------------------------------------------

        if (t.isTransfer) continue;

        final catId = t.categoryId;
        if (catId == null) continue;

        final cat = catP.getCategoryByUuid(catId);
        if (cat == null) continue;

        if (cat.type == 'income') {
          totalIncome += t.amount.abs();
        } else if (cat.type == 'expense') {
          totalExpenses += t.amount.abs();
        }
      }

      rows.add(
        _MonthRow(month: m, expenses: totalExpenses, income: totalIncome),
      );
    }
    return rows;
  }

  // ── FORMAT helpers ─────────────────────────
  String _fmtAmt(double v) => CurrencyFormatter.format(v);

  String _fmtPct(double v) {
    final sign = v >= 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(2)}%';
  }

  // ── BUILD ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Χρήση session (mandatory)
    final _ = context.session.userId;

    return Consumer2<CategoriesProvider, TransactionsProvider>(
      builder: (context, catP, transP, _) {
        // ── offline-safe listener ──
        _ensureListener(transP);

        final isLoading = transP.isLoadingPeriod(_periodKey);
        final hasError = transP.getErrorForPeriod(_periodKey) != null;
        final errorMsg = transP.getErrorForPeriod(_periodKey) ?? '';

        final rows = _computeRows(transP, catP);
        _lastRows = rows;
        _lastExportYear = _selectedYear;

        // Totals
        final totalExpenses = rows.fold(0.0, (s, r) => s + r.expenses);
        final totalIncome = rows.fold(0.0, (s, r) => s + r.income);
        final totalDiff = totalIncome - totalExpenses;
        final totalPct = totalIncome == 0
            ? 0.0
            : (totalIncome - totalExpenses) / totalIncome * 100;

        return Scaffold(
          backgroundColor: context.cBg,
          body: SafeArea(
            child: Column(
              children: [
                // ── HEADER ────────────────────────────
                _buildHeader(),

                // ── YEAR SELECTOR ─────────────────────
                _buildYearSelector(),

                // ── OFFLINE / ERROR banner ─────────────
                if (hasError) _buildErrorBanner(errorMsg),

                // ── CONTENT ───────────────────────────
                Expanded(
                  child:
                      isLoading &&
                          rows.every((r) => r.expenses == 0 && r.income == 0)
                      ? _buildLoading()
                      : _buildTable(
                          rows: rows,
                          totalExpenses: totalExpenses,
                          totalIncome: totalIncome,
                          totalDiff: totalDiff,
                          totalPct: totalPct.toDouble(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── HEADER ──────────────────────────────────
  Widget _buildHeader() {
    return Semantics(
      header: true,
      label: 'Σύνολα εσόδων εξόδων ανά μήνα',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: context.cPrimary,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            // back
            Semantics(
              button: true,
              label: 'Πίσω',
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.cOnPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.arrow_back,
                      color: context.cOnPrimary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Σύνολα ανά Μήνα',
                style: TextStyle(
                  color: context.cOnPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            // Export actions
            Semantics(
              button: true,
              label: 'Εξαγωγή σε Excel',
              child: IconButton(
                icon: ExcludeSemantics(
                  child: Icon(Icons.table_chart, color: context.cOnPrimary),
                ),
                tooltip: 'Εξαγωγή Excel',
                onPressed: _exportToExcel,
              ),
            ),
            Semantics(
              button: true,
              label: 'Εξαγωγή σε PDF',
              child: IconButton(
                icon: ExcludeSemantics(
                  child: Icon(Icons.picture_as_pdf, color: context.cOnPrimary),
                ),
                tooltip: 'Εξαγωγή PDF',
                onPressed: _exportToPdf,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── YEAR SELECTOR ────────────────────────────
  Widget _buildYearSelector() {
    final now = DateTime.now();
    final canNext = _selectedYear < now.year;

    return Semantics(
      label: 'Επιλογή έτους: $_selectedYear',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              button: true,
              label: 'Προηγούμενο έτος',
              child: IconButton(
                icon: ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_left,
                    color: context.cPrimary,
                    size: 32,
                  ),
                ),
                onPressed: _prevYear,
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              liveRegion: true,
              label: 'Επιλεγμένο έτος: $_selectedYear',
              child: ExcludeSemantics(
                child: Text(
                  '$_selectedYear',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.cText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Επόμενο έτος',
              enabled: canNext,
              child: IconButton(
                icon: ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: canNext
                        ? context.cPrimary
                        : context.cText2.withValues(alpha: 0.3),
                    size: 32,
                  ),
                ),
                onPressed: canNext ? _nextYear : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ERROR BANNER ─────────────────────────────
  Widget _buildErrorBanner(String msg) {
    return Semantics(
      liveRegion: true,
      label: 'Σφάλμα φόρτωσης: $msg',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.wifi_off, color: Colors.orange, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Offline mode – τα δεδομένα ενδέχεται να μην είναι ενημερωμένα.',
                style: TextStyle(color: context.cText2, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── LOADING ──────────────────────────────────
  Widget _buildLoading() {
    return Semantics(
      liveRegion: true,
      label: 'Φόρτωση δεδομένων. Παρακαλώ περιμένετε.',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: CircularProgressIndicator(color: context.cPrimary),
            ),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Text(
                'Φόρτωση δεδομένων...',
                style: TextStyle(color: context.cText2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TABLE ─────────────────────────────────────
  Widget _buildTable({
    required List<_MonthRow> rows,
    required double totalExpenses,
    required double totalIncome,
    required double totalDiff,
    required double totalPct,
  }) {
    // Χρώματα header (ακολουθεί screenshot: σκούρο/σκιασμένο)
    final headerBg = context.cPrimary;
    final headerFg = context.cOnPrimary;
    final surfaceBg = context.cSurface;
    final textColor = context.cText;
    final text2Color = context.cText2;
    final isDark = context.brightness == Brightness.dark;

    // Χρώματα γραμμών
    Color rowOverBudgetBg = isDark
        ? const Color(0xFF1B5E20).withValues(alpha: 0.35)
        : const Color(0xFFE8F5E9);
    Color rowNormalBg = isDark ? context.cSurface : Colors.white;
    Color rowAltBg = isDark
        ? context.cSurface.withValues(alpha: 0.7)
        : const Color(0xFFF8F8FB);

    // Χρώματα για διαφορά / ποσοστό
    Color colorPositiveDiff = ColorsUI.incomeLight; // income > expenses (καλό)
    Color colorNegativeDiff = ColorsUI.expenseLight; // expenses > income (κακό)
    if (isDark) {
      colorPositiveDiff = ColorsUI.incomeDark;
      colorNegativeDiff = ColorsUI.expenseDark;
    }

    // Totals row χρώμα
    final totalRowBg = isDark
        ? context.cPrimary.withValues(alpha: 0.25)
        : context.cPrimary.withValues(alpha: 0.12);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Card(
          elevation: 3,
          color: surfaceBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                // ── ΤΙΤΛΟΣ ΠΙΝΑΚΑ ──────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      'ΣΥΝΟΛΑ ΑΝΑ ΜΗΝΑ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: textColor,
                      ),
                    ),
                  ),
                ),

                // ── HORIZONTAL SCROLL για responsive ──
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 32,
                    ),
                    child: Table(
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: text2Color.withValues(alpha: 0.18),
                          width: 0.8,
                        ),
                        verticalInside: BorderSide(
                          color: text2Color.withValues(alpha: 0.12),
                          width: 0.5,
                        ),
                        top: BorderSide(
                          color: text2Color.withValues(alpha: 0.30),
                          width: 1,
                        ),
                        bottom: BorderSide(
                          color: text2Color.withValues(alpha: 0.30),
                          width: 1,
                        ),
                        left: BorderSide(
                          color: text2Color.withValues(alpha: 0.20),
                          width: 0.8,
                        ),
                        right: BorderSide(
                          color: text2Color.withValues(alpha: 0.20),
                          width: 0.8,
                        ),
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(2.0), // Μήνας
                        1: FlexColumnWidth(2.0), // ΕΞΟΔΑ
                        2: FlexColumnWidth(2.0), // ΕΣΟΔΑ
                        3: FlexColumnWidth(1.8), // Διαφορά €
                        4: FlexColumnWidth(1.4), // Ποσοστό
                      },
                      children: [
                        // ── HEADER ROW ─────────────────
                        TableRow(
                          decoration: BoxDecoration(color: headerBg),
                          children: [
                            _headerCell(
                              '',
                              fg: headerFg,
                              align: TextAlign.left,
                            ),
                            _headerCell('ΕΞΟΔΑ', fg: headerFg),
                            _headerCell('ΕΣΟΔΑ', fg: headerFg),
                            _headerCell('Διαφορά', fg: headerFg),
                            _headerCell('%', fg: headerFg),
                          ],
                        ),

                        // ── MONTH ROWS ─────────────────
                        for (int i = 0; i < rows.length; i++) ...[
                          _buildMonthTableRow(
                            row: rows[i],
                            rowBg: rows[i].isOverBudget
                                ? rowOverBudgetBg
                                : (i % 2 == 0 ? rowNormalBg : rowAltBg),
                            textColor: textColor,
                            colorPositiveDiff: colorPositiveDiff,
                            colorNegativeDiff: colorNegativeDiff,
                          ),
                        ],

                        // ── TOTAL ROW ──────────────────
                        _buildTotalTableRow(
                          totalExpenses: totalExpenses,
                          totalIncome: totalIncome,
                          totalDiff: totalDiff,
                          totalPct: totalPct,
                          bg: totalRowBg,
                          textColor: textColor,
                          colorPositiveDiff: colorPositiveDiff,
                          colorNegativeDiff: colorNegativeDiff,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── LEGEND ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Semantics(
                        label: 'Χρωματική ένδειξη: Έξοδα μεγαλύτερα από Έσοδα (υπέρβαση)',
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: rowOverBudgetBg,
                                  border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.5),
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Έξοδα > Έσοδα (υπέρβαση)',
                                style: TextStyle(fontSize: 11, color: text2Color),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Semantics(
                        label: 'Χρωματική ένδειξη: Αρνητικό υπόλοιπο',
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: colorNegativeDiff.withValues(alpha: 0.18),
                                  border: Border.all(
                                    color: colorNegativeDiff.withValues(alpha: 0.5),
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Αρνητικό υπόλοιπο',
                                style: TextStyle(fontSize: 11, color: text2Color),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── EXPORT BUTTONS ──────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Εξαγωγή σε Excel',
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF217346),
                              side: const BorderSide(
                                color: Color(0xFF217346),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const ExcludeSemantics(
                              child: Icon(Icons.table_chart, size: 20),
                            ),
                            label: const Text(
                              'Excel',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: _exportToExcel,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Εξαγωγή σε PDF',
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFC62828),
                              side: const BorderSide(
                                color: Color(0xFFC62828),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const ExcludeSemantics(
                              child: Icon(Icons.picture_as_pdf, size: 20),
                            ),
                            label: const Text(
                              'PDF',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: _exportToPdf,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header cell helper ────────────────────────
  Widget _headerCell(
    String text, {
    required Color fg,
    TextAlign align = TextAlign.center,
  }) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // ── Month data row ─────────────────────────────
  // ── Month data row ─────────────────────────────
  TableRow _buildMonthTableRow({
    required _MonthRow row,
    required Color rowBg,
    required Color textColor,
    required Color colorPositiveDiff,
    required Color colorNegativeDiff,
  }) {
    final diffColor = row.diff >= 0 ? colorPositiveDiff : colorNegativeDiff;
    final pctColor = row.pct >= 0
        ? colorPositiveDiff // πράσινο όταν είναι θετικό
        : colorNegativeDiff; // κόκκινο όταν είναι αρνητικό
    final diffStr = row.expenses == 0 && row.income == 0
        ? '—'
        : _fmtAmt(row.diff);
    final pctStr = row.expenses == 0 && row.income == 0
        ? '—'
        : _fmtPct(row.pct);

    return TableRow(
      decoration: BoxDecoration(color: rowBg),
      children: [
        // Μήνας
        // Μήνας
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Semantics(
            label: 'Μήνας: ${_kMonthNames[row.month - 1]}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                child: Text(
                  _kMonthNames[row.month - 1],
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),

        // ΕΞΟΔΑ
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Semantics(
            label: 'Έξοδα: ${_fmtAmt(row.expenses)}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                child: Text(
                  _fmtAmt(row.expenses),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: textColor, fontSize: 12),
                ),
              ),
            ),
          ),
        ),

        // ΕΣΟΔΑ
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Semantics(
            label: 'Έσοδα: ${_fmtAmt(row.income)}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                child: Text(
                  _fmtAmt(row.income),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: textColor, fontSize: 12),
                ),
              ),
            ),
          ),
        ),

        // Διαφορά €
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Semantics(
            label: 'Διαφορά: $diffStr',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    diffStr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: diffColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Ποσοστό
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Semantics(
            label: 'Ποσοστό: $pctStr',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                child: Text(
                  pctStr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: pctColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Totals row ─────────────────────────────────
  // ── Totals row ─────────────────────────────────
  TableRow _buildTotalTableRow({
    required double totalExpenses,
    required double totalIncome,
    required double totalDiff,
    required double totalPct,
    required Color bg,
    required Color textColor,
    required Color colorPositiveDiff,
    required Color colorNegativeDiff,
  }) {
    final diffColor = totalDiff >= 0 ? colorPositiveDiff : colorNegativeDiff;
    final pctColor = totalPct >= 0
        ? colorPositiveDiff // πράσινο
        : colorNegativeDiff; // κόκκινο

    return TableRow(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: context.cPrimary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
      ),
      children: [
        // Label ΣΥΝΟΛΟ
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(
              'ΣΥΝΟΛΟ',
              style: TextStyle(
                color: context.cPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),

        // ΕΞΟΔΑ total
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Semantics(
            label: 'Σύνολο εξόδων: ${_fmtAmt(totalExpenses)}',
    child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Text(
                _fmtAmt(totalExpenses),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ),
        ),

        // ΕΣΟΔΑ total
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Semantics(
            label: 'Σύνολο εσόδων: ${_fmtAmt(totalIncome)}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: Text(
                  _fmtAmt(totalIncome),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Διαφορά total
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Semantics(
            label: 'Σύνολο διαφοράς: ${_fmtAmt(totalDiff)}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: diffColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    _fmtAmt(totalDiff),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: diffColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Ποσοστό total
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Semantics(
            label: 'Σύνολο ποσοστό: ${_fmtPct(totalPct)}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: Text(
                  _fmtPct(totalPct),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: pctColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // EXPORT TO EXCEL
  // ══════════════════════════════════════════════
  Future<void> _exportToExcel() async {
    if (_lastRows.isEmpty) {
      _showSnack('Δεν υπάρχουν δεδομένα για εξαγωγή.', isError: true);
      return;
    }

    AccessibilityService.announcePolite('Δημιουργία αρχείου Excel...');

    try {
      final excel = Excel.createExcel();
      for (final name in excel.sheets.keys.toList()) {
        excel.delete(name);
      }

      final sheetName = 'Μηνιαία Σύνολα';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // ── Meta ──────────────────────────────────
      final now = DateTime.now();
      final dtFmt = DateFormat('dd/MM/yyyy HH:mm');

      sheet.appendRow([TextCellValue('Αναφορά Μηνιαίων Συνόλων')]);
      sheet.appendRow([
        TextCellValue('Έτος:'),
        TextCellValue('$_lastExportYear'),
      ]);
      sheet.appendRow([
        TextCellValue('Ημερομηνία Εξαγωγής:'),
        TextCellValue(dtFmt.format(now)),
      ]);
      sheet.appendRow([TextCellValue('')]);

      // ── Headers ───────────────────────────────
      sheet.appendRow([
        TextCellValue('ΜΗΝΑΣ'),
        TextCellValue('ΕΞΟΔΑ'),
        TextCellValue('ΕΣΟΔΑ'),
        TextCellValue('ΔΙΑΦΟΡΑ €'),
        TextCellValue('ΠΟΣΟΣΤΟ %'),
      ]);

      // ── Data rows ─────────────────────────────
      for (final r in _lastRows) {
        final diffPrefix = r.diff >= 0 ? '+' : '';
        final pctPrefix = r.pct >= 0 ? '+' : '';
        sheet.appendRow([
          TextCellValue(_kMonthNames[r.month - 1]),
          TextCellValue(_fmtAmt(r.expenses)),
          TextCellValue(_fmtAmt(r.income)),
          TextCellValue(
            r.expenses == 0 && r.income == 0
                ? '—'
                : '$diffPrefix${_fmtAmt(r.diff.abs())}',
          ),
          TextCellValue(
            r.expenses == 0 && r.income == 0
                ? '—'
                : '$pctPrefix${r.pct.toStringAsFixed(2)}%',
          ),
        ]);
      }

      // ── Total row ─────────────────────────────
      final totalExpenses = _lastRows.fold(0.0, (s, r) => s + r.expenses);
      final totalIncome = _lastRows.fold(0.0, (s, r) => s + r.income);
      final totalDiff = totalIncome - totalExpenses;
      final totalPct = totalIncome == 0
          ? 0.0
          : (totalIncome - totalExpenses) / totalIncome * 100;
      final totalDiffPrefix = totalDiff >= 0 ? '+' : '';
      final totalPctPrefix = totalPct >= 0 ? '+' : '';

      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue('ΣΥΝΟΛΟ'),
        TextCellValue(_fmtAmt(totalExpenses)),
        TextCellValue(_fmtAmt(totalIncome)),
        TextCellValue('$totalDiffPrefix${_fmtAmt(totalDiff.abs())}'),
        TextCellValue('$totalPctPrefix${totalPct.toStringAsFixed(2)}%'),
      ]);

      // ── Save ──────────────────────────────────
      final bytes = excel.encode();
      if (bytes == null) {
        _showSnack('Σφάλμα δημιουργίας Excel.', isError: true);
        return;
      }

      final ts = DateFormat('yyyyMMdd_HHmm').format(now);
      final fileName = 'Σύνολα_Ανά_Μήνα_${_lastExportYear}_$ts.xlsx';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Αποθήκευση Excel',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );

      if (savePath == null) return;
      if (!mounted) return;

      AccessibilityService.announcePolite('Το Excel αποθηκεύτηκε επιτυχώς.');
      _showSnack('Το Excel αποθηκεύτηκε επιτυχώς!', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Σφάλμα εξαγωγής Excel: $e', isError: true);
    }
  }

  // ══════════════════════════════════════════════
  // EXPORT TO PDF
  // ══════════════════════════════════════════════
  Future<void> _exportToPdf() async {
    if (_lastRows.isEmpty) {
      _showSnack('Δεν υπάρχουν δεδομένα για εξαγωγή.', isError: true);
      return;
    }

    AccessibilityService.announcePolite('Δημιουργία αρχείου PDF...');

    try {
      final ttf = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
      );
      final ttfBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
      );

      final pdf = pw.Document();
      final now = DateTime.now();
      final dtFmt = DateFormat('dd/MM/yyyy HH:mm');

      final totalExpenses = _lastRows.fold(0.0, (s, r) => s + r.expenses);
      final totalIncome = _lastRows.fold(0.0, (s, r) => s + r.income);
      final totalDiff = totalIncome - totalExpenses;
      final totalPct = totalIncome == 0
          ? 0.0
          : (totalIncome - totalExpenses) / totalIncome * 100;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(
            base: ttf,
            bold: ttfBold,
            italic: ttf,
            boldItalic: ttfBold,
          ),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Συνολικά Έσοδα / Έξοδα ανά Μήνα — $_lastExportYear',
                style: pw.TextStyle(
                  font: ttfBold,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Ημερομηνία Εξαγωγής: ${dtFmt.format(now)}',
                style: pw.TextStyle(font: ttf, fontSize: 10),
              ),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 4),
            ],
          ),
          build: (context) {
            // ── Summary card ──────────────────────
            final content = <pw.Widget>[];

            content.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EDE7F6'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Σύνολο Εσόδων:',
                      style: pw.TextStyle(font: ttfBold, fontSize: 11),
                    ),
                    pw.Text(
                      _fmtAmt(totalIncome),
                      style: pw.TextStyle(font: ttfBold, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
            content.add(pw.SizedBox(height: 6));
            content.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFEBEE'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Σύνολο Εξόδων:',
                      style: pw.TextStyle(font: ttfBold, fontSize: 11),
                    ),
                    pw.Text(
                      _fmtAmt(totalExpenses),
                      style: pw.TextStyle(font: ttfBold, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
            content.add(pw.SizedBox(height: 12));

            // ── Main table ────────────────────────

            final tableData = <List<String>>[];
            for (final r in _lastRows) {
              final diffPrefix = r.diff >= 0 ? '+' : '';
              final pctPrefix = r.pct >= 0 ? '+' : '';
              tableData.add([
                _kMonthNames[r.month - 1],
                _fmtAmt(r.expenses),
                _fmtAmt(r.income),
                r.expenses == 0 && r.income == 0
                    ? '—'
                    : '$diffPrefix${_fmtAmt(r.diff.abs())}',
                r.expenses == 0 && r.income == 0
                    ? '—'
                    : '$pctPrefix${r.pct.toStringAsFixed(2)}%',
              ]);
            }

            // Total row
            final tDiffPrefix = totalDiff >= 0 ? '+' : '';
            final tPctPrefix = totalPct >= 0 ? '+' : '';
            tableData.add([
              'ΣΥΝΟΛΟ',
              _fmtAmt(totalExpenses),
              _fmtAmt(totalIncome),
              '$tDiffPrefix${_fmtAmt(totalDiff.abs())}',
              '$tPctPrefix${totalPct.toStringAsFixed(2)}%',
            ]);

            // ── Main table ────────────────────────
            // Header row
            final pw.TextStyle headerStyle = pw.TextStyle(
              font: ttfBold,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            );
            final pw.TextStyle cellStyle = pw.TextStyle(font: ttf, fontSize: 9);
            final pw.TextStyle totalStyle = pw.TextStyle(
              font: ttfBold,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            );

            const colWidths = {
              0: pw.FlexColumnWidth(2.2),
              1: pw.FlexColumnWidth(1.8),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(1.8),
              4: pw.FlexColumnWidth(1.4),
            };

            pw.Widget buildCell(
              String text,
              pw.TextStyle style, {
              pw.Alignment align = pw.Alignment.centerRight,
              PdfColor? bg,
            }) {
              return pw.Container(
                color: bg,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 5,
                ),
                child: pw.Align(
                  alignment: align,
                  child: pw.Text(text, style: style),
                ),
              );
            }

            final tableRows = <pw.TableRow>[];

            // Header
            tableRows.add(
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#6750A4'),
                ),
                children: [
                  buildCell(
                    'ΜΗΝΑΣ',
                    headerStyle,
                    align: pw.Alignment.centerLeft,
                  ),
                  buildCell('ΕΞΟΔΑ', headerStyle),
                  buildCell('ΕΣΟΔΑ', headerStyle),
                  buildCell('ΔΙΑΦΟΡΑ €', headerStyle),
                  buildCell('ΠΟΣΟΣΤΟ', headerStyle),
                ],
              ),
            );

            // Data rows
            for (int i = 0; i < _lastRows.length; i++) {
              final r = _lastRows[i];
              final diffPrefix = r.diff >= 0 ? '+' : '';
              final pctPrefix = r.pct >= 0 ? '+' : '';
              final rowBg = i % 2 == 0
                  ? PdfColor.fromHex('#FAFAFA')
                  : PdfColor.fromHex('#FFFFFF');

              tableRows.add(
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: rowBg),
                  children: [
                    buildCell(
                      _kMonthNames[r.month - 1],
                      cellStyle,
                      align: pw.Alignment.centerLeft,
                      bg: rowBg,
                    ),
                    buildCell(_fmtAmt(r.expenses), cellStyle, bg: rowBg),
                    buildCell(_fmtAmt(r.income), cellStyle, bg: rowBg),
                    buildCell(
                      r.expenses == 0 && r.income == 0
                          ? '—'
                          : '$diffPrefix${_fmtAmt(r.diff.abs())}',
                      cellStyle,
                      bg: rowBg,
                    ),
                    buildCell(
                      r.expenses == 0 && r.income == 0
                          ? '—'
                          : '$pctPrefix${r.pct.toStringAsFixed(2)}%',
                      cellStyle,
                      bg: rowBg,
                    ),
                  ],
                ),
              );
            }

            // Total row
            final totalBg = PdfColor.fromHex('#EDE7F6');
            tableRows.add(
              pw.TableRow(
                decoration: pw.BoxDecoration(color: totalBg),
                children: [
                  buildCell(
                    'ΣΥΝΟΛΟ',
                    totalStyle,
                    align: pw.Alignment.centerLeft,
                    bg: totalBg,
                  ),
                  buildCell(_fmtAmt(totalExpenses), totalStyle, bg: totalBg),
                  buildCell(_fmtAmt(totalIncome), totalStyle, bg: totalBg),
                  buildCell(
                    '$tDiffPrefix${_fmtAmt(totalDiff.abs())}',
                    totalStyle,
                    bg: totalBg,
                  ),
                  buildCell(
                    '$tPctPrefix${totalPct.toStringAsFixed(2)}%',
                    totalStyle,
                    bg: totalBg,
                  ),
                ],
              ),
            );

            content.add(
              pw.Table(
                columnWidths: colWidths,
                border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#CCCCCC'),
                  width: 0.5,
                ),
                children: tableRows,
              ),
            );

            content.add(pw.SizedBox(height: 8));
            content.add(
              pw.Text(
                '* Διαφορά = Έσοδα − Έξοδα  |  Ποσοστό = (Έξοδα − Έσοδα) / Έσοδα × 100',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            );

            return content;
          },
        ),
      );

      final bytes = await pdf.save();
      final ts = DateFormat('yyyyMMdd_HHmm').format(now);
      final fileName = 'Συνολα_Ανά_Μήνα_${_lastExportYear}_$ts.pdf';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Αποθήκευση PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: Uint8List.fromList(bytes),
      );

      if (savePath == null) return;
      if (!mounted) return;

      AccessibilityService.announcePolite('Το PDF αποθηκεύτηκε επιτυχώς.');
      _showSnack('Το PDF αποθηκεύτηκε επιτυχώς!', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Σφάλμα εξαγωγής PDF: $e', isError: true);
    }
  }

  // ── SnackBar helper ───────────────────────────
  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                isError ? Icons.error_outline : Icons.check_circle,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
