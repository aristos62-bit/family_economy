// ============================================================
// FILE: transactions_actions_service.dart
// Path: lib/core/services/transactions_actions_service.dart
//
// Ρόλος: ΕΝΙΑΙΟ σημείο αλήθειας για:
// 1) Εισαγωγή (income/expense/transfer)
// 2) Μεταβολή (income/expense/transfer)
// 3) Διαγραφή (income/expense/transfer)
// + ΕΝΗΜΕΡΩΣΗ ΥΠΟΛΟΙΠΩΝ ΛΟΓΑΡΙΑΣΜΩΝ (balances) ΜΟΝΟ ΕΔΩ
//
// ✅ Στόχος: Οι σελίδες ΔΕΝ υπολογίζουν balances με άλλο τρόπο.
// ✅ Online/Offline: όλα με batch + cache fallback όπου χρειάζεται.
// ✅ Soft-delete: deleted=true (όπως ήδη έχεις)
//
// Σημείωση: Κρατάμε τη λογική που ήδη έχεις για delete/edit transfers,
// και προσθέτουμε "create" (insert) ώστε να καλούν όλοι αυτό το service.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class TransactionsActionsService {
  final FirebaseFirestore _db;
  final Uuid _uuid;

  TransactionsActionsService({
    FirebaseFirestore? db,
    Uuid? uuid,
  })  : _db = db ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  // ============================================================
  // PUBLIC API (ένα σημείο για όλα)
  // ============================================================

  /// ------------------------------------------------------------
  /// CREATE: Income / Expense / Transfer
  /// ------------------------------------------------------------
  ///
  /// - Income/Expense: γράφει 1 transaction doc
  /// - Transfer: γράφει 2 transaction docs με κοινό transfer_group_id
  /// - ΠΑΝΤΑ ενημερώνει balances με FieldValue.increment μέσα στο ίδιο batch
  ///
  /// Returns:
  /// - income/expense: transactionUuid
  /// - transfer: transferGroupId
  Future<String> create({
    required String userId,
    required String transactionType, // 'income' | 'expense' | 'transfer'
    required DateTime date,
    required double amountAbs, // ΠΑΝΤΑ θετικό
    required String currency,

    // Source account (πάντα απαιτείται)
    required String accountUuid,

    // Transfer target (μόνο για transfer)
    String? targetAccountUuid,

    // Category (μόνο για non-transfer)
    String? categoryUuid,
    String? subcategoryUuid,

    String? notes,
    List<String>? tagIds,
  }) async {
    final type = transactionType.trim();
    if (amountAbs <= 0) {
      throw ArgumentError('amountAbs must be > 0');
    }
    if (accountUuid.trim().isEmpty) {
      throw ArgumentError('accountUuid is required');
    }

    if (type == 'transfer') {
      if ((targetAccountUuid ?? '').trim().isEmpty) {
        throw ArgumentError('targetAccountUuid is required for transfer');
      }
      if (targetAccountUuid == accountUuid) {
        // Προαιρετική προστασία (αν θες να το επιτρέπεις, βγάλ' το)
        throw ArgumentError('source and target account cannot be the same');
      }
      return _createTransfer(
        userId: userId,
        sourceAccountUuid: accountUuid,
        targetAccountUuid: targetAccountUuid!,
        date: date,
        amountAbs: amountAbs,
        notes: notes,
        currency: currency,
        tagIds: tagIds,
      );
    }

    // income/expense
    if ((categoryUuid ?? '').trim().isEmpty) {
      throw ArgumentError('categoryUuid is required for income/expense');
    }

    return _createIncomeExpense(
      userId: userId,
      accountUuid: accountUuid,
      categoryUuid: categoryUuid!,
      subcategoryUuid: subcategoryUuid,
      date: date,
      amountAbs: amountAbs,
      notes: notes,
      currency: currency,
      transactionType: type,
      tagIds: tagIds,
    );
  }

  /// ------------------------------------------------------------
  /// DELETE: Soft delete + reverse balances (income/expense/transfer)
  /// ------------------------------------------------------------
  ///
  /// tx map πρέπει να περιέχει:
  /// - uuid
  /// - transaction_type
  /// - amount
  /// - account_id
  /// - transfer_group_id (αν transfer)
  Future<void> delete({
    required String userId,
    required Map<String, dynamic> tx,
    bool skipBalanceUpdate = false,
  }) async {
    await deleteTransaction(
      userId: userId,
      tx: tx,
      skipBalanceUpdate: skipBalanceUpdate,
    );
  }

  /// ------------------------------------------------------------
  /// EDIT: Ενημέρωση tx + balances σωστά (income/expense/transfer)
  /// ------------------------------------------------------------
  ///
  /// Δένει με το υπάρχον TransactionEditSheet σου:
  /// - newAmountAbs (πάντα θετικό)
  /// - newDate
  /// - για non-transfer: μπορεί να αλλάξει category/subcategory/account
  /// - για transfer: στο sheet τα έχεις disabled (σωστό)
  Future<void> edit({
    required String userId,
    required Map<String, dynamic> tx,
    required double newAmountAbs,
    required DateTime newDate,
    required String? newCategoryId,
    required String? newSubcategoryId,
    required String? newAccountId,

    // ✅ ΝΕΟ
    String? newNotes,
  }) async {
    await saveTransactionEdit(
      userId: userId,
      tx: tx,
      newAmountAbs: newAmountAbs,
      newDate: newDate,
      newCategoryId: newCategoryId,
      newSubcategoryId: newSubcategoryId,
      newAccountId: newAccountId,

      // ✅ ΝΕΟ
      newNotes: newNotes,
    );
  }


  // ============================================================
  // CREATE IMPLEMENTATION
  // ============================================================

  Future<String> _createIncomeExpense({
    required String userId,
    required String accountUuid,
    required String categoryUuid,
    String? subcategoryUuid,
    required String transactionType, // 'income'|'expense'
    required DateTime date,
    required double amountAbs,
    required String currency,
    String? notes,
    List<String>? tagIds,
  }) async {
    final now = DateTime.now();
    final txUuid = _uuid.v4();

    final signedAmount =
    (transactionType == 'expense') ? -amountAbs.abs() : amountAbs.abs();

    final txRef = _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(txUuid);

    final batch = _db.batch();

    batch.set(txRef, {
      'user_id': userId,
      'account_id': accountUuid,
      'category_id': categoryUuid,
      'subcategory_id': subcategoryUuid,
      'date': Timestamp.fromDate(date),
      'amount': signedAmount,
      'currency': currency,
      'exchange_rate': 1.0,
      'notes': notes,
      'attachment_path': null,
      'transaction_type': transactionType, // 'income'|'expense'
      'transfer_group_id': null,
      'is_recurring': false,
      'recurring_schedule_id': null,
      'tags': tagIds ?? <String>[],
      'location_lat': null,
      'location_lng': null,
      'is_split': false,
      'created_at': Timestamp.fromDate(now),
      'updated_at': Timestamp.fromDate(now),
      'last_modified_device_id': '',
      'deleted': false,
    });

    // balances: increment signedAmount
    batch.update(_accountRef(userId, accountUuid), {
      'current_balance': FieldValue.increment(signedAmount),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return txUuid;
  }

  Future<String> _createTransfer({
    required String userId,
    required String sourceAccountUuid,
    required String targetAccountUuid,
    required DateTime date,
    required double amountAbs,
    required String currency,
    String? notes,
    List<String>? tagIds,
  }) async {
    final now = DateTime.now();
    final transferGroupId = _uuid.v4();

    // Κατηγορία "Μεταφορά" (system/hidden)
    final transferCategoryUuid = await _getOrCreateTransferCategory(userId);

    final sourceTxUuid = _uuid.v4();
    final targetTxUuid = _uuid.v4();

    final sourceRef = _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(sourceTxUuid);

    final targetRef = _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(targetTxUuid);

    final batch = _db.batch();

    // Source leg (negative)
    batch.set(sourceRef, {
      'user_id': userId,
      'account_id': sourceAccountUuid,
      'category_id': transferCategoryUuid,
      'subcategory_id': null,
      'date': Timestamp.fromDate(date),
      'amount': -amountAbs.abs(),
      'currency': currency,
      'exchange_rate': 1.0,
      'notes': notes,
      'attachment_path': null,
      'transaction_type': 'transfer',
      'transfer_group_id': transferGroupId,
      'is_recurring': false,
      'recurring_schedule_id': null,
      'tags': tagIds ?? <String>[],
      'location_lat': null,
      'location_lng': null,
      'is_split': false,
      'created_at': Timestamp.fromDate(now),
      'updated_at': Timestamp.fromDate(now),
      'last_modified_device_id': '',
      'deleted': false,
      'transfer_peer_uuid': targetTxUuid,
      'transfer_peer_account_id': targetAccountUuid,
    });

    // Target leg (positive)
    batch.set(targetRef, {
      'user_id': userId,
      'account_id': targetAccountUuid,
      'category_id': transferCategoryUuid,
      'subcategory_id': null,
      'date': Timestamp.fromDate(date),
      'amount': amountAbs.abs(),
      'currency': currency,
      'exchange_rate': 1.0,
      'notes': notes,
      'attachment_path': null,
      'transaction_type': 'transfer',
      'transfer_group_id': transferGroupId,
      'is_recurring': false,
      'recurring_schedule_id': null,
      'tags': tagIds ?? <String>[],
      'location_lat': null,
      'location_lng': null,
      'is_split': false,
      'created_at': Timestamp.fromDate(now),
      'updated_at': Timestamp.fromDate(now),
      'last_modified_device_id': '',
      'deleted': false,
      'transfer_peer_uuid': sourceTxUuid,
      'transfer_peer_account_id': sourceAccountUuid,
    });

    // balances in same batch:
    batch.update(_accountRef(userId, sourceAccountUuid), {
      'current_balance': FieldValue.increment(-amountAbs.abs()),
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(_accountRef(userId, targetAccountUuid), {
      'current_balance': FieldValue.increment(amountAbs.abs()),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return transferGroupId;
  }

  // ============================================================
  // EXISTING LOGIC (kept) - DELETE
  // ============================================================

  Future<void> deleteTransaction({
    required String userId,
    required Map<String, dynamic> tx,
    bool skipBalanceUpdate = false,
  }) async {
    final txUuid = tx['uuid'] as String;
    final isTransfer = tx['transaction_type'] == 'transfer';

    final txRef = _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(txUuid);

    if (isTransfer) {
      final transferGroupId = tx['transfer_group_id'];
      final peerUuid = tx['transfer_peer_uuid'] as String?;
      final peerAccountId = tx['transfer_peer_account_id'] as String?;
      final thisAccountId = tx['account_id'] as String?;
      final thisAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

// ✅ Offline-safe path: αν έχουμε peer info, δεν χρειάζεται query
      if ((peerUuid ?? '').isNotEmpty &&
          (peerAccountId ?? '').isNotEmpty &&
          (thisAccountId ?? '').isNotEmpty) {
        final batch = _db.batch();

        // ✅ soft delete ΚΑΙ τα 2 docs χωρίς να χρειάζονται στην cache
        batch.set(txRef, {
          'deleted': true,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final peerRef = _db
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .doc(peerUuid);

        batch.set(peerRef, {
          'deleted': true,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // ✅ reverse balances με βάση το amount του τρέχοντος leg
        // delta για αυτόν τον λογαριασμό = -thisAmount
        if (!skipBalanceUpdate) {
          batch.update(_accountRef(userId, thisAccountId!), {
            'current_balance': FieldValue.increment(-thisAmount),
            'updated_at': FieldValue.serverTimestamp(),
          });

          final peerAmount = -thisAmount;
          batch.update(_accountRef(userId, peerAccountId!), {
            'current_balance': FieldValue.increment(-peerAmount),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        return;
      }

      if (transferGroupId == null) {
        // fallback: διαγράφει μόνο αυτό + ενημερώνει balance
        final accountId = tx['account_id'] as String?;
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

        final batch = _db.batch();
        batch.update(txRef, {
          'deleted': true,
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (accountId != null && accountId.isNotEmpty && !skipBalanceUpdate) {
          batch.update(_accountRef(userId, accountId), {
            'current_balance': FieldValue.increment(-amount),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        return;
      }

      // Αν έχουμε peer uuid, κάνουμε delete ΚΑΙ το άλλο leg στοχευμένα
      if ((peerUuid ?? '').trim().isNotEmpty) {
        final peerRef = _db
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .doc(peerUuid);

        final peerSnap = await _getDocWithCacheFallback(peerRef);
        final peerData = peerSnap.data();

        // Αν για κάποιο λόγο δεν υπάρχει, πέφτουμε στο query fallback
        if (peerData != null) {
          final peerAmount = (peerData['amount'] as num?)?.toDouble() ?? 0.0;
          final peerAccountIdFromDoc =
              (peerData['account_id'] as String?) ?? peerAccountId;

          final batch = _db.batch();

          // Soft delete: και τα 2 legs
          batch.update(txRef, {
            'deleted': true,
            'updated_at': FieldValue.serverTimestamp(),
          });
          batch.update(peerRef, {
            'deleted': true,
            'updated_at': FieldValue.serverTimestamp(),
          });

          // Reverse balances:
          // delta = -amount (αντιστρέφει την κίνηση)
          if (!skipBalanceUpdate) {
            if ((thisAccountId ?? '').trim().isNotEmpty) {
              batch.update(_accountRef(userId, thisAccountId!), {
                'current_balance': FieldValue.increment(-thisAmount),
                'updated_at': FieldValue.serverTimestamp(),
              });
            }

            if ((peerAccountIdFromDoc ?? '').trim().isNotEmpty) {
              batch.update(_accountRef(userId, peerAccountIdFromDoc!), {
                'current_balance': FieldValue.increment(-peerAmount),
                'updated_at': FieldValue.serverTimestamp(),
              });
            }
          }

          await batch.commit();
          return;
        }
      }

      // ✅ 2) Fallback: query by transfer_group_id (και ΜΟΝΟ μη-deleted)
      final snap = await _getQueryWithCacheFallback(
        _db
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .where('transfer_group_id', isEqualTo: transferGroupId)
            .where('deleted', isEqualTo: false),
      );

      final Map<String, double> deltas = {};
      final batch = _db.batch();

      for (final doc in snap.docs) {
        final data = doc.data();

        // Guard (αν έρθει κάτι περίεργο)
        if (data['deleted'] == true) continue;

        final accountId = data['account_id'] as String?;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

        batch.update(doc.reference, {
          'deleted': true,
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (accountId != null && accountId.isNotEmpty && !skipBalanceUpdate) {
          deltas[accountId] = (deltas[accountId] ?? 0.0) + (-amount);
        }
      }

      deltas.forEach((accountId, delta) {
        batch.update(_accountRef(userId, accountId), {
          'current_balance': FieldValue.increment(delta),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();
      return;

    }

    // Non-transfer
    final accountId = tx['account_id'] as String?;
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

    final batch = _db.batch();

    batch.update(txRef, {
      'deleted': true,
      'updated_at': FieldValue.serverTimestamp(),
    });

    if (accountId != null && accountId.isNotEmpty && !skipBalanceUpdate) {
      batch.update(_accountRef(userId, accountId), {
        'current_balance': FieldValue.increment(-amount),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ============================================================
  // EXISTING LOGIC (kept) - EDIT
  // ============================================================

  Future<void> saveTransactionEdit({
    required String userId,
    required Map<String, dynamic> tx,
    required double newAmountAbs, // πάντα θετικό
    required DateTime newDate,
    required String? newCategoryId,
    required String? newSubcategoryId,
    required String? newAccountId,

    // ✅ ΝΕΟ
    String? newNotes,
  }) async {
    final txUuid = tx['uuid'] as String;
    final isTransfer = tx['transaction_type'] == 'transfer';

    final txRef = _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(txUuid);

    // ------------------------------------------------------------
    // TRANSFER: update BOTH legs + balances with deltas
    // ------------------------------------------------------------
    if (isTransfer) {

      // ✅ OFFLINE-SAFE TRANSFER EDIT (χωρίς query) αν έχουμε peer info
      // ✅ TRANSFER EDIT: αν έχουμε peer_uuid, κάνουμε στοχευμένο update και στα 2 legs
      final peerUuid = (tx['transfer_peer_uuid'] as String?)?.trim();
      final thisAccountId = (tx['account_id'] as String?)?.trim();

      if ((peerUuid ?? '').isNotEmpty && (thisAccountId ?? '').isNotEmpty) {
        final oldThisAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

        final peerRef = _db
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .doc(peerUuid!);

        final peerSnap = await _getDocWithCacheFallback(peerRef);
        final peerData = peerSnap.data();

        // Αν βρούμε peer doc (online ή cache), παίρνουμε ΑΛΗΘΙΝΑ oldPeerAmount & peerAccountId
        if (peerData != null) {
          final peerAccountIdFromDoc =
          (peerData['account_id'] as String?)?.trim();
          final oldPeerAmount =
              (peerData['amount'] as num?)?.toDouble() ?? 0.0;

          if ((peerAccountIdFromDoc ?? '').isNotEmpty) {
            // κρατάμε πρόσημο σε κάθε leg όπως ήταν
            final newThisAmount =
            oldThisAmount >= 0 ? newAmountAbs.abs() : -newAmountAbs.abs();

            final newPeerAmount =
            oldPeerAmount >= 0 ? newAmountAbs.abs() : -newAmountAbs.abs();

            final deltaThis = newThisAmount - oldThisAmount;
            final deltaPeer = newPeerAmount - oldPeerAmount;

            final batch = _db.batch();

            final thisUpdate = <String, dynamic>{
              'amount': newThisAmount,
              'date': Timestamp.fromDate(newDate),
              'updated_at': FieldValue.serverTimestamp(),
            };
            final peerUpdate = <String, dynamic>{
              'amount': newPeerAmount,
              'date': Timestamp.fromDate(newDate),
              'updated_at': FieldValue.serverTimestamp(),
            };

            // ✅ ΝΕΟ: notes και στα 2 legs (μόνο αν δόθηκαν)
            if (newNotes != null) {
              final trimmed = newNotes.trim();
              thisUpdate['notes'] = trimmed;
              peerUpdate['notes'] = trimmed;
            }

            batch.set(txRef, thisUpdate, SetOptions(merge: true));
            batch.set(peerRef, peerUpdate, SetOptions(merge: true));


            final thisAcc = thisAccountId!;
            final peerAcc = peerAccountIdFromDoc!;

            if (deltaThis != 0) {
              batch.update(_accountRef(userId, thisAcc), {
                'current_balance': FieldValue.increment(deltaThis),
                'updated_at': FieldValue.serverTimestamp(),
              });
            }

            if (deltaPeer != 0) {
              batch.update(_accountRef(userId, peerAcc), {
                'current_balance': FieldValue.increment(deltaPeer),
                'updated_at': FieldValue.serverTimestamp(),
              });
            }

            await batch.commit();
            return;
          }
        }

        // Αν δεν βρούμε peer doc, συνεχίζουμε στο transfer_group_id fallback από κάτω.
      }



      final transferGroupId = tx['transfer_group_id'];

      // “ορφανό transfer” fallback: treat as single doc but still fix balances delta
      if (transferGroupId == null) {
        final oldAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final oldAccountId = tx['account_id'] as String?;
        final signedAmount = oldAmount >= 0 ? newAmountAbs : -newAmountAbs;

        final batch = _db.batch();

        batch.update(txRef, {
          'amount': signedAmount,
          'date': Timestamp.fromDate(newDate),
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Balance delta = new - old
        if (oldAccountId != null && oldAccountId.isNotEmpty) {
          final delta = signedAmount - oldAmount;
          if (delta != 0) {
            batch.update(_accountRef(userId, oldAccountId), {
              'current_balance': FieldValue.increment(delta),
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }

        await batch.commit();
        return;
      }

      // Φέρνουμε και τα 2 legs με cache fallback
      final snap = await _getQueryWithCacheFallback(
        _db
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .where('transfer_group_id', isEqualTo: transferGroupId)
            .where('deleted', isEqualTo: false),
      );

// ✅ ΑΣΦΑΛΕΙΑ: transfer πρέπει να έχει ΠΑΝΤΑ 2 legs
      if (snap.docs.length != 2) {
        throw StateError(
          'Transfer delete mismatch: expected 2 legs, got ${snap.docs.length} '
              '(transfer_group_id: $transferGroupId)',
        );
      }


      final editedOldAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final editedIsPositive = editedOldAmount >= 0;
      final absAmount = newAmountAbs.abs();
      final batch = _db.batch();

      // Deltas ανά account (1 update ανά account)
      final Map<String, double> deltasByAccount = {};

      if (snap.docs.length != 2) {
        throw StateError(
          'Transfer legs mismatch: expected 2, got ${snap.docs.length} '
              '(transfer_group_id: $transferGroupId)',
        );
      }

      for (final doc in snap.docs) {
        final data = doc.data();
        final oldLegAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final accountId = data['account_id'] as String?;

        // Preserve sign: one positive, one negative
        final isEditedDoc = doc.id == txUuid;
        final shouldBePositive = isEditedDoc ? editedIsPositive : !editedIsPositive;
        final newLegAmount = shouldBePositive ? absAmount : -absAmount;

        final legUpdate = <String, dynamic>{
          'amount': newLegAmount,
          'date': Timestamp.fromDate(newDate),
          'updated_at': FieldValue.serverTimestamp(),
        };

        // ✅ ΝΕΟ: notes (μόνο αν δόθηκαν)
        if (newNotes != null) {
          legUpdate['notes'] = newNotes.trim();
        }

        batch.update(doc.reference, legUpdate);


        // Balance delta for that account = new - old
        if (accountId != null && accountId.isNotEmpty) {
          final delta = newLegAmount - oldLegAmount;
          if (delta != 0) {
            deltasByAccount[accountId] =
                (deltasByAccount[accountId] ?? 0.0) + delta;
          }
        }
      }

      // Apply balance deltas
      deltasByAccount.forEach((accountId, delta) {
        batch.update(_accountRef(userId, accountId), {
          'current_balance': FieldValue.increment(delta),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();
      return;
    }

    // ------------------------------------------------------------
    // NON-TRANSFER: update tx + balances correctly
    // ------------------------------------------------------------
    final oldAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final oldAccountId = tx['account_id'] as String?;
    final signedAmount = oldAmount >= 0 ? newAmountAbs : -newAmountAbs;

    final batch = _db.batch();

    final updateData = <String, dynamic>{
      'amount': signedAmount,
      'date': Timestamp.fromDate(newDate),
      'category_id': newCategoryId,
      'subcategory_id': newSubcategoryId,
      'account_id': newAccountId,
      'updated_at': FieldValue.serverTimestamp(),
    };

    // ✅ ΝΕΟ: notes (μόνο αν δόθηκαν)
    if (newNotes != null) {
      updateData['notes'] = newNotes.trim();
    }

    batch.update(txRef, updateData);


    final newAccId = (newAccountId ?? '').trim();
    final oldAccId = (oldAccountId ?? '').trim();

    if (oldAccId.isNotEmpty && newAccId.isNotEmpty && oldAccId != newAccId) {
      // moved to another account:
      batch.update(_accountRef(userId, oldAccId), {
        'current_balance': FieldValue.increment(-oldAmount),
        'updated_at': FieldValue.serverTimestamp(),
      });
      batch.update(_accountRef(userId, newAccId), {
        'current_balance': FieldValue.increment(signedAmount),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else if (oldAccId.isNotEmpty) {
      // same account -> apply delta only
      final delta = signedAmount - oldAmount;
      if (delta != 0) {
        batch.update(_accountRef(userId, oldAccId), {
          'current_balance': FieldValue.increment(delta),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  DocumentReference<Map<String, dynamic>> _accountRef(String userId, String accountId) {
    return _db.collection('users').doc(userId).collection('accounts').doc(accountId);
  }

  /// Προσπαθεί να κάνει query στο server, αν αποτύχει χρησιμοποιεί cache
  Future<QuerySnapshot<Map<String, dynamic>>> _getQueryWithCacheFallback(
      Query<Map<String, dynamic>> query,
      ) async {
    try {
      return await query.get(const GetOptions(source: Source.server));
    } catch (_) {
      return await query.get(const GetOptions(source: Source.cache));
    }
  }

  /// Get or create special "Transfer" category (system/hidden)
  Future<String> _getOrCreateTransferCategory(String userId) async {
    // Check if transfer category exists
    final query = await _getQueryWithCacheFallback(
      _db
          .collection('users')
          .doc(userId)
          .collection('categories')
          .where('type', isEqualTo: 'transfer')
          .where('is_system', isEqualTo: true)
          .limit(1),
    );

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }

    // Create transfer category
    final categoryUuid = _uuid.v4();
    final now = DateTime.now();

    await _db
        .collection('users')
        .doc(userId)
        .collection('categories')
        .doc(categoryUuid)
        .set({
      'user_id': userId,
      'name': 'Μεταφορά',
      'type': 'transfer',
      'icon_index': null,
      'color': '#0277BD',
      'is_system': true,
      'hidden': true,
      'display_order': 999,
      'created_at': Timestamp.fromDate(now),
      'updated_at': Timestamp.fromDate(now),
      'last_modified_device_id': '',
      'deleted': false,
    });

    return categoryUuid;
  }
  Future<DocumentSnapshot<Map<String, dynamic>>> _getDocWithCacheFallback(
      DocumentReference<Map<String, dynamic>> ref,
      ) async {
    try {
      return await ref.get(const GetOptions(source: Source.server));
    } catch (_) {
      return await ref.get(const GetOptions(source: Source.cache));
    }
  }

}
