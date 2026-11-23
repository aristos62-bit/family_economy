// ============================================================
// FILE: accounts_provider.dart
// Path: lib/providers/accounts_provider.dart
// Ρόλος: Real-time Firestore listener για λογαριασμούς
// ✅ FIX: Safe handling on logout / permission-denied (stop listener, no spam)
// ✅ FIX: Guards for empty userId + disposed state (Windows-safe too)
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_economy/core/utils/account_balance.dart';
import 'package:family_economy/core/utils/debug_config.dart';

class AccountModel {
  final String uuid;
  final String userId;
  final String name;
  final double initialBalance;
  final double currentBalance;
  final String currency;
  final String accountType;
  final int? iconIndex;
  final String? color;
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  /// E26: πότε αρχειοθετήθηκε (null = ποτέ). Διακριτικό από τους legacy
  /// `is_active=false` που δεν πρέπει να μετράνε στο σύνολο.
  final DateTime? archivedAt;

  AccountModel({
    required this.uuid,
    required this.userId,
    required this.name,
    required this.initialBalance,
    required this.currentBalance,
    required this.currency,
    required this.accountType,
    this.iconIndex,
    this.color,
    required this.isActive,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    this.archivedAt,
  });

  /// Μετράει στο συνολικό υπόλοιπο: ενεργός **ή** αρχειοθετημένος.
  bool get countsInTotal => isActive || archivedAt != null;

  bool get isArchived => archivedAt != null;

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  factory AccountModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AccountModel(
      uuid: doc.id,
      userId: data['user_id'] as String,
      name: data['name'] as String,
      initialBalance: (data['initial_balance'] as num).toDouble(),
      currentBalance: (data['current_balance'] as num).toDouble(),
      currency: data['currency'] as String? ?? 'EUR',
      accountType: data['account_type'] as String? ?? 'cash',
      iconIndex: data['icon_index'] as int?,
      color: data['color'] as String?,
      isActive: data['is_active'] as bool? ?? true,
      displayOrder: data['display_order'] as int? ?? 0,
      createdAt: _parseTimestamp(data['created_at']),
      updatedAt: _parseTimestamp(data['updated_at']),
      deleted: data['deleted'] as bool? ?? false,
      archivedAt: (data['archived_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'initial_balance': initialBalance,
      'current_balance': currentBalance,
      'currency': currency,
      'account_type': accountType,
      'icon_index': iconIndex,
      'color': color,
      'is_active': isActive,
      'display_order': displayOrder,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'deleted': deleted,
      'archived_at':
          archivedAt == null ? null : Timestamp.fromDate(archivedAt!),
    };
  }
}

class AccountsProvider extends ChangeNotifier {
  final String userId;
  StreamSubscription<QuerySnapshot>? _subscription;

  List<AccountModel> _accounts = [];
  List<AccountModel> _visibleAccounts = [];

  /// E27: UUIDs που ο χρήστης εξαίρεσε από το σύνολο/γράφημα
  /// (τοπική προτίμηση `excluded_accounts_{uid}`).
  Set<String> _excludedAccountUuids = <String>{};

  bool _isLoading = true;
  String? _error;

  bool _disposed = false;

  AccountsProvider({required this.userId}) {
    _initListener();
    unawaited(_loadExcludedAccounts());
  }

  // Getters
  List<AccountModel> get accounts => _visibleAccounts;

  /// Όλοι οι μη διαγραμμένοι: ενεργοί + αρχειοθετημένοι + legacy ανενεργοί.
  /// Χρησιμοποιείται για σύνολα και για εμφάνιση ονομάτων (E12/E26).
  List<AccountModel> get allAccounts => _accounts;

  /// Μόνο οι αρχειοθετημένοι (E26), νεότεροι πρώτα.
  List<AccountModel> get archivedAccounts {
    final list = _accounts
        .where((a) => !a.deleted && a.archivedAt != null)
        .toList()
      ..sort((a, b) => b.archivedAt!.compareTo(a.archivedAt!));
    return list;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasAccounts => _visibleAccounts.isNotEmpty;

  // ============================================================
  // E27 — ΕΞΑΙΡΕΣΕΙΣ ΑΠΟ ΤΟ ΣΥΝΟΛΟ (τοπική προτίμηση)
  // ============================================================

  /// Λογαριασμοί που δεν μετράνε στο σύνολο/γράφημα.
  /// Επιστρέφεται αντίγραφο ώστε να μην αλλοιώνεται η εσωτερική κατάσταση.
  Set<String> get excludedAccountUuids =>
      Set<String>.unmodifiable(_excludedAccountUuids);

  bool isExcludedFromTotal(String uuid) =>
      _excludedAccountUuids.contains(uuid);

  /// Ορίζει αν ο λογαριασμός μετράει στο σύνολο (idempotent).
  /// Ποτέ δεν πετάει: αν αποτύχει η αποθήκευση, η in-memory κατάσταση μένει.
  Future<void> setExcludedFromTotal(
    String uuid, {
    required bool excluded,
  }) async {
    if (userId.trim().isEmpty) return;

    final changed = excluded
        ? _excludedAccountUuids.add(uuid)
        : _excludedAccountUuids.remove(uuid);
    if (!changed) return;

    if (!_disposed) notifyListeners();
    await _persistExcludedAccounts();
  }

  Future<void> _loadExcludedAccounts() async {
    final uid = userId.trim();
    if (uid.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved =
          prefs.getStringList('excluded_accounts_$uid') ?? const <String>[];
      if (_disposed) return;

      final loaded = saved.toSet();
      if (setEquals(loaded, _excludedAccountUuids)) return;

      _excludedAccountUuids = loaded;
      notifyListeners();
      DebugConfig.print(
        '✅ Excluded accounts loaded: ${_excludedAccountUuids.length}',
      );
    } catch (e) {
      DebugConfig.print('🔴 Error loading excluded accounts: $e');
    }
  }

  Future<void> _persistExcludedAccounts() async {
    final uid = userId.trim();
    if (uid.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = _excludedAccountUuids.toList()..sort();
      await prefs.setStringList('excluded_accounts_$uid', sorted);
    } catch (e) {
      DebugConfig.print('🔴 Error saving excluded accounts: $e');
    }
  }

  // ============================================================
  // INIT
  // ============================================================

  void _initListener() {
    final uid = userId.trim();

    DebugConfig.print('→ AccountsProvider: Ξεκινάω real-time listener για accounts...');

    // ✅ Guard: αν για κάποιο λόγο φτιαχτεί provider χωρίς uid, μην ξεκινήσεις listeners
    if (uid.isEmpty) {
      _isLoading = false;
      _error = 'Missing userId for AccountsProvider';
      DebugConfig.print('⚠️ AccountsProvider: missing userId, listener not started');
      if (!_disposed) notifyListeners();
      return;
    }

    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .where('deleted', isEqualTo: false)
        .snapshots()
        .listen(
      _onAccountsChanged,
      onError: _onError,
    );
    DebugConfig.print('→ AccountsProvider: listener (FILTERED: deleted=false) initialized for userId=$uid');
  }

  // ============================================================
  // LISTENERS
  // ============================================================

  void _onAccountsChanged(QuerySnapshot snapshot) {
    if (_disposed) return;

    try {
      _accounts = snapshot.docs.map((doc) => AccountModel.fromFirestore(doc)).toList();

      // ✅ Υπολόγισε μία φορά τη "ορατή" λίστα (filtered + sorted)
      _visibleAccounts = _accounts.where((a) => !a.deleted && a.isActive).toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      _isLoading = false;
      _error = null;
      notifyListeners();

      DebugConfig.print(
        '✅ Accounts loaded: ${_accounts.length} (visible: ${_visibleAccounts.length})',
      );
    } catch (e) {
      DebugConfig.print('🔴 Error parsing accounts: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onError(Object error) {
    if (_disposed) return;

    final msg = error.toString();
    final isPermissionDenied =
        msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED');

    // ✅ Logout / no-permission scenario:
    // σταμάτα τον listener για να μη “σφυροκοπάει” με errors
    if (isPermissionDenied) {
      DebugConfig.print('⚠️ AccountsProvider: permission-denied -> stopping listener');

      try {
        _subscription?.cancel();
      } catch (_) {}
      _subscription = null;

      // clear state (ώστε σε νέο login να ξαναφορτώσει σωστά)
      _accounts = [];
      _visibleAccounts = [];
      _isLoading = false;

      // προαιρετικά: μην “κοκκινίζεις” UI σε logout
      _error = null;

      notifyListeners();
      return;
    }

    DebugConfig.print('🔴 Accounts listener error: $error');
    _error = msg;
    _isLoading = false;
    notifyListeners();
  }

  // ============================================================
  // LOOKUPS
  // ============================================================

  /// Ψάχνει σε **όλους** τους μη διαγραμμένους (και αρχειοθετημένους) ώστε
  /// παλιές κινήσεις/budgets να δείχνουν σωστό όνομα (E12/E16).
  AccountModel? getAccountByUuid(String uuid) {
    try {
      return _accounts.firstWhere((a) => a.uuid == uuid);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // FIRESTORE UPDATE
  // ============================================================

  /// Update account balance (after transaction)
  Future<void> updateAccountBalance(String uuid, double newBalance) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .doc(uuid)
          .update({
        'current_balance': newBalance,
        'updated_at': FieldValue.serverTimestamp(),
      });

      DebugConfig.print('✅ Account balance updated: $uuid -> $newBalance');
    } catch (e) {
      DebugConfig.print('🔴 Error updating account balance: $e');
      rethrow;
    }
  }

  // ============================================================
  // E20 — ΕΠΑΝΥΠΟΛΟΓΙΣΜΟΣ ΥΠΟΛΟΙΠΟΥ
  // ============================================================

  /// Επαναϋπολογίζει το υπόλοιπο από το αρχικό ποσό + τις κινήσεις που
  /// έχουν **ήδη εφαρμοστεί** (κανόνας: `AccountBalanceRules`).
  ///
  /// I/O: 1 ανάγνωση λογαριασμού + 1 query κινήσεων (φίλτρο μόνο
  /// `account_id` — `deleted`/`is_scheduled` ελέγχονται σε Dart, E6)
  /// + 1 εγγραφή **τελευταία** μέσω [updateAccountBalance].
  Future<AccountBalanceRecalcOutcome> recalculateAccountBalance(
    String accountUuid,
  ) async {
    final uid = userId.trim();
    if (uid.isEmpty) {
      return const AccountBalanceRecalcOutcome(
        failure: AccountBalanceRecalcFailure.missingUser,
      );
    }

    try {
      final accountRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .doc(accountUuid);

      final accountDoc = await accountRef.get();

      // Ανάγνωση με ανοχή: το AccountModel απαιτεί τα πεδία (`as num`).
      final accountData = accountDoc.data();
      if (!accountDoc.exists ||
          accountData == null ||
          accountData['deleted'] == true) {
        return const AccountBalanceRecalcOutcome(
          failure: AccountBalanceRecalcFailure.accountMissing,
        );
      }

      final initialBalance =
          (accountData['initial_balance'] as num?)?.toDouble() ?? 0.0;
      final beforeBalance =
          (accountData['current_balance'] as num?)?.toDouble() ?? 0.0;

      final txSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where('account_id', isEqualTo: accountUuid)
          .get();

      final result = AccountBalanceRules.compute(
        initialBalance: initialBalance,
        transactions: txSnapshot.docs.map((doc) => doc.data()),
      );

      final changed = AccountBalanceRules.centsOf(beforeBalance) !=
          AccountBalanceRules.centsOf(result.newBalance);

      if (changed) {
        await updateAccountBalance(accountUuid, result.newBalance);
      }

      DebugConfig.print(
        '♻️ Recalc $accountUuid: counted=${result.countedCount}, '
        'pendingExcluded=${result.pendingExcludedCount}, '
        'deletedSkipped=${result.deletedSkippedCount}, '
        'before=$beforeBalance, after=${result.newBalance}, '
        'changed=$changed',
      );

      return AccountBalanceRecalcOutcome(
        failure: AccountBalanceRecalcFailure.none,
        beforeBalance: beforeBalance,
        afterBalance: result.newBalance,
        countedCount: result.countedCount,
        pendingExcludedCount: result.pendingExcludedCount,
        pendingExcludedAmount: result.pendingExcludedAmount,
        changed: changed,
      );
    } catch (e) {
      DebugConfig.print('🔴 Recalc failed for $accountUuid: $e');
      return const AccountBalanceRecalcOutcome(
        failure: AccountBalanceRecalcFailure.failed,
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _disposed = true;
    try {
      _subscription?.cancel();
    } catch (_) {}
    _subscription = null;

    DebugConfig.print('→ AccountsProvider disposed, subscription cancelled');

    super.dispose();
  }
}
