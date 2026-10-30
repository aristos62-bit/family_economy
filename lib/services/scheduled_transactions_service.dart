// ============================================================
// FILE: scheduled_transactions_service.dart
// Path: lib/services/scheduled_transactions_service.dart
// Ρόλος: Διαχείριση προγραμματισμένων κινήσεων
// VERSION: Final - Uses transactions table with scheduling flags
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/services/notifications_service.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';

class ScheduledTransactionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ✅ ΜΟΝΗ ΠΡΟΣΘΗΚΗ: Static field για startup notification
  static int lastExecutedCount = 0;

  /// Δημιουργία προγραμματισμένης κίνησης (Income/Expense)
  Future<String> createScheduledTransaction({
    required String userId,
    required String accountUuid,
    required String categoryUuid,
    String? subcategoryUuid,
    required double amount,
    required String transactionType, // 'income' | 'expense'
    required DateTime scheduledDate,
    String? notes,
    String currency = 'EUR',
  }) async {
    try {
      final transactionUuid = _uuid.v4();
      final now = DateTime.now();

      final data = {
        'user_id': userId,
        'account_id': accountUuid,
        'category_id': categoryUuid,
        'subcategory_id': subcategoryUuid,
        'date': Timestamp.fromDate(
          scheduledDate,
        ), // Η ημερομηνία που θα εμφανίζεται
        'scheduled_for_date': Timestamp.fromDate(
          scheduledDate,
        ), // Πότε θα εκτελεστεί
        'amount': transactionType == 'expense' ? -amount.abs() : amount.abs(),
        'currency': currency,
        'exchange_rate': 1.0,
        'notes': notes,
        'attachment_path': null,
        'transaction_type': transactionType,
        'transfer_group_id': null,
        'is_recurring': false,
        'recurring_schedule_id': null,
        'tags': <String>[],
        'location_lat': null,
        'location_lng': null,
        'is_split': false,
        // ✅ Scheduled flags
        'is_scheduled': true,
        'is_executed': false,
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
        'last_modified_device_id': '',
        'deleted': false,
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transactionUuid)
          .set(data);

      DebugConfig.print('✅ Scheduled transaction created: $transactionUuid');
      return transactionUuid;
    } catch (e) {
      DebugConfig.print('🔴 Error creating scheduled transaction: $e');
      rethrow;
    }
  }

  /// Δημιουργία προγραμματισμένης μεταφοράς
  Future<String> createScheduledTransfer({
    required String userId,
    required String sourceAccountUuid,
    required String targetAccountUuid,
    required double amount,
    required DateTime scheduledDate,
    String? notes,
    String currency = 'EUR',
  }) async {
    try {
      final transferGroupId = _uuid.v4();
      final now = DateTime.now();

      // Get or create Transfer category
      final transferCategoryUuid = await _getOrCreateTransferCategory(userId);

      // Transaction 1: Source account (outgoing = negative)
      final sourceTransactionUuid = _uuid.v4();
      final sourceData = {
        'user_id': userId,
        'account_id': sourceAccountUuid,
        'category_id': transferCategoryUuid,
        'subcategory_id': null,
        'date': Timestamp.fromDate(scheduledDate),
        'scheduled_for_date': Timestamp.fromDate(scheduledDate),
        'amount': -amount.abs(),
        'currency': currency,
        'exchange_rate': 1.0,
        'notes': notes,
        'attachment_path': null,
        'transaction_type': 'transfer',
        'transfer_group_id': transferGroupId,
        'is_recurring': false,
        'recurring_schedule_id': null,
        'tags': <String>[],
        'location_lat': null,
        'location_lng': null,
        'is_split': false,
        // ✅ Scheduled flags
        'is_scheduled': true,
        'is_executed': false,
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
        'last_modified_device_id': '',
        'deleted': false,
      };

      // Transaction 2: Target account (incoming = positive)
      final targetTransactionUuid = _uuid.v4();
      final targetData = {
        'user_id': userId,
        'account_id': targetAccountUuid,
        'category_id': transferCategoryUuid,
        'subcategory_id': null,
        'date': Timestamp.fromDate(scheduledDate),
        'scheduled_for_date': Timestamp.fromDate(scheduledDate),
        'amount': amount.abs(),
        'currency': currency,
        'exchange_rate': 1.0,
        'notes': notes,
        'attachment_path': null,
        'transaction_type': 'transfer',
        'transfer_group_id': transferGroupId,
        'is_recurring': false,
        'recurring_schedule_id': null,
        'tags': <String>[],
        'location_lat': null,
        'location_lng': null,
        'is_split': false,
        // ✅ Scheduled flags
        'is_scheduled': true,
        'is_executed': false,
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
        'last_modified_device_id': '',
        'deleted': false,
      };

      // Batch write
      final batch = _firestore.batch();

      batch.set(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .doc(sourceTransactionUuid),
        sourceData,
      );

      batch.set(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .doc(targetTransactionUuid),
        targetData,
      );

      await batch.commit();

      DebugConfig.print('✅ Scheduled transfer created: $transferGroupId');
      return transferGroupId;
    } catch (e) {
      DebugConfig.print('🔴 Error creating scheduled transfer: $e');
      rethrow;
    }
  }

  /// Εκτέλεση προγραμματισμένης κίνησης
  Future<bool> executeScheduledTransaction(
    String userId,
    String transactionUuid,
  ) async {
    try {
      final txRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transactionUuid);

      final txDoc = await txRef.get();

      if (!txDoc.exists) {
        DebugConfig.print(
          '⚠️ Scheduled transaction not found: $transactionUuid',
        );
        return false;
      }

      final data = txDoc.data()!;
      final isScheduled = data['is_scheduled'] as bool? ?? false;
      final isExecuted = data['is_executed'] as bool? ?? false;
      final isDeleted = data['deleted'] as bool? ?? false;
      final executionFailed = data['execution_failed'] as bool? ?? false;

      // Εκτελεσμένη, ακυρωμένη ή αποτυχημένη (περιμένει απόφαση χρήστη): δεν εκτελείται
      if (!isScheduled || isExecuted || isDeleted || executionFailed) {
        DebugConfig.print(
          '⚠️ Transaction not executable (not scheduled / executed / cancelled / failed): $transactionUuid',
        );
        return false;
      }

      final transactionType = data['transaction_type'] as String;
      final amount = (data['amount'] as num).toDouble();
      final accountId = data['account_id'] as String;

      // ✅ BALANCE CHECK κατά την ΕΚΤΕΛΕΣΗ (όχι κατά την εισαγωγή)
      final insufficient = await _findInsufficientDebit(userId, data);
      if (insufficient != null) {
        await _markExecutionFailed(userId, transactionUuid, data, insufficient);
        return false;
      }

      // ✅ Mark as executed
      await txRef.update({
        'is_executed': true,
        'is_scheduled': false,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // ✅ Update account balance
      if (transactionType == 'transfer') {
        // For transfers, handle both accounts
        final transferGroupId = data['transfer_group_id'] as String?;

        if (transferGroupId != null) {
          // Find both legs of transfer
          final transferLegs = await _firestore
              .collection('users')
              .doc(userId)
              .collection('transactions')
              .where('transfer_group_id', isEqualTo: transferGroupId)
              .get();

          final batch = _firestore.batch();

          for (final leg in transferLegs.docs) {
            final legData = leg.data();
            final legAccountId = legData['account_id'] as String;
            final legAmount = (legData['amount'] as num).toDouble();

            // Update transaction
            batch.update(leg.reference, {
              'is_executed': true,
              'is_scheduled': false,
              'updated_at': FieldValue.serverTimestamp(),
            });

            // Update account balance
            final accountRef = _firestore
                .collection('users')
                .doc(userId)
                .collection('accounts')
                .doc(legAccountId);

            batch.update(accountRef, {
              'current_balance': FieldValue.increment(legAmount),
              'updated_at': FieldValue.serverTimestamp(),
            });
          }

          await batch.commit();
        }
      } else {
        // Single transaction (income/expense)
        final accountRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc(accountId);

        await accountRef.update({
          'current_balance': FieldValue.increment(amount),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      // ✅ ΝΕΟΣ: Στείλε system notification
      try {
        final typeLabel = transactionType == 'income'
            ? 'Έσοδο'
            : transactionType == 'expense'
            ? 'Έξοδο'
            : 'Μεταφορά';

        final formattedAmount = '€${amount.abs().toStringAsFixed(2)}';

        await NotificationsService().showImmediateNotification(
          title: 'Προγραμματισμένη Κίνηση',
          message: '$typeLabel $formattedAmount εκτελέστηκε',
        );
      } catch (e) {
        DebugConfig.print('⚠️ Could not send notification: $e');
      }

      DebugConfig.print('✅ Scheduled transaction executed: $transactionUuid');
      return true;
    } catch (e) {
      DebugConfig.print('🔴 Error executing scheduled transaction: $e');
      return false;
    }
  }

  /// Έλεγχος και εκτέλεση εκκρεμών προγραμματισμένων κινήσεων
  Future<List<Map<String, dynamic>>> checkAndExecutePendingTransactions(
      String userId,
      ) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final executed = <Map<String, dynamic>>[];

      final todayStart = Timestamp.fromDate(today);
      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('is_scheduled', isEqualTo: true)
          .where('is_executed', isEqualTo: false)
          .where('deleted', isEqualTo: false)
          .where('scheduled_for_date', isLessThanOrEqualTo: todayStart)
          .get();

      // ✅ Σειρά εκτέλεσης: ημερομηνία ↑ και μέσα στην ίδια ημέρα πρώτα τα έσοδα
      final docs = query.docs.toList()
        ..sort((a, b) {
          final da = (a.data()['scheduled_for_date'] as Timestamp)
              .toDate()
              .toLocal();
          final db = (b.data()['scheduled_for_date'] as Timestamp)
              .toDate()
              .toLocal();
          final dayA = DateTime(da.year, da.month, da.day);
          final dayB = DateTime(db.year, db.month, db.day);
          final byDay = dayA.compareTo(dayB);
          if (byDay != 0) return byDay;
          final pa = a.data()['transaction_type'] == 'income' ? 0 : 1;
          final pb = b.data()['transaction_type'] == 'income' ? 0 : 1;
          return pa.compareTo(pb);
        });

      for (final doc in docs) {
        final data = doc.data();
        final scheduledForDate = (data['scheduled_for_date'] as Timestamp).toDate();
        // ✅ FIX: Convert to local timezone before extracting date
        final localScheduledDate = scheduledForDate.toLocal();
        final scheduledDay = DateTime(
          localScheduledDate.year,
          localScheduledDate.month,
          localScheduledDate.day,
        );

        if (scheduledDay.isBefore(today) || scheduledDay.isAtSameMomentAs(today)) {
          final success = await executeScheduledTransaction(userId, doc.id);
          if (success) {
            executed.add({
              'uuid': doc.id,
              'type': data['transaction_type'],
              'amount': (data['amount'] as num).toDouble(),
              'account_id': data['account_id'],
              'category_id': data['category_id'],
            });
          }
        }
      }

      if (executed.isNotEmpty) {
        DebugConfig.print(
          '✅ Executed ${executed.length} scheduled transactions',
        );
      }

      return executed;
    } catch (e) {
      DebugConfig.print('🔴 Error checking pending transactions: $e');
      return [];
    }
  }

  /// Αν ο λογαριασμός χρέωσης ΔΕΝ καλύπτει το ποσό επιστρέφει στοιχεία, αλλιώς null
  Future<Map<String, dynamic>?> _findInsufficientDebit(
      String userId,
      Map<String, dynamic> data,
      ) async {
    final transactionType = data['transaction_type'] as String;
    if (transactionType == 'income') return null;

    String debitAccountId;
    double debitAmount;

    if (transactionType == 'transfer') {
      final transferGroupId = data['transfer_group_id'] as String?;
      if (transferGroupId == null) return null;

      final legs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('transfer_group_id', isEqualTo: transferGroupId)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? debitLeg;
      for (final leg in legs.docs) {
        if ((leg.data()['amount'] as num).toDouble() < 0) {
          debitLeg = leg;
          break;
        }
      }
      if (debitLeg == null) return null;

      debitAccountId = debitLeg.data()['account_id'] as String;
      debitAmount = (debitLeg.data()['amount'] as num).toDouble().abs();
    } else {
      debitAccountId = data['account_id'] as String;
      debitAmount = (data['amount'] as num).toDouble().abs();
    }

    final accDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .doc(debitAccountId)
        .get();
    final balance =
        (accDoc.data()?['current_balance'] as num?)?.toDouble() ?? 0.0;

    if (CurrencyFormatter.covers(balance, debitAmount)) return null;

    return {
      'account_id': debitAccountId,
      'amount': debitAmount,
      'balance': balance,
    };
  }

  /// Σημείωση αποτυχίας εκτέλεσης λόγω ανεπαρκούς υπολοίπου.
  /// Η κίνηση ΜΕΝΕΙ προγραμματισμένη (δεν διαγράφεται, δεν αλλάζει υπόλοιπο)
  /// και περιμένει απόφαση του χρήστη (διαγραφή ή νέα ημερομηνία).
  Future<void> _markExecutionFailed(
      String userId,
      String transactionUuid,
      Map<String, dynamic> data,
      Map<String, dynamic> info,
      ) async {
    try {
      final transactionType = data['transaction_type'] as String;
      final transferGroupId = data['transfer_group_id'] as String?;
      final txCol = _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions');

      final failFields = <String, dynamic>{
        'execution_failed': true,
        'execution_failed_reason': 'insufficient_balance',
        'execution_failed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (transferGroupId != null) {
        final legs = await txCol
            .where('transfer_group_id', isEqualTo: transferGroupId)
            .get();
        final batch = _firestore.batch();
        for (final leg in legs.docs) {
          batch.update(leg.reference, failFields);
        }
        await batch.commit();
      } else {
        await txCol.doc(transactionUuid).update(failFields);
      }

      // Ειδοποίηση συστήματος
      try {
        final scheduledDate =
        (data['scheduled_for_date'] as Timestamp).toDate().toLocal();
        final dateStr =
            '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}';
        final typeLabel =
        transactionType == 'transfer' ? 'Η μεταφορά' : 'Το έξοδο';
        final accountName = await getAccountName(
          userId,
          info['account_id'] as String,
        );

        await NotificationsService().showImmediateNotification(
          title: 'Προγραμματισμένη Κίνηση',
          message:
          '$typeLabel €${(info['amount'] as double).toStringAsFixed(2)} '
              'ημερομηνίας $dateStr από «$accountName» δεν εκτελέστηκε '
              'λόγω ανεπαρκούς υπολοίπου.',
        );
      } catch (e) {
        DebugConfig.print('⚠️ Could not send failure notification: $e');
      }

      DebugConfig.print(
        '⛔ Scheduled transaction NOT executed (insufficient balance): $transactionUuid',
      );
    } catch (e) {
      DebugConfig.print('🔴 Error marking execution failure: $e');
    }
  }

  /// Κινήσεις που απέτυχαν λόγω ανεπαρκούς υπολοίπου και περιμένουν απόφαση χρήστη.
  /// Για μεταφορά επιστρέφεται μία εγγραφή (το σκέλος χρέωσης).
  Future<List<Map<String, dynamic>>> getFailedScheduledTransactions(
      String userId,
      ) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .where('execution_failed', isEqualTo: true)
        .where('is_executed', isEqualTo: false)
        .where('deleted', isEqualTo: false)
        .get();

    final result = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final type = data['transaction_type'] as String? ?? 'expense';
      final amount = (data['amount'] as num).toDouble();

      // Μεταφορά: μόνο το σκέλος χρέωσης (αρνητικό ποσό)
      if (type == 'transfer' && amount > 0) continue;

      result.add({
        'uuid': doc.id,
        'type': type,
        'amount': amount.abs(),
        'date': (data['scheduled_for_date'] as Timestamp).toDate().toLocal(),
        'account_id': data['account_id'] as String,
      });
    }

    result.sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );
    return result;
  }

  /// Αλλαγή ημερομηνίας εκτέλεσης αποτυχημένης κίνησης (και των δύο σκελών αν είναι μεταφορά)
  Future<void> rescheduleFailedTransaction(
      String userId,
      String transactionUuid,
      DateTime newDate,
      ) async {
    final txCol = _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions');

    final doc = await txCol.doc(transactionUuid).get();
    if (!doc.exists) throw Exception('Transaction not found');

    final transferGroupId = doc.data()!['transfer_group_id'] as String?;
    final fields = <String, dynamic>{
      'date': Timestamp.fromDate(newDate),
      'scheduled_for_date': Timestamp.fromDate(newDate),
      'execution_failed': false,
      'execution_failed_reason': null,
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (transferGroupId != null) {
      final legs = await txCol
          .where('transfer_group_id', isEqualTo: transferGroupId)
          .get();
      final batch = _firestore.batch();
      for (final leg in legs.docs) {
        batch.update(leg.reference, fields);
      }
      await batch.commit();
    } else {
      await txCol.doc(transactionUuid).update(fields);
    }

    DebugConfig.print('✅ Failed transaction rescheduled: $transactionUuid');
  }

  /// Ακύρωση προγραμματισμένης κίνησης (soft delete)
  Future<void> cancelScheduledTransaction(
    String userId,
    String transactionUuid,
  ) async {
    try {
      final txRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transactionUuid);

      final txDoc = await txRef.get();

      if (!txDoc.exists) {
        throw Exception('Transaction not found');
      }

      final data = txDoc.data()!;
      final transferGroupId = data['transfer_group_id'] as String?;

      if (transferGroupId != null) {
        // Cancel all legs of transfer
        final transferLegs = await _firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .where('transfer_group_id', isEqualTo: transferGroupId)
            .get();

        final batch = _firestore.batch();

        for (final leg in transferLegs.docs) {
          batch.update(leg.reference, {
            'deleted': true,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      } else {
        // Cancel single transaction
        await txRef.update({
          'deleted': true,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      DebugConfig.print('✅ Scheduled transaction cancelled: $transactionUuid');
    } catch (e) {
      DebugConfig.print('🔴 Error cancelling scheduled transaction: $e');
      rethrow;
    }
  }

  /// Λήψη προγραμματισμένων κινήσεων
  Stream<List<Map<String, dynamic>>> getScheduledTransactions(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .where('is_scheduled', isEqualTo: true)
        .where('is_executed', isEqualTo: false)
        .where('deleted', isEqualTo: false)
        .orderBy('scheduled_for_date', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['uuid'] = doc.id;
            return data;
          }).toList();
        });
  }

  /// Helper: Get or create Transfer category
  Future<String> _getOrCreateTransferCategory(String userId) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .where('type', isEqualTo: 'transfer')
          .where('is_system', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }

      // Create transfer category
      final categoryUuid = _uuid.v4();
      final now = DateTime.now();

      await _firestore
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

      DebugConfig.print('✅ Transfer category created: $categoryUuid');
      return categoryUuid;
    } catch (e) {
      DebugConfig.print('🔴 Error getting/creating transfer category: $e');
      rethrow;
    }
  }

  /// Helper: Λήψη account name
  Future<String> getAccountName(String userId, String accountUuid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc(accountUuid)
          .get();

      if (doc.exists) {
        return doc.data()!['name'] as String;
      }
      return 'Άγνωστος Λογαριασμός';
    } catch (e) {
      return 'Άγνωστος Λογαριασμός';
    }
  }

  /// Helper: Λήψη category name
  Future<String> getCategoryName(String userId, String categoryUuid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(categoryUuid)
          .get();

      if (doc.exists) {
        return doc.data()!['name'] as String;
      }
      return 'Άγνωστη Κατηγορία';
    } catch (e) {
      return 'Άγνωστη Κατηγορία';
    }
  }

  /// ✅ ΝΕΟΣ: Helper: Λήψη subcategory name
  Future<String> getSubcategoryName(
    String userId,
    String subcategoryUuid,
  ) async {
    try {
      // Πρέπει να βρούμε το subcategory μέσα στις κατηγορίες
      final categoriesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .get();

      for (final categoryDoc in categoriesSnapshot.docs) {
        final subcategoryDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('categories')
            .doc(categoryDoc.id)
            .collection('subcategories')
            .doc(subcategoryUuid)
            .get();

        if (subcategoryDoc.exists) {
          return subcategoryDoc.data()!['name'] as String;
        }
      }

      return 'Άγνωστη Υποκατηγορία';
    } catch (e) {
      DebugConfig.print('❌ Error getting subcategory name: $e');
      return 'Άγνωστη Υποκατηγορία';
    }
  }
}
