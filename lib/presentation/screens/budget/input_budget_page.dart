import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/core/utils/icon_mapper.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/CORE/widgets/custom_text_field.dart';
import 'package:family_economy/core/widgets/custom_currency_field.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';

import 'package:family_economy/models/budget_model.dart';
import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/budgets_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';
import 'package:family_economy/core/session/session_scope.dart';

class InputBudgetPage extends StatefulWidget {
  /// ✅ EDIT mode: περνάς όλα τα budgets ενός group
  final List<BudgetModel>? existingBudgets;

  const InputBudgetPage({
    super.key,
    this.existingBudgets,
  });

  @override
  State<InputBudgetPage> createState() => _InputBudgetPageState();
}

class _InputBudgetPageState extends State<InputBudgetPage> {
  // ============================================================
  // STATE
  // ============================================================

  final TextEditingController _nameController = TextEditingController();

  bool _isUpdatingFromSubcategory = false;

  String? _selectedAccountId; // null = όλοι
  String _periodTypeUi = 'Μήνας';
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = true;
  bool _isSubmitting = false;

  /// ✅ κρατάμε τη λογική “μόνο εισοδήματα” όπως στο παλιό (επηρεάζει τα έσοδα περιόδου)
  bool _onlyIncome = true;

  /// null = δεν έχει επιλέξει ακόμα, -1 = όλες, αλλιώς categoryId
  String? _selectedCategoryFilter;

  /// Controllers / amounts (uuid keys)
  final Map<String, TextEditingController> _amountControllers = {};
  final Map<String, double> _categoryAmounts = {};

  final Set<String> _expandedCategories = {};

  final Map<String, double> _subcategoryAmounts = {};
  final Map<String, TextEditingController> _subAmountControllers = {};

  final Map<String, bool> _categoryManual = {};

  String? _errorMessage;

  // ✅ NEW: debounce για να μην γίνεται setState συνέχεια
  Timer? _limitDebounce;
  static const Duration _limitDebounceDelay = Duration(milliseconds: 120);

  // ✅ NEW: schedule loadPeriod μετά το frame
  bool _txLoadScheduled = false;
  DateTime? _listeningStart;
  DateTime? _listeningEnd;

  // ✅ NEW: για να κάνουμε refresh “Έσοδα περιόδου” μόνο όταν αλλάξει το snapshot
  int _lastTxCount = -1;

  // chart colors (ίδια λογική)
  final List<Color> budgetColors = const [
    Color(0xFF563318),
    Color(0xFFCB09EC),
    Color(0xFFF10A0A),
    Color(0xFFF15A2A),
    Color(0xFFFFD54F),
    Color(0xFF098BF3),
    Color(0xFF0BF315),
    Color(0xFF081CEE),
    Color(0xFF623B1E),
    Color(0xFF5A8F37),
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _initializeDatesAndEditMode();
    AccessibilityService.announceAfterFirstFrame(
      context,
      widget.existingBudgets != null
          ? 'Επεξεργασία προϋπολογισμού. Τροποποιήστε τα στοιχεία και πατήστε Αποθήκευση.'
          : 'Νέος προϋπολογισμός. Συμπληρώστε τα στοιχεία και πατήστε Αποθήκευση.',
    );
  }

  void _initializeDatesAndEditMode() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);

    // EDIT MODE: διάβασε από το πρώτο budget
    if (widget.existingBudgets != null && widget.existingBudgets!.isNotEmpty) {
      final first = widget.existingBudgets!.first;
      _nameController.text = first.name ?? '';
      _selectedAccountId = first.accountId;
      _startDate = first.startDate;
      _endDate = first.endDate;

      // period type mapping
      _periodTypeUi = _mapPeriodTypeToUi(first.periodType);

      // Προαιρετικό: αν θες να “θυμάται” το onlyIncome, χρειάζεται field στο model.
      // Εδώ κρατάμε default true, όπως είπες να μην πειράζουμε μοντέλα.
      _onlyIncome = true;
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _mapPeriodTypeToUi(String pt) {
    switch (pt) {
      case 'monthly':
        return 'Μήνας';
      case 'weekly':
        return 'Εβδομάδα';
      case 'yearly':
        return 'Έτος';
      default:
        return 'Προσαρμοσμένο';
    }
  }

  String _mapUiToPeriodType(String ui) {
    if (ui == 'Μήνας') return 'monthly';
    if (ui == 'Εβδομάδα') return 'weekly';
    if (ui == 'Έτος') return 'yearly';
    return 'custom';
  }

  String _formatDateLabel(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  String _periodKey() => 'INPUT_BUDGET_PAGE';

  String _newBudgetDocId(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('budgets')
        .doc()
        .id;
  }

  // ============================================================
  // TRANSACTIONS LISTENER (NO build-time calls)
  // ============================================================

  void _ensureTransactionsListener(TransactionsProvider transactionsP) {
    if (_startDate == null || _endDate == null) return;

    final start = _startDate!;
    final end = _endDate!;

    final rangeChanged = _listeningStart == null ||
        _listeningEnd == null ||
        _listeningStart != start ||
        _listeningEnd != end;

    if (rangeChanged && !_txLoadScheduled) {
      _listeningStart = start;
      _listeningEnd = end;
      _txLoadScheduled = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _txLoadScheduled = false;
        if (!mounted) return;

        transactionsP.loadPeriod(_periodKey(), start, end);
      });
    }
  }

  double _calculateIncomeForPeriodFromProvider(
      TransactionsProvider transactionsP,
      CategoriesProvider categoriesP,
      ) {
    // same rule as old sqlite:
    // - exclude transfers
    // - if _selectedAccountId != null → filter account
    // - if _onlyIncome → amount > 0 only
    final txs = transactionsP.getTransactionsForPeriod(_periodKey());

    double total = 0.0;
    for (final t in txs) {
      if (t.isTransfer) continue;

      if (_selectedAccountId != null && t.accountId != _selectedAccountId) {
        continue;
      }

      if (_onlyIncome && t.amount <= 0) continue;

      total += t.amount;
    }

    return total;
  }

  // ============================================================
  // TOTAL LIMIT (DEBOUNCE)
  // ============================================================

  double _getTotalUsed() {
    double total = 0.0;
    for (final v in _categoryAmounts.values) {
      total += v;
    }
    for (final v in _subcategoryAmounts.values) {
      total += v;
    }
    return total;
  }

  void _checkTotalLimit(double accountIncome) {
    _limitDebounce?.cancel();

    _limitDebounce = Timer(_limitDebounceDelay, () {
      if (!mounted) return;

      final totalUsed = _getTotalUsed();
      final newMsg =
      totalUsed > accountIncome ? 'Υπέρβαση Συνολικού Ποσού Εσόδων Περιόδου' : null;

      if (newMsg == _errorMessage) return;

      setState(() {
        _errorMessage = newMsg;
      });
    });
  }

  // ============================================================
  // BUILD PIE CHART
  // ============================================================

  List<PieChartSectionData> _buildPieChartSections(
      double totalIncome, {
        CategoriesProvider? categoriesP,
      }) {
    final bool isFiltered =
        _selectedCategoryFilter != null && _selectedCategoryFilter != '-1';

    final List<PieChartSectionData> sections = [];
    double totalBudget = 0.0;

    // Μάζεψε τα subcategory UUIDs της φιλτραρισμένης κατηγορίας
    final Set<String> allowedSubcatIds = {};
    if (isFiltered && categoriesP != null) {
      final subcats =
      categoriesP.getSubcategoriesForCategory(_selectedCategoryFilter!);
      for (final sc in subcats) {
        allowedSubcatIds.add(sc.uuid);
      }
    }

    for (final entry in _categoryAmounts.entries) {
      if (isFiltered && entry.key != _selectedCategoryFilter) continue;
      totalBudget += entry.value;
    }
    for (final entry in _subcategoryAmounts.entries) {
      if (isFiltered && !allowedSubcatIds.contains(entry.key)) continue;
      totalBudget += entry.value;
    }

    if (totalBudget == 0) {
      sections.add(
        PieChartSectionData(
          value: 1,
          color: Colors.green,
          title: CurrencyFormatter.format(totalIncome),
          radius: 60,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
      return sections;
    }

    int idx = 0;
    _categoryAmounts.forEach((catId, amount) {
      if (amount <= 0) return;
      if (isFiltered && catId != _selectedCategoryFilter) return;
      final colorIndex = idx % budgetColors.length;
      idx++;

      sections.add(
        PieChartSectionData(
          value: amount,
          color: budgetColors[colorIndex],
          title: '${amount.toStringAsFixed(0)}€',
          radius: 70,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    });

    final remaining = totalIncome - totalBudget;
    if (remaining > 0) {
      sections.add(
        PieChartSectionData(
          value: remaining,
          color: Colors.green.shade300,
          title: '',
          radius: 60,
        ),
      );
    }

    return sections;
  }

  List<Widget> _buildLegend(CategoriesProvider categoriesP) {
    final bool isFiltered =
        _selectedCategoryFilter != null && _selectedCategoryFilter != '-1';

    final List<Widget> items = [];

    int idx = 0;
    _categoryAmounts.forEach((catId, amount) {
      if (amount <= 0) return;
      if (isFiltered && catId != _selectedCategoryFilter) return;

      final colorIndex = idx % budgetColors.length;
      idx++;

      final cat = categoriesP.getCategoryByUuid(catId);
      final name = cat?.name ?? '??';

      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: budgetColors[colorIndex],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.black.withValues(alpha: 0.85)),
                ),
              ),
              Text(
                CurrencyFormatter.format(amount),
                style: TextStyle(
                  fontSize: 14,
                  color: budgetColors[colorIndex],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    });

    return items;
  }

  // ============================================================
  // SAVE (BUDGETS PROVIDER) - OFFLINE SAFE
  // ============================================================

  Future<void> _saveBudget({
    required BudgetsProvider budgetsP,
    required CategoriesProvider categoriesP,
  }) async {
    if (_startDate == null || _endDate == null) return;

    setState(() => _isSubmitting = true);

    try {
      final userId = context.session.userId;

      final budgetName = _nameController.text.trim();
      final periodType = _mapUiToPeriodType(_periodTypeUi);

      // 1) build budgets list (subcategory + parent)
      final List<BudgetModel> toSave = [];

      for (final cat in categoriesP.getCategoriesByType('expense')) {
        final catId = cat.uuid;

        final subcats = categoriesP.getSubcategoriesForCategory(catId);

        double subTotal = 0.0;
        bool hasSub = false;

        // Subcategory rows
        for (final sc in subcats) {
          final subId = sc.uuid;
          final value = _subcategoryAmounts[subId] ?? 0.0;

          if (value > 0) {
            hasSub = true;
            subTotal += value;

            toSave.add(
              BudgetModel(
                uuid: _newBudgetDocId(userId),
                userId: userId,
                name: budgetName.isEmpty ? null : budgetName,
                budgetType: 'subcategory',
                categoryId: catId,
                subcategoryId: subId,
                accountId: _selectedAccountId,
                periodType: periodType,
                startDate: _startDate!,
                endDate: _endDate!,
                amount: value,
                currency: 'EUR',
                alertThreshold: 80,
                allowOverspend: true,
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                lastModifiedDeviceId: '',
                deleted: false,
              ),
            );
          }
        }

        // Parent category row (always store)
        final manual = _categoryAmounts[catId] ?? 0.0;
        final finalAmount = hasSub ? subTotal : manual;

        if (finalAmount > 0) {
          toSave.add(
            BudgetModel(
              uuid: _newBudgetDocId(userId),
              userId: userId,
              name: budgetName.isEmpty ? null : budgetName,
              budgetType: 'category',
              categoryId: catId,
              subcategoryId: null,
              accountId: _selectedAccountId,
              periodType: periodType,
              startDate: _startDate!,
              endDate: _endDate!,
              amount: finalAmount,
              currency: 'EUR',
              alertThreshold: 80,
              allowOverspend: true,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              lastModifiedDeviceId: '',
              deleted: false,
            ),
          );
        }
      }

      // 2) EDIT MODE: delete old group first
      if (widget.existingBudgets != null && widget.existingBudgets!.isNotEmpty) {
        final oldUuids = widget.existingBudgets!.map((b) => b.uuid).toList();
        await budgetsP.deleteBudgetBatch(oldUuids);
      }

      // 3) Save new budgets (offline-safe)
      await budgetsP.saveBudgetBatch(toSave);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      DebugConfig.print('❌ InputBudget save error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Σφάλμα αποθήκευσης: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ============================================================
  // UI WIDGETS
  // ============================================================

  Widget _buildCard(BuildContext context, Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: context.cSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: ColorsUI.getBorder(context.brightness),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: ColorsUI.byBrightness(
            brightness: context.brightness,
            light: ColorsUI.shadowLight,
            dark: ColorsUI.shadowDark,
          ),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );


  Widget _buildDateField(
      BuildContext context,
      String label,
      DateTime? date,
      void Function(DateTime) onSelected,
      VoidCallback onChanged,
      ) =>
      _buildCard(
        context,
        Semantics(
          label: 'Επιλογή ημερομηνίας $label',
          hint: 'Επιλέξτε ημερομηνία για το πεδίο $label',
          button: true,
          child: InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (d != null) {
                onSelected(d);
                setState(() {});
                onChanged();
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                border: InputBorder.none,
              ).copyWith(labelText: label),
              child: Text(date == null ? 'Επιλέξτε' : _formatDateLabel(date)),
            ),
          ),
        ),
      );

  /// ------------------------------------------------------------
  ///  Euro TextField (ίδια λειτουργία καθαρισμού)
  /// ------------------------------------------------------------
  Widget euroInputField({
    required BuildContext context,
    required TextEditingController controller,
    required bool enabled,
    required void Function(double? amount) onChanged,
  }) {
    return SizedBox(
      height: 72, // χώρος για label/error
      child: CustomCurrencyField(
        compact: true,
        controller: controller,
        label: 'Ποσό',
        hint: '0,00',
        enabled: enabled,
        required: false,
        allowNegative: false,
        textInputAction: TextInputAction.done,
        onChanged: onChanged, // ✅ double?
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {

    return Consumer4<AccountsProvider, CategoriesProvider, BudgetsProvider, TransactionsProvider>(
      builder: (context, accountsP, categoriesP, budgetsP, transactionsP, _) {
        // 1) categories/accounts from providers
        final accounts = accountsP.accounts.where((a) => !a.deleted && a.isActive).toList();
        final expenseCats = categoriesP.getCategoriesByType('expense');

        // 2) First load: prepare controllers once
        if (_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            // init controllers for categories/subcategories (once)
            for (final cat in expenseCats) {
              _amountControllers.putIfAbsent(cat.uuid, () => TextEditingController());
              _categoryAmounts.putIfAbsent(cat.uuid, () => 0.0);
              _categoryManual.putIfAbsent(cat.uuid, () => false);

              final subcats = categoriesP.getSubcategoriesForCategory(cat.uuid);
              for (final sc in subcats) {
                _subAmountControllers.putIfAbsent(sc.uuid, () => TextEditingController());
                _subcategoryAmounts.putIfAbsent(sc.uuid, () => 0.0);
              }
            }

            // EDIT MODE: fill amounts from existingBudgets (only once)
            if (widget.existingBudgets != null && widget.existingBudgets!.isNotEmpty) {
              final rows = widget.existingBudgets!;

              _subcategoryAmounts.clear();
              _categoryAmounts.clear();

              for (final b in rows) {
                final catId = b.categoryId;
                if (catId == null) continue;

                if (b.budgetType == 'subcategory' && b.subcategoryId != null) {
                  _subcategoryAmounts[b.subcategoryId!] = b.amount;
                  _subAmountControllers[b.subcategoryId!]?.text =
                  b.amount > 0 ? b.amount.toStringAsFixed(2) : '';
                } else if (b.budgetType == 'category') {
                  _categoryAmounts[catId] = b.amount;
                  _amountControllers[catId]?.text = b.amount > 0 ? b.amount.toStringAsFixed(2) : '';
                }
              }

              // manual/auto + expand
              _expandedCategories.clear();

              for (final cat in expenseCats) {
                final catId = cat.uuid;
                final subcats = categoriesP.getSubcategoriesForCategory(catId);
                final hasSubcats = subcats.isNotEmpty;

                // Υπολογισμός αθροίσματος υποκατηγοριών (αν υπάρχουν)
                double subSum = 0.0;
                for (final sc in subcats) {
                  subSum += _subcategoryAmounts[sc.uuid] ?? 0.0;
                }

                if (hasSubcats) {
                  // Αν έχει υποκατηγορίες, πάντα δίνουμε δυνατότητα επεξεργασίας υποκατηγοριών
                  _categoryManual[catId] = false;
                  // Το ποσό της κατηγορίας είναι το άθροισμα των υποκατηγοριών
                  _categoryAmounts[catId] = subSum;
                  _amountControllers[catId]?.text = subSum > 0 ? subSum.toStringAsFixed(2) : '';
                  if (subSum > 0) {
                   // _expandedCategories.add(catId);
                  }
                } else {
                  // Κατηγορία χωρίς υποκατηγορίες: χειροκίνητο ποσό
                  final parent = _categoryAmounts[catId] ?? 0.0;
                  _categoryManual[catId] = true;
                  _categoryAmounts[catId] = parent;
                  _amountControllers[catId]?.text = parent > 0 ? parent.toStringAsFixed(2) : '';
                }
              }
            }

            setState(() => _isLoading = false);
          });
        }

        if (_isLoading) {
          return Scaffold(
            body: Semantics(
              liveRegion: true,
              label: 'Φόρτωση προϋπολογισμού. Παρακαλώ περιμένετε.',
              excludeSemantics: true,
              child: const Center(
                child: ExcludeSemantics(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          );
        }

        // 3) Ensure tx listener (NO build-time calls)
        _ensureTransactionsListener(transactionsP);

        // 4) Income (real-time)
        final income = _calculateIncomeForPeriodFromProvider(transactionsP, categoriesP);

        // 5) Only react when tx snapshot changes (avoid loops)
        final txCount = transactionsP.getTransactionsForPeriod(_periodKey()).length;
        if (txCount != _lastTxCount) {
          _lastTxCount = txCount;

          // debounce validation, no heavy setState here
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _checkTotalLimit(income);
          });
        }

        // 6) responsive paddings/width
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final isWide = w >= 900;
            final horizontal = isWide ? 24.0 : 16.0;

            final title = widget.existingBudgets != null ? 'Επεξεργασία Προϋπολογισμού' : 'Νέος Προϋπολογισμός';

            return Scaffold(
                appBar: AppBar(
                  backgroundColor: context.cPrimary,
                  elevation: 0,
                  iconTheme: IconThemeData(color: context.cOnPrimary),
                  title: Text(
                    title,
                    style: context.titleMd.withColor(context.cOnPrimary),
                  ),
                  centerTitle: true,
                ),
                body: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCard(
                      context,
                      CustomTextField(
                        controller: _nameController,
                        label: 'Όνομα Προϋπολογισμού (προαιρετικό)',
                        hint: 'Π.χ. “Οικογενειακός Μήνας”',
                        required: false,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {},
                      ),
                    ),

                    _buildCard(
                      context,
                      Semantics(
                        label: 'Επιλογή περιόδου προϋπολογισμού',
                        child: DropdownButtonFormField<String>(
                          initialValue: _periodTypeUi,
                          decoration: const InputDecoration(
                            labelText: 'Περίοδος',
                            border: InputBorder.none,
                          ),
                          items: const ['Μήνας', 'Εβδομάδα', 'Έτος', 'Προσαρμοσμένο']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (val) async {
                            if (val == null) return;
                            setState(() {
                              _periodTypeUi = val;
                              final now = DateTime.now();

                              if (val == 'Μήνας') {
                                _startDate = DateTime(now.year, now.month, 1);
                                _endDate = DateTime(now.year, now.month + 1, 0);
                              } else if (val == 'Εβδομάδα') {
                                final monday = now.subtract(Duration(days: now.weekday - 1));
                                _startDate = monday;
                                _endDate = monday.add(const Duration(days: 6));
                              } else if (val == 'Έτος') {
                                _startDate = DateTime(now.year, 1, 1);
                                _endDate = DateTime(now.year, 12, 31);
                              }
                            });

                            // refresh tx listener safely
                            _ensureTransactionsListener(transactionsP);
                            _checkTotalLimit(income);
                          },
                        ),
                      ),
                    ),

                    if (_periodTypeUi == 'Προσαρμοσμένο') ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              context,
                              'Από',
                              _startDate,
                                  (d) => setState(() => _startDate = d),
                                  () {
                                _ensureTransactionsListener(transactionsP);
                                _checkTotalLimit(income);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateField(
                              context,
                              'Έως',
                              _endDate,
                                  (d) => setState(() => _endDate = d),
                                  () {
                                _ensureTransactionsListener(transactionsP);
                                _checkTotalLimit(income);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    _buildCard(
                      context,
                      Semantics(
                        label: 'Επιλογή λογαριασμού για τον προϋπολογισμό',
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedAccountId,
                          dropdownColor: context.cSurface,
                          decoration: InputDecoration(
                            labelText: 'Λογαριασμός',
                            labelStyle: TextStyle(color: context.cText2),
                            border: InputBorder.none,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('όλοι οι Λογαριασμοί'),
                            ),
                            ...accounts.map(
                                  (a) => DropdownMenuItem<String?>(
                                value: a.uuid,
                                child: Text(a.name),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedAccountId = v);
                            _checkTotalLimit(income);
                          },
                        ),
                      ),
                    ),

                    _buildCard(
                      context,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: context.cSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Έσοδα περιόδου: ${CurrencyFormatter.format(income)}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Semantics(
                            label: 'Φίλτρο μόνο εσόδων',
                            hint: 'Ενεργοποιήστε για να υπολογίζονται μόνο τα έσοδα της περιόδου',
                            child: Switch(
                              value: _onlyIncome,
                              onChanged: (v) {
                                setState(() => _onlyIncome = v);
                                _checkTotalLimit(income);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (income > 0 &&
                        _buildPieChartSections(income, categoriesP: categoriesP)
                            .isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cSurface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 150,
                              width: 150,
                              child: Semantics(
                                label: 'Διάγραμμα προϋπολογισμού',
                                hint: 'Εμφανίζει την κατανομή των ποσών ανά κατηγορία και το υπόλοιπο ποσό',
                                excludeSemantics: true,
                                child: ExcludeSemantics(
                                  child: PieChart(
                                    PieChartData(
                                      sections:
                                      _buildPieChartSections(income, categoriesP: categoriesP),
                                      centerSpaceRadius: 10,
                                      sectionsSpace: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildLegend(categoriesP),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Filter categories dropdown
                    _buildCard(
                      context,
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedCategoryFilter,
                        dropdownColor: context.cSurface,
                        decoration: InputDecoration(
                          labelText: 'Φίλτρο Κατηγοριών',
                          labelStyle: TextStyle(color: context.cText2),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: '-1',
                            child: Text('Όλες οι Κατηγορίες'),
                          ),
                          ...expenseCats.map(
                                (cat) => DropdownMenuItem<String?>(
                              value: cat.uuid,
                              child: Text(cat.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCategoryFilter = value);
                        },
                      ),
                    ),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Semantics(
                          liveRegion: true,
                          label: _errorMessage!,
                          excludeSemantics: true,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Categories list (filtered)
                    if (_selectedCategoryFilter != null)
                      ...(((_selectedCategoryFilter == '-1')
                          ? expenseCats
                          : expenseCats.where((c) => c.uuid == _selectedCategoryFilter))
                          .map((cat) {
                        final catId = cat.uuid;
                        final subcats = categoriesP.getSubcategoriesForCategory(catId);
                        final hasSubcats = subcats.isNotEmpty;
                        final isExpanded = _expandedCategories.contains(catId);

                        final subTotal = subcats.fold<double>(
                          0.0,
                              (total, s) => total + (_subcategoryAmounts[s.uuid] ?? 0.0),
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: context.cSurface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Semantics(
                                  label: 'Κατηγορία ${cat.name}',
                                  child: Row(
                                    children: [
                                      ExcludeSemantics(
                                        child: Image.asset(
                                          IconMapper.getIconPath(
                                            'category',
                                            cat.iconIndex,
                                            categoryType: 'expense',
                                          ),
                                          width: 36,
                                          height: 36,
                                          errorBuilder: (_, _, _) => Icon(Icons.category, color: context.cText),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          cat.name,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                        if (hasSubcats)
                                          IconButton(
                                            tooltip: isExpanded
                                                ? 'Σύμπτυξη υποκατηγοριών για ${cat.name}'
                                                : 'Ανάπτυξη υποκατηγοριών για ${cat.name}',
                                            icon: ExcludeSemantics(
                                              child: Icon(
                                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                if (isExpanded) {
                                                  _expandedCategories.remove(catId);
                                                } else {
                                                  _expandedCategories.add(catId);
                                                }
                                              });
                                            },
                                          ),
                                      SizedBox(
                                        width: 110,
                                        child: euroInputField(
                                          context: context,
                                          controller: _amountControllers[catId]!,
                                          enabled: !hasSubcats || subTotal == 0.0,
                                          onChanged: (amount) {
                                            if (_isUpdatingFromSubcategory) return;

                                            final v = amount ?? 0.0;
                                            _categoryAmounts[catId] = v;

                                            if (v > 0) {
                                              _categoryManual[catId] = true;
                                              for (final sc in subcats) {
                                                _subcategoryAmounts[sc.uuid] = 0.0;
                                                _subAmountControllers[sc.uuid]?.text = '';
                                              }
                                            } else {
                                              _categoryManual[catId] = false;
                                            }

                                            setState(() {});
                                            _checkTotalLimit(income);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              if (isExpanded && hasSubcats)
                                ...subcats.map((sub) {
                                  final subId = sub.uuid;

                                  return Container(
                                    margin: const EdgeInsets.fromLTRB(56, 4, 16, 4),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(color: Colors.grey[300]!, width: 2),
                                      ),
                                    ),
                                    child: Semantics(
                                      label: 'Υποκατηγορία ${sub.name}',
                                      child: Row(
                                        children: [
                                          ExcludeSemantics(
                                            child: Image.asset(
                                              IconMapper.getIconPath(
                                                'subcategory',
                                                sub.iconIndex,
                                                categoryType: 'expense',
                                              ),
                                              width: 28,
                                              height: 28,
                                              errorBuilder: (_, _, _) => Icon(Icons.label, color: context.cText),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(sub.name, style: const TextStyle(fontSize: 15)),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 100,
                                            child: euroInputField(
                                              context: context,
                                              controller: _subAmountControllers[subId]!,
                                              enabled: !(_categoryManual[catId] ?? false),
                                              onChanged: (amount) {
                                                final v = amount ?? 0.0;
                                                _subcategoryAmounts[subId] = v;

                                                _categoryManual[catId] = false;

                                                double sum = 0.0;
                                                for (final sc in subcats) {
                                                  sum += _subcategoryAmounts[sc.uuid] ?? 0.0;
                                                }

                                                _categoryAmounts[catId] = sum;

                                                _isUpdatingFromSubcategory = true;
                                                _amountControllers[catId]?.text = sum > 0 ? sum.toStringAsFixed(2) : '';
                                                _isUpdatingFromSubcategory = false;

                                                setState(() {});
                                                _checkTotalLimit(income);
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),

                              if (isExpanded && subTotal > 0)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Άθροισμα υποκατηγοριών: ${CurrencyFormatter.format(subTotal)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      })),

                    const SizedBox(height: 40),

                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            label: 'Ακύρωση',
                            hint: 'Επιστρέφει χωρίς αποθήκευση του προϋπολογισμού',
                            button: true,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Άκυρο'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Semantics(
                            label: 'Αποθήκευση προϋπολογισμού',
                            hint: 'Αποθηκεύει τον προϋπολογισμό και επιστρέφει στην προηγούμενη οθόνη',
                            button: true,
                            child: ElevatedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _saveBudget(
                                budgetsP: budgetsP,
                                categoriesP: categoriesP,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF51D275),
                                foregroundColor: Colors.black,
                              ),
                              child: _isSubmitting
                                  ? Semantics(
                                liveRegion: true,
                                label: 'Αποθήκευση σε εξέλιξη. Παρακαλώ περιμένετε.',
                                excludeSemantics: true,
                                child: const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: ExcludeSemantics(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                                  : const Text('Αποθήκευση'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _limitDebounce?.cancel();

    _nameController.dispose();
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    for (final c in _subAmountControllers.values) {
      c.dispose();
    }

    super.dispose();
  }
}
