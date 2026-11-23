// ============================================================
// FILE: account_restore_service.dart
// Path: lib/core/services/account_restore_service.dart
// Ρόλος: I/O για την επαναφορά διαγραμμένου λογαριασμού (E19/E14/E29/E30/E31).
// - 4 αναγνώσεις (server) → πλάνο (account_restore_policy.dart)
// - Chunks ≤499 με deltas **ανά chunk** → ενεργοποίηση **τελευταία**
// - «Χωρίς υπόλοιπο»: κρύβει ό,τι είναι ορατό, καθαρίζει markers, μηδενίζει
// Καμία εξάρτηση από providers/UI.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:family_economy/core/utils/account_delete_guard.dart';
import 'package:family_economy/core/utils/account_restore_policy.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/core/utils/debug_config.dart';

/// Ορατό/ανεκτικό στιγμιότυπο διαγραμμένου λογαριασμού (E31: χωρίς strict casts).
class DeletedAccountInfo {
  const DeletedAccountInfo({
    required this.uuid,
    required this.name,
    required this.currency,
    required this.initialBalance,
    required this.currentBalance,
    required this.archivedAt,
  });

  final String uuid;
  final String name;
  final String currency;
  final double initialBalance;
  final double currentBalance;
  final DateTime? archivedAt;
}

enum AccountRestoreFailure {
  /// Επιτυχία.
  none,

  /// Ο λογαριασμός δεν υπάρχει πλέον.
  missing,

  /// Ο λογαριασμός είναι ήδη ενεργός (π.χ. άλλη συσκευή).
  alreadyActive,

  /// Τα δεδομένα άλλαξαν ανάμεσα σε προεπισκόπηση και εκτέλεση.
  changed,

  /// Σφάλμα ανάγνωσης.
  readFailed,

  /// Σφάλμα εγγραφής (ο λογαριασμός παραμένει διαγραμμένος).
  writeFailed,
}

class AccountRestorePreview {
  const AccountRestorePreview({
    required this.failure,
    this.plan,
    this.account,
  });

  final AccountRestoreFailure failure;
  final AccountRestorePlan? plan;
  final DeletedAccountInfo? account;

  bool get isSuccess =>
      failure == AccountRestoreFailure.none && plan != null;
}

class AccountRestoreResult {
  const AccountRestoreResult({
    required this.failure,
    this.plan,
    this.accountName = '',
    this.currency = CurrencyFormatter.defaultCurrency,
    this.hiddenNow = 0,
    this.markersCleared = 0,
    this.wiped = false,
  });

  final AccountRestoreFailure failure;
  final AccountRestorePlan? plan;
  final String accountName;
  final String currency;
  final int hiddenNow;
  final int markersCleared;
  final bool wiped;

  bool get isSuccess => failure == AccountRestoreFailure.none;

  String message() {
    switch (failure) {
      case AccountRestoreFailure.missing:
        return 'Ο λογαριασμός δεν υπάρχει πλέον.';
      case AccountRestoreFailure.alreadyActive:
        return 'Ο λογαριασμός είναι ήδη ενεργός.';
      case AccountRestoreFailure.changed:
        return 'Τα δεδομένα άλλαξαν όσο ήταν ανοιχτός ο διάλογος. '
            'Δεν άλλαξε τίποτα — δοκιμάστε ξανά.';
      case AccountRestoreFailure.readFailed:
        return 'Σφάλμα ανάγνωσης. Δεν άλλαξε τίποτα.';
      case AccountRestoreFailure.writeFailed:
        return 'Η επαναφορά δεν ολοκληρώθηκε. Ο λογαριασμός παραμένει '
            'διαγραμμένος — δοκιμάστε ξανά.';
      case AccountRestoreFailure.none:
        break;
    }

    if (wiped) {
      final who = accountName.trim().isEmpty
          ? 'Ο λογαριασμός'
          : 'Ο λογαριασμός «${accountName.trim()}»';
      final buffer = StringBuffer(
        '$who επανήλθε με μηδέν υπόλοιπο. Το ιστορικό παραμένει κρυφό.',
      );
      if (hiddenNow > 0) {
        buffer.write(
          ' ${hiddenNow == 1 ? '1 κίνηση κρύφτηκε' : '$hiddenNow κινήσεις κρύφτηκαν'} ξανά.',
        );
      }
      return buffer.toString();
    }

    return plan?.successMessage() ?? 'Η επαναφορά ολοκληρώθηκε.';
  }
}

class AccountRestoreService {
  AccountRestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const GetOptions _server = GetOptions(source: Source.server);
  static const int _maxWrites = AccountDeleteGuard.maxWritesPerBatch;

  DocumentReference<Map<String, dynamic>> _accountRef(
    String userId,
    String accountUuid,
  ) => _db
      .collection('users')
      .doc(userId)
      .collection('accounts')
      .doc(accountUuid);

  CollectionReference<Map<String, dynamic>> _txCol(String userId) => _db
      .collection('users')
      .doc(userId)
      .collection('transactions');

  CollectionReference<Map<String, dynamic>> _accountsCol(String userId) =>
      _db.collection('users').doc(userId).collection('accounts');

  // ============================================================
  // ΠΡΟΕΠΙΣΚΟΠΗΣΗ
  // ============================================================

  Future<AccountRestorePreview> preview({
    required String userId,
    required String accountUuid,
  }) async {
    try {
      final accountSnap =
          await _accountRef(userId, accountUuid).get(_server);
      if (!accountSnap.exists) {
        return const AccountRestorePreview(
          failure: AccountRestoreFailure.missing,
        );
      }

      final data = accountSnap.data() ?? <String, dynamic>{};
      if (data['deleted'] != true) {
        return AccountRestorePreview(
          failure: AccountRestoreFailure.alreadyActive,
          account: _infoOf(accountUuid, data),
        );
      }

      final plan = await _buildPlan(
        userId: userId,
        accountUuid: accountUuid,
        accountData: data,
      );

      return AccountRestorePreview(
        failure: AccountRestoreFailure.none,
        plan: plan,
        account: _infoOf(accountUuid, data),
      );
    } catch (error) {
      DebugConfig.print('❌ Account restore preview error: $error');
      return const AccountRestorePreview(
        failure: AccountRestoreFailure.readFailed,
      );
    }
  }

  Future<AccountRestorePlan> _buildPlan({
    required String userId,
    required String accountUuid,
    required Map<String, dynamic> accountData,
  }) async {
    final ownSnap = await _txCol(userId)
        .where('account_id', isEqualTo: accountUuid)
        .get(_server);
    final markedSnap = await _txCol(userId)
        .where('annulled_by_account_deleted', isEqualTo: accountUuid)
        .get(_server);
    final accountsSnap = await _accountsCol(userId).get(_server);

    final accountsById = <String, Map<String, dynamic>>{
      for (final doc in accountsSnap.docs) doc.id: doc.data(),
    };

    return AccountRestorePolicy.build(
      accountUuid: accountUuid,
      accountData: accountData,
      ownTransactions: _mapsOf(ownSnap),
      markedLegs: _mapsOf(markedSnap),
      existingAccountIds: accountsById.keys.toSet()..add(accountUuid),
      accountsById: accountsById,
    );
  }

  // ============================================================
  // ΕΠΑΝΑΦΟΡΑ ΜΕ ΙΣΤΟΡΙΚΟ
  // ============================================================

  Future<AccountRestoreResult> restoreWithHistory({
    required String userId,
    required AccountRestorePlan plan,
  }) async {
    try {
      final accountSnap =
          await _accountRef(userId, plan.accountUuid).get(_server);
      if (!accountSnap.exists) {
        return const AccountRestoreResult(
          failure: AccountRestoreFailure.missing,
        );
      }

      final data = accountSnap.data() ?? <String, dynamic>{};
      if (data['deleted'] != true) {
        return AccountRestoreResult(
          failure: AccountRestoreFailure.alreadyActive,
          accountName: plan.accountName,
          currency: plan.currency,
        );
      }

      final fresh = await _buildPlan(
        userId: userId,
        accountUuid: plan.accountUuid,
        accountData: data,
      );

      // Ποτέ σιωπηλά «παλιό» υπόλοιπο: αν άλλαξαν τα δεδομένα, ματαίωση.
      if (fresh.fingerprint != plan.fingerprint) {
        DebugConfig.print(
          '⚠️ Restore plan changed: ${plan.fingerprint} → ${fresh.fingerprint}',
        );
        return AccountRestoreResult(
          failure: AccountRestoreFailure.changed,
          plan: plan,
          accountName: plan.accountName,
          currency: plan.currency,
        );
      }

      final txCol = _txCol(userId);
      final accountsCol = _accountsCol(userId);

      for (final chunk in fresh.chunks) {
        final batch = _db.batch();

        for (final unit in chunk.units) {
          for (final legId in unit.legUuids) {
            batch.update(txCol.doc(legId), <String, dynamic>{
              'deleted': false,
              'annulled_by_account_deleted': FieldValue.delete(),
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }

        chunk.deltasByAccount.forEach((accountId, delta) {
          if (accountId == fresh.accountUuid) return;
          batch.update(accountsCol.doc(accountId), <String, dynamic>{
            'current_balance': FieldValue.increment(delta),
            'updated_at': FieldValue.serverTimestamp(),
          });
        });

        await batch.commit();
      }

      // Commit point:ενεργοποίηση + καθαρισμός archived_at + απόλυτο υπόλοιπο.
      await accountsCol.doc(fresh.accountUuid).update(<String, dynamic>{
        'deleted': false,
        'is_active': true,
        'archived_at': FieldValue.delete(),
        'current_balance': fresh.targetBalance,
        'updated_at': FieldValue.serverTimestamp(),
      });

      DebugConfig.print(
        '✅ Account restored: ${fresh.accountUuid} '
        '(pairs=${fresh.restorablePairs}, hidden=${fresh.hiddenLegs}, '
        'writes=${fresh.totalWrites}, balance=${fresh.targetBalance})',
      );

      return AccountRestoreResult(
        failure: AccountRestoreFailure.none,
        plan: fresh,
        accountName: fresh.accountName,
        currency: fresh.currency,
      );
    } catch (error) {
      DebugConfig.print('❌ Account restore error: $error');
      return AccountRestoreResult(
        failure: AccountRestoreFailure.writeFailed,
        plan: plan,
        accountName: plan.accountName,
        currency: plan.currency,
      );
    }
  }

  // ============================================================
  // ΕΠΑΝΑΦΟΡΑ ΧΩΡΙΣ ΥΠΟΛΟΙΠΟ (E30)
  // ============================================================

  Future<AccountRestoreResult> restoreWithoutBalance({
    required String userId,
    required String accountUuid,
  }) async {
    try {
      final accountSnap =
          await _accountRef(userId, accountUuid).get(_server);
      if (!accountSnap.exists) {
        return const AccountRestoreResult(
          failure: AccountRestoreFailure.missing,
        );
      }

      final data = accountSnap.data() ?? <String, dynamic>{};
      final info = _infoOf(accountUuid, data);
      if (data['deleted'] != true) {
        return AccountRestoreResult(
          failure: AccountRestoreFailure.alreadyActive,
          accountName: info.name,
          currency: info.currency,
        );
      }

      final ownSnap = await _txCol(userId)
          .where('account_id', isEqualTo: accountUuid)
          .get(_server);
      final markedSnap = await _txCol(userId)
          .where('annulled_by_account_deleted', isEqualTo: accountUuid)
          .get(_server);

      final fields = <String, Map<String, dynamic>>{};
      var hiddenNow = 0;

      for (final doc in ownSnap.docs) {
        if (doc.data()['deleted'] != true) {
          fields[doc.id] = <String, dynamic>{
            'deleted': true,
            'updated_at': FieldValue.serverTimestamp(),
          };
          hiddenNow++;
        }
      }

      var markersCleared = 0;
      for (final doc in markedSnap.docs) {
        final current = fields.putIfAbsent(doc.id, () => <String, dynamic>{});
        current['annulled_by_account_deleted'] = FieldValue.delete();
        markersCleared++;
      }

      final txCol = _txCol(userId);
      final ids = fields.keys.toList();

      for (var i = 0; i < ids.length; i += _maxWrites) {
        final batch = _db.batch();
        final end = (i + _maxWrites < ids.length) ? i + _maxWrites : ids.length;
        for (var j = i; j < end; j++) {
          batch.update(txCol.doc(ids[j]), fields[ids[j]]!);
        }
        await batch.commit();
      }

      // Commit point: μηδενισμός + ενεργοποίηση + καθαρισμός archived_at.
      await _accountRef(userId, accountUuid).update(<String, dynamic>{
        'deleted': false,
        'is_active': true,
        'archived_at': FieldValue.delete(),
        'initial_balance': 0.0,
        'current_balance': 0.0,
        'updated_at': FieldValue.serverTimestamp(),
      });

      DebugConfig.print(
        '✅ Account restored without balance: $accountUuid '
        '(hidden=$hiddenNow, markers=$markersCleared)',
      );

      return AccountRestoreResult(
        failure: AccountRestoreFailure.none,
        accountName: info.name,
        currency: info.currency,
        hiddenNow: hiddenNow,
        markersCleared: markersCleared,
        wiped: true,
      );
    } catch (error) {
      DebugConfig.print('❌ Account restore (wipe) error: $error');
      return const AccountRestoreResult(
        failure: AccountRestoreFailure.writeFailed,
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static List<Map<String, dynamic>> _mapsOf(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map(
          (doc) => <String, dynamic>{'uuid': doc.id, ...doc.data()},
        )
        .toList();
  }

  static DeletedAccountInfo _infoOf(
    String uuid,
    Map<String, dynamic> data,
  ) {
    return DeletedAccountInfo(
      uuid: uuid,
      name: _text(data['name']),
      currency: _text(
        data['currency'],
        fallback: CurrencyFormatter.defaultCurrency,
      ),
      initialBalance: _amount(data['initial_balance']),
      currentBalance: _amount(data['current_balance']),
      archivedAt: _date(data['archived_at']),
    );
  }

  static String _text(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    return fallback;
  }

  static double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return CurrencyFormatter.parseInput(value) ?? 0.0;
    }
    return 0.0;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
