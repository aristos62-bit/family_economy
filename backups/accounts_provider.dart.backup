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
  });

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
    };
  }
}

class AccountsProvider extends ChangeNotifier {
  final String userId;
  StreamSubscription<QuerySnapshot>? _subscription;

  List<AccountModel> _accounts = [];
  List<AccountModel> _visibleAccounts = [];
  bool _isLoading = true;
  String? _error;

  bool _disposed = false;

  AccountsProvider({required this.userId}) {
    _initListener();
  }

  // Getters
  List<AccountModel> get accounts => _visibleAccounts;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasAccounts => _visibleAccounts.isNotEmpty;

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
        .snapshots()
        .listen(
      _onAccountsChanged,
      onError: _onError,
    );
    DebugConfig.print('→ AccountsProvider: listener initialized for userId=$uid');
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

  AccountModel? getAccountByUuid(String uuid) {
    try {
      return accounts.firstWhere((a) => a.uuid == uuid);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // OFFLINE-FIRST LOCAL UPDATE
  // ============================================================

  /// ✅ Optimistic local balance update (works offline too)
  void applyLocalBalanceDelta({
    required String accountUuid,
    required double delta,
  }) {
    if (_disposed) return;

    final index = _accounts.indexWhere((a) => a.uuid == accountUuid);
    if (index == -1) return;

    final old = _accounts[index];

    _accounts[index] = AccountModel(
      uuid: old.uuid,
      userId: old.userId,
      name: old.name,
      initialBalance: old.initialBalance,
      currentBalance: old.currentBalance + delta,
      currency: old.currency,
      accountType: old.accountType,
      iconIndex: old.iconIndex,
      color: old.color,
      isActive: old.isActive,
      displayOrder: old.displayOrder,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(), // local timestamp
      deleted: old.deleted,
    );

    // ✅ Keep visible list in sync
    _visibleAccounts = _accounts.where((a) => !a.deleted && a.isActive).toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    DebugConfig.print('↗️ Local balance delta applied: $delta to account $accountUuid. New balance=${_accounts[index].currentBalance}');

    notifyListeners();
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
