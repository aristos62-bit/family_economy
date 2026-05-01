// ============================================================
// FILE: stats_page.dart
// Path: lib/presentation/screens/stats/stats_page.dart (ή όπου το κρατάς)
// Firebase + Providers (offline-safe) + Export Excel/PDF
// ✅ Compatible with:
//   - AccountsProvider (uuid/name/currency/currentBalance/displayOrder)
//   - CategoriesProvider (getCategoriesByType / getSubcategoriesForCategory)
//   - TransactionsProvider (loadPeriod + cache + listener)
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

import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';
import 'package:family_economy/providers/tags_provider.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  // ------------------ STATE ------------------

  DateTime? _fromDate;
  DateTime? _toDate;

  bool _includeComments = false;
  bool _isGenerating = false;

  String? _movementType; // 'income' | 'expense'

  // selections by uuid
  final Map<String, bool> _selectedAccounts = {};
  final Map<String, bool> _selectedCategories = {};
  final Map<String, Map<String, bool>> _selectedSubcategories = {};
  final Map<String, bool> _expandedCategories = {};

  _SortOption _sortBy = _SortOption.dateDesc;
  _GroupOption _groupBy = _GroupOption.none;

  // last report cache
  List<_ReportRow> _lastReportRows = [];
  DateTime? _lastFromDate;
  DateTime? _lastToDate;
  String? _lastMovementType;
  bool _lastIncludeComments = false;
  _SortOption? _lastSortBy;
  _GroupOption? _lastGroupBy;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _reportDateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  // ✅ avoid spam loadPeriod in build
  bool _loadScheduled = false;
  DateTime? _listeningStart;
  DateTime? _listeningEnd;

  static const String _periodKey = 'STATS_PAGE';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month + 1, 0);
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Ανάλυση Εσόδων Εξόδων. '
      'Επιλέξτε χρονικό διάστημα, τύπο κινήσεων και κατηγορίες.',
    );
  }

  // ------------------ HELPERS ------------------

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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
  }

  void _onToggleMovementType(String type) {
    setState(() {
      if (_movementType == type) {
        _movementType = null;
      } else {
        _movementType = type;
      }

      // reset selections when type changes
      _selectedCategories.clear();
      _selectedSubcategories.clear();
      _expandedCategories.clear();
      _lastReportRows = [];
    });
  }

  void _toggleCategoryExpansion(String categoryId) {
    setState(() {
      _expandedCategories[categoryId] =
          !(_expandedCategories[categoryId] ?? false);
    });
  }

  void _onCategoryChanged(
    String categoryId,
    bool? value, {
    required List<SubcategoryModel> subs,
  }) {
    setState(() {
      _selectedCategories[categoryId] = value ?? false;

      _selectedSubcategories.putIfAbsent(categoryId, () => {});
      if (value == true) {
        for (final s in subs) {
          _selectedSubcategories[categoryId]![s.uuid] = true;
        }
        _expandedCategories[categoryId] = true;
      } else {
        for (final s in subs) {
          _selectedSubcategories[categoryId]![s.uuid] = false;
        }
      }
    });
  }

  void _onSubcategoryChanged(
    String categoryId,
    String subcategoryId,
    bool? value,
  ) {
    setState(() {
      _selectedSubcategories.putIfAbsent(categoryId, () => {});
      _selectedSubcategories[categoryId]![subcategoryId] = value ?? false;

      if (value == true) {
        _selectedCategories[categoryId] = true;
      } else {
        final anySubSelected =
            _selectedSubcategories[categoryId]?.values.any((v) => v == true) ??
            false;
        if (!anySubSelected) _selectedCategories[categoryId] = false;
      }
    });
  }

  bool _hasSelectedSubcategories(List<CategoryModel> visibleCats) {
    for (final cat in visibleCats) {
      final subMap = _selectedSubcategories[cat.uuid];
      if (subMap == null) continue;
      if (subMap.values.any((v) => v == true)) return true;
    }
    return false;
  }

  bool _canGenerateReport(List<CategoryModel> visibleCats) {
    return _fromDate != null &&
        _toDate != null &&
        _movementType != null &&
        _selectedAccounts.values.any((v) => v == true) &&
        _hasSelectedSubcategories(visibleCats);
  }

  double _calculateTotal(List<_ReportRow> rows) {
    return rows.fold(0.0, (sum, row) => sum + row.amount);
  }

  // ------------------ OFFLINE-SAFE: Load period from TransactionsProvider ------------------

  void _ensureTransactionsListener({
    required TransactionsProvider transactionsP,
    required DateTime from,
    required DateTime to,
  }) {
    final rangeChanged =
        _listeningStart == null ||
        _listeningEnd == null ||
        _listeningStart != from ||
        _listeningEnd != to;

    if (!rangeChanged || _loadScheduled) return;

    _listeningStart = from;
    _listeningEnd = to;
    _loadScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!mounted) return;

      transactionsP.loadPeriod(_periodKey, from, to);
    });
  }

  // ------------------ REPORT GENERATION ------------------

  Future<void> _generateReport({
    required AccountsProvider accountsP,
    required CategoriesProvider categoriesP,
    required TransactionsProvider transactionsP,
    required List<CategoryModel> visibleCategories,
    required Map<String, List<SubcategoryModel>> subsByCategory,
  }) async {
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Παρακαλώ επιλέξτε χρονικό διάστημα.'),
          behavior: SnackBarBehavior.fixed,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_movementType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Παρακαλώ επιλέξτε Έσοδα ή Έξοδα.'),
          behavior: SnackBarBehavior.fixed,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_selectedAccounts.values.any((v) => v == true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Παρακαλώ επιλέξτε τουλάχιστον έναν λογαριασμό.'),
          behavior: SnackBarBehavior.fixed,
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_hasSelectedSubcategories(visibleCategories)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Παρακαλώ επιλέξτε τουλάχιστον μία υποκατηγορία.'),
          behavior: SnackBarBehavior.fixed,
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final from = DateTime(
        _fromDate!.year,
        _fromDate!.month,
        _fromDate!.day,
        0,
        0,
        0,
      );
      final to = DateTime(
        _toDate!.year,
        _toDate!.month,
        _toDate!.day,
        23,
        59,
        59,
      );

      final selectedAccountIds = _selectedAccounts.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toSet();

      final selectedCategoryIds = _selectedCategories.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toSet();

      final selectedSubIds = <String>{};
      _selectedSubcategories.forEach((catId, subMap) {
        subMap.forEach((subId, selected) {
          if (selected == true) selectedSubIds.add(subId);
        });
      });

      // ✅ Single-source filter (provider helper) — no duplicated filters here
      final filtered = transactionsP.getFilteredTransactionsForPeriod(
        _periodKey,
        includeTransfers: false,
        includeFuture:
            false, // keep same behavior as provider's future-filter intent
        from: from,
        to: to,
        accountIds: selectedAccountIds,
        categoryIds: selectedCategoryIds,
        subcategoryIds: selectedSubIds,
        movementType: _movementType, // 'income' | 'expense'
        categoryTypeOf: (categoryId) {
          final cat = categoriesP.getCategoryByUuid(categoryId);
          return cat?.type;
        },
      );

      if (filtered.isEmpty) {
        if (!mounted) return;

        setState(() {
          _isGenerating = false;
          _lastReportRows = [];
        });

        Future.delayed(Duration.zero, () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Δεν βρέθηκαν κινήσεις για τα κριτήρια που επιλέξατε.',
              ),
              behavior: SnackBarBehavior.fixed,
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        });

        return;
      }

      // Build report rows with provider lookups
      final rows = <_ReportRow>[];
      for (final t in filtered) {
        final acc = accountsP.getAccountByUuid(t.accountId);
        final cat = t.categoryId != null
            ? categoriesP.getCategoryByUuid(t.categoryId!)
            : null;

        String subName = '';
        if (t.categoryId != null && t.subcategoryId != null) {
          final sub = categoriesP.getSubcategoryByUuid(
            t.categoryId!,
            t.subcategoryId!,
          );
          subName = sub?.name ?? '';
        }

        // ✅ ΝΕΟ: Tags
        final tagsProvider = context.read<TagsProvider>();
        final tagModels = tagsProvider.getTagsByIds(t.tagIds);
        final tagNames = tagModels.map((t) => t.name).join(', ');

        rows.add(
          _ReportRow(
            date: t.date,
            accountName: acc?.name ?? '',
            categoryName: cat?.name ?? '',
            subcategoryName: subName,
            amount: t.amount,
            notes: t.notes,
            tagNames: tagNames, // ✅ ΝΕΟ
          ),
        );
      }

      _applySorting(rows);

      _lastReportRows = rows;
      _lastFromDate = _fromDate;
      _lastToDate = _toDate;
      _lastMovementType = _movementType;
      _lastIncludeComments = _includeComments;
      _lastSortBy = _sortBy;
      _lastGroupBy = _groupBy;

      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showReportPreviewDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Σφάλμα κατά τη δημιουργία report: $e'),
          behavior: SnackBarBehavior.fixed,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applySorting(List<_ReportRow> rows) {
    switch (_sortBy) {
      case _SortOption.dateAsc:
        rows.sort((a, b) => a.date.compareTo(b.date));
        break;
      case _SortOption.dateDesc:
        rows.sort((a, b) => b.date.compareTo(a.date));
        break;
      case _SortOption.amountAsc:
        rows.sort((a, b) => a.amount.abs().compareTo(b.amount.abs()));
        break;
      case _SortOption.amountDesc:
        rows.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
        break;
      case _SortOption.category:
        rows.sort((a, b) {
          final catCompare = a.categoryName.compareTo(b.categoryName);
          if (catCompare != 0) return catCompare;
          return a.subcategoryName.compareTo(b.subcategoryName);
        });
        break;
      case _SortOption.account:
        rows.sort((a, b) => a.accountName.compareTo(b.accountName));
        break;
    }
  }

  Map<String, List<_ReportRow>> _groupRows(List<_ReportRow> rows) {
    if (_groupBy == _GroupOption.none) {
      return {'Όλες οι Κινήσεις': rows};
    }

    final Map<String, List<_ReportRow>> grouped = {};
    for (final row in rows) {
      String key;
      switch (_groupBy) {
        case _GroupOption.category:
          key = row.categoryName;
          break;
        case _GroupOption.subcategory:
          key = '${row.categoryName} → ${row.subcategoryName}';
          break;
        case _GroupOption.account:
          key = row.accountName;
          break;
        case _GroupOption.day:
          key = _dateFormat.format(row.date);
          break;
        case _GroupOption.month:
          key = DateFormat('MMMM yyyy', 'el_GR').format(row.date);
          break;
        case _GroupOption.none:
          key = 'Όλες οι Κινήσεις';
          break;
      }
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(row);
    }
    return grouped;
  }

  Map<String, double> _calculateSubtotals(
    Map<String, List<_ReportRow>> grouped,
  ) {
    final Map<String, double> subtotals = {};
    grouped.forEach((key, rows) {
      subtotals[key] = _calculateTotal(rows);
    });
    return subtotals;
  }

  // ------------------ PREVIEW DIALOG ------------------

  void _showReportPreviewDialog() {
    final grouped = _groupRows(_lastReportRows);
    final subtotals = _calculateSubtotals(grouped);
    final grandTotal = _calculateTotal(_lastReportRows);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.cSurface,
          title: const Text('Προεπισκόπηση Αναφοράς'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_lastFromDate != null && _lastToDate != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      'Περίοδος: ${_dateFormat.format(_lastFromDate!)} – ${_dateFormat.format(_lastToDate!)}',
                      style: TextStyle(color: context.cText2, fontSize: 12),
                    ),
                  ),
                if (_lastMovementType != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      'Τύπος: ${_lastMovementType == 'income' ? 'Έσοδα' : 'Έξοδα'}',
                      style: TextStyle(color: context.cText2, fontSize: 12),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  margin: const EdgeInsets.only(bottom: 8.0),
                  decoration: BoxDecoration(
                    color: context.cPrimary.withValues(alpha: 0.10),
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
                        label: 'Γενικό σύνολο ${CurrencyFormatter.format(grandTotal.abs())}',
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
                Divider(color: context.cText2.withValues(alpha: 0.25)),
                Flexible(
                  child: SingleChildScrollView(
                    child: _buildGroupedReportTable(grouped, subtotals),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: _exportToExcel,
              icon: const ExcludeSemantics(child: Icon(Icons.table_chart)),
              label: const Text('Excel'),
            ),
            TextButton.icon(
              onPressed: _exportToPdf,
              icon: const ExcludeSemantics(child: Icon(Icons.picture_as_pdf)),
              label: const Text('PDF'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Κλείσιμο'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupedReportTable(
    Map<String, List<_ReportRow>> grouped,
    Map<String, double> subtotals,
  ) {
    final List<Widget> sections = [];

    grouped.forEach((groupName, rows) {
      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_groupBy != _GroupOption.none)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 12.0,
                ),
                margin: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                decoration: BoxDecoration(
                  color: context.cSurface,
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
                      CurrencyFormatter.format(subtotals[groupName]!.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.cPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16.0,
                horizontalMargin: 8.0,
                columns: [
                  const DataColumn(label: Text('Ημ/νία')),
                  if (_groupBy != _GroupOption.account)
                    const DataColumn(label: Text('Λογαριασμός')),
                  if (_groupBy != _GroupOption.category &&
                      _groupBy != _GroupOption.subcategory)
                    const DataColumn(label: Text('Κατηγορία')),
                  if (_groupBy != _GroupOption.subcategory)
                    const DataColumn(label: Text('Υποκατηγορία')),
                  const DataColumn(label: Text('Ποσό')),
                  const DataColumn(label: Text('Tags')), // ✅ ΝΕΟ
                  if (_lastIncludeComments)
                    const DataColumn(label: Text('Σχόλια')),
                ],
                rows: rows.map((r) {
                  final cells = <DataCell>[
                    DataCell(Text(_dateFormat.format(r.date))),
                    if (_groupBy != _GroupOption.account)
                      DataCell(Text(r.accountName)),
                    if (_groupBy != _GroupOption.category &&
                        _groupBy != _GroupOption.subcategory)
                      DataCell(Text(r.categoryName)),
                    if (_groupBy != _GroupOption.subcategory)
                      DataCell(Text(r.subcategoryName)),
                    DataCell(Text(CurrencyFormatter.format(r.amount.abs()))),
                    DataCell(Text(r.tagNames)), // ✅ ΝΕΟ
                  ];
                  if (_lastIncludeComments) {
                    cells.add(DataCell(Text((r.notes ?? '').toString())));
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

  // ------------------ EXPORT EXCEL ------------------

  Future<void> _exportToExcel() async {
    if (_lastReportRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Δεν υπάρχει διαθέσιμο report προς εξαγωγή.'),
          behavior: SnackBarBehavior.fixed,
        ),
      );
      return;
    }

    try {
      final excel = Excel.createExcel();
      for (final name in excel.sheets.keys.toList()) {
        excel.delete(name);
      }
      final sheet = excel['Αναφορά'];
      excel.setDefaultSheet('Αναφορά');

      final reportGeneratedAt = DateTime.now();

      sheet.appendRow([
        TextCellValue('Ημερομηνία Αναφοράς:'),
        TextCellValue(_reportDateTimeFormat.format(reportGeneratedAt)),
      ]);
      sheet.appendRow([TextCellValue('')]);

      sheet.appendRow([
        TextCellValue('Περίοδος:'),
        TextCellValue(
          '${_dateFormat.format(_lastFromDate!)} - ${_dateFormat.format(_lastToDate!)}',
        ),
      ]);
      sheet.appendRow([
        TextCellValue('Τύπος:'),
        TextCellValue(_lastMovementType == 'income' ? 'Έσοδα' : 'Έξοδα'),
      ]);
      sheet.appendRow([TextCellValue('')]);

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

      final grouped = _groupRows(_lastReportRows);
      final subtotals = _calculateSubtotals(grouped);
      final grandTotal = _calculateTotal(_lastReportRows);

      final headers = <String>[
        'Ημ/νία',
        'Λογαριασμός',
        'Κατηγορία',
        'Υποκατηγορία',
        'Ποσό',
        'Tags',
      ];
      if (_lastIncludeComments) headers.add('Σχόλια');

      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      grouped.forEach((groupName, rows) {
        if (_groupBy != _GroupOption.none) {
          sheet.appendRow([
            TextCellValue(''),
            TextCellValue(groupName),
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
            row.add(TextCellValue((r.notes ?? '').toString()));
          }
          sheet.appendRow(row);
        }

        if (_groupBy != _GroupOption.none) {
          sheet.appendRow([TextCellValue('')]);
        }
      });

      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('ΓΕΝΙΚΟ ΣΥΝΟΛΟ:'),
        TextCellValue(CurrencyFormatter.format(grandTotal.abs())),
      ]);

      final bytes = excel.encode();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Σφάλμα κατά τη δημιουργία του Excel.'),
            behavior: SnackBarBehavior.fixed,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'Αναφορά_Στατιστικών_$ts.xlsx';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Αποθήκευση Αναφοράς Excel',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );

      if (savePath == null) return;
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.check_circle, color: Colors.white),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Το Excel αποθηκεύτηκε επιτυχώς!')),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Σφάλμα εξαγωγής: $e'),
          behavior: SnackBarBehavior.fixed,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ------------------ EXPORT PDF ------------------

  Future<void> _exportToPdf() async {
    if (_lastReportRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Δεν υπάρχει διαθέσιμο report προς εξαγωγή.'),
          behavior: SnackBarBehavior.fixed,
        ),
      );
      return;
    }

    try {
      final ttf = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
      );

      final pdf = pw.Document();

      final grouped = _groupRows(_lastReportRows);
      final subtotals = _calculateSubtotals(grouped);
      final grandTotal = _calculateTotal(_lastReportRows);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: ttf,
            bold: ttf,
            italic: ttf,
            boldItalic: ttf,
          ),
          build: (context) {
            final content = <pw.Widget>[];

            content.add(
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Αναφορά Στατιστικών',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            );

            final reportGeneratedAt = DateTime.now();

            content.add(
              pw.Text(
                'Ημερομηνία Αναφοράς: ${_reportDateTimeFormat.format(reportGeneratedAt)}',
                style: const pw.TextStyle(fontSize: 11),
              ),
            );

            content.add(pw.SizedBox(height: 6));

            content.add(
              pw.Text(
                'Περίοδος: ${_dateFormat.format(_lastFromDate!)} - ${_dateFormat.format(_lastToDate!)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            );

            content.add(
              pw.Text(
                'Τύπος: ${_lastMovementType == "income" ? "Έσοδα" : "Έξοδα"}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            );

            content.add(pw.SizedBox(height: 12));

            content.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E3F2FD'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Γενικό Σύνολο:',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      CurrencyFormatter.format(grandTotal.abs()),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );

            content.add(pw.SizedBox(height: 12));

            grouped.forEach((groupName, rows) {
              if (_groupBy != _GroupOption.none) {
                content.add(
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
                    color: PdfColor.fromHex('#EEEEEE'),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          groupName,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        pw.Text(
                          'Υποσύνολο: ${CurrencyFormatter.format(subtotals[groupName]!.abs())}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final headers = [
                'Ημ/νία',
                'Λογαριασμός',
                'Κατηγορία',
                'Υποκατηγορία',
                'Ποσό',
                'Tags',
                if (_lastIncludeComments) 'Σχόλια',
              ];

              final data = rows.map((r) {
                return [
                  _dateFormat.format(r.date),
                  r.accountName,
                  r.categoryName,
                  r.subcategoryName,
                  CurrencyFormatter.format(r.amount.abs()),
                  r.tagNames,
                  if (_lastIncludeComments) (r.notes ?? ''),
                ];
              }).toList();

              content.add(
                pw.TableHelper.fromTextArray(
                  headers: headers,
                  data: data,
                  headerStyle: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#DDDDDD'),
                  ),
                  border: pw.TableBorder.all(
                    color: PdfColor.fromHex('#BBBBBB'),
                  ),
                  cellPadding: const pw.EdgeInsets.all(4),
                ),
              );
            });

            return content;
          },
        ),
      );

      final bytes = await pdf.save();

      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'Αναφορά_Στατιστικών_$ts.pdf';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Αποθήκευση Αναφοράς PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: Uint8List.fromList(bytes),
      );

      if (savePath == null) return;
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Το PDF αποθηκεύτηκε επιτυχώς!')),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Σφάλμα PDF: $e'),
          behavior: SnackBarBehavior.fixed,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ------------------ BUILD UI ------------------

  @override
  Widget build(BuildContext context) {
    // keep session available like other pages
    final _ = context.session.userId;

    return Consumer3<
      AccountsProvider,
      CategoriesProvider,
      TransactionsProvider
    >(
      builder: (context, accountsP, categoriesP, transactionsP, _) {
        // Handle loading gracefully (providers are real-time)
        final from = _fromDate ?? DateTime.now();
        final to = _toDate ?? DateTime.now();

        // ✅ load transactions period (offline-safe)
        _ensureTransactionsListener(
          transactionsP: transactionsP,
          from: from,
          to: to,
        );

        // ACCOUNTS
        final accounts = accountsP.accounts;
        for (final a in accounts) {
          _selectedAccounts.putIfAbsent(a.uuid, () => false);
        }
        _selectedAccounts.removeWhere(
          (k, _) => accounts.every((a) => a.uuid != k),
        );

        // CATEGORIES (provider already sorts by displayOrder)
        final visibleCategories = _movementType == null
            ? <CategoryModel>[]
            : categoriesP.getCategoriesByType(_movementType!);

        // SUBCATEGORIES (provider already sorts by displayOrder)
        final subsByCategory = <String, List<SubcategoryModel>>{};
        for (final cat in visibleCategories) {
          subsByCategory[cat.uuid] = categoriesP.getSubcategoriesForCategory(
            cat.uuid,
          );
          // TAGS (provider
          context.watch<TagsProvider>();
          // final tags = tagsProvider.tags;
        }

        // init selection keys
        for (final cat in visibleCategories) {
          _selectedCategories.putIfAbsent(cat.uuid, () => false);
          _expandedCategories.putIfAbsent(cat.uuid, () => false);

          _selectedSubcategories.putIfAbsent(cat.uuid, () => {});
          for (final s in (subsByCategory[cat.uuid] ?? [])) {
            _selectedSubcategories[cat.uuid]!.putIfAbsent(s.uuid, () => false);
          }
        }

        final canGenerate = _canGenerateReport(visibleCategories);

        return Scaffold(
          backgroundColor: context.cBg,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(
                    top: 18,
                    bottom: 18,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    color: context.cPrimary,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
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
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Ανάλυση Εσόδων Εξόδων',
                            style: TextStyle(
                              color: context.cOnPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.normal,
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
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 10,
                      left: 16,
                      right: 16,
                    ),
                    child: ListView(
                      children: [
                        _buildDateRangeCard(),
                        const SizedBox(height: 10),
                        _buildTypeCard(),
                        const SizedBox(height: 10),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _movementType != null
                              ? _buildAccountsCard(accountsP.accounts)
                              : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child:
                              _movementType != null &&
                                  _selectedAccounts.containsValue(true)
                              ? _buildCategoriesCard(
                                  visibleCategories,
                                  subsByCategory,
                                )
                              : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _selectedCategories.containsValue(true)
                              ? _buildSortingGroupingCard()
                              : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _selectedCategories.containsValue(true)
                              ? _buildCommentsCheckbox()
                              : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: canGenerate
                              ? _buildSummaryCard()
                              : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: canGenerate
                              ? _buildGenerateButton(
                                  canGenerate: canGenerate,
                                  onPressed: () {
                                    AccessibilityService.announcePolite(
                                      'Δημιουργία αναφοράς...',
                                    );
                                    _generateReport(
                                      accountsP: accountsP,
                                      categoriesP: categoriesP,
                                      transactionsP: transactionsP,
                                      visibleCategories: visibleCategories,
                                      subsByCategory: subsByCategory,
                                    );
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------ UI SECTIONS ------------------

  Widget _buildDateRangeCard() {
    return Card(
      elevation: 2,
      color: context.cSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.calendar_month,
                    color: context.cPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  header: true,
                  child: Text(
                    'Χρονικό Διάστημα',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.cText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label:
                        'Ημερομηνία από. Τρέχουσα: ${_fromDate == null ? 'Μη επιλεγμένη' : _dateFormat.format(_fromDate!)}',
                    child: InkWell(
                      onTap: () => _pickDate(isFrom: true),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Από',
                          border: const OutlineInputBorder(),
                          prefixIcon: const ExcludeSemantics(
                            child: Icon(Icons.calendar_today),
                          ),
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
                        'Ημερομηνία έως. Τρέχουσα: ${_toDate == null ? 'Μη επιλεγμένη' : _dateFormat.format(_toDate!)}',
                    child: InkWell(
                      onTap: () => _pickDate(isFrom: false),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Έως',
                          border: const OutlineInputBorder(),
                          prefixIcon: const ExcludeSemantics(
                            child: Icon(Icons.calendar_today),
                          ),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard() {
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
                'Τύπος Κινήσεων',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.cText,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Επιλέξτε Έσοδα ή Έξοδα (όχι και τα δύο)',
              style: TextStyle(color: context.cText2, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Έσοδα'),
                    value: _movementType == 'income',
                    onChanged: (_) => _onToggleMovementType('income'),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Έξοδα'),
                    value: _movementType == 'expense',
                    onChanged: (_) => _onToggleMovementType('expense'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
                onChanged: (val) =>
                    setState(() => _selectedAccounts[acc.uuid] = val ?? false),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesCard(
    List<CategoryModel> visibleCategories,
    Map<String, List<SubcategoryModel>> subsByCategory,
  ) {
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
                'Κατηγορίες & Υποκατηγορίες',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.cText,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Η σειρά είναι σύμφωνα με display_order της βάσης.',
              style: TextStyle(color: context.cText2, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...visibleCategories.map((cat) {
              final catSelected = _selectedCategories[cat.uuid] ?? false;
              final subs = subsByCategory[cat.uuid] ?? [];
              final isExpanded = _expandedCategories[cat.uuid] ?? false;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(cat.name),
                          value: catSelected,
                          onChanged: (val) =>
                              _onCategoryChanged(cat.uuid, val, subs: subs),
                        ),
                      ),
                      if (subs.isNotEmpty)
                        Semantics(
                          button: true,
                          label: isExpanded
                              ? 'Σύμπτυξη κατηγορίας ${cat.name}'
                              : 'Ανάπτυξη κατηγορίας ${cat.name}',
                          child: IconButton(
                            icon: ExcludeSemantics(
                              child: Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: context.cPrimary,
                              ),
                            ),
                            onPressed: () => _toggleCategoryExpansion(cat.uuid),
                          ),
                        ),
                    ],
                  ),
                  if (isExpanded && subs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 24.0),
                      child: Column(
                        children: [
                          ...subs.map((s) {
                            final selected =
                                _selectedSubcategories[cat.uuid]?[s.uuid] ??
                                false;
                            return Column(
                              children: [
                                CheckboxListTile(
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(
                                    s.name,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  value: selected,
                                  onChanged: (val) => _onSubcategoryChanged(
                                    cat.uuid,
                                    s.uuid,
                                    val,
                                  ),
                                ),
                                ExcludeSemantics(
                                  child: Divider(
                                    height: 1,
                                    color: context.cText2.withValues(
                                      alpha: 0.20,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ExcludeSemantics(
                    child: Divider(
                      height: 1,
                      color: context.cText2.withValues(alpha: 0.20),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSortingGroupingCard() {
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
                'Ταξινόμηση & Ομαδοποίηση',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.cText,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ταξινόμηση:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.cText,
              ),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<_SortOption>(
              initialValue: _sortBy,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: ExcludeSemantics(child: Icon(Icons.sort)),
              ),
              items: _SortOption.values
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        o.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _sortBy = val);
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Ομαδοποίηση:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.cText,
              ),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<_GroupOption>(
              initialValue: _groupBy,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: ExcludeSemantics(child: Icon(Icons.grid_view)),
              ),
              items: _GroupOption.values
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        o.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
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

  Widget _buildCommentsCheckbox() {
    return Card(
      elevation: 2,
      color: context.cSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Σχόλια κινήσεων'),
        subtitle: const Text(
          'Αν επιλεγεί, στο report θα εμφανίζονται και τα σχόλια των κινήσεων',
        ),
        value: _includeComments,
        onChanged: (val) => setState(() => _includeComments = val ?? false),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final selectedAccountsCount = _selectedAccounts.values
        .where((v) => v)
        .length;
    final selectedCategoriesCount = _selectedCategories.values
        .where((v) => v)
        .length;

    int selectedSubcategoriesCount = 0;
    _selectedSubcategories.forEach((_, subMap) {
      selectedSubcategoriesCount += subMap.values.where((v) => v).length;
    });

    final periodText = (_fromDate != null && _toDate != null)
        ? '${_dateFormat.format(_fromDate!)} - ${_dateFormat.format(_toDate!)}'
        : '-';

    final bg = (context.brightness == Brightness.dark)
        ? context.cSurface
        : context.cPrimary.withValues(alpha: 0.08);

    final fg = ColorsUI.getAccessibleTextColor(bg);
    fg.withValues(alpha: 0.78);

    return Card(
      elevation: 3,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: context.cPrimary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: fg),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: fg),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.summarize,
                        color: context.cPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      header: true,
                      child: Text(
                        'Περίληψη Επιλογών',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.cPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _summaryRow(Icons.calendar_month, 'Περίοδος', periodText),
                _summaryRow(
                  Icons.compare_arrows,
                  'Τύπος',
                  _movementType == 'income' ? 'Έσοδα' : 'Έξοδα',
                ),
                _summaryRow(
                  Icons.account_balance_wallet,
                  'Λογαριασμοί',
                  selectedAccountsCount == 0
                      ? 'Κανένας'
                      : '$selectedAccountsCount επιλεγμένοι',
                ),
                _summaryRow(
                  Icons.category,
                  'Κατηγορίες',
                  '$selectedCategoriesCount επιλεγμένες',
                ),
                _summaryRow(
                  Icons.subdirectory_arrow_right,
                  'Υποκατηγορίες',
                  '$selectedSubcategoriesCount επιλεγμένες',
                ),
                _summaryRow(Icons.sort, 'Ταξινόμηση', _sortBy.label),
                _summaryRow(Icons.grid_view, 'Ομαδοποίηση', _groupBy.label),
                _summaryRow(
                  Icons.comment,
                  'Σχόλια',
                  _includeComments ? 'Ναι' : 'Όχι',
                ),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ExcludeSemantics(
          child: Row(
            children: [
              Icon(icon, size: 16, color: context.cPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label: $value',
                  style: TextStyle(color: context.cText2, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton({
    required bool canGenerate,
    required VoidCallback onPressed,
  }) {
    final onPrimary = context.cOnPrimary;

    return Center(
      child: Semantics(
        button: true,
        label: 'Δημιουργία αναφοράς',
        enabled: canGenerate && !_isGenerating,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: canGenerate ? context.cPrimary : Colors.grey,
            foregroundColor: canGenerate ? onPrimary : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: canGenerate ? 4 : 0,
          ),
          icon: _isGenerating
              ? SizedBox(
                  height: 18,
                  width: 18,
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
            child: Icon(
              Icons.summarize,
              size: 20,
              color: canGenerate ? onPrimary : Colors.white,
            ),
          ),
          label: Text(
            _isGenerating ? 'Δημιουργία αναφοράς...' : 'Δημιουργία Αναφοράς',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          onPressed: (canGenerate && !_isGenerating) ? onPressed : null,
        ),
      ),
    );
  }
}

// ------------------ DATA CLASSES ------------------

class _ReportRow {
  final DateTime date;
  final String accountName;
  final String categoryName;
  final String subcategoryName;
  final double amount;
  final String? notes;
  final String tagNames; // ✅ ΝΕΟ

  _ReportRow({
    required this.date,
    required this.accountName,
    required this.categoryName,
    required this.subcategoryName,
    required this.amount,
    this.notes,
    this.tagNames = '',
  });
}

enum _SortOption {
  dateDesc('Ημερομηνία (Νεότερη → Παλαιότερη)'),
  dateAsc('Ημερομηνία (Παλαιότερη → Νεότερη)'),
  amountDesc('Ποσό (Μεγαλύτερο → Μικρότερο)'),
  amountAsc('Ποσό (Μικρότερο → Μεγαλύτερο)'),
  category('Κατηγορία (Αλφαβητικά)'),
  account('Λογαριασμός (Αλφαβητικά)');

  final String label;
  const _SortOption(this.label);
}

enum _GroupOption {
  none('Χωρίς ομαδοποίηση'),
  category('Ανά Κατηγορία'),
  subcategory('Ανά Υποκατηγορία'),
  account('Ανά Λογαριασμό'),
  day('Ανά Ημέρα'),
  month('Ανά Μήνα');

  final String label;
  const _GroupOption(this.label);
}
