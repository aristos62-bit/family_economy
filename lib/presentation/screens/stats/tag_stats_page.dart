// ============================================================
// FILE: tag_stats_page.dart
// Path: lib/presentation/screens/stats/tag_stats_page.dart
// Ρόλος: Στατιστικά φιλτραρισμένα ανά Tags
// ✅ Accessibility, UI Tokens, Providers real-time
// ✅ Offline-safe (ConnectivityService + Firestore offline cache)
// ✅ SessionScope για userId
// ✅ Export PDF + Excel (ίδιο format με StatsPage)
// ✅ Responsive: mobile / tablet / desktop
// ✅ Προστέθηκε φίλτρο Λογαριασμών (όπως στο StatsPage)
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
import 'package:family_economy/core/services/connectivity_service.dart';

import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';
import 'package:family_economy/providers/tags_provider.dart';

class TagStatsPage extends StatefulWidget {
  const TagStatsPage({super.key});

  @override
  State<TagStatsPage> createState() => _TagStatsPageState();
}

class _TagStatsPageState extends State<TagStatsPage> {
  // ──────────────────────────────────────────────────────────
  // STATE
  // ──────────────────────────────────────────────────────────

  DateTime? _fromDate;
  DateTime? _toDate;

  String? _movementType; // 'income' | 'expense'

  /// tagId → selected
  final Map<String, bool> _selectedTags = {};

  // ✅ ΝΕΟ: Λογαριασμοί
  final Map<String, bool> _selectedAccounts = {};

  bool _includeComments = false;
  bool _isGenerating = false;

  _TagSortOption _sortBy = _TagSortOption.dateDesc;
  _TagGroupOption _groupBy = _TagGroupOption.none;

  // last report cache
  List<_TagReportRow> _lastReportRows = [];
  DateTime? _lastFromDate;
  DateTime? _lastToDate;
  String? _lastMovementType;
  bool _lastIncludeComments = false;
  _TagSortOption? _lastSortBy;
  _TagGroupOption? _lastGroupBy;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _reportDateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  // ✅ avoid spam loadPeriod in build
  bool _loadScheduled = false;
  DateTime? _listeningStart;
  DateTime? _listeningEnd;

  static const String _periodKey = 'TAG_STATS_PAGE';

  // ──────────────────────────────────────────────────────────
  // INIT
  // ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate   = DateTime(now.year, now.month + 1, 0);
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Στατιστικά από Tags. '
          'Επιλέξτε χρονικό διάστημα, τύπο κινήσεων, λογαριασμούς και tags.',
    );
  }

  // ──────────────────────────────────────────────────────────
  // HELPERS – DATE
  // ──────────────────────────────────────────────────────────

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate  ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate:  DateTime(2100),
      helpText: isFrom ? 'Ημ/νία από' : 'Ημ/νία έως',
      locale: const Locale('el', 'GR'),
    );
    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
          _toDate = _fromDate;
        }
      } else {
        _toDate = picked;
        if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
          _fromDate = _toDate;
        }
      }
    });
    AccessibilityService.announcePolite(
      isFrom
          ? 'Ημερομηνία από: ${_dateFormat.format(picked)}'
          : 'Ημερομηνία έως: ${_dateFormat.format(picked)}',
    );
  }

  // ──────────────────────────────────────────────────────────
  // HELPERS – MOVEMENT TYPE
  // ──────────────────────────────────────────────────────────

  void _onToggleMovementType(String type) {
    setState(() {
      _movementType = (_movementType == type) ? null : type;
      _selectedTags.clear();
      _lastReportRows = [];
      // Δεν επαναφέρουμε τους λογαριασμούς – μπορούν να παραμείνουν
    });
    AccessibilityService.announcePolite(
      _movementType == null
          ? 'Τύπος κινήσεων αποεπιλέχθηκε'
          : (_movementType == 'income' ? 'Επιλέχθηκαν Έσοδα' : 'Επιλέχθηκαν Έξοδα'),
    );
  }

  // ──────────────────────────────────────────────────────────
  // HELPERS – ACCOUNTS (ΝΕΟ)
  // ──────────────────────────────────────────────────────────

  void _onToggleAccount(String accountId, bool? value) {
    setState(() {
      _selectedAccounts[accountId] = value ?? false;
      _lastReportRows = [];
    });
  }

  bool _hasSelectedAccounts() =>
      _selectedAccounts.values.any((v) => v == true);

  // ──────────────────────────────────────────────────────────
  // HELPERS – TAGS
  // ──────────────────────────────────────────────────────────

  void _onToggleTag(String tagId, bool? value) {
    setState(() {
      _selectedTags[tagId] = value ?? false;
      _lastReportRows = [];
    });
  }

  void _selectAllTags(List<TagModel> tags) {
    setState(() {
      for (final t in tags) {
        _selectedTags[t.uuid] = true;
      }
    });
    AccessibilityService.announcePolite('Επιλέχθηκαν όλα τα tags');
  }

  void _clearAllTags(List<TagModel> tags) {
    setState(() {
      for (final t in tags) {
        _selectedTags[t.uuid] = false;
      }
    });
    AccessibilityService.announcePolite('Αποεπιλέχθηκαν όλα τα tags');
  }

  bool _hasSelectedTags() =>
      _selectedTags.values.any((v) => v == true);

  bool _canGenerateReport() =>
      _fromDate != null &&
          _toDate   != null &&
          _movementType != null &&
          _hasSelectedAccounts() &&   // ✅ ΝΕΟ
          _hasSelectedTags();

  // ──────────────────────────────────────────────────────────
  // OFFLINE-SAFE: ensure TransactionsProvider listener
  // ──────────────────────────────────────────────────────────

  void _ensureTransactionsListener({
    required TransactionsProvider transactionsP,
    required DateTime from,
    required DateTime to,
  }) {
    final rangeChanged =
        _listeningStart == null ||
            _listeningEnd   == null ||
            _listeningStart != from ||
            _listeningEnd   != to;

    if (!rangeChanged || _loadScheduled) return;

    _listeningStart = from;
    _listeningEnd   = to;
    _loadScheduled  = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!mounted) return;
      transactionsP.loadPeriod(_periodKey, from, to);
    });
  }

  // ──────────────────────────────────────────────────────────
  // REPORT GENERATION
  // ──────────────────────────────────────────────────────────

  Future<void> _generateReport({
    required AccountsProvider accountsP,
    required CategoriesProvider categoriesP,
    required TransactionsProvider transactionsP,
    required TagsProvider tagsP,
  }) async {
    if (_fromDate == null || _toDate == null) {
      _showSnack('Παρακαλώ επιλέξτε χρονικό διάστημα.', Colors.red);
      return;
    }
    if (_movementType == null) {
      _showSnack('Παρακαλώ επιλέξτε Έσοδα ή Έξοδα.', Colors.red);
      return;
    }
    if (!_hasSelectedAccounts()) {
      _showSnack('Παρακαλώ επιλέξτε τουλάχιστον έναν λογαριασμό.', Colors.orange);
      return;
    }
    if (!_hasSelectedTags()) {
      _showSnack('Παρακαλώ επιλέξτε τουλάχιστον ένα tag.', Colors.orange);
      return;
    }

    // ✅ Offline check – δεν μπλοκάρει, απλώς ενημερώνει
    final connectivity = context.read<ConnectivityService>();
    if (connectivity.isOffline) {
      _showSnack(
        'Εκτός σύνδεσης. Τα αποτελέσματα βασίζονται στα τοπικά δεδομένα.',
        Colors.orange,
        duration: const Duration(seconds: 3),
      );
    }

    setState(() => _isGenerating = true);
    AccessibilityService.announcePolite('Δημιουργία αναφοράς tags...');

    try {
      final from = DateTime(
        _fromDate!.year, _fromDate!.month, _fromDate!.day, 0, 0, 0,
      );
      final to = DateTime(
        _toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59,
      );

      final selectedAccountIds = _selectedAccounts.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toSet();

      final selectedTagIds = _selectedTags.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toSet();

      // ── Φέρε όλες τις transactions της περιόδου ────────────
      final allTxs = transactionsP.getFilteredTransactionsForPeriod(
        _periodKey,
        includeTransfers: false,
        includeFuture:    false,
        from: from,
        to:   to,
        movementType: _movementType,
        categoryTypeOf: (categoryId) {
          return categoriesP.getCategoryByUuid(categoryId)?.type;
        },
        // ✅ ΝΕΟ: φιλτράρισμα λογαριασμών
        accountIds: selectedAccountIds,
      );

      // ── Φίλτρο Tags: η transaction πρέπει να έχει
      //    τουλάχιστον ένα από τα επιλεγμένα tags ────────────
      final filtered = allTxs.where((t) {
        return t.tagIds.any((tid) => selectedTagIds.contains(tid));
      }).toList();

      if (filtered.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
          _lastReportRows = [];
        });
        Future.delayed(Duration.zero, () {
          if (!mounted) return;
          _showSnack(
            'Δεν βρέθηκαν κινήσεις για τα επιλεγμένα tags και λογαριασμούς.',
            Colors.orange,
            duration: const Duration(seconds: 3),
          );
        });
        AccessibilityService.announceAssertive(
          'Δεν βρέθηκαν κινήσεις για τα επιλεγμένα tags.',
        );
        return;
      }

      // ── Δημιουργία γραμμών report ─────────────────────────
      final rows = <_TagReportRow>[];
      for (final t in filtered) {
        final acc = accountsP.getAccountByUuid(t.accountId);
        final cat = t.categoryId != null
            ? categoriesP.getCategoryByUuid(t.categoryId!)
            : null;

        String subName = '';
        if (t.categoryId != null && t.subcategoryId != null) {
          final sub = categoriesP.getSubcategoryByUuid(
            t.categoryId!, t.subcategoryId!,
          );
          subName = sub?.name ?? '';
        }

        final tagModels = tagsP.getTagsByIds(t.tagIds);
        final tagNames  = tagModels.map((tg) => tg.name).join(', ');
        final tagColors = tagModels.map((tg) => tg.color).toList();

        rows.add(_TagReportRow(
          date:            t.date,
          accountName:     acc?.name ?? '',
          categoryName:    cat?.name ?? '',
          subcategoryName: subName,
          amount:          t.amount,
          notes:           t.notes,
          tagNames:        tagNames,
          tagColors:       tagColors,
        ));
      }

      _applySorting(rows);

      _lastReportRows      = rows;
      _lastFromDate        = _fromDate;
      _lastToDate          = _toDate;
      _lastMovementType    = _movementType;
      _lastIncludeComments = _includeComments;
      _lastSortBy          = _sortBy;
      _lastGroupBy         = _groupBy;

      if (!mounted) return;
      setState(() => _isGenerating = false);
      AccessibilityService.announcePolite(
        'Αναφορά έτοιμη. ${rows.length} κινήσεις βρέθηκαν.',
      );
      _showReportPreviewDialog();

    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showSnack('Σφάλμα κατά τη δημιουργία report: $e', Colors.red);
    }
  }

  // ──────────────────────────────────────────────────────────
  // SORTING
  // ──────────────────────────────────────────────────────────

  void _applySorting(List<_TagReportRow> rows) {
    switch (_sortBy) {
      case _TagSortOption.dateAsc:
        rows.sort((a, b) => a.date.compareTo(b.date));
        break;
      case _TagSortOption.dateDesc:
        rows.sort((a, b) => b.date.compareTo(a.date));
        break;
      case _TagSortOption.amountAsc:
        rows.sort((a, b) => a.amount.abs().compareTo(b.amount.abs()));
        break;
      case _TagSortOption.amountDesc:
        rows.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
        break;
      case _TagSortOption.category:
        rows.sort((a, b) {
          final c = a.categoryName.compareTo(b.categoryName);
          if (c != 0) return c;
          return a.subcategoryName.compareTo(b.subcategoryName);
        });
        break;
      case _TagSortOption.account:
        rows.sort((a, b) => a.accountName.compareTo(b.accountName));
        break;
      case _TagSortOption.tag:
        rows.sort((a, b) => a.tagNames.compareTo(b.tagNames));
        break;
    }
  }

  // ──────────────────────────────────────────────────────────
  // GROUPING
  // ──────────────────────────────────────────────────────────

  Map<String, List<_TagReportRow>> _groupRows(List<_TagReportRow> rows) {
    if (_groupBy == _TagGroupOption.none) {
      return {'Όλες οι Κινήσεις': rows};
    }

    final Map<String, List<_TagReportRow>> grouped = {};
    for (final row in rows) {
      String key;
      switch (_groupBy) {
        case _TagGroupOption.tag:
          key = row.tagNames.isNotEmpty ? row.tagNames : 'Χωρίς Tag';
          break;
        case _TagGroupOption.category:
          key = row.categoryName;
          break;
        case _TagGroupOption.subcategory:
          key = '${row.categoryName} → ${row.subcategoryName}';
          break;
        case _TagGroupOption.account:
          key = row.accountName;
          break;
        case _TagGroupOption.day:
          key = _dateFormat.format(row.date);
          break;
        case _TagGroupOption.month:
          key = DateFormat('MMMM yyyy', 'el_GR').format(row.date);
          break;
        case _TagGroupOption.none:
          key = 'Όλες οι Κινήσεις';
          break;
      }
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(row);
    }
    return grouped;
  }

  double _calculateTotal(List<_TagReportRow> rows) =>
      rows.fold(0.0, (sum, r) => sum + r.amount);

  Map<String, double> _calculateSubtotals(
      Map<String, List<_TagReportRow>> grouped) {
    final Map<String, double> subtotals = {};
    grouped.forEach((key, rows) {
      subtotals[key] = _calculateTotal(rows);
    });
    return subtotals;
  }

  // ──────────────────────────────────────────────────────────
  // SNACK HELPER
  // ──────────────────────────────────────────────────────────

  void _showSnack(
      String message,
      Color color, {
        Duration duration = const Duration(seconds: 2),
      }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.fixed,
      duration: duration,
    ));
  }

  // ──────────────────────────────────────────────────────────
  // PREVIEW DIALOG
  // ──────────────────────────────────────────────────────────

  void _showReportPreviewDialog() {
    final grouped    = _groupRows(_lastReportRows);
    final subtotals  = _calculateSubtotals(grouped);
    final grandTotal = _calculateTotal(_lastReportRows);

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          backgroundColor: context.cSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Semantics(
            header: true,
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.label_rounded, color: context.cPrimary),
                ),
                const SizedBox(width: 8),
                Text(
                  'Αναφορά από Tags',
                  style: TextStyle(
                    color: context.cText,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Metadata ──────────────────────────────────
                if (_lastFromDate != null && _lastToDate != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      'Περίοδος: ${_dateFormat.format(_lastFromDate!)} – '
                          '${_dateFormat.format(_lastToDate!)}',
                      style: TextStyle(color: context.cText2, fontSize: 12),
                    ),
                  ),
                if (_lastMovementType != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Τύπος: ${_lastMovementType == 'income' ? 'Έσοδα' : 'Έξοδα'}',
                      style: TextStyle(color: context.cText2, fontSize: 12),
                    ),
                  ),

                // ── Grand Total ───────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color:        context.cPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.cPrimary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ΓΕΝΙΚΟ ΣΥΝΟΛΟ:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.cText,
                        ),
                      ),
                      Semantics(
                        label: 'Γενικό σύνολο '
                            '${CurrencyFormatter.format(grandTotal.abs())}',
                        child: ExcludeSemantics(
                          child: Text(
                            CurrencyFormatter.format(grandTotal.abs()),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: context.cPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                ExcludeSemantics(
                  child: Divider(
                    color: context.cText2.withValues(alpha: 0.25),
                  ),
                ),

                // ── Table ─────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    child: _buildGroupedReportTable(grouped, subtotals),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Semantics(
              button: true,
              label: 'Εξαγωγή σε Excel',
              child: TextButton.icon(
                onPressed: _exportToExcel,
                icon: const ExcludeSemantics(child: Icon(Icons.table_chart)),
                label: const Text('Excel'),
              ),
            ),
            Semantics(
              button: true,
              label: 'Εξαγωγή σε PDF',
              child: TextButton.icon(
                onPressed: _exportToPdf,
                icon: const ExcludeSemantics(child: Icon(Icons.picture_as_pdf)),
                label: const Text('PDF'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Κλείσιμο'),
            ),
          ],
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────
  // GROUPED REPORT TABLE (screen preview)
  // ──────────────────────────────────────────────────────────

  Widget _buildGroupedReportTable(
      Map<String, List<_TagReportRow>> grouped,
      Map<String, double> subtotals,
      ) {
    final sections = <Widget>[];

    grouped.forEach((groupName, rows) {
      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group header
            if (_groupBy != _TagGroupOption.none)
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 12),
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color:        context.cSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.cText2.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        groupName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: context.cText,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(
                          subtotals[groupName]!.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.cPrimary,
                      ),
                    ),
                  ],
                ),
              ),

            // DataTable
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                horizontalMargin: 8,
                columns: [
                  const DataColumn(label: Text('Ημ/νία')),
                  if (_groupBy != _TagGroupOption.account)
                    const DataColumn(label: Text('Λογαριασμός')),
                  if (_groupBy != _TagGroupOption.category &&
                      _groupBy != _TagGroupOption.subcategory)
                    const DataColumn(label: Text('Κατηγορία')),
                  if (_groupBy != _TagGroupOption.subcategory)
                    const DataColumn(label: Text('Υποκατηγορία')),
                  const DataColumn(
                      label: Text('Ποσό'),
                      numeric: true),
                  const DataColumn(label: Text('Tags')),
                  if (_lastIncludeComments)
                    const DataColumn(label: Text('Σχόλια')),
                ],
                rows: rows.map((r) {
                  final cells = <DataCell>[
                    DataCell(Text(
                      _dateFormat.format(r.date),
                      style: TextStyle(
                          fontSize: 11, color: context.cText),
                    )),
                    if (_groupBy != _TagGroupOption.account)
                      DataCell(Text(r.accountName,
                          style: TextStyle(
                              fontSize: 11, color: context.cText))),
                    if (_groupBy != _TagGroupOption.category &&
                        _groupBy != _TagGroupOption.subcategory)
                      DataCell(Text(r.categoryName,
                          style: TextStyle(
                              fontSize: 11, color: context.cText))),
                    if (_groupBy != _TagGroupOption.subcategory)
                      DataCell(Text(r.subcategoryName,
                          style: TextStyle(
                              fontSize: 11, color: context.cText))),
                    DataCell(
                      Semantics(
                        label: 'Ποσό '
                            '${CurrencyFormatter.format(r.amount.abs())}',
                        child: ExcludeSemantics(
                          child: Text(
                            CurrencyFormatter.format(r.amount.abs()),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _lastMovementType == 'income'
                                  ? ColorsUI.getIncomeColor(
                                  context.brightness)
                                  : ColorsUI.getExpenseColor(
                                  context.brightness),
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(_buildTagChips(r)),
                  ];
                  if (_lastIncludeComments) {
                    cells.add(DataCell(Text(
                      r.notes ?? '',
                      style: TextStyle(
                          fontSize: 10, color: context.cText2),
                    )));
                  }
                  return DataRow(cells: cells);
                }).toList(),
              ),
            ),
          ],
        ),
      );
    });

    return Column(children: sections);
  }

  /// Χρωματιστά tag chips για προεπισκόπηση
  Widget _buildTagChips(_TagReportRow row) {
    if (row.tagNames.isEmpty) {
      return Text('–',
          style: TextStyle(fontSize: 11, color: context.cText2));
    }

    final names  = row.tagNames.split(', ');
    final colors = row.tagColors;

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: List.generate(names.length, (i) {
        Color chipColor;
        try {
          final hex = colors[i].replaceAll('#', '');
          chipColor = Color(int.parse('FF$hex', radix: 16));
        } catch (_) {
          chipColor = context.cPrimary;
        }
        final onChip = ThemeData.estimateBrightnessForColor(chipColor) ==
            Brightness.dark
            ? Colors.white
            : Colors.black87;

        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color:        chipColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            names[i],
            style: TextStyle(
              fontSize: 9,
              color: onChip,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }),
    );
  }

  // ──────────────────────────────────────────────────────────
  // EXPORT EXCEL
  // ──────────────────────────────────────────────────────────

  Future<void> _exportToExcel() async {
    if (_lastReportRows.isEmpty) {
      _showSnack('Δεν υπάρχει διαθέσιμο report προς εξαγωγή.',
          Colors.orange);
      return;
    }

    try {
      final excel = Excel.createExcel();
      for (final name in excel.sheets.keys.toList()) {
        excel.delete(name);
      }
      final sheet = excel['Αναφορά Tags'];
      excel.setDefaultSheet('Αναφορά Tags');

      final reportAt = DateTime.now();

      // ── Μεταδεδομένα ──────────────────────────────────────
      sheet.appendRow([
        TextCellValue('Ημερομηνία Αναφοράς:'),
        TextCellValue(_reportDateTimeFormat.format(reportAt)),
      ]);
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue('Περίοδος:'),
        TextCellValue(
          '${_dateFormat.format(_lastFromDate!)} - '
              '${_dateFormat.format(_lastToDate!)}',
        ),
      ]);
      sheet.appendRow([
        TextCellValue('Τύπος:'),
        TextCellValue(
            _lastMovementType == 'income' ? 'Έσοδα' : 'Έξοδα'),
      ]);
      if (_lastSortBy != null) {
        sheet.appendRow([
          TextCellValue('Ταξινόμηση:'),
          TextCellValue(_lastSortBy!.label),
        ]);
      }
      if (_lastGroupBy != null) {
        sheet.appendRow([
          TextCellValue('Ομαδοποίηση:'),
          TextCellValue(_lastGroupBy!.label),
        ]);
      }
      sheet.appendRow([TextCellValue('')]);

      // ── Headers ───────────────────────────────────────────
      final headers = <String>[
        'Ημ/νία', 'Λογαριασμός', 'Κατηγορία',
        'Υποκατηγορία', 'Ποσό', 'Tags',
      ];
      if (_lastIncludeComments) headers.add('Σχόλια');
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // ── Data ──────────────────────────────────────────────
      final grouped   = _groupRows(_lastReportRows);
      final subtotals = _calculateSubtotals(grouped);
      final grandTotal = _calculateTotal(_lastReportRows);

      grouped.forEach((groupName, rows) {
        if (_groupBy != _TagGroupOption.none) {
          sheet.appendRow([
            TextCellValue(''),
            TextCellValue('── $groupName ──'),
            TextCellValue(''),
            TextCellValue(''),
            TextCellValue(
              'Υποσύνολο: ${CurrencyFormatter.format(subtotals[groupName]!.abs())}',
            ),
          ]);
        }
        for (final r in rows) {
          final row = <CellValue>[
            TextCellValue(_dateFormat.format(r.date)),
            TextCellValue(r.accountName),
            TextCellValue(r.categoryName),
            TextCellValue(r.subcategoryName),
            TextCellValue(CurrencyFormatter.format(r.amount.abs())),
            TextCellValue(r.tagNames),
          ];
          if (_lastIncludeComments) {
            row.add(TextCellValue(r.notes ?? ''));
          }
          sheet.appendRow(row);
        }
        if (_groupBy != _TagGroupOption.none) {
          sheet.appendRow([TextCellValue('')]);
        }
      });

      // ── Grand total ───────────────────────────────────────
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue(''), TextCellValue(''), TextCellValue(''),
        TextCellValue('ΓΕΝΙΚΟ ΣΥΝΟΛΟ:'),
        TextCellValue(CurrencyFormatter.format(grandTotal.abs())),
      ]);

      final bytes = excel.encode();
      if (bytes == null) {
        _showSnack('Σφάλμα κατά τη δημιουργία Excel.', Colors.red);
        return;
      }

      final ts       = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'Αναφορά_Tags_$ts.xlsx';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle:       'Αποθήκευση Αναφοράς Excel',
        fileName:          fileName,
        type:              FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes:             Uint8List.fromList(bytes),
      );

      if (savePath == null) return;
      if (!mounted) return;

      AccessibilityService.announcePolite('Excel αποθηκεύτηκε επιτυχώς!');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          ExcludeSemantics(
              child: Icon(Icons.check_circle, color: Colors.white)),
          SizedBox(width: 12),
          Expanded(child: Text('Το Excel αποθηκεύτηκε επιτυχώς!')),
        ]),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      _showSnack('Σφάλμα Excel: $e', Colors.red);
    }
  }

  // ──────────────────────────────────────────────────────────
  // EXPORT PDF
  // ──────────────────────────────────────────────────────────

  Future<void> _exportToPdf() async {
    if (_lastReportRows.isEmpty) {
      _showSnack('Δεν υπάρχει διαθέσιμο report προς εξαγωγή.',
          Colors.orange);
      return;
    }

    try {
      final ttf = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
      );

      final pdf     = pw.Document();
      final grouped = _groupRows(_lastReportRows);
      final subtotals  = _calculateSubtotals(grouped);
      final grandTotal = _calculateTotal(_lastReportRows);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base:      ttf,
            bold:      ttf,
            italic:    ttf,
            boldItalic: ttf,
          ),
          build: (pdfCtx) {
            final content = <pw.Widget>[];

            // ── Title ────────────────────────────────────────
            content.add(pw.Header(
              level: 0,
              child: pw.Text(
                'Αναφορά Στατιστικών από Tags',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ));

            content.add(pw.Text(
              'Ημερομηνία Αναφοράς: '
                  '${_reportDateTimeFormat.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ));

            content.add(pw.SizedBox(height: 6));

            content.add(pw.Text(
              'Περίοδος: ${_dateFormat.format(_lastFromDate!)} – '
                  '${_dateFormat.format(_lastToDate!)}',
              style: const pw.TextStyle(fontSize: 11),
            ));

            content.add(pw.Text(
              'Τύπος: ${_lastMovementType == 'income' ? 'Έσοδα' : 'Έξοδα'}',
              style: const pw.TextStyle(fontSize: 11),
            ));

            if (_lastSortBy != null) {
              content.add(pw.Text(
                'Ταξινόμηση: ${_lastSortBy!.label}',
                style: const pw.TextStyle(fontSize: 10),
              ));
            }

            content.add(pw.SizedBox(height: 12));

            // ── Grand total box ───────────────────────────────
            content.add(pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color:        PdfColor.fromHex('#E3F2FD'),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Γενικό Σύνολο:',
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    CurrencyFormatter.format(grandTotal.abs()),
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ));

            content.add(pw.SizedBox(height: 12));

            // ── Grouped tables ────────────────────────────────
            grouped.forEach((groupName, rows) {
              if (_groupBy != _TagGroupOption.none) {
                content.add(pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
                  color: PdfColor.fromHex('#EEEEEE'),
                  child: pw.Row(
                    mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(groupName,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11)),
                      pw.Text(
                        'Υποσύνολο: '
                            '${CurrencyFormatter.format(subtotals[groupName]!.abs())}',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ));
              }

              final headers = [
                'Ημ/νία', 'Λογαριασμός', 'Κατηγορία',
                'Υποκατηγορία', 'Ποσό', 'Tags',
                if (_lastIncludeComments) 'Σχόλια',
              ];

              final data = rows.map((r) => [
                _dateFormat.format(r.date),
                r.accountName,
                r.categoryName,
                r.subcategoryName,
                CurrencyFormatter.format(r.amount.abs()),
                r.tagNames,
                if (_lastIncludeComments) (r.notes ?? ''),
              ]).toList();

              content.add(pw.TableHelper.fromTextArray(
                headers: headers,
                data:    data,
                headerStyle: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold),
                cellStyle:   const pw.TextStyle(fontSize: 8),
                headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#DDDDDD')),
                border: pw.TableBorder.all(
                    color: PdfColor.fromHex('#BBBBBB')),
                cellPadding: const pw.EdgeInsets.all(4),
              ));
            });

            return content;
          },
        ),
      );

      final bytes    = await pdf.save();
      final ts       = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'Αναφορά_Tags_$ts.pdf';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle:       'Αποθήκευση Αναφοράς PDF',
        fileName:          fileName,
        type:              FileType.custom,
        allowedExtensions: ['pdf'],
        bytes:             Uint8List.fromList(bytes),
      );

      if (savePath == null) return;
      if (!mounted) return;

      AccessibilityService.announcePolite('PDF αποθηκεύτηκε επιτυχώς!');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          ExcludeSemantics(
              child: Icon(Icons.check_circle, color: Colors.white)),
          SizedBox(width: 12),
          Expanded(child: Text('Το PDF αποθηκεύτηκε επιτυχώς!')),
        ]),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      _showSnack('Σφάλμα PDF: $e', Colors.red);
    }
  }

  // ──────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ✅ SessionScope guard
    final _ = context.session.userId;

    final accountsP     = context.watch<AccountsProvider>();
    final categoriesP   = context.watch<CategoriesProvider>();
    final transactionsP = context.watch<TransactionsProvider>();
    final tagsP         = context.watch<TagsProvider>();
    final connectivity  = context.watch<ConnectivityService>();

    // ✅ Συγχρονισμός λογαριασμών
    final accounts = accountsP.accounts;
    for (final a in accounts) {
      _selectedAccounts.putIfAbsent(a.uuid, () => false);
    }
    _selectedAccounts.removeWhere(
          (k, _) => accounts.every((a) => a.uuid != k),
    );

    final from = _fromDate ?? DateTime.now();
    final to   = _toDate   ?? DateTime.now();

    // ✅ Offline-safe: trigger listener για τη χρονική περίοδο
    _ensureTransactionsListener(
      transactionsP: transactionsP,
      from: from,
      to:   to,
    );

    // ✅ Συγχρονισμός tags state με τα διαθέσιμα tags
    final availableTags = tagsP.tags;
    for (final t in availableTags) {
      _selectedTags.putIfAbsent(t.uuid, () => false);
    }
    _selectedTags.removeWhere(
          (k, _) => availableTags.every((t) => t.uuid != k),
    );

    final canGenerate = _canGenerateReport();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide      = screenWidth >= 700;

    return Scaffold(
      backgroundColor: context.cBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(connectivity),
            if (connectivity.isOffline)
              _buildOfflineBanner(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 16,
                  vertical:   10,
                ),
                child: isWide
                    ? _buildWideLayout(
                  accountsP:     accountsP,
                  categoriesP:   categoriesP,
                  transactionsP: transactionsP,
                  tagsP:         tagsP,
                  availableTags: availableTags,
                  canGenerate:   canGenerate,
                )
                    : _buildNarrowLayout(
                  accountsP:     accountsP,
                  categoriesP:   categoriesP,
                  transactionsP: transactionsP,
                  tagsP:         tagsP,
                  availableTags: availableTags,
                  canGenerate:   canGenerate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader(ConnectivityService connectivity) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.cPrimary,
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Πίσω',
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.cOnPrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: ExcludeSemantics(
                  child: Icon(Icons.arrow_back,
                      color: context.cOnPrimary, size: 22),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          ExcludeSemantics(
            child: Icon(Icons.label_rounded,
                color: context.cOnPrimary.withValues(alpha: 0.85),
                size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Στατιστικά από Tags',
                style: TextStyle(
                  color:      context.cOnPrimary,
                  fontSize:   19,
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(
                        color:      Colors.black45,
                        blurRadius: 6,
                        offset:     Offset(0, 1)),
                  ],
                ),
              ),
            ),
          ),
          if (connectivity.isOffline)
            ExcludeSemantics(
              child: Icon(Icons.cloud_off,
                  color: context.cOnPrimary.withValues(alpha: 0.70),
                  size: 20),
            ),
        ],
      ),
    );
  }

  // ── Offline banner ────────────────────────────────────────

  Widget _buildOfflineBanner() {
    return Semantics(
      liveRegion: true,
      label: 'Εκτός σύνδεσης. Λειτουργία offline.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        color: ColorsUI.getWarning(context.brightness).withValues(alpha: 0.20),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.cloud_off,
                  size: 16,
                  color: ColorsUI.getWarning(context.brightness)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Εκτός σύνδεσης – χρήση τοπικών δεδομένων',
                style: TextStyle(
                  fontSize: 11,
                  color: ColorsUI.getWarning(context.brightness),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Narrow layout (mobile) ────────────────────────────────

  Widget _buildNarrowLayout({
    required AccountsProvider accountsP,
    required CategoriesProvider categoriesP,
    required TransactionsProvider transactionsP,
    required TagsProvider tagsP,
    required List<TagModel> availableTags,
    required bool canGenerate,
  }) {
    return ListView(
      children: _buildFormCards(
        accountsP:     accountsP,
        categoriesP:   categoriesP,
        transactionsP: transactionsP,
        tagsP:         tagsP,
        availableTags: availableTags,
        canGenerate:   canGenerate,
      ),
    );
  }

  // ── Wide layout (tablet / desktop) ───────────────────────

  Widget _buildWideLayout({
    required AccountsProvider accountsP,
    required CategoriesProvider categoriesP,
    required TransactionsProvider transactionsP,
    required TagsProvider tagsP,
    required List<TagModel> availableTags,
    required bool canGenerate,
  }) {
    final cards = _buildFormCards(
      accountsP:     accountsP,
      categoriesP:   categoriesP,
      transactionsP: transactionsP,
      tagsP:         tagsP,
      availableTags: availableTags,
      canGenerate:   canGenerate,
    );

    final left  = cards.take((cards.length / 2).ceil()).toList();
    final right = cards.skip((cards.length / 2).ceil()).toList();

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: left
                  .map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: w,
              ))
                  .toList(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: right
                  .map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: w,
              ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Επιστρέφει όλες τις κάρτες της φόρμας ως λίστα widgets
  List<Widget> _buildFormCards({
    required AccountsProvider accountsP,
    required CategoriesProvider categoriesP,
    required TransactionsProvider transactionsP,
    required TagsProvider tagsP,
    required List<TagModel> availableTags,
    required bool canGenerate,
  }) {
    final widgets = <Widget>[
      // 1. Χρονικό διάστημα
      _buildDateRangeCard(),
      const SizedBox(height: 10),

      // 2. Τύπος (Έσοδα / Έξοδα)
      _buildTypeCard(),
      const SizedBox(height: 10),
    ];

    // 3. Λογαριασμοί – εμφανίζεται μόνο αν έχει επιλεγεί τύπος
    if (_movementType != null && accountsP.accounts.isNotEmpty) {
      widgets.add(_buildAccountsCard(accountsP.accounts));
      widgets.add(const SizedBox(height: 10));
    }

    // 4. Tags – εμφανίζεται μόνο αν έχει επιλεγεί τύπος
    if (_movementType != null && availableTags.isNotEmpty) {
      widgets.add(_buildTagsCard(availableTags));
      widgets.add(const SizedBox(height: 10));
    } else if (_movementType != null && availableTags.isEmpty) {
      widgets.add(_buildNoTagsCard());
      widgets.add(const SizedBox(height: 10));
    }

    // 5. Ταξινόμηση & Ομαδοποίηση (μόνο αν έχει επιλεγεί tag)
    if (_hasSelectedTags()) {
      widgets.add(_buildSortingGroupingCard());
      widgets.add(const SizedBox(height: 10));
    }

    // 6. Σχόλια checkbox
    if (_hasSelectedTags()) {
      widgets.add(_buildCommentsCheckbox());
      widgets.add(const SizedBox(height: 10));
    }

    // 7. Summary
    if (canGenerate) {
      widgets.add(_buildSummaryCard(accountsP.accounts, availableTags));
      widgets.add(const SizedBox(height: 16));
    }

    // 8. Generate button
    if (canGenerate) {
      widgets.add(_buildGenerateButton(
        canGenerate: canGenerate,
        onPressed: () {
          AccessibilityService.announcePolite('Δημιουργία αναφοράς tags...');
          _generateReport(
            accountsP:     context.read<AccountsProvider>(),
            categoriesP:   context.read<CategoriesProvider>(),
            transactionsP: context.read<TransactionsProvider>(),
            tagsP:         context.read<TagsProvider>(),
          );
        },
      ));
      widgets.add(const SizedBox(height: 40));
    }

    return widgets;
  }

  // ──────────────────────────────────────────────────────────
  // CARD: DATE RANGE
  // ──────────────────────────────────────────────────────────

  Widget _buildDateRangeCard() {
    return Card(
      elevation: 2,
      color: context.cSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ExcludeSemantics(
                child: Icon(Icons.calendar_month,
                    color: context.cPrimary, size: 22),
              ),
              const SizedBox(width: 8),
              Semantics(
                header: true,
                child: Text('Χρονικό Διάστημα',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.cText)),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label:
                  'Ημερομηνία από. '
                      '${_fromDate == null ? 'Μη επιλεγμένη' : _dateFormat.format(_fromDate!)}',
                  child: InkWell(
                    onTap: () => _pickDate(isFrom: true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Από',
                        border: const OutlineInputBorder(),
                        prefixIcon: const ExcludeSemantics(
                            child: Icon(Icons.calendar_today)),
                        isDense: true,
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          _fromDate == null
                              ? 'Επιλογή ημερομηνίας'
                              : _dateFormat.format(_fromDate!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  label:
                  'Ημερομηνία έως. '
                      '${_toDate == null ? 'Μη επιλεγμένη' : _dateFormat.format(_toDate!)}',
                  child: InkWell(
                    onTap: () => _pickDate(isFrom: false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Έως',
                        border: const OutlineInputBorder(),
                        prefixIcon: const ExcludeSemantics(
                            child: Icon(Icons.calendar_today)),
                        isDense: true,
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          _toDate == null
                              ? 'Επιλογή ημερομηνίας'
                              : _dateFormat.format(_toDate!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // CARD: MOVEMENT TYPE
  // ──────────────────────────────────────────────────────────

  Widget _buildTypeCard() {
    return Card(
      elevation: 2,
      color: context.cSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('Τύπος Κινήσεων',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.cText)),
            ),
            const SizedBox(height: 4),
            Text(
              'Επιλέξτε Έσοδα ή Έξοδα',
              style: TextStyle(color: context.cText2, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Semantics(
                  label: 'Έσοδα, '
                      '${_movementType == 'income' ? 'επιλεγμένο' : 'μη επιλεγμένο'}',
                  child: CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const ExcludeSemantics(child: Text('Έσοδα')),
                    value: _movementType == 'income',
                    activeColor: ColorsUI.getIncomeColor(
                        context.brightness),
                    onChanged: (_) => _onToggleMovementType('income'),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  label: 'Έξοδα, '
                      '${_movementType == 'expense' ? 'επιλεγμένο' : 'μη επιλεγμένο'}',
                  child: CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const ExcludeSemantics(child: Text('Έξοδα')),
                    value: _movementType == 'expense',
                    activeColor: ColorsUI.getExpenseColor(
                        context.brightness),
                    onChanged: (_) => _onToggleMovementType('expense'),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // CARD: ACCOUNTS (ΝΕΟ)
  // ──────────────────────────────────────────────────────────

  Widget _buildAccountsCard(List<AccountModel> accounts) {
    return Card(
      elevation: 2,
      color: context.cSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Λογαριασμοί',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.cText,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Επιλέξτε έναν ή περισσότερους λογαριασμούς',
              style: TextStyle(color: context.cText2, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...accounts.map((acc) {
              final selected = _selectedAccounts[acc.uuid] ?? false;
              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(acc.name),
                subtitle: Text(
                  'Υπόλοιπο: ${CurrencyFormatter.format(acc.currentBalance)}',
                ),
                value: selected,
                onChanged: (val) => _onToggleAccount(acc.uuid, val),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // CARD: TAGS
  // ──────────────────────────────────────────────────────────

  Widget _buildTagsCard(List<TagModel> tags) {
    return Card(
      key: const ValueKey('tags_card'),
      elevation: 2,
      color: context.cSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  ExcludeSemantics(
                    child: Icon(Icons.label_rounded,
                        color: context.cPrimary, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    header: true,
                    child: Text('Tags',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.cText)),
                  ),
                ]),
                Row(children: [
                  Semantics(
                    button: true,
                    label: 'Επιλογή όλων tags',
                    child: TextButton(
                      onPressed: () => _selectAllTags(tags),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8)),
                      child: Text('Όλα',
                          style: TextStyle(
                              fontSize: 11,
                              color: context.cPrimary)),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Καθαρισμός επιλογής tags',
                    child: TextButton(
                      onPressed: () => _clearAllTags(tags),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8)),
                      child: Text('Καθαρισμός',
                          style: TextStyle(
                              fontSize: 11,
                              color: context.cText2)),
                    ),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Επιλέξτε τα tags που θέλετε να συμπεριλάβετε',
              style: TextStyle(color: context.cText2, fontSize: 12),
            ),
            const SizedBox(height: 10),

            // ── Tag checkboxes ────────────────────────────────
            ...tags.map((tag) {
              final selected = _selectedTags[tag.uuid] ?? false;
              Color tagColor;
              try {
                final hex = tag.color.replaceAll('#', '');
                tagColor = Color(int.parse('FF$hex', radix: 16));
              } catch (_) {
                tagColor = context.cPrimary;
              }

              return Semantics(
                label: '${tag.name}, '
                    '${selected ? 'επιλεγμένο' : 'μη επιλεγμένο'}',
                child: CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: tagColor,
                  value: selected,
                  onChanged: (val) => _onToggleTag(tag.uuid, val),
                  title: ExcludeSemantics(
                    child: Row(children: [
                      Container(
                        width:  12,
                        height: 12,
                        decoration: BoxDecoration(
                          color:  tagColor,
                          shape:  BoxShape.circle,
                          border: Border.all(
                            color: context.cText2.withValues(
                                alpha: 0.30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(tag.name,
                          style: TextStyle(
                              color: context.cText, fontSize: 14)),
                    ]),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTagsCard() {
    return Card(
      key: const ValueKey('no_tags_card'),
      elevation: 2,
      color: context.cSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          ExcludeSemantics(
            child: Icon(Icons.label_off_rounded,
                color: context.cText2, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Δεν υπάρχουν διαθέσιμα tags. '
                  'Δημιουργήστε tags από τη Διαχείριση Tags.',
              style: TextStyle(
                  color: context.cText2, fontSize: 13),
            ),
          ),
        ]),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // CARD: SORTING & GROUPING
  // ──────────────────────────────────────────────────────────

  Widget _buildSortingGroupingCard() {
    return Card(
      elevation: 2,
      color: context.cSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('Ταξινόμηση & Ομαδοποίηση',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.cText)),
            ),
            const SizedBox(height: 10),
            Text('Ταξινόμηση:',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.cText)),
            const SizedBox(height: 4),
            DropdownButtonFormField<_TagSortOption>(
              initialValue: _sortBy,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: ExcludeSemantics(
                    child: Icon(Icons.sort)),
              ),
              items: _TagSortOption.values
                  .map((o) => DropdownMenuItem(
                value: o,
                child: Text(o.label,
                    style: const TextStyle(fontSize: 12)),
              ))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _sortBy = val);
              },
            ),
            const SizedBox(height: 12),
            Text('Ομαδοποίηση:',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.cText)),
            const SizedBox(height: 4),
            DropdownButtonFormField<_TagGroupOption>(
              initialValue: _groupBy,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: ExcludeSemantics(
                    child: Icon(Icons.grid_view)),
              ),
              items: _TagGroupOption.values
                  .map((o) => DropdownMenuItem(
                value: o,
                child: Text(o.label,
                    style: const TextStyle(fontSize: 12)),
              ))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _groupBy = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // CARD: COMMENTS
  // ──────────────────────────────────────────────────────────

  Widget _buildCommentsCheckbox() {
    return Card(
      elevation: 2,
      color: context.cSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Semantics(
        label: 'Συμπερίληψη σχολίων, '
            '${_includeComments ? 'ενεργό' : 'ανενεργό'}',
        child: CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: const ExcludeSemantics(
              child: Text('Συμπερίληψη Σχολίων')),
          subtitle: ExcludeSemantics(
            child: Text(
              'Εμφάνιση σχολίων κινήσεων στο report',
              style: TextStyle(color: context.cText2, fontSize: 12),
            ),
          ),
          value: _includeComments,
          onChanged: (val) =>
              setState(() => _includeComments = val ?? false),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // CARD: SUMMARY (ενημερωμένο με λογαριασμούς)
  // ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(List<AccountModel> accounts, List<TagModel> tags) {
    final selectedAccountsCount = _selectedAccounts.values.where((v) => v).length;
    final selectedTagsCount = _selectedTags.values.where((v) => v).length;

    final periodText = (_fromDate != null && _toDate != null)
        ? '${_dateFormat.format(_fromDate!)} – '
        '${_dateFormat.format(_toDate!)}'
        : '–';

    final bg = context.brightness == Brightness.dark
        ? context.cSurface
        : context.cPrimary.withValues(alpha: 0.08);
    final fg = ColorsUI.getAccessibleTextColor(bg);

    return Card(
      elevation: 3,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: context.cPrimary.withValues(alpha: 0.35), width: 1.2),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg),
        child: IconTheme.merge(
          data: IconThemeData(color: fg),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  ExcludeSemantics(
                    child: Icon(Icons.summarize,
                        color: context.cPrimary, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    header: true,
                    child: Text('Περίληψη Επιλογών',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.cPrimary)),
                  ),
                ]),
                const SizedBox(height: 10),
                _summaryRow(Icons.calendar_month, 'Περίοδος',
                    periodText),
                _summaryRow(
                    Icons.compare_arrows,
                    'Τύπος',
                    _movementType == 'income' ? 'Έσοδα' : 'Έξοδα'),
                _summaryRow(
                    Icons.account_balance_wallet,
                    'Λογαριασμοί',
                    selectedAccountsCount == 0
                        ? 'Κανένας'
                        : '$selectedAccountsCount επιλεγμένοι'),
                _summaryRow(
                    Icons.label_rounded,
                    'Tags',
                    '$selectedTagsCount επιλεγμένα'),
                _summaryRow(
                    Icons.sort, 'Ταξινόμηση', _sortBy.label),
                _summaryRow(
                    Icons.grid_view, 'Ομαδοποίηση', _groupBy.label),
                _summaryRow(
                    Icons.comment,
                    'Σχόλια',
                    _includeComments ? 'Ναι' : 'Όχι'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: ExcludeSemantics(
          child: Row(children: [
            Icon(icon, size: 15, color: context.cPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$label: $value',
                  style: TextStyle(
                      color: context.cText2, fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // BUTTON: GENERATE
  // ──────────────────────────────────────────────────────────

  Widget _buildGenerateButton({
    required bool canGenerate,
    required VoidCallback onPressed,
  }) {
    final onPrimary = context.cOnPrimary;
    return Center(
      child: Semantics(
        button:  true,
        label:   'Δημιουργία αναφοράς από Tags',
        enabled: canGenerate && !_isGenerating,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor:
            canGenerate ? context.cPrimary : Colors.grey,
            foregroundColor:
            canGenerate ? onPrimary : Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: canGenerate ? 4 : 0,
          ),
          icon: _isGenerating
              ? SizedBox(
            height: 18,
            width:  18,
            child: ExcludeSemantics(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  canGenerate ? onPrimary : Colors.white,
                ),
              ),
            ),
          )
              : ExcludeSemantics(
            child: Icon(Icons.label_rounded,
                size: 20,
                color: canGenerate ? onPrimary : Colors.white),
          ),
          label: Text(
            _isGenerating
                ? 'Δημιουργία αναφοράς...'
                : 'Δημιουργία Αναφοράς',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold),
          ),
          onPressed: (canGenerate && !_isGenerating) ? onPressed : null,
        ),
      ),
    );
  }
}

// ============================================================
// DATA CLASSES
// ============================================================

class _TagReportRow {
  final DateTime date;
  final String   accountName;
  final String   categoryName;
  final String   subcategoryName;
  final double   amount;
  final String?  notes;
  final String   tagNames;
  final List<String> tagColors;

  _TagReportRow({
    required this.date,
    required this.accountName,
    required this.categoryName,
    required this.subcategoryName,
    required this.amount,
    this.notes,
    this.tagNames  = '',
    this.tagColors = const [],
  });
}

// ============================================================
// ENUMS
// ============================================================

enum _TagSortOption {
  dateDesc( 'Ημερομηνία (Νεότερη → Παλαιότερη)'),
  dateAsc(  'Ημερομηνία (Παλαιότερη → Νεότερη)'),
  amountDesc('Ποσό (Μεγαλύτερο → Μικρότερο)'),
  amountAsc( 'Ποσό (Μικρότερο → Μεγαλύτερο)'),
  category(  'Κατηγορία (Αλφαβητικά)'),
  account(   'Λογαριασμός (Αλφαβητικά)'),
  tag(       'Tag (Αλφαβητικά)');

  final String label;
  const _TagSortOption(this.label);
}

enum _TagGroupOption {
  none(       'Χωρίς ομαδοποίηση'),
  tag(        'Ανά Tag'),
  category(   'Ανά Κατηγορία'),
  subcategory('Ανά Υποκατηγορία'),
  account(    'Ανά Λογαριασμό'),
  day(        'Ανά Ημέρα'),
  month(      'Ανά Μήνα');

  final String label;
  const _TagGroupOption(this.label);
}