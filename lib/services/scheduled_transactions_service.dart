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

      if (!isScheduled || isExecuted) {
        DebugConfig.print(
          '⚠️ Transaction not scheduled or already executed: $transactionUuid',
        );
        return false;
      }

      final transactionType = data['transaction_type'] as String;
      final amount = (data['amount'] as num).toDouble();
      final accountId = data['account_id'] as String;

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

      for (final doc in query.docs) {
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
