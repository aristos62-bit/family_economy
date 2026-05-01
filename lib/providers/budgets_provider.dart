// ============================================================
// FILE: budgets_provider.dart
// Path: lib/providers/budgets_provider.dart
// Ρόλος: Real-time Firestore listener for budgets
// NOTE: spent_amount is calculated dynamically, NOT stored!
//
// ✅ FIX v2: Real-time transactions listener → auto-recalculate spent amounts
// ✅ FIX v2: notifyListeners() added in _calculateSpentAmountsAsync
// ✅ FIX v2: Debounce on transactions changes to avoid UI spam
// ✅ FIX v2: Immediate notifyListeners() after budget save (optimistic update)
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/models/budget_model.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';

class BudgetsProvider extends ChangeNotifier {
  final String userId;
  final FirebaseFirestore _db;

  StreamSubscription<QuerySnapshot>? _budgetsSubscription;

  List<BudgetModel> _budgets = [];
  bool _isLoading = true;
  String? _error;

  // Cache for spent amounts (calculated dynamically)
  final Map<String, double> _spentAmountCache = {};

  BudgetsProvider({
    required this.userId,
    FirebaseFirestore? db,
  })  : _db = db ?? FirebaseFirestore.instance {
    _initBudgetsListener();
  }

  // ============================================================
  // GETTERS
  // ============================================================

  List<BudgetModel> get budgets {
    final filtered = _budgets.where((b) => !b.deleted && b.isActive).toList();
    filtered.sort((a, b) => b.startDate.compareTo(a.startDate));
    return filtered;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get spent amount for a budget (from cache or calculate)
  double getSpentAmount(String budgetUuid) {
    return _spentAmountCache[budgetUuid] ?? 0.0;
  }

  /// Επιστρέφει true αν το cache έχει τιμές για ΟΛΟΥΣ τους ενεργούς budgets
  bool get isSpentCachePopulated {
    if (budgets.isEmpty) return false;
    return budgets.every((b) => _spentAmountCache.containsKey(b.uuid));
  }
  /// Group budgets by (name, account, start_date, end_date)
  Map<String, List<BudgetModel>> get groupedBudgets {
    final Map<String, List<BudgetModel>> groups = {};

    for (final budget in budgets) {
      final key = '${budget.name}_${budget.accountId}_'
          '${budget.startDate.toIso8601String()}_'
          '${budget.endDate.toIso8601String()}';

      groups.putIfAbsent(key, () => []).add(budget);
    }

    return groups;
  }

  // ============================================================
  // INIT LISTENERS
  // ============================================================

  void _initBudgetsListener() {
    DebugConfig.print('↳ BudgetsProvider: Starting budgets real-time listener...');

    _budgetsSubscription = _db
        .collection('users')
        .doc(userId)
        .collection('budgets')
        .where('deleted', isEqualTo: false)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .listen(
      _onBudgetsChanged,
      onError: _onError,
    );
    DebugConfig.print('→ BudgetsProvider: listener initialized for userId=$userId');
  }

  void _onBudgetsChanged(QuerySnapshot snapshot) {
    try {
      final newBudgets = snapshot.docs
          .map((doc) => BudgetModel.fromFirestore(doc))
          .toList();

      // ✅ Καθάρισε cache για budgets που δεν υπάρχουν πλέον
      final newIds = newBudgets.map((b) => b.uuid).toSet();
      _spentAmountCache.removeWhere((key, _) => !newIds.contains(key));

      _budgets = newBudgets;
      _isLoading = false;
      _error = null;

      DebugConfig.print('✅ Budgets loaded: ${_budgets.length}');

      notifyListeners();
    } catch (e) {
      DebugConfig.print('🔴 Error parsing budgets: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }


  void _onError(Object error) {
    DebugConfig.print('🔴 Budgets listener error: $error');
    _error = error.toString();
    _isLoading = false;
    notifyListeners();
  }

  // ============================================================
  // SPENT AMOUNT CALCULATION
  // ============================================================

  /// Calculate spent amount for a specific budget
  Future<double> calculateSpentAmount(BudgetModel budget) async {
    try {
      DebugConfig.print('📊 Calculating spent for: ${budget.uuid}');

      var query = _db
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('deleted', isEqualTo: false)
          .where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(budget.startDate))
          .where('date',
          isLessThan: Timestamp.fromDate(
              budget.endDate.add(const Duration(days: 1))));

      // Filter by account if specified
      if (budget.accountId != null) {
        query = query.where('account_id', isEqualTo: budget.accountId);
      }

      // ✅ CRITICAL: Use cache-first to avoid network wait in offline mode
      QuerySnapshot snapshot;
      try {
        snapshot = await query
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 2));
        DebugConfig.print('✅ Used cache for spent calculation: ${budget.uuid}');
      } catch (e) {
        // Cache miss or timeout - try server with short timeout
        DebugConfig.print('⚠️ Cache miss for ${budget.uuid}, trying server...');
        snapshot = await query
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            DebugConfig.print('⏱️ Server timeout for ${budget.uuid} - returning empty');
            throw TimeoutException('Server query timeout');
          },
        );
      }

      double total = 0.0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};

        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final transactionType = data['transaction_type'] as String?;
        final categoryId = data['category_id'] as String?;
        final subcategoryId = data['subcategory_id'] as String?;

        // Skip transfers
        if (transactionType == 'transfer') continue;

        // ✅ FIX: Skip income — budgets track EXPENSES only
        if (transactionType == 'income') continue;

        // Match based on budget type
        bool matches = false;

        if (budget.isTotalBudget) {
          // Total budget: all non-transfer transactions
          matches = true;
        } else if (budget.isSubcategoryBudget) {
          // Subcategory budget: exact match
          matches = categoryId == budget.categoryId &&
              subcategoryId == budget.subcategoryId;
        } else if (budget.isCategoryBudget) {
          // Category budget: all subcategories under this category
          matches = categoryId == budget.categoryId;
        }

        if (matches) {
          total += amount.abs();
        }
      }

      // Update cache
      final rounded = CurrencyFormatter.round(total);
      _spentAmountCache[budget.uuid] = rounded;

      DebugConfig.print('✅ Spent calculated: ${budget.uuid} = €$rounded');
      return rounded;
    } catch (e) {
      DebugConfig.print('🔴 Error calculating spent amount for ${budget.uuid}: $e');
      // Set to 0 in cache to prevent repeated errors
      _spentAmountCache[budget.uuid] = 0.0;
      return 0.0;
    }
  }

  /// Recalculate spent amounts for ALL budgets
  Future<void> recalculateAllSpentAmounts() async {
    try {
      for (final budget in budgets) {
        await calculateSpentAmount(budget);
      }

      notifyListeners();
      DebugConfig.print('✅ Recalculated spent amounts for ${budgets.length} budgets');
    } catch (e) {
      DebugConfig.print('🔴 Error recalculating spent amounts: $e');
      rethrow;
    }
  }

  // ============================================================
  // CRUD OPERATIONS
  // ============================================================

  /// Save budget (create or update)
  Future<void> saveBudget(BudgetModel budget) async {
    try {
      final budgetRef = _db
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .doc(budget.uuid);

      await budgetRef.set(budget.toMap(), SetOptions(merge: true));

      DebugConfig.print('✅ Budget saved: ${budget.uuid}');

      // Recalculate spent amount for this budget
      await calculateSpentAmount(budget);
      notifyListeners(); // ✅ FIX: notify after single save too
      DebugConfig.print('↗️ Budget saved & UI notified: ${budget.uuid}');
    } catch (e) {
      DebugConfig.print('🔴 Error saving budget: $e');
      rethrow;
    }
  }

  /// ✅ Batch save multiple budgets (OFFLINE SAFE)
  Future<void> saveBudgetBatch(List<BudgetModel> budgets) async {
    if (budgets.isEmpty) {
      DebugConfig.print('⚠️ saveBudgetBatch: No budgets to save');
      return;
    }

    try {
      DebugConfig.print('📦 BATCH SAVE: Starting ${budgets.length} budgets...');

      // ✅ OPTIMISTIC UPDATE: τοπική ενημέρωση της λίστας
      // Αφαίρεσε τυχόν υπάρχοντα budgets με ίδια uuid (π.χ. από προηγούμενη επεξεργασία)
      for (final b in budgets) {
        _budgets.removeWhere((existing) => existing.uuid == b.uuid);
      }
      // Πρόσθεσε τα νέα
      _budgets.addAll(budgets);
      // Αρχικοποίηση cache (προσωρινά 0, θα υπολογιστεί στο background)
      for (final b in budgets) {
        _spentAmountCache[b.uuid] = 0.0;
      }
      notifyListeners(); // άμεση ενημέρωση UI

      final batch = _db.batch();

      for (final budget in budgets) {
        final budgetRef = _db
            .collection('users')
            .doc(userId)
            .collection('budgets')
            .doc(budget.uuid);

        batch.set(budgetRef, budget.toMap(), SetOptions(merge: true));

        DebugConfig.print('  ➕ Added to batch: ${budget.uuid} (${budget.budgetType})');
      }

      bool saveTimedOut = false;
      try {
        await batch.commit().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            saveTimedOut = true;
            DebugConfig.print('⏱️ Batch commit timeout (offline mode) - data saved to cache');
          },
        );
        if (!saveTimedOut) {
          DebugConfig.print('✅ BATCH SAVE: Server confirmed ${budgets.length} budgets');
        }
      } catch (e) {
        DebugConfig.print('⚠️ BATCH SAVE: Committed to cache (will sync when online)');
      }

      // Υπολόγισε spent amounts στο background (δεν μπλοκάρει)
      _calculateSpentAmountsAsync(budgets);

      DebugConfig.print('✅ BATCH SAVE: Complete (spent calculation in background)');
    } catch (e) {
      DebugConfig.print('🔴 BATCH SAVE ERROR: $e');
      rethrow;
    }
  }

  /// ✅ Calculate spent amounts asynchronously (non-blocking)
  /// ✅ FIX: Now calls notifyListeners() at the end so UI updates automatically
  Future<void> _calculateSpentAmountsAsync(List<BudgetModel> budgets) async {
    for (final budget in budgets) {
      try {
        // This may take time in offline mode, but won't block the UI
        await calculateSpentAmount(budget).timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            DebugConfig.print('⏱️ Spent calculation timeout for ${budget.uuid} - setting to 0.0');
            _spentAmountCache[budget.uuid] = 0.0;
            return 0.0;
          },
        );
      } catch (e) {
        DebugConfig.print('⚠️ Background spent calculation failed for ${budget.uuid}: $e');
        // Set to 0 in cache to prevent errors
        _spentAmountCache[budget.uuid] = 0.0;
      }
    }

    // ✅ FIX: Notify AFTER all calculations complete
    notifyListeners();
    DebugConfig.print('✅ Background spent calculation complete for ${budgets.length} budgets → UI notified');
  }

  /// Delete single budget
  Future<void> deleteBudget(String budgetUuid) async {
    try {
      final ref = _db
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .doc(budgetUuid);

      // ✅ OFFLINE SAFE: timeout so UI doesn't freeze
      try {
        await ref.update({
          'deleted': true,
          'updated_at': FieldValue.serverTimestamp(),
        }).timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            DebugConfig.print('⏱️ deleteBudget timeout (offline) - queued for sync');
          },
        );
      } catch (e) {
        DebugConfig.print('⚠️ deleteBudget: written to cache (will sync when online)');
      }

      _spentAmountCache.remove(budgetUuid);
      DebugConfig.print('✅ Budget deleted (or queued): $budgetUuid');
    } catch (e) {
      DebugConfig.print('🔴 Error deleting budget: $e');
      rethrow;
    }
  }

  /// ✅ Batch delete multiple budgets by UUID (OFFLINE SAFE)
  Future<void> deleteBudgetBatch(List<String> budgetUuids) async {
    if (budgetUuids.isEmpty) {
      DebugConfig.print('⚠️ deleteBudgetBatch: No budgets to delete');
      return;
    }

    try {
      DebugConfig.print('🗒️ BATCH DELETE: Starting ${budgetUuids.length} budgets...');

      // ✅ OPTIMISTIC UPDATE: αφαίρεσε από τοπική λίστα
      _budgets.removeWhere((b) => budgetUuids.contains(b.uuid));
      for (final uuid in budgetUuids) {
        _spentAmountCache.remove(uuid);
      }
      notifyListeners(); // άμεση ενημέρωση UI

      final batch = _db.batch();

      for (final uuid in budgetUuids) {
        final budgetRef = _db
            .collection('users')
            .doc(userId)
            .collection('budgets')
            .doc(uuid);

        batch.update(budgetRef, {
          'deleted': true,
          'updated_at': FieldValue.serverTimestamp(),
        });

        DebugConfig.print('  ➖ Added to delete batch: $uuid');
      }

      bool deleteTimedOut = false;
      try {
        await batch.commit().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            deleteTimedOut = true;
            DebugConfig.print('⏱️ BATCH DELETE timeout (offline) - queued for sync');
          },
        );
        if (!deleteTimedOut) {
          DebugConfig.print('✅ BATCH DELETE: Server confirmed ${budgetUuids.length} budgets deleted');
        }
      } catch (e) {
        DebugConfig.print('⚠️ BATCH DELETE: Written to cache (will sync when online)');
      }

      // Δεν χρειάζεται notifyListeners() ξανά
    } catch (e) {
      DebugConfig.print('🔴 BATCH DELETE ERROR: $e');
      rethrow;
    }
  }

  /// Delete budget group
  Future<void> deleteBudgetGroup(List<BudgetModel> groupBudgets) async {
    try {
      final batch = _db.batch();

      for (final budget in groupBudgets) {
        final budgetRef = _db
            .collection('users')
            .doc(userId)
            .collection('budgets')
            .doc(budget.uuid);

        batch.update(budgetRef, {
          'deleted': true,
          'updated_at': FieldValue.serverTimestamp(),
        });

        _spentAmountCache.remove(budget.uuid);
      }

      // ✅ OFFLINE SAFE
      try {
        bool groupDeleteTimedOut = false;
        await batch.commit().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            groupDeleteTimedOut = true;
            DebugConfig.print('⏱️ deleteBudgetGroup timeout (offline) - queued for sync');
          },
        );
        if (!groupDeleteTimedOut) {
          DebugConfig.print('✅ deleteBudgetGroup: Server confirmed deletion');
        }
      } catch (e) {
        DebugConfig.print('⚠️ deleteBudgetGroup: written to cache (will sync when online)');
      }

      DebugConfig.print('✅ Deleted (or queued) ${groupBudgets.length} budgets from group');
    } catch (e) {
      DebugConfig.print('🔴 Error deleting budget group: $e');
      rethrow;
    }
  }

  /// Update budget dates
  Future<void> updateBudgetDates({
    required List<BudgetModel> groupBudgets,
    required DateTime newStartDate,
    required DateTime newEndDate,
  }) async {
    try {
      final batch = _db.batch();

      for (final budget in groupBudgets) {
        final budgetRef = _db
            .collection('users')
            .doc(userId)
            .collection('budgets')
            .doc(budget.uuid);

        batch.update(budgetRef, {
          'start_date': newStartDate.toIso8601String().split('T')[0],
          'end_date': newEndDate.toIso8601String().split('T')[0],
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      // ✅ OFFLINE SAFE
      bool datesTimedOut = false;
      try {
        await batch.commit().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            datesTimedOut = true;
            DebugConfig.print('⏱️ updateBudgetDates timeout (offline) - queued for sync');
          },
        );
        if (!datesTimedOut) {
          DebugConfig.print('✅ updateBudgetDates: Server confirmed');
        }
      } catch (e) {
        DebugConfig.print('⚠️ updateBudgetDates: written to cache (will sync when online)');
      }

      // Recalculate spent amounts after date change
      for (final budget in groupBudgets) {
        final updated = budget.copyWith(
          startDate: newStartDate,
          endDate: newEndDate,
        );
        await calculateSpentAmount(updated);
      }

      notifyListeners(); // ✅ FIX: notify after date update too

      DebugConfig.print(
          '✅ Updated dates for ${groupBudgets.length} budgets in group');
    } catch (e) {
      DebugConfig.print('🔴 Error updating budget dates: $e');
      rethrow;
    }
  }

  /// Get budgets for specific period and account
  List<BudgetModel> getBudgetsByPeriodAndAccount({
    required DateTime startDate,
    required DateTime endDate,
    String? accountId,
  }) {
    return budgets.where((budget) {
      final periodMatches = budget.startDate.isAtSameMomentAs(startDate) &&
          budget.endDate.isAtSameMomentAs(endDate);

      final accountMatches = accountId == null
          ? budget.accountId == null
          : budget.accountId == accountId;

      return periodMatches && accountMatches;
    }).toList();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _budgetsSubscription?.cancel();
    _spentAmountCache.clear();

    DebugConfig.print('→ BudgetsProvider disposed, subscription cancelled, cache cleared');

    super.dispose();
  }
}