// ============================================================
// FILE: stats4_budget_page.dart
// Path: lib/presentation/screens/stats/stats4_budget_page.dart
// Ρόλος: Πρόβλεψη Στόχου Εξοικονόμησης ανά κατηγορία/υποκατηγορία
// ✅ UTF-8 | Providers | Offline-safe | Accessibility | Dark mode
// ✅ Export Excel + PDF | Responsive | SessionScope
// ✅ v2: Αποθήκευση ως Προϋπολογισμός στη βάση
// ============================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/models/budget_model.dart';
import 'package:family_economy/providers/categories_provider.dart';

// ─────────────────────────────────────────────
// Μοντέλο αποτελέσματος ανά κατηγορία
// ─────────────────────────────────────────────
class _CategoryBudget {
  final String categoryId;
  final String categoryName;
  final double historicalAvgPerDay;
  final double suggestedBudget;
  final List<_SubcategoryBudget> subcategories;
  // ✅ ΝΕΟ: διαχωρισμός real από uncategorized
  final int realSubcategoryCount;
  final bool hasUncategorizedExpenses;

  const _CategoryBudget({
    required this.categoryId,
    required this.categoryName,
    required this.historicalAvgPerDay,
    required this.suggestedBudget,
    required this.subcategories,
    this.realSubcategoryCount = 0,
    this.hasUncategorizedExpenses = false,
  });
}

class _SubcategoryBudget {
  final String subcategoryId;
  final String subcategoryName;
  final double historicalAvgPerDay;
  final double suggestedBudget;

  const _SubcategoryBudget({
    required this.subcategoryId,
    required this.subcategoryName,
    required this.historicalAvgPerDay,
    required this.suggestedBudget,
  });
}

// ─────────────────────────────────────────────
// Τύποι επιλεγμένης περιόδου
// ─────────────────────────────────────────────
enum _PeriodType { week, month, year, custom }

// ─────────────────────────────────────────────
// Σελίδα
// ─────────────────────────────────────────────
class Stats4BudgetPage extends StatefulWidget {
  const Stats4BudgetPage({super.key});

  @override
  State<Stats4BudgetPage> createState() => _Stats4BudgetPageState();
}

class _Stats4BudgetPageState extends State<Stats4BudgetPage> {

  // ── STATE ────────────────────────────────
  _PeriodType _selectedPeriodType = _PeriodType.month;
  DateTime? _customStart;
  DateTime? _customEnd;
  double _savingsGoalPct = 10.0;

  bool _isLoading = false;
  bool _hasCalculated = false;
  String? _errorMsg;

  List<_CategoryBudget> _results = [];
  String _periodLabel = '';
  int _periodDays = 30;

  // Για export
  List<_CategoryBudget> _lastResults = [];
  String _lastPeriodLabel = '';
  double _lastGoalPct = 0;

  // Για αποθήκευση budget
  bool _budgetSaved = false;
  bool _isSavingBudget = false;

  late final TextEditingController _goalController;
  int _totalHistoricalDays = 0;

  final Map<String, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(text: '10');
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Στόχος Εξοικονόμησης. '
          'Ορίστε χρονική περίοδο και ποσοστό μείωσης εξόδων.',
    );
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────

  String _fmtAmt(double v) => CurrencyFormatter.format(v);

  String _buildPeriodLabel() {
    switch (_selectedPeriodType) {
      case _PeriodType.week:
        return 'Εβδομάδα (7 ημέρες)';
      case _PeriodType.month:
        return 'Μήνας (30 ημέρες)';
      case _PeriodType.year:
        return 'Έτος (365 ημέρες)';
      case _PeriodType.custom:
        if (_customStart == null || _customEnd == null) return 'Προσαρμοσμένο';
        final days = _customEnd!.difference(_customStart!).inDays + 1;
        final fmt = DateFormat('dd/MM/yyyy');
        return 'Προσαρμοσμένο: ${fmt.format(_customStart!)} - ${fmt.format(_customEnd!)} ($days ημέρες)';
    }
  }

  int _getPeriodDays() {
    switch (_selectedPeriodType) {
      case _PeriodType.week:   return 7;
      case _PeriodType.month:  return 30;
      case _PeriodType.year:   return 365;
      case _PeriodType.custom:
        if (_customStart == null || _customEnd == null) return 30;
        return _customEnd!.difference(_customStart!).inDays + 1;
    }
  }

  // Υπολογισμός ημερομηνιών για τον νέο προϋπολογισμό
  // Ξεκινά από σήμερα και καλύπτει την επιλεγμένη περίοδο
  (DateTime start, DateTime end) _getBudgetDateRange() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    switch (_selectedPeriodType) {
      case _PeriodType.week:
        return (startOfToday, startOfToday.add(const Duration(days: 6)));
      case _PeriodType.month:
        return (startOfToday, startOfToday.add(const Duration(days: 29)));
      case _PeriodType.year:
        return (startOfToday, startOfToday.add(const Duration(days: 364)));
      case _PeriodType.custom:
        if (_customStart != null && _customEnd != null) {
          return (_customStart!, _customEnd!);
        }
        return (startOfToday, startOfToday.add(const Duration(days: 29)));
    }
  }

  String _getPeriodTypeString() {
    switch (_selectedPeriodType) {
      case _PeriodType.week:   return 'weekly';
      case _PeriodType.month:  return 'monthly';
      case _PeriodType.year:   return 'yearly';
      case _PeriodType.custom: return 'custom';
    }
  }

  // ── Main calculation ────────────────────────

  Future<void> _calculate() async {
    // Offline: δεν μπλοκάρουμε — το Firestore χρησιμοποιεί local cache.
    // Το offline banner εμφανίζεται ήδη στο build() μέσω context.watch.

    final goalText = _goalController.text.trim().replaceAll(',', '.');
    final goal = double.tryParse(goalText);
    if (goal == null || goal <= 0 || goal >= 100) {
      setState(() {
        _errorMsg = 'Ο στόχος εξοικονόμησης πρέπει να είναι μεταξύ 1% και 99%.';
      });
      return;
    }

    if (_selectedPeriodType == _PeriodType.custom &&
        (_customStart == null || _customEnd == null)) {
      setState(() {
        _errorMsg = 'Ορίστε ημερομηνία έναρξης και λήξης για την προσαρμοσμένη περίοδο.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _hasCalculated = false;
      _budgetSaved = false;
    });

    AccessibilityService.announcePolite('Υπολογισμός προβλέψεων...');

    try {
      final userId = context.session.userId;
      final categoriesProvider = context.read<CategoriesProvider>();

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('deleted', isEqualTo: false)
          .get(const GetOptions(source: Source.serverAndCache));

      final allDocs = snapshot.docs;

      if (allDocs.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Δεν υπάρχουν δεδομένα συναλλαγών για ανάλυση.';
        });
        return;
      }

      DateTime? firstDate;
      DateTime? lastDate;

      for (final doc in allDocs) {
        final data = doc.data();
        final ts = data['date'];
        if (ts == null) continue;
        final dt = ts is Timestamp ? ts.toDate() : null;
        if (dt == null) continue;
        if (firstDate == null || dt.isBefore(firstDate)) firstDate = dt;
        if (lastDate == null || dt.isAfter(lastDate)) lastDate = dt;
      }

      if (firstDate == null || lastDate == null) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Δεν βρέθηκαν έγκυρες ημερομηνίες στα δεδομένα.';
        });
        return;
      }

      final today = DateTime.now();
      final totalDays = today.difference(firstDate).inDays;
      if (totalDays <= 0) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Ανεπαρκές ιστορικό δεδομένων για υπολογισμό.';
        });
        return;
      }

      final Map<String, Map<String?, double>> catSubTotals = {};
      final Map<String, double> catTotals = {};

      // Expense categories από provider (για εμφάνιση ονομάτων αργότερα)
      final expenseCategories = categoriesProvider.getCategoriesByType('expense');
      final expenseCategoryIds = expenseCategories.map((c) => c.uuid).toSet();

      for (final doc in allDocs) {
        final data = doc.data();
        final categoryId = data['category_id'] as String?;
        final subcategoryId = data['subcategory_id'] as String?;
        final rawAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final absAmount = rawAmount.abs(); // ✅ Χειρίζεται και αρνητικά ποσά

        // ── Φιλτράρισμα ακριβώς όπως το budgets_provider ──────────
        final transactionType = data['transaction_type'] as String?;
        final transferGroupId  = data['transfer_group_id']  as String?;

        // Παράλειψη μεταφορών (και οι δύο τρόποι αναγνώρισης)
        if (transactionType == 'transfer') continue;
        if (transferGroupId != null && transferGroupId.isNotEmpty) continue;

        // Παράλειψη εσόδων
        if (transactionType == 'income') continue;

        // Παράλειψη αν δεν υπάρχει κατηγορία
        if (categoryId == null || categoryId.isEmpty) continue;

        // Παράλειψη αν το ποσό είναι μηδέν
        if (absAmount <= 0) continue;

        // ✅ Αποδεχόμαστε την κατηγορία αν:
        //    α) το transaction_type είναι ρητά 'expense', Ή
        //    β) η κατηγορία βρίσκεται στις expense κατηγορίες του provider, Ή
        //    γ) δεν υπάρχει transaction_type (παλιά δεδομένα) και δεν είναι income
        final isExpenseByType   = transactionType == 'expense';
        final isExpenseByCategory = expenseCategoryIds.contains(categoryId);
        final hasNoType         = transactionType == null || transactionType.isEmpty;

        if (!isExpenseByType && !isExpenseByCategory && !hasNoType) continue;

        catTotals[categoryId] = (catTotals[categoryId] ?? 0.0) + absAmount;
        catSubTotals.putIfAbsent(categoryId, () => {});
        catSubTotals[categoryId]![subcategoryId] =
            (catSubTotals[categoryId]![subcategoryId] ?? 0.0) + absAmount;
      }

      // ✅ Δεν μπλοκάρουμε ακόμα και με λίγα δεδομένα — συνεχίζουμε πάντα
      if (catTotals.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Δεν βρέθηκαν συναλλαγές εξόδων. '
              'Βεβαιωθείτε ότι υπάρχουν καταχωρημένα έξοδα στην εφαρμογή.';
        });
        return;
      }

      final periodDays = _getPeriodDays();
      final reductionFactor = 1.0 - (goal / 100.0);
      final results = <_CategoryBudget>[];

      for (final cat in expenseCategories) {
        final totalForCat = catTotals[cat.uuid] ?? 0.0;
        if (totalForCat == 0.0) continue;

        final dailyAvg = totalForCat / totalDays;
        final periodScaled = dailyAvg * periodDays;
        final suggested = periodScaled * reductionFactor;

        final subcategoryResults = <_SubcategoryBudget>[];
        final subMap = catSubTotals[cat.uuid] ?? {};
        final allSubs = categoriesProvider.getSubcategoriesForCategory(cat.uuid);

        for (final sub in allSubs) {
          final subTotal = subMap[sub.uuid] ?? 0.0;
          if (subTotal == 0.0) continue;
          final subDailyAvg = subTotal / totalDays;
          final subScaled = subDailyAvg * periodDays;
          subcategoryResults.add(_SubcategoryBudget(
            subcategoryId: sub.uuid,
            subcategoryName: sub.name,
            historicalAvgPerDay: subDailyAvg,
            suggestedBudget: subScaled * reductionFactor,
          ));
        }

        final uncategorizedTotal = subMap[null] ?? 0.0;
        if (uncategorizedTotal > 0.0) {
          final uDailyAvg = uncategorizedTotal / totalDays;
          final uScaled = uDailyAvg * periodDays;
          subcategoryResults.add(_SubcategoryBudget(
            subcategoryId: '__none__',
            subcategoryName: '(Χωρίς υποκατηγορία)',
            historicalAvgPerDay: uDailyAvg,
            suggestedBudget: uScaled * reductionFactor,
          ));
        }

        // ✅ Διαχωρίζουμε real subcategories από __none__
        // Έτσι ξέρουμε αν η κατηγορία θα είναι expandable στον προϋπολογισμό
        final realSubcategories = subcategoryResults
            .where((s) => s.subcategoryId != '__none__')
            .toList();
        final hasUncategorized = subcategoryResults
            .any((s) => s.subcategoryId == '__none__');

        results.add(_CategoryBudget(
          categoryId: cat.uuid,
          categoryName: cat.name,
          historicalAvgPerDay: dailyAvg,
          suggestedBudget: suggested,
          subcategories: subcategoryResults,       // εμφανίζονται στη stats4 σελίδα
          realSubcategoryCount: realSubcategories.length,
          hasUncategorizedExpenses: hasUncategorized,
        ));
      }

      results.sort((a, b) => b.suggestedBudget.compareTo(a.suggestedBudget));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasCalculated = true;
        _results = results;
        _lastResults = List.from(results);
        _periodLabel = _buildPeriodLabel();
        _periodDays = periodDays;
        _lastPeriodLabel = _buildPeriodLabel();
        _lastGoalPct = goal;
        _savingsGoalPct = goal;
        _totalHistoricalDays = totalDays;
        _errorMsg = null;
        _budgetSaved = false;
      });

      AccessibilityService.announcePolite(
          'Ο υπολογισμός ολοκληρώθηκε. Βλέπετε ${results.length} κατηγορίες.');

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = 'Σφάλμα υπολογισμού: $e';
      });
      AccessibilityService.announceAssertive('Σφάλμα κατά τον υπολογισμό.');
    }
  }

  // ── Save as Budget ──────────────────────────

  Future<void> _showSaveBudgetDialog() async {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final primary = ColorsUI.getPrimary(brightness);
    final textPrimary = ColorsUI.getTextPrimary(brightness);
    final textSecondary = ColorsUI.getTextSecondary(brightness);
    final cardColor = ColorsUI.getCard(brightness);

    final (startDate, endDate) = _getBudgetDateRange();
    final fmt = DateFormat('dd/MM/yyyy');
    final totalSuggested = _lastResults.fold(0.0, (s, r) => s + r.suggestedBudget);

    // Count categories (exclude subcategories with __none__ from sub-budgets)
    final categoryCount = _lastResults.length;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.savings_rounded, color: primary, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Αποθήκευση Προϋπολογισμού',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info description
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primary.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'Θέλετε να δημιουργηθεί αυτόματα ο παρακάτω προϋπολογισμός στη σελίδα Προϋπολογισμών;',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Budget details
              _DialogInfoRow(
                label: 'Όνομα:',
                value: 'Εξοικονόμηση Περιόδου',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                valueColor: primary,
                bold: true,
              ),
              _DialogInfoRow(
                label: 'Από:',
                value: fmt.format(startDate),
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _DialogInfoRow(
                label: 'Έως:',
                value: fmt.format(endDate),
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _DialogInfoRow(
                label: 'Στόχος:',
                value: '${_lastGoalPct.toStringAsFixed(0)}% μείωση',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 12),
              Divider(color: ColorsUI.getDivider(brightness), height: 1),
              const SizedBox(height: 12),

              // What will be created
              Text(
                'Θα δημιουργηθούν:',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),

          _DialogBullet(
            icon: Icons.account_tree_rounded,
            text: '$categoryCount προϋπολογισμοί κατηγοριών',
            color: primary,
            textColor: textSecondary,
          ),
          const SizedBox(height: 4),
          _DialogBullet(
            icon: Icons.subdirectory_arrow_right_rounded,
            text: '${_lastResults.fold(0, (s, c) => s + c.subcategories.where((s) => s.subcategoryId != '__none__').length)} υποκατηγορίες',
            color: primary,
            textColor: textSecondary,
          ),
              const SizedBox(height: 4),
              _DialogBullet(
                icon: Icons.bar_chart_rounded,
                text: 'Σύνολο: ${_fmtAmt(totalSuggested)}',
                color: isDark ? ColorsUI.successDark : ColorsUI.successLight,
                textColor: textSecondary,
              ),

              const SizedBox(height: 12),

              // Warning if existing budgets could conflict
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: (isDark ? ColorsUI.warningDark : ColorsUI.warningLight)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isDark ? ColorsUI.warningDark : ColorsUI.warningLight)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: isDark ? ColorsUI.warningDark : ColorsUI.warningLight,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Οι προϋπολογισμοί θα εμφανιστούν αμέσως στη σελίδα Προϋπολογισμών.',
                        style: TextStyle(
                          color: isDark ? ColorsUI.warningDark : ColorsUI.warningLight,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Άκυρο',
              style: TextStyle(color: textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: ColorsUI.getOnPrimary(brightness),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const ExcludeSemantics(
              child: Icon(Icons.check_rounded, size: 18),
            ),
            label: const Text('Δημιουργία'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _saveBudgets(startDate: startDate, endDate: endDate);
    }
  }

  Future<void> _saveBudgets({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_lastResults.isEmpty) return;

    setState(() => _isSavingBudget = true);
    AccessibilityService.announcePolite('Αποθήκευση προϋπολογισμών...');

    try {
      final userId = context.session.userId;
      final now = DateTime.now();
      final periodType = _getPeriodTypeString();
      final db = FirebaseFirestore.instance;

      // Το Firestore batch δέχεται max 500 ops — για ασφάλεια κάνουμε
      // flush κάθε 400 εγγραφές
      var batch = db.batch();
      int opsInBatch = 0;
      bool timedOut = false;

      Future<void> flushBatch() async {
        if (opsInBatch == 0) return;
        try {
          await batch.commit().timeout(
            const Duration(seconds: 5),
            onTimeout: () { timedOut = true; },
          );
        } catch (_) {
          timedOut = true;
        }
        batch = db.batch();
        opsInBatch = 0;
      }

      void addToBatch(DocumentReference ref, Map<String, dynamic> data) {
        batch.set(ref, data, SetOptions(merge: true));
        opsInBatch++;
      }

      // ── 1. Budget Συνόλου (total-level) ────────────────────
      final totalSuggested =
      _lastResults.fold(0.0, (s, r) => s + r.suggestedBudget);

      final totalRef = db
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .doc();

      addToBatch(totalRef, BudgetModel(
        uuid: totalRef.id,
        userId: userId,
        name: 'Εξοικονόμηση Περιόδου',
        budgetType: 'total',
        categoryId: null,
        subcategoryId: null,
        accountId: null,
        periodType: periodType,
        startDate: startDate,
        endDate: endDate,
        amount: double.parse(totalSuggested.toStringAsFixed(2)),
        currency: 'EUR',
        alertThreshold: 80,
        allowOverspend: true,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        lastModifiedDeviceId: '',
        deleted: false,
      ).toMap());

      // ── 2. Budget ανά κατηγορία + υποκατηγορία ─────────────
      for (final cat in _lastResults) {

        // 2a. Category-level budget
        final catRef = db
            .collection('users')
            .doc(userId)
            .collection('budgets')
            .doc();

        addToBatch(catRef, BudgetModel(
          uuid: catRef.id,
          userId: userId,
          name: 'Εξοικονόμηση Περιόδου',
          budgetType: 'category',
          categoryId: cat.categoryId,
          subcategoryId: null,
          accountId: null,
          periodType: periodType,
          startDate: startDate,
          endDate: endDate,
          amount: double.parse(cat.suggestedBudget.toStringAsFixed(2)),
          currency: 'EUR',
          alertThreshold: 80,
          allowOverspend: true,
          isActive: true,
          createdAt: now,
          updatedAt: now,
          lastModifiedDeviceId: '',
          deleted: false,
        ).toMap());

        // 2b. Subcategory-level budgets (ένα ανά υποκατηγορία)
        // ✅ Παραλείπουμε το '__none__' — δεν είναι πραγματική υποκατηγορία
        for (final sub in cat.subcategories) {
          if (sub.subcategoryId == '__none__') continue;

          final subRef = db
              .collection('users')
              .doc(userId)
              .collection('budgets')
              .doc();

          addToBatch(subRef, BudgetModel(
            uuid: subRef.id,
            userId: userId,
            name: 'Εξοικονόμηση Περιόδου',    // ✅ ΊΔΙΟόνομα group
            budgetType: 'subcategory',
            categoryId: cat.categoryId,
            subcategoryId: sub.subcategoryId,
            accountId: null,
            periodType: periodType,
            startDate: startDate,
            endDate: endDate,
            amount: double.parse(sub.suggestedBudget.toStringAsFixed(2)),
            currency: 'EUR',
            alertThreshold: 80,
            allowOverspend: true,
            isActive: true,
            createdAt: now,
            updatedAt: now,
            lastModifiedDeviceId: '',
            deleted: false,
          ).toMap());

          // Flush αν πλησιάζουμε το όριο
          if (opsInBatch >= 400) await flushBatch();
        }
      }

      // Τελικό flush
      await flushBatch();

      if (!mounted) return;

      setState(() {
        _isSavingBudget = false;
        _budgetSaved = true;
      });

      final msg = timedOut
          ? 'Οι προϋπολογισμοί αποθηκεύτηκαν τοπικά (θα συγχρονιστούν αργότερα).'
          : 'Οι προϋπολογισμοί δημιουργήθηκαν επιτυχώς στη σελίδα Προϋπολογισμών!';

      AccessibilityService.announcePolite(msg);
      _showSnack(msg, isError: false);

    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingBudget = false);
      _showSnack('Σφάλμα αποθήκευσης: $e', isError: true);
      AccessibilityService.announceAssertive('Σφάλμα αποθήκευσης προϋπολογισμών.');
    }
  }

  // ── Date picker helpers ────────────────────

  Future<void> _pickCustomStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customStart ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Επιλογή ημερομηνίας έναρξης',
    );
    if (picked != null && mounted) {
      setState(() {
        _customStart = picked;
        if (_customEnd != null && _customEnd!.isBefore(picked)) {
          _customEnd = null;
        }
      });
    }
  }

  Future<void> _pickCustomEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customEnd ?? DateTime.now(),
      firstDate: _customStart ?? DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Επιλογή ημερομηνίας λήξης',
    );
    if (picked != null && mounted) {
      setState(() => _customEnd = picked);
    }
  }

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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final bgColor = ColorsUI.getBackground(brightness);
    final cardColor = ColorsUI.getCard(brightness);
    final textPrimary = ColorsUI.getTextPrimary(brightness);
    final textSecondary = ColorsUI.getTextSecondary(brightness);
    final primary = ColorsUI.getPrimary(brightness);

    context.watch<ConnectivityService>();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: ColorsUI.getOnPrimary(brightness),
        iconTheme: IconThemeData(color: ColorsUI.getOnPrimary(brightness)),
        title: Semantics(
          header: true,
          child: Text(
            'Στόχος Εξοικονόμησης',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ColorsUI.getOnPrimary(brightness),
            ),
          ),
        ),
        actions: [
          if (_hasCalculated) ...[
            Semantics(
              label: 'Εξαγωγή σε Excel',
              button: true,
              child: IconButton(
                icon: const ExcludeSemantics(
                  child: Icon(Icons.table_view_rounded),
                ),
                tooltip: 'Export Excel',
                onPressed: _exportToExcel,
              ),
            ),
            Semantics(
              label: 'Εξαγωγή σε PDF',
              button: true,
              child: IconButton(
                icon: const ExcludeSemantics(
                  child: Icon(Icons.picture_as_pdf_rounded),
                ),
                tooltip: 'Export PDF',
                onPressed: _exportToPdf,
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 900
                ? 860.0
                : constraints.maxWidth > 600
                ? constraints.maxWidth * 0.9
                : constraints.maxWidth;
            final hPad = constraints.maxWidth > 600 ? 24.0 : 12.0;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // ── Offline banner ──────────────────────
                      // if (connectivity.isOffline)
                      //   Semantics(
                      //     liveRegion: true,
                      //     child: Container(
                      //       margin: const EdgeInsets.only(bottom: 10),
                      //       padding: const EdgeInsets.symmetric(
                      //           horizontal: 12, vertical: 8),
                      //       decoration: BoxDecoration(
                      //         color: ColorsUI.warningLight.withValues(alpha: 0.15),
                      //         borderRadius: BorderRadius.circular(8),
                      //         border: Border.all(
                      //             color: ColorsUI.warningLight
                      //                 .withValues(alpha: 0.5)),
                      //       ),
                      //       child: Row(
                      //         children: [
                      //           Icon(Icons.wifi_off_rounded,
                      //               color: isDark
                      //                   ? ColorsUI.warningDark
                      //                   : ColorsUI.warningLight,
                      //               size: 18),
                      //           const SizedBox(width: 8),
                      //           Expanded(
                      //             child: Text(
                      //               'Εκτός σύνδεσης — τα δεδομένα ενδέχεται να μην είναι ενημερωμένα.',
                      //               style: TextStyle(
                      //                 color: isDark
                      //                     ? ColorsUI.warningDark
                      //                     : ColorsUI.warningLight,
                      //                 fontSize: 12,
                      //               ),
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   ),

                      // ── Κάρτα Παραμέτρων ───────────────────
                      _buildParamsCard(
                        cardColor: cardColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        primary: primary,
                        isDark: isDark,
                        brightness: brightness,
                      ),

                      const SizedBox(height: 16),

                      // ── Error message ───────────────────────
                      if (_errorMsg != null)
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ColorsUI.errorLight.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: ColorsUI.errorLight
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                ExcludeSemantics(
                                  child: Icon(Icons.error_outline,
                                      color: isDark
                                          ? ColorsUI.errorDark
                                          : ColorsUI.errorLight,
                                      size: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMsg!,
                                    style: TextStyle(
                                      color: isDark
                                          ? ColorsUI.errorDark
                                          : ColorsUI.errorLight,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── Loading ─────────────────────────────
                      if (_isLoading)
                          Semantics(
                            liveRegion: true,
                            label: 'Γίνεται υπολογισμός. Ανάλυση ιστορικών δεδομένων.',
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  children: [
                                    ExcludeSemantics(
                                      child: CircularProgressIndicator(),
                                    ),
                                    SizedBox(height: 16),
                                    ExcludeSemantics(
                                      child: Text('Ανάλυση ιστορικών δεδομένων...'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                      // ── Results ─────────────────────────────
                      if (_hasCalculated && !_isLoading)
                        _buildResults(
                          cardColor: cardColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          primary: primary,
                          isDark: isDark,
                          brightness: brightness,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  // ════════════════════════════════════════════
  // ΚΆΡΤΑ ΠΑΡΑΜΈΤΡΩΝ
  // ════════════════════════════════════════════
  Widget _buildParamsCard({
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primary,
    required bool isDark,
    required Brightness brightness,
  }) {
    final dividerColor = ColorsUI.getDivider(brightness);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? ColorsUI.shadowDark : ColorsUI.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.savings_rounded, color: primary, size: 22),
              ),
              const SizedBox(width: 8),
              Semantics(
                header: true,
                child: Text(
                  'Παράμετροι Στόχου',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          ExcludeSemantics(
            child: Divider(color: dividerColor, height: 1),
          ),
          const SizedBox(height: 16),

          Text(
            'Χρονική Περίοδος Στόχου',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),

          Semantics(
            label: 'Επιλογή χρονικής περιόδου',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PeriodChip(
                  label: 'Εβδομάδα',
                  selected: _selectedPeriodType == _PeriodType.week,
                  onTap: () => setState(() {
                    _selectedPeriodType = _PeriodType.week;
                    _hasCalculated = false;
                    _budgetSaved = false;
                  }),
                  primary: primary,
                  textPrimary: textPrimary,
                  isDark: isDark,
                ),
                _PeriodChip(
                  label: 'Μήνας',
                  selected: _selectedPeriodType == _PeriodType.month,
                  onTap: () => setState(() {
                    _selectedPeriodType = _PeriodType.month;
                    _hasCalculated = false;
                    _budgetSaved = false;
                  }),
                  primary: primary,
                  textPrimary: textPrimary,
                  isDark: isDark,
                ),
                _PeriodChip(
                  label: 'Έτος',
                  selected: _selectedPeriodType == _PeriodType.year,
                  onTap: () => setState(() {
                    _selectedPeriodType = _PeriodType.year;
                    _hasCalculated = false;
                    _budgetSaved = false;
                  }),
                  primary: primary,
                  textPrimary: textPrimary,
                  isDark: isDark,
                ),
                _PeriodChip(
                  label: 'Προσαρμοσμένο',
                  selected: _selectedPeriodType == _PeriodType.custom,
                  onTap: () => setState(() {
                    _selectedPeriodType = _PeriodType.custom;
                    _hasCalculated = false;
                    _budgetSaved = false;
                  }),
                  primary: primary,
                  textPrimary: textPrimary,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          if (_selectedPeriodType == _PeriodType.custom) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Από',
                    date: _customStart,
                    onTap: _pickCustomStart,
                    primary: primary,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateButton(
                    label: 'Έως',
                    date: _customEnd,
                    onTap: _pickCustomEnd,
                    primary: primary,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          ExcludeSemantics(
            child: Divider(color: dividerColor, height: 1),
          ),
          const SizedBox(height: 16),

          Text(
            'Στόχος Εξοικονόμησης (%)',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Εισάγετε το ποσοστό μείωσης εξόδων που θέλετε να επιτύχετε',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Ρυθμιστικό στόχου εξοικονόμησης',
                  child: Slider(
                    value: _savingsGoalPct.clamp(1, 50),
                    min: 1,
                    max: 50,
                    divisions: 49,
                    activeColor: primary,
                    onChanged: (v) {
                      final rounded = v.round().toDouble();
                      setState(() {
                        _savingsGoalPct = rounded;
                        _goalController.text = rounded.toStringAsFixed(0);
                        _hasCalculated = false;
                        _budgetSaved = false;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: Semantics(
                  label: 'Εισαγωγή ποσοστού στόχου',
                  child: TextField(
                    controller: _goalController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      suffixText: '%',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primary, width: 2),
                      ),
                    ),
                    style: TextStyle(
                        color: textPrimary, fontWeight: FontWeight.bold),
                    onChanged: (v) {
                      final parsed =
                      double.tryParse(v.replaceAll(',', '.'));
                      if (parsed != null && parsed >= 1 && parsed <= 50) {
                        setState(() {
                          _savingsGoalPct = parsed;
                          _hasCalculated = false;
                          _budgetSaved = false;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'Στόχος: ${_savingsGoalPct.toStringAsFixed(0)}% μείωση εξόδων',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          ExcludeSemantics(
            child: Divider(color: dividerColor, height: 1),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: Semantics(
              button: true,
              label: 'Εκτέλεση υπολογισμού στόχου εξοικονόμησης',
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _calculate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: ColorsUI.getOnPrimary(brightness),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const ExcludeSemantics(
                  child: Icon(Icons.calculate_rounded),
                ),
                label: Text(
                  _isLoading ? 'Υπολογισμός...' : 'Υπολόγισε Στόχο',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // ΑΠΟΤΕΛΈΣΜΑΤΑ
  // ════════════════════════════════════════════
  Widget _buildResults({
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primary,
    required bool isDark,
    required Brightness brightness,
  }) {
    final totalSuggested = _results.fold(0.0, (s, r) => s + r.suggestedBudget);
    final totalHistAvg =
    _results.fold(0.0, (s, r) => s + r.historicalAvgPerDay * _periodDays);
    final saving = totalHistAvg - totalSuggested;
    final successColor = isDark ? ColorsUI.successDark : ColorsUI.successLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        // ── Summary Card ───────────────────────
        Semantics(
          label: 'Σύνοψη αποτελεσμάτων',
          child: Container(
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(Icons.insights_rounded, color: primary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Σύνοψη Πρόβλεψης',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  label: 'Χρονική Περίοδος:',
                  value: _periodLabel,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                _SummaryRow(
                  label: 'Ιστορικό Δεδομένων:',
                  value: '$_totalHistoricalDays ημέρες',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                _SummaryRow(
                  label: 'Στόχος Εξοικονόμησης:',
                  value: '${_lastGoalPct.toStringAsFixed(0)}%',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  valueColor: primary,
                ),
                const SizedBox(height: 8),
                Divider(color: ColorsUI.getDivider(brightness), height: 1),
                const SizedBox(height: 8),
                _SummaryRow(
                  label: 'Μέσος Όρος Εξόδων (περίοδος):',
                  value: _fmtAmt(totalHistAvg),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  valueColor:
                  isDark ? ColorsUI.expenseDark : ColorsUI.expenseLight,
                  bold: true,
                ),
                _SummaryRow(
                  label: 'Προτεινόμενο Ανώτατο Όριο:',
                  value: _fmtAmt(totalSuggested),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  valueColor: successColor,
                  bold: true,
                ),
                _SummaryRow(
                  label: 'Εξοικονόμηση (στόχος):',
                  value: _fmtAmt(saving),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  valueColor: successColor,
                  bold: true,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Κουμπί Αποθήκευσης ως Προϋπολογισμός ──────────
        Semantics(
          button: true,
          label: _budgetSaved
              ? 'Ο προϋπολογισμός αποθηκεύτηκε'
              : 'Αποθήκευση ως προϋπολογισμός Εξοικονόμηση Περιόδου',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: _budgetSaved
                  ? successColor.withValues(alpha: 0.1)
                  : primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _budgetSaved
                    ? successColor.withValues(alpha: 0.5)
                    : primary.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        _budgetSaved
                            ? Icons.check_circle_rounded
                            : Icons.account_balance_wallet_rounded,
                        color: _budgetSaved ? successColor : primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _budgetSaved
                                ? 'Προϋπολογισμός Δημιουργήθηκε!'
                                : 'Δημιουργία Προϋπολογισμού',
                            style: TextStyle(
                              color: _budgetSaved ? successColor : textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _budgetSaved
                                ? 'Ο προϋπολογισμός "Εξοικονόμηση Περιόδου" εμφανίζεται τώρα στη σελίδα Προϋπολογισμών.'
                                : 'Αποθηκεύστε αυτόματα το αποτέλεσμα ως προϋπολογισμό "Εξοικονόμηση Περιόδου" για να το παρακολουθείτε.',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_budgetSaved) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSavingBudget ? null : _showSaveBudgetDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: ColorsUI.getOnPrimary(brightness),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      icon: _isSavingBudget
                          ? const ExcludeSemantics(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                          : const ExcludeSemantics(
                        child: Icon(Icons.add_chart_rounded, size: 18),
                      ),
                      label: Text(
                        _isSavingBudget
                            ? 'Αποθήκευση...'
                            : 'Αποθήκευση ως Προϋπολογισμός',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  // "Νέος υπολογισμός" link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _hasCalculated = false;
                          _budgetSaved = false;
                          _results = [];
                        });
                      },
                      icon: ExcludeSemantics(
                        child: Icon(Icons.refresh_rounded,
                            size: 16, color: primary),
                      ),
                      label: Text(
                        'Νέος υπολογισμός',
                        style: TextStyle(color: primary, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Επεξήγηση ───────────────────────────
        Semantics(
          label: 'Επεξήγηση αποτελεσμάτων',
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? ColorsUI.infoDark.withValues(alpha: 0.1)
                  : ColorsUI.infoLight.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? ColorsUI.infoDark.withValues(alpha: 0.3)
                    : ColorsUI.infoLight.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: isDark ? ColorsUI.infoDark : ColorsUI.infoLight,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Τα παρακάτω ποσά είναι τα ΑΝΩΤΑΤΑ ΟΡΙΑ δαπάνης ανά κατηγορία για '
                        'τη επιλεγμένη περίοδο. Εάν τηρηθούν, θα επιτύχετε '
                        '${_lastGoalPct.toStringAsFixed(0)}% μείωση εξόδων σε σχέση με '
                        'τον ιστορικό μέσο όρο.',
                    style: TextStyle(
                      color: isDark ? ColorsUI.infoDark : ColorsUI.infoLight,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Κεφαλίδα πίνακα ─────────────────────
        Semantics(
          header: true,
          label: 'Πίνακας αποτελεσμάτων ανά κατηγορία',
          child: _TableHeader(isDark: isDark, primary: primary),
        ),

        const SizedBox(height: 4),

        // ── Γραμμές κατηγοριών ──────────────────
        ..._results.asMap().entries.map((entry) {
          final idx = entry.key;
          final cat = entry.value;
          final isEven = idx % 2 == 0;
          final rowBg =
          isEven ? cardColor : cardColor.withValues(alpha: 0.7);
          final isExpanded =
              _expandedCategories[cat.categoryId] ?? false;

          return Semantics(
            label: 'Κατηγορία ${cat.categoryName}',
            child: _CategoryRow(
              cat: cat,
              isExpanded: isExpanded,
              rowBg: rowBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isDark: isDark,
              primary: primary,
              brightness: brightness,
              periodDays: _periodDays,
              fmtAmt: _fmtAmt,
              showUncategorizedNote: cat.hasUncategorizedExpenses && cat.realSubcategoryCount == 0,
              onToggle: () {
                setState(() {
                  _expandedCategories[cat.categoryId] = !isExpanded;
                });
                AccessibilityService.announcePolite(
                  isExpanded
                      ? 'Έκλεισε η κατηγορία ${cat.categoryName}'
                      : 'Άνοιξε η κατηγορία ${cat.categoryName}',
                );
              },
            ),
          );
        }),

        const SizedBox(height: 8),

        // ── Σύνολο ──────────────────────────────
        _TotalRow(
          totalSuggested: totalSuggested,
          totalHistAvg: totalHistAvg,
          isDark: isDark,
          primary: primary,
          textPrimary: textPrimary,
          fmtAmt: _fmtAmt,
        ),

        const SizedBox(height: 20),

        // ── Export Buttons ───────────────────────
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Εξαγωγή σε Excel',
                child: OutlinedButton.icon(
                  onPressed: _exportToExcel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const ExcludeSemantics(
                    child: Icon(Icons.table_view_rounded, size: 18),
                  ),
                  label: const Text('Export Excel'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Εξαγωγή σε PDF',
                child: OutlinedButton.icon(
                  onPressed: _exportToPdf,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const ExcludeSemantics(
                    child: Icon(Icons.picture_as_pdf_rounded, size: 18),
                  ),
                  label: const Text('Export PDF'),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }
  // ════════════════════════════════════════════
  // EXPORT TO EXCEL
  // ════════════════════════════════════════════
  Future<void> _exportToExcel() async {
    if (_lastResults.isEmpty) {
      _showSnack('Δεν υπάρχουν δεδομένα για εξαγωγή.', isError: true);
      return;
    }

    AccessibilityService.announcePolite('Δημιουργία αρχείου Excel...');

    try {
      final excel = Excel.createExcel();
      for (final name in excel.sheets.keys.toList()) {
        excel.delete(name);
      }

      const sheetName = 'Στόχος Εξοικονόμησης';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      final now = DateTime.now();
      final dtFmt = DateFormat('dd/MM/yyyy HH:mm');

      sheet.appendRow([TextCellValue('Στόχος Εξοικονόμησης — Πρόβλεψη Δαπανών')]);
      sheet.appendRow([TextCellValue('Περίοδος:'), TextCellValue(_lastPeriodLabel)]);
      sheet.appendRow([
        TextCellValue('Στόχος μείωσης:'),
        TextCellValue('${_lastGoalPct.toStringAsFixed(0)}%'),
      ]);
      sheet.appendRow([
        TextCellValue('Ιστορικό δεδομένων:'),
        TextCellValue('$_totalHistoricalDays ημέρες'),
      ]);
      sheet.appendRow([
        TextCellValue('Ημερομηνία εξαγωγής:'),
        TextCellValue(dtFmt.format(now)),
      ]);
      sheet.appendRow([TextCellValue('')]);

      sheet.appendRow([
        TextCellValue('ΚΑΤΗΓΟΡΙΑ'),
        TextCellValue('ΥΠΟΚΑΤΗΓΟΡΙΑ'),
        TextCellValue('ΜΕΣΟΣ ΟΡΟΣ ΗΜΕΡΑΣ (€)'),
        TextCellValue('ΜΕΣΟΣ ΟΡΟΣ ΠΕΡΙΟΔΟΥ (€)'),
        TextCellValue('ΑΝΩΤΑΤΟ ΟΡΙΟ (€)'),
        TextCellValue('ΕΞΟΙΚΟΝΟΜΗΣΗ (€)'),
      ]);

      double totalHistAvg = 0;
      double totalSuggested = 0;

      for (final cat in _lastResults) {
        final catHistPeriod = cat.historicalAvgPerDay * _periodDays;
        totalHistAvg += catHistPeriod;
        totalSuggested += cat.suggestedBudget;

        sheet.appendRow([
          TextCellValue(cat.categoryName),
          TextCellValue('— ΣΥΝΟΛΟ ΚΑΤΗΓΟΡΙΑΣ —'),
          TextCellValue(CurrencyFormatter.format(cat.historicalAvgPerDay)),
          TextCellValue(CurrencyFormatter.format(catHistPeriod)),
          TextCellValue(CurrencyFormatter.format(cat.suggestedBudget)),
          TextCellValue(CurrencyFormatter.format(catHistPeriod - cat.suggestedBudget)),
        ]);

        for (final sub in cat.subcategories) {
          final subHistPeriod = sub.historicalAvgPerDay * _periodDays;
          sheet.appendRow([
            TextCellValue(''),
            TextCellValue('  › ${sub.subcategoryName}'),
            TextCellValue(CurrencyFormatter.format(sub.historicalAvgPerDay)),
            TextCellValue(CurrencyFormatter.format(subHistPeriod)),
            TextCellValue(CurrencyFormatter.format(sub.suggestedBudget)),
            TextCellValue(CurrencyFormatter.format(subHistPeriod - sub.suggestedBudget)),
          ]);
        }
      }

      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue('ΣΥΝΟΛΟ'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(CurrencyFormatter.format(totalHistAvg)),
        TextCellValue(CurrencyFormatter.format(totalSuggested)),
        TextCellValue(CurrencyFormatter.format(totalHistAvg - totalSuggested)),
      ]);

      final bytes = excel.encode();
      if (bytes == null) {
        _showSnack('Σφάλμα δημιουργίας Excel.', isError: true);
        return;
      }

      final ts = DateFormat('yyyyMMdd_HHmm').format(now);
      final fileName = 'Στόχος_Εξοικονόμησης_$ts.xlsx';

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

  // ════════════════════════════════════════════
  // EXPORT TO PDF
  // ════════════════════════════════════════════
  Future<void> _exportToPdf() async {
    if (_lastResults.isEmpty) {
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

      double totalHistAvg = _lastResults.fold(
          0.0, (s, r) => s + r.historicalAvgPerDay * _periodDays);
      double totalSuggested =
      _lastResults.fold(0.0, (s, r) => s + r.suggestedBudget);
      double totalSaving = totalHistAvg - totalSuggested;

      final pw.TextStyle headerStyle = pw.TextStyle(
        font: ttfBold, fontSize: 9, fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      );
      final pw.TextStyle cellStyle = pw.TextStyle(font: ttf, fontSize: 8);
      final pw.TextStyle catStyle = pw.TextStyle(
        font: ttfBold, fontSize: 9, fontWeight: pw.FontWeight.bold,
      );
      final pw.TextStyle subStyle = pw.TextStyle(font: ttf, fontSize: 8);
      final pw.TextStyle totalStyle = pw.TextStyle(
        font: ttfBold, fontSize: 9, fontWeight: pw.FontWeight.bold,
      );

      pw.Widget buildCell(String text, pw.TextStyle style,
          {pw.Alignment align = pw.Alignment.centerRight, PdfColor? bg}) {
        return pw.Container(
          color: bg,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: pw.Align(
            alignment: align,
            child: pw.Text(text, style: style),
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(
            base: ttf, bold: ttfBold, italic: ttf, boldItalic: ttfBold,
          ),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Στόχος Εξοικονόμησης — Πρόβλεψη Δαπανών',
                style: pw.TextStyle(
                    font: ttfBold, fontSize: 15, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Text('Περίοδος: ', style: pw.TextStyle(font: ttfBold, fontSize: 9)),
                pw.Text(_lastPeriodLabel, style: pw.TextStyle(font: ttf, fontSize: 9)),
                pw.SizedBox(width: 20),
                pw.Text('Στόχος: ', style: pw.TextStyle(font: ttfBold, fontSize: 9)),
                pw.Text('${_lastGoalPct.toStringAsFixed(0)}% μείωση',
                    style: pw.TextStyle(font: ttf, fontSize: 9)),
                pw.SizedBox(width: 20),
                pw.Text('Ιστορικό: ', style: pw.TextStyle(font: ttfBold, fontSize: 9)),
                pw.Text('$_totalHistoricalDays ημέρες',
                    style: pw.TextStyle(font: ttf, fontSize: 9)),
              ]),
              pw.SizedBox(height: 2),
              pw.Text('Εξαγωγή: ${dtFmt.format(now)}',
                  style: pw.TextStyle(
                      font: ttf, fontSize: 8, color: PdfColors.grey600)),
              pw.Divider(thickness: 0.8),
              pw.SizedBox(height: 4),
            ],
          ),
          build: (context) {
            final content = <pw.Widget>[];

            content.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EDE7F6'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('Μέσος Όρος Περιόδου',
                          style: pw.TextStyle(font: ttf, fontSize: 8)),
                      pw.Text(CurrencyFormatter.format(totalHistAvg),
                          style: pw.TextStyle(
                              font: ttfBold, fontSize: 11,
                              color: PdfColor.fromHex('#C62828'))),
                    ]),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('Ανώτατο Όριο (Στόχος)',
                          style: pw.TextStyle(font: ttf, fontSize: 8)),
                      pw.Text(CurrencyFormatter.format(totalSuggested),
                          style: pw.TextStyle(
                              font: ttfBold, fontSize: 11,
                              color: PdfColor.fromHex('#2E7D32'))),
                    ]),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('Εξοικονόμηση', style: pw.TextStyle(font: ttf, fontSize: 8)),
                      pw.Text(CurrencyFormatter.format(totalSaving),
                          style: pw.TextStyle(
                              font: ttfBold, fontSize: 11,
                              color: PdfColor.fromHex('#2E7D32'))),
                    ]),
                  ],
                ),
              ),
            );
            content.add(pw.SizedBox(height: 12));

            const colWidths = {
              0: pw.FlexColumnWidth(2.5),
              1: pw.FlexColumnWidth(2.0),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(1.6),
              4: pw.FlexColumnWidth(1.6),
            };

            final tableRows = <pw.TableRow>[];
            tableRows.add(pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#6750A4')),
              children: [
                buildCell('ΚΑΤΗΓΟΡΙΑ', headerStyle, align: pw.Alignment.centerLeft),
                buildCell('ΥΠΟΚΑΤΗΓΟΡΙΑ', headerStyle, align: pw.Alignment.centerLeft),
                buildCell('ΜΕΣΟΣ ΟΡ. ΠΕΡΙΟΔΟΥ', headerStyle),
                buildCell('ΑΝΩΤΑΤΟ ΟΡΙΟ', headerStyle),
                buildCell('ΕΞΟΙΚΟΝΟΜΗΣΗ', headerStyle),
              ],
            ));

            int rowIdx = 0;
            for (final cat in _lastResults) {
              final catHistPeriod = cat.historicalAvgPerDay * _periodDays;
              final catSaving = catHistPeriod - cat.suggestedBudget;
              final catBg = rowIdx % 2 == 0
                  ? PdfColor.fromHex('#F3EFF9')
                  : PdfColor.fromHex('#FAFAFA');

              tableRows.add(pw.TableRow(
                decoration: pw.BoxDecoration(color: catBg),
                children: [
                  buildCell(cat.categoryName, catStyle,
                      align: pw.Alignment.centerLeft, bg: catBg),
                  buildCell('—', cellStyle,
                      align: pw.Alignment.centerLeft, bg: catBg),
                  buildCell(CurrencyFormatter.format(catHistPeriod), catStyle, bg: catBg),
                  buildCell(CurrencyFormatter.format(cat.suggestedBudget), catStyle, bg: catBg),
                  buildCell(CurrencyFormatter.format(catSaving), catStyle, bg: catBg),
                ],
              ));

              for (final sub in cat.subcategories) {
                final subHistPeriod = sub.historicalAvgPerDay * _periodDays;
                final subSaving = subHistPeriod - sub.suggestedBudget;
                final subBg = PdfColor.fromHex('#FFFFFF');
                tableRows.add(pw.TableRow(
                  decoration: pw.BoxDecoration(color: subBg),
                  children: [
                    buildCell('', subStyle, align: pw.Alignment.centerLeft, bg: subBg),
                    buildCell('  › ${sub.subcategoryName}', subStyle,
                        align: pw.Alignment.centerLeft, bg: subBg),
                    buildCell(CurrencyFormatter.format(subHistPeriod), subStyle, bg: subBg),
                    buildCell(CurrencyFormatter.format(sub.suggestedBudget), subStyle, bg: subBg),
                    buildCell(CurrencyFormatter.format(subSaving), subStyle, bg: subBg),
                  ],
                ));
              }
              rowIdx++;
            }

            final totalBg = PdfColor.fromHex('#EDE7F6');
            tableRows.add(pw.TableRow(
              decoration: pw.BoxDecoration(color: totalBg),
              children: [
                buildCell('ΣΥΝΟΛΟ', totalStyle,
                    align: pw.Alignment.centerLeft, bg: totalBg),
                buildCell('', totalStyle, bg: totalBg),
                buildCell(CurrencyFormatter.format(totalHistAvg), totalStyle, bg: totalBg),
                buildCell(CurrencyFormatter.format(totalSuggested), totalStyle, bg: totalBg),
                buildCell(CurrencyFormatter.format(totalSaving), totalStyle, bg: totalBg),
              ],
            ));

            content.add(pw.Table(
              columnWidths: colWidths,
              border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#CCCCCC'), width: 0.4),
              children: tableRows,
            ));

            content.add(pw.SizedBox(height: 8));
            content.add(pw.Text(
              '* Ο υπολογισμός βασίζεται στον ημερήσιο μέσο όρο εξόδων από $_totalHistoricalDays '
                  'ημέρες ιστορικού, κλιμακωμένο στη επιλεγμένη περίοδο με μείωση '
                  '${_lastGoalPct.toStringAsFixed(0)}%.',
              style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey600),
            ));

            return content;
          },
        ),
      );

      final bytes = await pdf.save();
      final ts = DateFormat('yyyyMMdd_HHmm').format(now);
      final fileName = 'Στόχος_Εξοικονόμησης_$ts.pdf';

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
}

// ════════════════════════════════════════════
// HELPER WIDGETS
// ════════════════════════════════════════════

// ── Period Chip ───────────────────────────────
class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;
  final Color textPrimary;
  final bool isDark;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primary,
    required this.textPrimary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${selected ? " (επιλεγμένο)" : ""}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? primary : primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? primary : primary.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? (isDark ? Colors.black : Colors.white)
                  : textPrimary,
              fontWeight:
              selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Date Button ───────────────────────────────
class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Semantics(
      button: true,
      label: '$label: ${date != null ? fmt.format(date!) : "Μη επιλεγμένο"}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: date != null
                  ? primary
                  : primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: textSecondary, fontSize: 11)),
                    Text(
                      date != null ? fmt.format(date!) : 'Επιλογή...',
                      style: TextStyle(
                        color: date != null ? textPrimary : textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Summary Row ───────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;
  final Color? valueColor;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(color: textSecondary, fontSize: 13)),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? textPrimary,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dialog Info Row ───────────────────────────
class _DialogInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;
  final Color? valueColor;
  final bool bold;

  const _DialogInfoRow({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? textPrimary,
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialog Bullet ─────────────────────────────
class _DialogBullet extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color textColor;

  const _DialogBullet({
    required this.icon,
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: textColor, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Table Header ──────────────────────────────
class _TableHeader extends StatelessWidget {
  final bool isDark;
  final Color primary;

  const _TableHeader({required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context) {
    // ✅ Στο dark mode το primary είναι ανοιχτό μωβ → χρειάζεται μαύρο κείμενο
    final headerTextColor = ColorsUI.getOnPrimary(
      isDark ? Brightness.dark : Brightness.light,
    );

    return Container(
      decoration: BoxDecoration(
        color: primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 22),
          Expanded(
            flex: 3,
            child: Text('ΚΑΤΗΓΟΡΙΑ',
                style: TextStyle(
                    color: headerTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ),
          Expanded(
            flex: 2,
            child: Text('ΜΕΣΟΣ ΟΡΟΣ',
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: headerTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ),
          Expanded(
            flex: 2,
            child: Text('ΑΝΩΤΑΤΟ ΟΡΙΟ',
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: headerTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ),
          Expanded(
            flex: 2,
            child: Text('ΕΞΟΙΚΟΝΟΜΗΣΗ',
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: headerTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ── Category Row ──────────────────────────────
class _CategoryRow extends StatelessWidget {
  final _CategoryBudget cat;
  final bool isExpanded;
  final Color rowBg;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;
  final Color primary;
  final Brightness brightness;
  final int periodDays;
  final String Function(double) fmtAmt;
  final VoidCallback onToggle;
  // ✅ ΝΕΟ: σήμανση για uncategorized-only κατηγορίες
  final bool showUncategorizedNote;

  const _CategoryRow({
    required this.cat,
    required this.isExpanded,
    required this.rowBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
    required this.primary,
    required this.brightness,
    required this.periodDays,
    required this.fmtAmt,
    required this.onToggle,
    this.showUncategorizedNote = false,
  });

  @override
  Widget build(BuildContext context) {
    final catHistPeriod = cat.historicalAvgPerDay * periodDays;
    final catSaving = catHistPeriod - cat.suggestedBudget;
    final successColor = isDark ? ColorsUI.successDark : ColorsUI.successLight;
    final expenseColor = isDark ? ColorsUI.expenseDark : ColorsUI.expenseLight;
    final hasSubs = cat.subcategories.isNotEmpty;

    return Column(
      children: [
        InkWell(
          onTap: hasSubs ? onToggle : null,
          child: Container(
            color: rowBg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (hasSubs)
                  if (hasSubs)
                    ExcludeSemantics(
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        color: primary, size: 18,
                      ),
                    )
                  else
                    const SizedBox(width: 18),
                const SizedBox(width: 4),
                Expanded(
                  flex: 3,
                  child: Text(
                    cat.categoryName,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    fmtAmt(catHistPeriod),
                    textAlign: TextAlign.end,
                    style: TextStyle(color: expenseColor, fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    fmtAmt(cat.suggestedBudget),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: successColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    fmtAmt(catSaving),
                    textAlign: TextAlign.end,
                    style: TextStyle(color: successColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (isExpanded && hasSubs)
          ...cat.subcategories.map((sub) {
            final subHistPeriod = sub.historicalAvgPerDay * periodDays;
            final subSaving = subHistPeriod - sub.suggestedBudget;
            return Semantics(
              label: 'Υποκατηγορία ${sub.subcategoryName}',
              child: Container(
                color: primary.withValues(alpha: 0.04),
                padding: const EdgeInsets.only(
                    left: 40, right: 12, top: 8, bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: Icon(Icons.subdirectory_arrow_right_rounded,
                                size: 14, color: textSecondary),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(sub.subcategoryName,
                                style: TextStyle(
                                    color: textSecondary, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        fmtAmt(subHistPeriod),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            color: expenseColor.withValues(alpha: 0.8),
                            fontSize: 11),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        fmtAmt(sub.suggestedBudget),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            color: successColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 11),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        fmtAmt(subSaving),
                        textAlign: TextAlign.end,
                        style:
                        TextStyle(color: successColor, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

        // ✅ Σήμανση για κατηγορίες χωρίς αντιστοίχιση υποκατηγοριών
        if (showUncategorizedNote)
          Padding(
            padding: const EdgeInsets.only(left: 36, right: 12, bottom: 6),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.info_outline_rounded,
                      size: 13,
                      color: isDark ? ColorsUI.warningDark : ColorsUI.warningLight),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Τα έξοδα αυτής της κατηγορίας δεν έχουν υποκατηγορία — '
                        'δεν θα εμφανίζεται expandable στον προϋπολογισμό.',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? ColorsUI.warningDark : ColorsUI.warningLight,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Divider(
          height: 1,
          color: ColorsUI.getDivider(brightness),
        ),
      ],
    );
  }
}

// ── Total Row ─────────────────────────────────
class _TotalRow extends StatelessWidget {
  final double totalSuggested;
  final double totalHistAvg;
  final bool isDark;
  final Color primary;
  final Color textPrimary;
  final String Function(double) fmtAmt;

  const _TotalRow({
    required this.totalSuggested,
    required this.totalHistAvg,
    required this.isDark,
    required this.primary,
    required this.textPrimary,
    required this.fmtAmt,
  });

  @override
  Widget build(BuildContext context) {
    final totalSaving = totalHistAvg - totalSuggested;
    final successColor = isDark ? ColorsUI.successDark : ColorsUI.successLight;
    final expenseColor = isDark ? ColorsUI.expenseDark : ColorsUI.expenseLight;

    return Semantics(
      label:
      'Σύνολο: Μέσος Όρος ${fmtAmt(totalHistAvg)}, Ανώτατο Όριο ${fmtAmt(totalSuggested)}, Εξοικονόμηση ${fmtAmt(totalSaving)}',
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            border: Border.all(color: primary.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const SizedBox(width: 22),
              Expanded(
                flex: 3,
                child: Text('ΣΥΝΟΛΟ',
                    style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  fmtAmt(totalHistAvg),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color: expenseColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  fmtAmt(totalSuggested),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color: successColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  fmtAmt(totalSaving),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color: successColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}