// ============================================================
// FILE: transactions_provider.dart
// Path: lib/providers/transactions_provider.dart
// Ρόλος: Centralized transaction data management με REAL-TIME updates
// ✅ IMPROVED: Real-time Firestore listener για αυτόματη ενημέρωση
// ✅ FIX: Safe handling on logout / permission-denied (stop listeners, no spam)
// ✅ FIX: Guards for empty userId + disposed state (Windows-safe too)
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';

/// Transaction model για charts (lightweight)
class TransactionModel {
  final String id;
  final String userId;
  final String accountId;
  final String? categoryId;
  final String? subcategoryId;
  final String? transferGroupId;
  final double amount;
  final DateTime date;
  final String? notes;
  final List<String> tagIds; // ✅ ΝΕΟΝ: tag UUIDs

  TransactionModel({
    required this.id,
    required this.userId,
    required this.accountId,
    this.categoryId,
    this.subcategoryId,
    this.transferGroupId,
    required this.amount,
    required this.date,
    this.notes,
    this.tagIds = const [],
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return TransactionModel(
      id: doc.id,
      userId: data['user_id'] as String,
      accountId: data['account_id'] as String,
      categoryId: data['category_id'] as String?,
      subcategoryId: data['subcategory_id'] as String?,
      transferGroupId: data['transfer_group_id'] as String?,
      amount: (data['amount'] as num).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      notes: data['notes'] as String?,
      tagIds: List<String>.from(data['tags'] as List<dynamic>? ?? []),
    );
  }

  /// Check if this is a transfer
  bool get isTransfer => transferGroupId != null;

  /// Check if this is income (requires category lookup from provider)
  bool isIncome(String? categoryType) => !isTransfer && categoryType == 'income';

  /// Check if this is expense (requires category lookup from provider)
  bool isExpense(String? categoryType) => !isTransfer && categoryType == 'expense';
}

class TransactionsProvider extends ChangeNotifier {
  final String userId;

  TransactionsProvider({required this.userId});

  // ============================================================
  // STATE
  // ============================================================

  bool _disposed = false;

  /// Cache: period → transactions
  final Map<String, List<TransactionModel>> _periodCache = {};

  /// Currently loaded period
  String? _currentPeriod;

  /// Loading state per period
  final Map<String, bool> _loadingStates = {};

  /// Error state per period
  final Map<String, String?> _errorStates = {};

  // ✅ Real-time listeners per period
  final Map<String, StreamSubscription<QuerySnapshot>> _periodListeners = {};

  // ✅ Track period date ranges
  final Map<String, _PeriodRange> _periodRanges = {};

  // ============================================================
  // GETTERS
  // ============================================================

  /// Get transactions for a specific period
  List<TransactionModel> getTransactionsForPeriod(String period) {
    return _periodCache[period] ?? [];
  }

  /// Check if a period is currently loading
  bool isLoadingPeriod(String period) {
    return _loadingStates[period] ?? false;
  }

  /// Get error for a period
  String? getErrorForPeriod(String period) {
    return _errorStates[period];
  }

  /// Check if period is cached
  bool isPeriodCached(String period) {
    return _periodCache.containsKey(period);
  }

  /// Get current period
  String? get currentPeriod => _currentPeriod;

  /// Check if period has active listener
  bool hasActiveListener(String period) {
    return _periodListeners.containsKey(period);
  }

  // ============================================================
  // DATA LOADING WITH REAL-TIME LISTENER
  // ============================================================

  /// Load transactions for a period with real-time updates
  Future<void> loadPeriod(
      String period,
      DateTime startDate,
      DateTime endDate,
      ) async {
    final uid = userId.trim();

    DebugConfig.print(
      'TP ▶️ loadPeriod userId=$uid period=$period start=$startDate end=$endDate',
    );

    // ✅ Guard: αν λείπει uid (π.χ. μετά από logout), μην ξεκινάς listener
    if (uid.isEmpty) {
      _loadingStates[period] = false;
      _errorStates[period] = 'Missing userId for TransactionsProvider';
      _currentPeriod = period;
      DebugConfig.print('⚠️ TransactionsProvider: missing userId, listener not started');
      if (!_disposed) notifyListeners();
      return;
    }

    // ✅ Αν υπάρχει ήδη listener, έλεγξε αν άλλαξε το range
    final existingRange = _periodRanges[period];
    final hasListener = _periodListeners.containsKey(period);

    final rangeChanged =
        existingRange == null || existingRange.start != startDate || existingRange.end != endDate;

    if (hasListener && !rangeChanged) {
      DebugConfig.print('TP 🎧 already has listener for period=$period (same range)');

      // ✅ εδώ δεν άλλαξαν δεδομένα, άρα ΔΕΝ χρειάζεται notifyListeners().
      _currentPeriod = period;
      return;
    }

    // ✅ Αν άλλαξε range και υπάρχει listener, κάνε restart
    if (hasListener && rangeChanged) {
      DebugConfig.print('TP 🔁 range changed for period=$period → restarting listener');

      try {
        await _periodListeners[period]?.cancel();
      } catch (_) {}
      _periodListeners.remove(period);

      _periodCache.remove(period);
      _loadingStates.remove(period);
      _errorStates.remove(period);
    }

    // ✅ Store/update period range
    _periodRanges[period] = _PeriodRange(startDate, endDate);

    // Set loading state
    _loadingStates[period] = true;
    _errorStates[period] = null;
    _currentPeriod = period;
    if (!_disposed) notifyListeners();

    try {
      DebugConfig.print('📊 TransactionsProvider: Setting up listener for $period...');

      // ✅ Setup real-time listener
      final listener = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThan: Timestamp.fromDate(endDate.add(const Duration(days: 1))))
          .where('deleted', isEqualTo: false)
          .snapshots()
          .listen(
            (snapshot) => _onPeriodDataChanged(period, snapshot),
        onError: (error) => _onPeriodError(period, error),
      );

      _periodListeners[period] = listener;

      DebugConfig.print('✅ TransactionsProvider: Listener setup complete for $period');
    } catch (e) {
      DebugConfig.print('❌ TransactionsProvider: Error setting up listener for $period: $e');
      _errorStates[period] = e.toString();
      _loadingStates[period] = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ============================================================
  // REAL-TIME CALLBACKS
  // ============================================================

  /// Handle real-time data changes
  void _onPeriodDataChanged(String period, QuerySnapshot snapshot) {
    if (_disposed) return;

    try {
      DebugConfig.print('TP 🔔 snapshot received for period=$period docs=${snapshot.docs.length}');

      // ✅ NO future-filter here.
      final transactions = snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();

      DebugConfig.print('TP ✅ snapshot mapped count=${transactions.length}');

      // Sort by date descending
      transactions.sort((a, b) => b.date.compareTo(a.date));

      // Update cache
      _periodCache[period] = transactions;

      DebugConfig.print(
        '✅ TransactionsProvider: Updated ${transactions.length} transactions for $period',
      );

      _loadingStates[period] = false;
      _errorStates[period] = null;

      // ✅ Notify listeners so charts update
      notifyListeners();
    } catch (e) {
      DebugConfig.print('❌ Error processing snapshot for $period: $e');
      _onPeriodError(period, e);
    }
  }

  /// Handle listener errors
  void _onPeriodError(String period, Object error) {
    if (_disposed) return;

    final msg = error.toString();
    final isPermissionDenied =
        msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED');

    // ✅ Logout / no-permission scenario:
    // σταμάτα τον συγκεκριμένο listener για να μη “σφυροκοπάει” με errors
    if (isPermissionDenied) {
      DebugConfig.print(
        '⚠️ TransactionsProvider: permission-denied for period=$period -> stopping listener',
      );

      // stop listener
      try {
        _periodListeners[period]?.cancel();
      } catch (_) {}
      _periodListeners.remove(period);

      // clear cache + range for that period (ώστε σε νέο login να ξαναφορτώσει σωστά)
      _periodCache.remove(period);
      _periodRanges.remove(period);

      _loadingStates[period] = false;

      // προαιρετικά: μην “κοκκινίζεις” UI σε logout
      _errorStates[period] = null;

      notifyListeners();
      return;
    }

    DebugConfig.print('❌ TransactionsProvider: Listener error for $period: $error');
    _errorStates[period] = msg;
    _loadingStates[period] = false;
    notifyListeners();
  }

  // ============================================================
  // PUBLIC CONTROL
  // ============================================================

  /// Reload current period (cancel and restart listener)
  Future<void> reloadCurrentPeriod(DateTime startDate, DateTime endDate) async {
    if (_currentPeriod == null) return;

    try {
      await _periodListeners[_currentPeriod]?.cancel();
    } catch (_) {}
    _periodListeners.remove(_currentPeriod);

    _periodCache.remove(_currentPeriod);

    await loadPeriod(_currentPeriod!, startDate, endDate);
  }

  /// Stop listening to a period (cleanup)
  Future<void> stopListeningToPeriod(String period) async {
    try {
      await _periodListeners[period]?.cancel();
    } catch (_) {}
    _periodListeners.remove(period);
    _periodRanges.remove(period);
    DebugConfig.print('TP 🔇 stopped listener for period=$period');
  }

  // ============================================================
  // FILTERING HELPERS (for charts)
  // ============================================================

  /// Common filter helper to avoid duplicated filters in pages
  /// Notes:
  /// - provider returns the period cache (already sorted by date desc)
  /// - categories provider is NOT imported here, so we accept a callback to resolve category type.
  List<TransactionModel> getFilteredTransactionsForPeriod(
      String period, {
        bool includeTransfers = false,
        bool includeFuture = true,
        DateTime? nowOverride,
        DateTime? from,
        DateTime? to,
        Set<String>? accountIds,
        Set<String>? categoryIds,
        Set<String>? subcategoryIds,
        String? movementType, // 'income' | 'expense'
        String? Function(String categoryId)? categoryTypeOf,
      }) {
    final txs = getTransactionsForPeriod(period);
    final now = nowOverride ?? DateTime.now();

    return txs.where((t) {
      // transfers
      if (!includeTransfers && t.isTransfer) return false;

      // future
      if (!includeFuture && t.date.isAfter(now)) return false;

      // optional from/to (inclusive)
      if (from != null && t.date.isBefore(from)) return false;
      if (to != null && t.date.isAfter(to)) return false;

      // account filter
      if (accountIds != null && accountIds.isNotEmpty) {
        if (!accountIds.contains(t.accountId)) return false;
      }

      final catId = t.categoryId;

      // movement type filter (needs categoryTypeOf)
      if (movementType != null) {
        if (catId == null) return false;
        final ct = categoryTypeOf?.call(catId);
        if (ct == null) return false;
        if (ct != movementType) return false;
      }

      // selected categories
      if (categoryIds != null && categoryIds.isNotEmpty) {
        if (catId == null || !categoryIds.contains(catId)) return false;
      }

      // selected subcategories
      if (subcategoryIds != null && subcategoryIds.isNotEmpty) {
        final subId = t.subcategoryId;
        if (subId == null || !subcategoryIds.contains(subId)) return false;
      }

      return true;
    }).toList();
  }

  /// Get income transactions for period
  List<TransactionModel> getIncomeTransactions(
      String period,
      Map<String, String> categoryTypes, // categoryId → type
      ) {
    final transactions = getTransactionsForPeriod(period);
    return transactions.where((t) {
      if (t.isTransfer) return false;
      final categoryType = t.categoryId != null ? categoryTypes[t.categoryId] : null;
      return categoryType == 'income';
    }).toList();
  }

  /// Get expense transactions for period
  List<TransactionModel> getExpenseTransactions(
      String period,
      Map<String, String> categoryTypes, // categoryId → type
      ) {
    final transactions = getTransactionsForPeriod(period);
    return transactions.where((t) {
      if (t.isTransfer) return false;
      final categoryType = t.categoryId != null ? categoryTypes[t.categoryId] : null;
      return categoryType == 'expense';
    }).toList();
  }

  /// Get transfer transactions for period
  List<TransactionModel> getTransferTransactions(String period) {
    final transactions = getTransactionsForPeriod(period);
    return transactions.where((t) => t.isTransfer).toList();
  }

  /// Get transactions by category
  List<TransactionModel> getTransactionsByCategory(
      String period,
      String categoryId,
      ) {
    final transactions = getTransactionsForPeriod(period);
    return transactions.where((t) => t.categoryId == categoryId).toList();
  }

  /// Get transactions by subcategory
  List<TransactionModel> getTransactionsBySubcategory(
      String period,
      String categoryId,
      String subcategoryId,
      ) {
    final transactions = getTransactionsForPeriod(period);
    return transactions.where((t) => t.categoryId == categoryId && t.subcategoryId == subcategoryId)
        .toList();
  }

  /// Get transactions by account
  List<TransactionModel> getTransactionsByAccount(
      String period,
      String accountId,
      ) {
    final transactions = getTransactionsForPeriod(period);
    return transactions.where((t) => t.accountId == accountId).toList();
  }

  // ============================================================
  // AGGREGATION HELPERS (for charts)
  // ============================================================

  /// Calculate total income for period
  double getTotalIncome(
      String period,
      Map<String, String> categoryTypes,
      ) {
    final incomeTransactions = getIncomeTransactions(period, categoryTypes);
    final total = incomeTransactions.fold(0.0, (total, t) => total + t.amount);
    return CurrencyFormatter.round(total);
  }

  /// Calculate total expense for period
  double getTotalExpense(
      String period,
      Map<String, String> categoryTypes,
      ) {
    final expenseTransactions = getExpenseTransactions(period, categoryTypes);
    final total = expenseTransactions.fold(0.0, (total, t) => total + t.amount.abs());
    return CurrencyFormatter.round(total);
  }

  /// Group transactions by category with totals
  Map<String, double> groupByCategory(
      String period,
      String categoryType, // 'income' or 'expense'
      Map<String, String> categoryTypes,
      ) {
    final transactions = categoryType == 'income'
        ? getIncomeTransactions(period, categoryTypes)
        : getExpenseTransactions(period, categoryTypes);

    final Map<String, double> totals = {};

    for (final t in transactions) {
      if (t.categoryId == null) continue;
      totals[t.categoryId!] = CurrencyFormatter.round((totals[t.categoryId!] ?? 0.0) + t.amount.abs());
    }

    return totals;
  }

  /// Group transactions by subcategory with totals
  Map<String, double> groupBySubcategory(
      String period,
      String categoryId,
      ) {
    final transactions = getTransactionsByCategory(period, categoryId);

    final Map<String, double> totals = {};

    for (final t in transactions) {
      if (t.subcategoryId == null) continue;
      totals[t.subcategoryId!] = CurrencyFormatter.round((totals[t.subcategoryId!] ?? 0.0) + t.amount.abs());
    }

    return totals;
  }

  // ============================================================
  // CACHE MANAGEMENT
  // ============================================================

  /// Clear cache for a specific period (and stop listener)
  Future<void> clearPeriodCache(String period) async {
    await stopListeningToPeriod(period);
    _periodCache.remove(period);
    _loadingStates.remove(period);
    _errorStates.remove(period);
    if (!_disposed) notifyListeners();
  }

  /// Clear all cache (and stop all listeners)
  Future<void> clearAllCache() async {
    // Cancel all listeners
    for (final listener in _periodListeners.values) {
      try {
        await listener.cancel();
      } catch (_) {}
    }

    _periodListeners.clear();
    _periodRanges.clear();
    _periodCache.clear();
    _loadingStates.clear();
    _errorStates.clear();
    _currentPeriod = null;
    if (!_disposed) notifyListeners();
  }

  /// Get cache statistics (for debugging)
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_periods': _periodCache.keys.toList(),
      'active_listeners': _periodListeners.keys.toList(),
      'current_period': _currentPeriod,
      'total_transactions':
      _periodCache.values.fold<int>(0, (total, list) => total + list.length),
    };
  }

  @override
  void dispose() {
    _disposed = true;

    for (final listener in _periodListeners.values) {
      try {
        listener.cancel();
      } catch (_) {}
    }

    _periodListeners.clear();
    _periodRanges.clear();
    _periodCache.clear();
    _loadingStates.clear();
    _errorStates.clear();
    super.dispose();
  }
}

// ============================================================
// HELPER CLASSES
// ============================================================

class _PeriodRange {
  final DateTime start;
  final DateTime end;

  _PeriodRange(this.start, this.end);
}
