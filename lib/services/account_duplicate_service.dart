// ============================================================
// FILE: account_duplicate_service.dart
// Path: lib/services/account_duplicate_service.dart
// Ρόλος: Διαχείριση διπλότυπων ονομάτων και επαναφορά διεγραμμένων
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/core/utils/account_delete_guard.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/session/session_scope.dart';

class AccountDuplicateService {
  // ✅ Singleton pattern
  AccountDuplicateService._();
  static final AccountDuplicateService instance = AccountDuplicateService._();

  void _showSuccessSnack(BuildContext context, String message) {
    final b = Theme.of(context).brightness;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: ColorsUI.getOnPrimary(b)),
        ),
        backgroundColor: ColorsUI.getSuccess(b),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnack(BuildContext context, String message) {
    final b = Theme.of(context).brightness;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: ColorsUI.getOnError(b))),
        backgroundColor: ColorsUI.getError(b),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Έλεγχος αν υπάρχει ενεργός λογαριασμός με το ίδιο όνομα
  bool activeAccountNameExists(
    BuildContext context,
    String name, {
    String? excludeUuid,
  }) {
    final accountsProvider = context.read<AccountsProvider>();
    final allAccounts = accountsProvider.accounts;

    return allAccounts.any((account) {
      if (excludeUuid != null && account.uuid == excludeUuid) {
        return false;
      }
      return account.name.trim().toLowerCase() == name.trim().toLowerCase();
    });
  }

  /// Εύρεση διεγραμμένου λογαριασμού με το ίδιο όνομα
  Future<AccountModel?> findDeletedAccountByName(
    String userId,
    String name,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .where('deleted', isEqualTo: true)
          .get();

      for (var doc in snapshot.docs) {
        final accountName = doc.data()['name'] as String;
        if (accountName.trim().toLowerCase() == name.trim().toLowerCase()) {
          return AccountModel.fromFirestore(doc);
        }
      }

      return null;
    } catch (e) {
      DebugConfig.print('❌ Error finding deleted account: $e');
      return null;
    }
  }

  /// Επαναφορά διεγραμμένου λογαριασμού ΜΕ υπόλοιπο και transactions.
  ///
  /// E11: τα ζεύγη μεταφορών που ακυρώθηκαν λόγω διαγραφής λογαριασμού
  /// (marker `annulled_by_account_deleted`) επανέρχονται **συμμετρικά**
  /// (και τα δύο σκέλη + αντιστροφή υπολοίπων)· ζεύγη που δεν είναι πλήρη
  /// ή δείχνουν σε διαγραμμένο λογαριασμό μένουν κρυφά. Γράφει σε chunks
  /// ≤499 (E13).
  Future<void> restoreAccountWithBalance(
    String userId,
    AccountModel deletedAccount,
  ) async {
    final db = FirebaseFirestore.instance;
    final accountUuid = deletedAccount.uuid;
    final usersCol = db.collection('users').doc(userId);
    final txCol = usersCol.collection('transactions');
    final accountsCol = usersCol.collection('accounts');

    try {
      // 1. Επαναφορά λογαριασμού
      await accountsCol.doc(accountUuid).update({
        'deleted': false,
        'is_active': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 2. Ενεργοί λογαριασμοί (έλεγχος peer των ζευγών)
      final accountsSnap =
          await accountsCol.where('deleted', isEqualTo: false).get();
      final activeAccountIds = accountsSnap.docs.map((doc) => doc.id).toSet()
        ..add(accountUuid);

      // 3. Σκέλη με marker ακύρωσης λόγω διαγραφής ΑΥΤΟΥ του λογαριασμού
      final markedSnap = await txCol
          .where('annulled_by_account_deleted', isEqualTo: accountUuid)
          .get();
      final markedLegs = markedSnap.docs
          .map((doc) => <String, dynamic>{'uuid': doc.id, ...doc.data()})
          .toList();
      final markedIds = markedLegs
          .map((leg) => (leg['uuid'] as String?)?.trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final units = AccountDeleteGuard.buildRestoreUnits(
        accountUuid: accountUuid,
        markedLegs: markedLegs,
        activeAccountIds: activeAccountIds,
      );

      // 4. Λοιπές διεγραμμένες κινήσεις του λογαριασμού (χωρίς marker)
      final generalSnap = await txCol
          .where('account_id', isEqualTo: accountUuid)
          .where('deleted', isEqualTo: true)
          .get();
      final generalIds = generalSnap.docs
          .map((doc) => doc.id)
          .where((id) => !markedIds.contains(id))
          .toList();

      // 5. Γραφή σε chunks ≤499: ζεύγη (με deltas) πρώτα, μετά τα υπόλοιπα.
      final updatedAt = FieldValue.serverTimestamp();
      var batch = db.batch();
      var writes = 0;

      Future<void> commitIfNeeded(int needed) async {
        if (writes + needed > AccountDeleteGuard.maxWritesPerBatch) {
          await batch.commit();
          batch = db.batch();
          writes = 0;
        }
      }

      var restoredPairs = 0;
      var skippedPairs = 0;

      for (final unit in units) {
        if (!unit.canRestore) {
          skippedPairs++;
          DebugConfig.print(
            'ℹ️ Restore: group ${unit.groupId} skipped (${unit.skipReason})',
          );
          continue;
        }

        final needed = unit.legUuids.length + unit.deltasByAccount.length;
        await commitIfNeeded(needed);

        for (final legId in unit.legUuids) {
          batch.update(txCol.doc(legId), {
            'deleted': false,
            'annulled_by_account_deleted': FieldValue.delete(),
            'updated_at': updatedAt,
          });
        }

        unit.deltasByAccount.forEach((accountId, delta) {
          batch.update(accountsCol.doc(accountId), {
            'current_balance': FieldValue.increment(delta),
            'updated_at': updatedAt,
          });
        });

        writes += needed;
        restoredPairs++;
      }

      for (final txId in generalIds) {
        await commitIfNeeded(1);
        batch.update(txCol.doc(txId), {
          'deleted': false,
          'updated_at': updatedAt,
        });
        writes++;
      }

      if (writes > 0) await batch.commit();

      DebugConfig.print(
        '✅ Account restored with balance: $accountUuid '
        '(pairs=$restoredPairs, skipped=$skippedPairs, '
        'transactions=${generalIds.length}, writes<='
        '${AccountDeleteGuard.maxWritesPerBatch}/batch)',
      );
    } catch (e) {
      DebugConfig.print('❌ Error restoring account with balance: $e');
      rethrow;
    }
  }

  /// Επαναφορά διεγραμμένου λογαριασμού ΧΩΡΙΣ υπόλοιπο
  Future<void> restoreAccountWithoutBalance(
    String userId,
    AccountModel deletedAccount,
  ) async {
    try {
      // 1) Restore account but ZERO balances
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc(deletedAccount.uuid)
          .update({
            'deleted': false,
            'is_active': true,
            'initial_balance': 0.0,
            'current_balance': 0.0,
            'updated_at': FieldValue.serverTimestamp(),
          });

      // 2) IMPORTANT: Ensure ALL transactions stay hidden (deleted = true)
      final txSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('account_id', isEqualTo: deletedAccount.uuid)
          .where('deleted', isEqualTo: false)
          .get();

      if (txSnapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in txSnapshot.docs) {
          batch.update(doc.reference, {
            'deleted': true,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        DebugConfig.print(
          '✅ Kept ${txSnapshot.docs.length} transactions deleted (WITHOUT balance restore)',
        );
      }

      DebugConfig.print(
        '✅ Account restored without balance: ${deletedAccount.uuid}',
      );
    } catch (e) {
      DebugConfig.print('❌ Error restoring account without balance: $e');
      rethrow;
    }
  }

  /// Dialog επιλογής επαναφοράς διεγραμμένου λογαριασμού
  Future<void> showRestoreAccountDialog(
    BuildContext context,
    String userId,
    AccountModel deletedAccount,
  ) async {
    final brightness = Theme.of(context).brightness;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.restore,
              color: ColorsUI.getPrimary(brightness),
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Λογαριασμός Διαγραμμένος',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Υπάρχει διεγραμμένος λογαριασμός με όνομα "${deletedAccount.name}".',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorsUI.getPrimary(brightness).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ColorsUI.getPrimary(brightness).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 18,
                        color: ColorsUI.getPrimary(brightness),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Στοιχεία λογαριασμού:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ColorsUI.getPrimary(brightness),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Αρχικό υπόλοιπο: ${CurrencyFormatter.format(deletedAccount.initialBalance, currency: deletedAccount.currency)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Τρέχον υπόλοιπο: ${CurrencyFormatter.format(deletedAccount.currentBalance, currency: deletedAccount.currency)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Θέλετε να τον επαναφέρετε;',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          // Ακύρωση
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ακύρωση'),
          ),

          // Επαναφορά ΧΩΡΙΣ υπόλοιπο
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                await restoreAccountWithoutBalance(userId, deletedAccount);

                if (context.mounted) {
                  _showSuccessSnack(
                    context,
                    'Ο λογαριασμός επαναφέρθηκε χωρίς υπόλοιπο',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _showErrorSnack(context, 'Αποτυχία επαναφοράς');
                }
              }
            },
            child: const Text('Χωρίς Υπόλοιπο'),
          ),

          // Επαναφορά ΜΕ υπόλοιπο
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                await restoreAccountWithBalance(userId, deletedAccount);

                if (context.mounted) {
                  _showSuccessSnack(
                    context,
                    'Ο λογαριασμός επαναφέρθηκε με υπόλοιπο',
                  );

                }
              } catch (e) {
                if (context.mounted) {
                  _showErrorSnack(
                    context,
                    'Αποτυχία επαναφοράς',
                  );

                }
              }
            },
            icon: const Icon(Icons.restore, size: 20),
            label: const Text('Με Υπόλοιπο'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsUI.getPrimary(brightness),
              foregroundColor: ColorsUI.getOnPrimary(brightness),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper: Πλήρης έλεγχος για δημιουργία λογαριασμού
  /// Returns: true αν μπορεί να συνεχίσει, false αν πρέπει να σταματήσει
  Future<bool> checkForCreateAccount(
    BuildContext context,
    String userId,
    String accountName,
  ) async {
    // 1. Έλεγχος ενεργών λογαριασμών
    if (activeAccountNameExists(context, accountName)) {
      _showErrorSnack(context, 'Υπάρχει ενεργός Λογαριασμός με αυτό το Όνομα');
      return false;
    }
    // 2. Έλεγχος διεγραμμένων λογαριασμών
    final deletedAccount = await findDeletedAccountByName(userId, accountName);
    if (!context.mounted) return false;
    if (deletedAccount != null) {
      // Εμφάνιση dialog επαναφοράς
      await showRestoreAccountDialog(context, userId, deletedAccount);
      return false; // Δεν συνεχίζει με δημιουργία
    }

    // 3. Όλα ΟΚ, μπορεί να συνεχίσει
    return true;
  }

  /// Helper: Έλεγχος για επεξεργασία λογαριασμού
  /// Returns: true αν μπορεί να συνεχίσει, false αν πρέπει να σταματήσει
  Future<bool> checkForEditAccount(
    BuildContext context,
    String accountName,
    String currentAccountUuid,
  ) async {
    // Έλεγχος μόνο ενεργών (όχι διεγραμμένων)
    if (activeAccountNameExists(
      context,
      accountName,
      excludeUuid: currentAccountUuid,
    )) {
      _showErrorSnack(
        context,
        'Υπάρχει ήδη ενεργός λογαριασμός με αυτό το όνομα',
      );
      return false;
    }
    // ✅ Έλεγχος διεγραμμένου λογαριασμού με ίδιο όνομα
    final userId = context.session.userId;

    final deletedAccount = await findDeletedAccountByName(userId, accountName);

    if (!context.mounted) return false;

    if (deletedAccount != null && deletedAccount.uuid != currentAccountUuid) {
      _showErrorSnack(context, 'Δεν μπορεί να χρησιμοποιηθεί αυτό το Όνομα');
      return false;
    }
    return true;
  }
}
