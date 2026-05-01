// ============================================================
// FILE: budget_page.dart
// Firebase + Providers + Real-time spent via TransactionsProvider
// ΧΩΡΙΣ ScreenUtil (responsive με LayoutBuilder)
// UI/συμπεριφορά ίδια λογική με την αρχική σελίδα
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/utils/debug_config.dart';

import 'package:family_economy/core/utils/icon_mapper.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';

import 'package:family_economy/models/budget_model.dart';
import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/providers/budgets_provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';

import 'package:family_economy/presentation/screens/budget/input_budget_page.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  // Debounce για να μην κάνουμε recalc σε κάθε rebuild/μικρο-αλλαγή snapshot
  Timer? _recalcDebounce;
  static const Duration _recalcDebounceDelay = Duration(milliseconds: 250);

  DateTime? _listeningStart;
  DateTime? _listeningEnd;

  // ✅ NEW: για να κάνουμε recalc μόνο όταν αλλάξουν τα transactions
  int _lastTxCount = -1;

  // ✅ NEW: guard για να μην κάνουμε loadPeriod μέσα στο build / πολλές φορές
  bool _loadScheduled = false;

  // Κρατάει ποιες κατηγορίες είναι ανοιχτές (key = budgetUuid της category)
  final Set<String> _expandedCategoryKeys = {};

  @override
  void initState() {
    super.initState();
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Σελίδα Προϋπολογισμών. Δείτε και διαχειριστείτε τους προϋπολογισμούς σας.',
    );
  }

  @override
  void dispose() {
    _recalcDebounce?.cancel();
    super.dispose();
  }

  String _formatDate(String iso) {
    try {
      final date = DateTime.parse(iso);
      return DateFormat('dd/MM').format(date);
    } catch (_) {
      return iso;
    }
  }

  // Ομαδοποίηση budgets ανά: (name/account + start_date + end_date)
  Map<String, List<_BudgetRowVM>> _groupBudgets(List<_BudgetRowVM> rows) {
    final Map<String, List<_BudgetRowVM>> grouped = {};

    for (final b in rows) {
      final String budgetName = (b.name ?? '').toString().isNotEmpty
          ? b.name!
          : 'Προϋπολογισμός';
      final String accountName = b.accountName ?? 'Όλοι';
      final String startDate = b.startDateIso ?? '';
      final String endDate = b.endDateIso ?? '';

      final String key = '$budgetName|$accountName|$startDate|$endDate';
      grouped.putIfAbsent(key, () => []).add(b);
    }

    return grouped;
  }

  // ============================================================
  // MENU ACTIONS
  // ============================================================

  Future<void> _showBudgetMenu(
    BuildContext context,
    List<_BudgetRowVM> groupBudgets,
    BudgetsProvider budgetsProvider,
  ) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 8),
              Text(
                'Επεξεργασία',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'move',
          child: Row(
            children: [
              Icon(Icons.drive_file_move, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Μετακίνηση',
                style: TextStyle(color: Colors.blue, fontSize: 16),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Διαγραφή Προϋπολογισμού',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );

    if (!mounted) return;

    if (result == 'edit') {
      await _editGroupedBudget(groupBudgets);
    } else if (result == 'move') {
      await _moveGroupedBudget(groupBudgets, budgetsProvider);
    } else if (result == 'delete') {
      await _deleteGroupedBudget(groupBudgets, budgetsProvider);
    }
  }

  Future<void> _editGroupedBudget(List<_BudgetRowVM> groupBudgets) async {
    // ✅ FIX: groupBudgets contains only category-level budgets (subcategory
    // ones are filtered out in visibleBudgets). We need to also include
    // the matching subcategory budgets so InputBudgetPage can pre-fill them.
    final budgetsP = context.read<BudgetsProvider>();

    // Use the first budget's key fields to find ALL budgets in this group
    final firstModel = groupBudgets.first.model;

    final allGroupBudgets = budgetsP.budgets.where((b) {
      // Match by name, accountId, startDate, endDate
      final sameName = b.name == firstModel.name;
      final sameAccount = b.accountId == firstModel.accountId;
      final sameStart = b.startDate.isAtSameMomentAs(firstModel.startDate);
      final sameEnd = b.endDate.isAtSameMomentAs(firstModel.endDate);
      return sameName && sameAccount && sameStart && sameEnd;
    }).toList();

    final existing = allGroupBudgets;

    // ✅ Πιάσε τα instances από το ΤΡΕΧΟΝ context
    final accountsP = context.read<AccountsProvider>();
    final categoriesP = context.read<CategoriesProvider>();
    final transactionsP = context.read<TransactionsProvider>();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountsProvider>.value(value: accountsP),
            ChangeNotifierProvider<CategoriesProvider>.value(
              value: categoriesP,
            ),
            ChangeNotifierProvider<BudgetsProvider>.value(value: budgetsP),
            ChangeNotifierProvider<TransactionsProvider>.value(
              value: transactionsP,
            ),
          ],
          child: SessionScope(
            session: context.session,
            child: InputBudgetPage(existingBudgets: existing),
          ),
        ),
      ),
    );

    if (result == true) {
      // Providers are real-time, nothing else needed.
    }
  }

  Future<void> _deleteGroupedBudget(
    List<_BudgetRowVM> groupBudgets,
    BudgetsProvider budgetsProvider,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Διαγραφή Προϋπολογισμού'),
        content: Text(
          'Θα διαγραφούν ${groupBudgets.length} κατηγορίες από τον προϋπολογισμό;',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Όχι'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ναι', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    try {
      final uuids = groupBudgets.map((e) => e.budgetUuid).toList();

      // ✅ Δείξε άμεσα feedback (δουλεύει και σε offline)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ο προϋπολογισμός διαγράφηκε'),
          backgroundColor: Colors.green,
        ),
      );

      // ✅ Το await μπορεί να καθυστερήσει σε offline μέχρι να γυρίσει το internet
      await budgetsProvider.deleteBudgetBatch(uuids);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Σφάλμα διαγραφής: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _moveGroupedBudget(
    List<_BudgetRowVM> groupBudgets,
    BudgetsProvider budgetsProvider,
  ) async {
    final firstBudget = groupBudgets.first;
    DateTime? newStartDate;
    DateTime? newEndDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.cSurface,
          title: Semantics(
            header: true,
            child: Text(
              'Μετακίνηση Προϋπολογισμού',
              style: TextStyle(color: context.cText),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  readOnly: true,
                  child: Text(
                    'Επιλέξτε το νέο χρονικό διάστημα:',
                    style: TextStyle(fontSize: 14, color: context.cText2),
                  ),
                ),
                const SizedBox(height: 16),

                // Current period display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.cSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ColorsUI.getBorder(Theme.of(context).brightness),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Τρέχον Διάστημα:',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.cText2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Semantics(
                        readOnly: true,
                        label:
                            'Τρέχον διάστημα από ${_formatDate(firstBudget.startDateIso ?? '')} έως ${_formatDate(firstBudget.endDateIso ?? '')}',
                        child: Text(
                          '${_formatDate(firstBudget.startDateIso ?? '')} - ${_formatDate(firstBudget.endDateIso ?? '')}',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.cText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // New Start Date
                Semantics(
                  button: true,
                  label: 'Επιλογή νέας ημερομηνίας έναρξης',
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: const Locale('el', 'GR'),
                        builder: (context, child) {
                          return Theme(
                            data:
                                Theme.of(context).brightness == Brightness.dark
                                ? ThemeData.dark()
                                : ThemeData.light(),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => newStartDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      newStartDate != null
                          ? 'Έναρξη: ${DateFormat('dd/MM/yyyy').format(newStartDate!)}'
                          : 'Επιλέξτε Έναρξη',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // New End Date
                Semantics(
                  button: true,
                  label: 'Επιλογή νέας ημερομηνίας λήξης',
                  child: OutlinedButton.icon(
                    onPressed: newStartDate == null
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: newStartDate!.add(
                                const Duration(days: 30),
                              ),
                              firstDate: newStartDate!,
                              lastDate: DateTime(2030),
                              locale: const Locale('el', 'GR'),
                              builder: (context, child) {
                                return Theme(
                                  data:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? ThemeData.dark()
                                      : ThemeData.light(),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() => newEndDate = picked);
                            }
                          },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      newEndDate != null
                          ? 'Λήξη: ${DateFormat('dd/MM/yyyy').format(newEndDate!)}'
                          : 'Επιλέξτε Λήξη',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),

                if (newStartDate != null && newEndDate != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Θα μετακινηθεί στο διάστημα:\n${DateFormat('dd/MM/yyyy').format(newStartDate!)} - ${DateFormat('dd/MM/yyyy').format(newEndDate!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            Semantics(
              button: true,
              label: 'Ακύρωση μετακίνησης',
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('Άκυρο', style: TextStyle(color: context.cText2)),
              ),
            ),
            Semantics(
              button: true,
              label: 'Επιβεβαίωση μετακίνησης προϋπολογισμού',
              child: ElevatedButton(
                onPressed: newStartDate != null && newEndDate != null
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('Μετακίνηση'),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != true || newStartDate == null || newEndDate == null) return;

    try {
      final models = groupBudgets.map((e) => e.model).toList();

      await budgetsProvider.updateBudgetDates(
        groupBudgets: models,
        newStartDate: newStartDate!,
        newEndDate: newEndDate!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ο προϋπολογισμός μετακινήθηκε στο νέο διάστημα'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Σφάλμα μετακίνησης: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addNewBudget() async {
    // ✅ Πιάσε τα instances από το ΤΡΕΧΟΝ context (εκεί που υπάρχουν)
    final accountsP = context.read<AccountsProvider>();
    final categoriesP = context.read<CategoriesProvider>();
    final budgetsP = context.read<BudgetsProvider>();
    final transactionsP = context.read<TransactionsProvider>();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountsProvider>.value(value: accountsP),
            ChangeNotifierProvider<CategoriesProvider>.value(
              value: categoriesP,
            ),
            ChangeNotifierProvider<BudgetsProvider>.value(value: budgetsP),
            ChangeNotifierProvider<TransactionsProvider>.value(
              value: transactionsP,
            ),
          ],
          child: SessionScope(
            session: context.session,
            child: const InputBudgetPage(),
          ),
        ),
      ),
    );

    if (result == true) {
      // Providers are real-time.
    }
  }

  // ============================================================
  // REAL-TIME spent: TransactionsProvider -> recalc visible budgets only
  // ============================================================

  void _ensureTransactionsListenerAndRecalc({
    required TransactionsProvider transactionsP,
    required BudgetsProvider budgetsP,
    required List<BudgetModel> visibleBudgets,
  }) {
    if (visibleBudgets.isEmpty) return;

    // 1) Υπολόγισε minStart / maxEnd από τα visible budgets
    DateTime minStart = visibleBudgets.first.startDate;
    DateTime maxEnd = visibleBudgets.first.endDate;

    for (final b in visibleBudgets) {
      if (b.startDate.isBefore(minStart)) minStart = b.startDate;
      if (b.endDate.isAfter(maxEnd)) maxEnd = b.endDate;
    }

    final rangeChanged =
        _listeningStart == null ||
        _listeningEnd == null ||
        _listeningStart != minStart ||
        _listeningEnd != maxEnd;

    // 2) ✅ ΜΗΝ καλείς loadPeriod μέσα στο build → μετά το frame
    if (rangeChanged && !_loadScheduled) {
      _listeningStart = minStart;
      _listeningEnd = maxEnd;
      _loadScheduled = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadScheduled = false;
        if (!mounted) return;

        transactionsP.loadPeriod('BUDGETS_PAGE', minStart, maxEnd);
      });
    }

    // 3) ✅ Recalc μόνο όταν αλλάξουν τα transactions του period
    final txCount = transactionsP
        .getTransactionsForPeriod('BUDGETS_PAGE')
        .length;

    if (txCount == _lastTxCount) return;

    // ✅ Αν είναι πρώτο άνοιγμα σελίδας (_lastTxCount == -1) ΚΑΙ
    // το cache έχει ήδη όλες τις τιμές → μην ξαναϋπολογίσεις
    if (_lastTxCount == -1 && budgetsP.isSpentCachePopulated) {
      _lastTxCount = txCount; // sync χωρίς recalc
      return;
    }

    _lastTxCount = txCount;

    _recalcDebounce?.cancel();
    _recalcDebounce = Timer(_recalcDebounceDelay, () async {
      try {
        for (final b in budgetsP.budgets) {
          // ← όλα τα budgets
          await budgetsP.calculateSpentAmount(b); // ← χωρίς skip
        }
      } catch (e) {
        DebugConfig.print('⚠️ BudgetPage spent recalculation error: $e');
      }

      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // session available if you need it later (δεν το περνάμε στο InputBudgetPage)
    final _ = context.session.userId;

    return Consumer4<
      BudgetsProvider,
      AccountsProvider,
      CategoriesProvider,
      TransactionsProvider
    >(
      builder: (context, budgetsP, accountsP, categoriesP, transactionsP, _) {
        final loading = budgetsP.isLoading;

        final visibleBudgets = budgetsP.budgets
            .where((b) => !b.isSubcategoryBudget)
            .toList();

        _ensureTransactionsListenerAndRecalc(
          transactionsP: transactionsP,
          budgetsP: budgetsP,
          visibleBudgets: visibleBudgets,
        );

        final rows = <_BudgetRowVM>[];
        for (final b in visibleBudgets) {
          final cat = b.categoryId != null
              ? categoriesP.getCategoryByUuid(b.categoryId!)
              : null;

          final acc = b.accountId != null
              ? accountsP.getAccountByUuid(b.accountId!)
              : null;

          rows.add(
            _BudgetRowVM(
              model: b,
              budgetUuid: b.uuid,
              name: b.name,
              accountName: acc?.name,
              startDateIso: b.startDate.toIso8601String(),
              endDateIso: b.endDate.toIso8601String(),
              categoryName: cat?.name ?? '',
              categoryIcon: cat?.iconIndex,
              amount: b.amount,
              spentAmount: budgetsP.getSpentAmount(b.uuid),
              categoryType: cat?.type ?? 'expense',
              // ✅ NEW
              subcategoryId: b.subcategoryId,
            ),
          );
        }

        final groupedBudgets = _groupBudgets(rows)
          ..removeWhere(
            (key, list) => list.every((b) => b.subcategoryId != null),
          );

        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: loading
                      ? Semantics(
                          label: 'Δεν υπάρχουν αποθηκευμένοι προϋπολογισμοί',
                          excludeSemantics: true,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ExcludeSemantics(
                                  child: Icon(
                                    Icons.pie_chart_outline,
                                    size: 80,
                                    color: context.cText2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Δεν υπάρχουν προϋπολογισμοί",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: context.cText2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: groupedBudgets.length,
                          itemBuilder: (context, index) {
                            final key = groupedBudgets.keys.elementAt(index);
                            final group = groupedBudgets[key]!;
                            final firstBudget = group.first;

                            // ✅ NEW: σειρά κατηγοριών όπως είναι στο CategoriesProvider (βάση/φόρτωμα)
                            final order = <String, int>{};
                            final orderedCats = categoriesP.getCategoriesByType(
                              'expense',
                            );
                            for (int i = 0; i < orderedCats.length; i++) {
                              order[orderedCats[i].uuid] = i;
                            }

                            final sortedGroup = [...group]
                              ..sort((a, b) {
                                final oa =
                                    order[a.model.categoryId ?? ''] ?? 999999;
                                final ob =
                                    order[b.model.categoryId ?? ''] ?? 999999;
                                return oa.compareTo(ob);
                              });

                            double totalAmount = 0;
                            double totalSpent = 0;
                            for (final b in group) {
                              totalAmount += b.amount;
                              totalSpent += b.spentAmount;
                            }

                            return Semantics(
                              label:
                                  'Προϋπολογισμός ${firstBudget.name ?? 'Χωρίς όνομα'}, '
                                  'Λογαριασμός: ${firstBudget.accountName ?? 'Όλοι'}, '
                                  'Περίοδος από ${_formatDate(firstBudget.startDateIso ?? '')} '
                                  'έως ${_formatDate(firstBudget.endDateIso ?? '')}',
                              hint: 'Πατήστε για επιλογές ή λεπτομέρειες',
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.cSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: ColorsUI.getBorder(
                                      Theme.of(context).brightness,
                                    ),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.cSurface,
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Header: Όνομα + Label + Λογαριασμός + Menu
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  (firstBudget.name ?? '')
                                                              .toString()
                                                              .isNotEmpty ==
                                                          true
                                                      ? firstBudget.name!
                                                      : 'Προϋπολογισμός',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: context.cText,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? (firstBudget.accountName !=
                                                          null
                                                      ? Colors.blue.withValues(
                                                          alpha: 0.20,
                                                        )
                                                      : Colors.grey.withValues(
                                                          alpha: 0.20,
                                                        ))
                                                : (firstBudget.accountName !=
                                                          null
                                                      ? Colors.blue.shade50
                                                      : Colors.grey.shade100),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? (firstBudget.accountName !=
                                                            null
                                                        ? Colors.blue.shade300
                                                        : Colors.grey.shade400)
                                                  : Colors.transparent,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            firstBudget.accountName ?? 'Όλοι',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  firstBudget.accountName !=
                                                      null
                                                  ? (Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? Colors.blue.shade200
                                                        : Colors.blue.shade700)
                                                  : context.cText2,
                                            ),
                                          ),
                                        ),
                                        Builder(
                                          builder: (buttonContext) => Semantics(
                                            button: true,
                                            label:
                                                'Μενού επιλογών προϋπολογισμού',
                                            hint: 'Επεξεργασία ή διαγραφή',
                                            child: InkWell(
                                              onTap: () => _showBudgetMenu(
                                                buttonContext,
                                                group,
                                                budgetsP,
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                child: ExcludeSemantics(
                                                  child: Icon(
                                                    Icons.more_vert,
                                                    size: 20,
                                                    color: context.cText2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    // Χρονική διάρκεια
                                    Text(
                                      '${_formatDate(firstBudget.startDateIso ?? '')} - ${_formatDate(firstBudget.endDateIso ?? '')}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.cText2,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // Κατηγορίες
                                    ...sortedGroup.map((b) {
                                      final amount = b.amount;
                                      final spent = b.spentAmount;
                                      final pct = (spent / amount).clamp(0, 1);
                                      final overspent = spent > amount;
                                      final double progress = pct
                                          .clamp(0.0, 1.0)
                                          .toDouble();
                                      final double overspendFactor = overspent
                                          ? ((spent - amount) / amount).clamp(
                                              0.0,
                                              double.infinity,
                                            )
                                          : 0.0;

                                      // ── Βρες υποκατηγορίες αυτής της κατηγορίας στο ίδιο group
                                      final subBudgets = budgetsP.budgets
                                          .where(
                                            (sub) =>
                                                sub.isSubcategoryBudget &&
                                                sub.categoryId ==
                                                    b.model.categoryId &&
                                                sub.name == b.model.name &&
                                                sub.accountId ==
                                                    b.model.accountId &&
                                                sub.startDate.isAtSameMomentAs(
                                                  b.model.startDate,
                                                ) &&
                                                sub.endDate.isAtSameMomentAs(
                                                  b.model.endDate,
                                                ),
                                          )
                                          .toList();

                                      final hasSubcats = subBudgets.isNotEmpty;
                                      final isExpanded = _expandedCategoryKeys
                                          .contains(b.budgetUuid);

                                      return Semantics(
                                        label:
                                            'Κατηγορία ${b.categoryName}, '
                                            'ποσό ${CurrencyFormatter.format(amount)}, '
                                            'ξοδεύτηκαν ${CurrencyFormatter.format(spent)}',
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // ── Γραμμή κατηγορίας ──
                                            GestureDetector(
                                              onTap: hasSubcats
                                                  ? () {
                                                      setState(() {
                                                        if (isExpanded) {
                                                          _expandedCategoryKeys
                                                              .remove(
                                                                b.budgetUuid,
                                                              );
                                                        } else {
                                                          _expandedCategoryKeys
                                                              .add(
                                                                b.budgetUuid,
                                                              );
                                                        }
                                                      });
                                                    }
                                                  : null,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 10,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    // Εικονίδιο κατηγορίας
                                                    ExcludeSemantics(
                                                      child: SizedBox(
                                                        width: 28,
                                                        height: 28,
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                5,
                                                              ),
                                                          child: Image.asset(
                                                            IconMapper.getIconPath(
                                                              'category',
                                                              b.categoryIcon,
                                                              categoryType:
                                                                  b.categoryType ==
                                                                      'income'
                                                                  ? 'income'
                                                                  : 'expense',
                                                            ),
                                                            fit: BoxFit.contain,
                                                            errorBuilder:
                                                                (
                                                                  context,
                                                                  error,
                                                                  stackTrace,
                                                                ) {
                                                                  return Icon(
                                                                    Icons
                                                                        .category,
                                                                    size: 20,
                                                                    color: context
                                                                        .cText2,
                                                                  );
                                                                },
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Progress bar + ποσά
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          // Όνομα κατηγορίας + chevron αν έχει subcats
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  b.categoryName ??
                                                                      '',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: context
                                                                        .cText,
                                                                  ),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                              if (hasSubcats)
                                                                Semantics(
                                                                  button: true,
                                                                  label:
                                                                      isExpanded
                                                                      ? 'Σύμπτυξη υποκατηγοριών για ${b.categoryName}'
                                                                      : 'Ανάπτυξη υποκατηγοριών για ${b.categoryName}',
                                                                  child: GestureDetector(
                                                                    onTap: () {
                                                                      setState(() {
                                                                        if (isExpanded) {
                                                                          _expandedCategoryKeys.remove(
                                                                            b.budgetUuid,
                                                                          );
                                                                        } else {
                                                                          _expandedCategoryKeys.add(
                                                                            b.budgetUuid,
                                                                          );
                                                                        }
                                                                      });
                                                                    },
                                                                    child: Padding(
                                                                      padding:
                                                                          const EdgeInsets.only(
                                                                            left:
                                                                                4,
                                                                          ),
                                                                      child: ExcludeSemantics(
                                                                        child: Icon(
                                                                          isExpanded
                                                                              ? Icons.expand_less
                                                                              : Icons.expand_more,
                                                                          size:
                                                                              16,
                                                                          color:
                                                                              context.cText2,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 3,
                                                          ),
                                                          // Progress bar
                                                          ExcludeSemantics(
                                                            child: Container(
                                                              height: 5,
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .grey[300],
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      3,
                                                                    ),
                                                              ),
                                                              child: ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      3,
                                                                    ),
                                                                child: Stack(
                                                                  children: [
                                                                    FractionallySizedBox(
                                                                      widthFactor:
                                                                          progress,
                                                                      child: Container(
                                                                        color: Colors
                                                                            .green,
                                                                      ),
                                                                    ),
                                                                    if (overspent)
                                                                      FractionallySizedBox(
                                                                        widthFactor:
                                                                            overspendFactor,
                                                                        alignment:
                                                                            Alignment.centerRight,
                                                                        child: Container(
                                                                          color:
                                                                              Colors.red,
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          // Ξοδεμένο + Ποσοστό
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Text(
                                                                CurrencyFormatter.format(
                                                                  spent,
                                                                ),
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color:
                                                                      overspent
                                                                      ? Colors
                                                                            .red
                                                                      : context
                                                                            .cText2,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              Text(
                                                                '${(pct * 100).toStringAsFixed(0)}%',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color:
                                                                      overspent
                                                                      ? Colors
                                                                            .red
                                                                      : (Theme.of(context).brightness ==
                                                                                Brightness.dark
                                                                            ? Colors.green.shade300
                                                                            : Colors.green.shade700),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Δεσμευμένο ποσό
                                                    Text(
                                                      CurrencyFormatter.format(
                                                        amount,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: context.cText,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // ── Υποκατηγορίες (εμφανίζονται μόνο αν expanded) ──
                                            if (hasSubcats && isExpanded) ...[
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 36,
                                                  bottom: 6,
                                                ),
                                                child: Text(
                                                  'Υποκατηγορίες',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: context.cText2,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                              ...subBudgets.map((sub) {
                                                final subAmount = sub.amount;
                                                final subSpent = budgetsP
                                                    .getSpentAmount(sub.uuid);
                                                final subRemaining =
                                                    subAmount - subSpent;
                                                final subPct = subAmount > 0
                                                    ? (subSpent / subAmount)
                                                          .clamp(0.0, 1.0)
                                                    : 0.0;
                                                final subOverspent =
                                                    subSpent > subAmount;

                                                // Βρες το όνομα της υποκατηγορίας
                                                final subcat =
                                                    sub.subcategoryId != null &&
                                                        sub.categoryId != null
                                                    ? categoriesP
                                                          .getSubcategoryByUuid(
                                                            sub.categoryId!,
                                                            sub.subcategoryId!,
                                                          )
                                                    : null;
                                                final subcatName =
                                                    subcat?.name ??
                                                    sub.subcategoryId ??
                                                    '';

                                                return Semantics(
                                                  label:
                                                      'Υποκατηγορία $subcatName, '
                                                      'ποσό ${CurrencyFormatter.format(subAmount)}, '
                                                      'ξοδεύτηκαν ${CurrencyFormatter.format(subSpent)}, '
                                                      '${subOverspent ? 'υπέρβαση ${CurrencyFormatter.format(subRemaining.abs())}' : 'απομένουν ${CurrencyFormatter.format(subRemaining.abs())}'}',
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 36,
                                                          bottom: 8,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        // Μικρή γραμμή σύνδεσης
                                                        ExcludeSemantics(
                                                          child: Container(
                                                            width: 2,
                                                            height: 40,
                                                            color: Colors
                                                                .grey
                                                                .shade300,
                                                            margin:
                                                                const EdgeInsets.only(
                                                                  right: 8,
                                                                ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              // Όνομα + Ποσό
                                                              Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                      subcatName,
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                        color: context
                                                                            .cText,
                                                                      ),
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    CurrencyFormatter.format(
                                                                      subAmount,
                                                                    ),
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: context
                                                                          .cText,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                height: 3,
                                                              ),
                                                              // Progress bar υποκατηγορίας
                                                              ExcludeSemantics(
                                                                child: Container(
                                                                  height: 3,
                                                                  decoration: BoxDecoration(
                                                                    color: Colors
                                                                        .grey[300],
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          2,
                                                                        ),
                                                                  ),
                                                                  child: ClipRRect(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          2,
                                                                        ),
                                                                    child: FractionallySizedBox(
                                                                      widthFactor:
                                                                          subPct,
                                                                      alignment:
                                                                          Alignment
                                                                              .centerLeft,
                                                                      child: Container(
                                                                        color:
                                                                            subOverspent
                                                                            ? Colors.red
                                                                            : Colors.green,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 3,
                                                              ),
                                                              // Απομένουν + %
                                                              Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: [
                                                                  Text(
                                                                    subOverspent
                                                                        ? 'Υπέρβαση ${CurrencyFormatter.format(subRemaining.abs())} €'
                                                                        : 'Απομένουν ${CurrencyFormatter.format(subRemaining.abs())} €',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color:
                                                                          subOverspent
                                                                          ? Colors.red
                                                                          : context.cText2,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    '${(subPct * 100).toStringAsFixed(0)}%',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color:
                                                                          subOverspent
                                                                          ? Colors.red
                                                                          : Colors.green.shade700,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }),
                                              const SizedBox(height: 4),
                                            ],
                                          ],
                                        ),
                                      );
                                    }),

                                    // Διαχωριστική γραμμή
                                    Divider(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300,
                                      thickness: 1,
                                      height: 16,
                                    ),

                                    // Τελευταία σειρά: Πορεία + Σύνολο
                                    Semantics(
                                      liveRegion: true,
                                      label:
                                          'Πορεία: ${CurrencyFormatter.format(totalSpent)}, '
                                          'Σύνολο: ${CurrencyFormatter.format(totalAmount)}',
                                      excludeSemantics: true,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Πορεία: ',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: context.cText2,
                                                ),
                                              ),
                                              Text(
                                                CurrencyFormatter.format(
                                                  totalSpent,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      totalSpent <= totalAmount
                                                      ? Colors.green.shade700
                                                      : Colors.red.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                'Σύνολο: ',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: context.cText2,
                                                ),
                                              ),
                                              Text(
                                                CurrencyFormatter.format(
                                                  totalAmount,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Positioned(
                  right: 20,
                  bottom: 5,
                  child: FloatingActionButton(
                    backgroundColor: Colors.blue,
                    onPressed: _addNewBudget,
                    tooltip: 'Προσθήκη νέου προϋπολογισμού',
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.add,
                        size: 32,
                        color: context.cOnPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ============================================================
// VM (για να κρατήσουμε την ίδια λογική UI με grouped "rows")
// ============================================================

class _BudgetRowVM {
  final BudgetModel model;
  final String budgetUuid;

  final String? name;
  final String? accountName;

  final String? startDateIso;
  final String? endDateIso;

  final String? categoryName;
  final int? categoryIcon;

  final double amount;
  final double spentAmount;

  final String categoryType; // ✅ NEW: 'income' ή 'expense'

  // κρατιέται για το removeWhere φίλτρο (ίδια λογική με πριν)
  final String? subcategoryId;

  _BudgetRowVM({
    required this.model,
    required this.budgetUuid,
    required this.name,
    required this.accountName,
    required this.startDateIso,
    required this.endDateIso,
    required this.categoryName,
    required this.categoryIcon,
    required this.amount,
    required this.spentAmount,
    required this.categoryType,
    required this.subcategoryId,
  });
}
