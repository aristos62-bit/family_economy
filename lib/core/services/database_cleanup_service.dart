// ============================================================
// FILE: database_cleanup_service.dart
// Path: lib/core/services/database_cleanup_service.dart
// Ρόλος: Καθαρισμός παλιών/αχρήστων δεδομένων από Firestore
// ✅ Safe cleanup με preview mode
// ✅ Offline-safe (no hanging)
// ✅ Detailed reporting
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/core/utils/debug_config.dart';

// ─────────────────────────────────────────────
// Cleanup Report Model
// ─────────────────────────────────────────────
class CleanupReport {
  final int notificationsDeleted;
  final int budgetsDeleted;
  final int transactionsDeleted;
  final int categoriesDeleted;
  final int subcategoriesDeleted;
  final int oilTankDeleted;
  final Duration duration;
  final DateTime timestamp;
  final bool success;
  final String? error;

  CleanupReport({
    required this.notificationsDeleted,
    required this.budgetsDeleted,
    required this.transactionsDeleted,
    required this.categoriesDeleted,
    required this.subcategoriesDeleted,
    this.oilTankDeleted = 0,
    required this.duration,
    required this.timestamp,
    this.success = true,
    this.error,
  });

  int get totalDeleted =>
      notificationsDeleted +
          budgetsDeleted +
          transactionsDeleted +
          categoriesDeleted +
          subcategoriesDeleted +
          oilTankDeleted;

  bool get hasDeleted => totalDeleted > 0;
}

// ─────────────────────────────────────────────
// Cleanup Options
// ─────────────────────────────────────────────
class CleanupOptions {
  final bool cleanNotifications;
  final bool cleanBudgets;
  final bool cleanTransactions;
  final bool cleanCategories;
  final bool cleanSubcategories;
  final bool cleanOilTank;

  final int notificationsDaysOld;
  final int budgetsDaysOld;
  final int transactionsDaysOld;
  final int categoriesDaysOld;

  const CleanupOptions({
    this.cleanNotifications = true,
    this.cleanBudgets = true,
    this.cleanTransactions = true,
    this.cleanCategories = false,
    this.cleanSubcategories = false,
    this.cleanOilTank = false,
    this.notificationsDaysOld = 90,
    this.budgetsDaysOld = 365,
    this.transactionsDaysOld = 30,
    this.categoriesDaysOld = 180,
  });
}

// ─────────────────────────────────────────────
// Preview Report (πόσα θα διαγραφούν)
// ─────────────────────────────────────────────
class CleanupPreview {
  final int notificationsCount;
  final int budgetsCount;
  final int transactionsCount;
  final int categoriesCount;
  final int subcategoriesCount;
  final int oilTankCount;

  CleanupPreview({
    required this.notificationsCount,
    required this.budgetsCount,
    required this.transactionsCount,
    required this.categoriesCount,
    required this.subcategoriesCount,
    this.oilTankCount = 0,
  });

  int get totalCount =>
      notificationsCount +
          budgetsCount +
          transactionsCount +
          categoriesCount +
          subcategoriesCount +
          oilTankCount;
}

// ═════════════════════════════════════════════
// DATABASE CLEANUP SERVICE
// ═════════════════════════════════════════════
class DatabaseCleanupService {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DatabaseCleanupService({required this.userId});

  // ══════════════════════════════════════════════
  // PREVIEW MODE
  // ══════════════════════════════════════════════
  Future<CleanupPreview> previewCleanup(CleanupOptions options) async {
    DebugConfig.print('🔍 Preview cleanup for user: $userId');

    try {
      final results = await Future.wait([
        if (options.cleanNotifications) _countOldNotifications(options.notificationsDaysOld) else Future.value(0),
        if (options.cleanBudgets) _countOldBudgets(options.budgetsDaysOld) else Future.value(0),
        if (options.cleanTransactions) _countOldTransactions(options.transactionsDaysOld) else Future.value(0),
        if (options.cleanCategories) _countOldCategories(options.categoriesDaysOld) else Future.value(0),
        if (options.cleanSubcategories) _countOldSubcategories(options.categoriesDaysOld) else Future.value(0),
        if (options.cleanOilTank) _countOilTankData() else Future.value(0),
      ]);

      return CleanupPreview(
        notificationsCount: results.isNotEmpty ? results[0] : 0,
        budgetsCount: results.length > 1 ? results[1] : 0,
        transactionsCount: results.length > 2 ? results[2] : 0,
        categoriesCount: results.length > 3 ? results[3] : 0,
        subcategoriesCount: results.length > 4 ? results[4] : 0,
        oilTankCount: results.length > 5 ? results[5] : 0,
      );
    } catch (e) {
      DebugConfig.print('🔴 Preview error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════
  // FULL CLEANUP
  // ══════════════════════════════════════════════
  Future<CleanupReport> performCleanup(CleanupOptions options) async {
    final startTime = DateTime.now();
    DebugConfig.print('🗑️ Starting cleanup for user: $userId');

    int notifDeleted = 0;
    int budgetsDeleted = 0;
    int transactionsDeleted = 0;
    int categoriesDeleted = 0;
    int subcategoriesDeleted = 0;
    int oilTankDeleted = 0;

    try {
      // 1. Clean Notifications
      if (options.cleanNotifications) {
        notifDeleted = await _cleanOldNotifications(options.notificationsDaysOld);
        DebugConfig.print('✅ Notifications cleaned: $notifDeleted');
      }

      // 2. Clean Budgets
      if (options.cleanBudgets) {
        budgetsDeleted = await _cleanOldBudgets(options.budgetsDaysOld);
        DebugConfig.print('✅ Budgets cleaned: $budgetsDeleted');
      }

      // 3. Clean Transactions
      if (options.cleanTransactions) {
        transactionsDeleted = await _cleanOldTransactions(options.transactionsDaysOld);
        DebugConfig.print('✅ Transactions cleaned: $transactionsDeleted');
      }

      // 4. Clean Categories (επικίνδυνο)
      if (options.cleanCategories) {
        categoriesDeleted = await _cleanOldCategories(options.categoriesDaysOld);
        DebugConfig.print('✅ Categories cleaned: $categoriesDeleted');
      }

      // 5. Clean Subcategories
      if (options.cleanSubcategories) {
        subcategoriesDeleted = await _cleanOldSubcategories(options.categoriesDaysOld);
        DebugConfig.print('✅ Subcategories cleaned: $subcategoriesDeleted');
      }

      // 6. Clean Oil Tank (πλήρης επαναφορά)
      if (options.cleanOilTank) {
        oilTankDeleted = await _cleanOilTankData();
        DebugConfig.print('✅ Oil tank cleaned: $oilTankDeleted');
      }

      final duration = DateTime.now().difference(startTime);

      return CleanupReport(
        notificationsDeleted: notifDeleted,
        budgetsDeleted: budgetsDeleted,
        transactionsDeleted: transactionsDeleted,
        categoriesDeleted: categoriesDeleted,
        subcategoriesDeleted: subcategoriesDeleted,
        oilTankDeleted: oilTankDeleted,
        duration: duration,
        timestamp: DateTime.now(),
        success: true,
      );
    } catch (e) {
      DebugConfig.print('🔴 Cleanup error: $e');
      final duration = DateTime.now().difference(startTime);

      return CleanupReport(
        notificationsDeleted: notifDeleted,
        budgetsDeleted: budgetsDeleted,
        transactionsDeleted: transactionsDeleted,
        categoriesDeleted: categoriesDeleted,
        subcategoriesDeleted: subcategoriesDeleted,
        oilTankDeleted: oilTankDeleted,
        duration: duration,
        timestamp: DateTime.now(),
        success: false,
        error: e.toString(),
      );
    }
  }

  // ══════════════════════════════════════════════
  // OIL TANK CLEANUP (πλήρης επαναφορά)
  // ══════════════════════════════════════════════

  Future<int> _countOilTankData() async {
    try {
      // Μετράμε όλες τις αγορές πετρελαίου
      final purchasesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('oil_purchases')
          .get(const GetOptions(source: Source.server));
      final purchasesCount = purchasesSnapshot.docs.length;

      // Αν υπάρχει έγγραφο ρυθμίσεων, το μετράμε ως 1
      final settingsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('oil_tank')
          .get(const GetOptions(source: Source.server));
      final settingsCount = settingsDoc.exists ? 1 : 0;

      return purchasesCount + settingsCount;
    } catch (e) {
      DebugConfig.print('🔴 Count oil tank error: $e');
      return 0;
    }
  }

  Future<int> _cleanOilTankData() async {
    int deleted = 0;
    final batch = _firestore.batch();

    try {
      // 1. Διαγραφή όλων των αγορών
      final purchasesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('oil_purchases')
          .get(const GetOptions(source: Source.server));
      for (final doc in purchasesSnapshot.docs) {
        batch.delete(doc.reference);
        deleted++;
        if (deleted % 500 == 0) {
          await batch.commit();
        }
      }

      // 2. Διαγραφή του εγγράφου ρυθμίσεων (oil_tank)
      final settingsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('oil_tank');
      batch.delete(settingsRef);
      deleted++;

      await batch.commit();
      return deleted;
    } catch (e) {
      DebugConfig.print('🔴 Clean oil tank error: $e');
      return deleted;
    }
  }

  // ══════════════════════════════════════════════
  // NOTIFICATIONS CLEANUP
  // ══════════════════════════════════════════════

  Future<int> _countOldNotifications(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('deleted', isEqualTo: false)
          .get(const GetOptions(source: Source.server));

      int count = 0;
      for (final doc in snapshot.docs) {
        if (_shouldDeleteNotification(doc.data(), cutoffDate)) {
          count++;
        }
      }

      return count;
    } catch (e) {
      DebugConfig.print('🔴 Count notifications error: $e');
      return 0;
    }
  }

  Future<int> _cleanOldNotifications(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('deleted', isEqualTo: false)
          .get(const GetOptions(source: Source.server));

      int deleted = 0;
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        if (_shouldDeleteNotification(doc.data(), cutoffDate)) {
          batch.delete(doc.reference);
          deleted++;
          if (deleted % 500 == 0) {
            await batch.commit();
          }
        }
      }

      if (deleted % 500 != 0) {
        await batch.commit();
      }

      return deleted;
    } catch (e) {
      DebugConfig.print('🔴 Clean notifications error: $e');
      return 0;
    }
  }

  bool _shouldDeleteNotification(Map<String, dynamic> data, DateTime cutoffDate) {
    final deliveredAt = _parseTimestamp(data['delivered_at']);
    final readAt = _parseTimestamp(data['read_at']);
    final dismissedAt = _parseTimestamp(data['dismissed_at']);
    final scheduledFor = _parseTimestamp(data['scheduled_for']);
    final recurringEndAt = _parseTimestamp(data['recurring_end_at']);
    final isRecurring = data['is_recurring'] as bool? ?? false;

    // 1. Delivered + Read + Old
    if (deliveredAt != null && readAt != null && readAt.isBefore(cutoffDate)) return true;
    // 2. Dismissed + Old
    if (dismissedAt != null && dismissedAt.isBefore(cutoffDate)) return true;
    // 3. Delivered + Old
    if (deliveredAt != null && deliveredAt.isBefore(cutoffDate)) return true;
    // 4. Expired recurring
    if (isRecurring && recurringEndAt != null && recurringEndAt.isBefore(DateTime.now())) return true;
    // 5. Scheduled in past, never delivered
    if (!isRecurring && scheduledFor != null && scheduledFor.isBefore(cutoffDate) && deliveredAt == null) return true;
    return false;
  }

  // ══════════════════════════════════════════════
  // BUDGETS CLEANUP
  // ══════════════════════════════════════════════

  Future<int> _countOldBudgets(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .where('deleted', isEqualTo: false)
          .get(const GetOptions(source: Source.server));

      int count = 0;
      for (final doc in snapshot.docs) {
        if (_shouldDeleteBudget(doc.data(), cutoffDate)) count++;
      }
      return count;
    } catch (e) {
      DebugConfig.print('🔴 Count budgets error: $e');
      return 0;
    }
  }

  Future<int> _cleanOldBudgets(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .where('deleted', isEqualTo: false)
          .get(const GetOptions(source: Source.server));

      int deleted = 0;
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        if (_shouldDeleteBudget(doc.data(), cutoffDate)) {
          batch.delete(doc.reference);
          deleted++;
          if (deleted % 500 == 0) await batch.commit();
        }
      }
      if (deleted % 500 != 0) await batch.commit();
      return deleted;
    } catch (e) {
      DebugConfig.print('🔴 Clean budgets error: $e');
      return 0;
    }
  }

  bool _shouldDeleteBudget(Map<String, dynamic> data, DateTime cutoffDate) {
    final endDate = _parseDate(data['end_date']);
    final isActive = data['is_active'] as bool? ?? true;
    if (endDate != null && endDate.isBefore(cutoffDate)) return true;
    if (!isActive && endDate != null && endDate.isBefore(DateTime.now())) return true;
    return false;
  }

  // ══════════════════════════════════════════════
  // TRANSACTIONS CLEANUP
  // ══════════════════════════════════════════════

  Future<int> _countOldTransactions(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('deleted', isEqualTo: true)
          .get(const GetOptions(source: Source.server));

      int count = 0;
      for (final doc in snapshot.docs) {
        final updatedAt = _parseTimestamp(doc.data()['updated_at']);
        if (updatedAt != null && updatedAt.isBefore(cutoffDate)) count++;
      }
      return count;
    } catch (e) {
      DebugConfig.print('🔴 Count transactions error: $e');
      return 0;
    }
  }

  Future<int> _cleanOldTransactions(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('deleted', isEqualTo: true)
          .get(const GetOptions(source: Source.server));

      int deleted = 0;
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        final updatedAt = _parseTimestamp(doc.data()['updated_at']);
        if (updatedAt != null && updatedAt.isBefore(cutoffDate)) {
          batch.delete(doc.reference);
          deleted++;
          if (deleted % 500 == 0) await batch.commit();
        }
      }
      if (deleted % 500 != 0) await batch.commit();
      return deleted;
    } catch (e) {
      DebugConfig.print('🔴 Clean transactions error: $e');
      return 0;
    }
  }

  // ══════════════════════════════════════════════
  // CATEGORIES CLEANUP (ΕΠΙΚΙΝΔΥΝΟ!)
  // ══════════════════════════════════════════════

  Future<int> _countOldCategories(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .where('deleted', isEqualTo: true)
          .get(const GetOptions(source: Source.server));

      int count = 0;
      for (final doc in snapshot.docs) {
        final updatedAt = _parseTimestamp(doc.data()['updated_at']);
        if (updatedAt != null && updatedAt.isBefore(cutoffDate)) count++;
      }
      return count;
    } catch (e) {
      DebugConfig.print('🔴 Count categories error: $e');
      return 0;
    }
  }

  Future<int> _cleanOldCategories(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .where('deleted', isEqualTo: true)
          .get(const GetOptions(source: Source.server));

      int deleted = 0;
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        final updatedAt = _parseTimestamp(doc.data()['updated_at']);
        if (updatedAt != null && updatedAt.isBefore(cutoffDate)) {
          batch.delete(doc.reference);
          deleted++;
          if (deleted % 500 == 0) await batch.commit();
        }
      }
      if (deleted % 500 != 0) await batch.commit();
      return deleted;
    } catch (e) {
      DebugConfig.print('🔴 Clean categories error: $e');
      return 0;
    }
  }

  // ══════════════════════════════════════════════
  // SUBCATEGORIES CLEANUP
  // ══════════════════════════════════════════════

  Future<int> _countOldSubcategories(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subcategories')
          .where('deleted', isEqualTo: true)
          .get(const GetOptions(source: Source.server));

      int count = 0;
      for (final doc in snapshot.docs) {
        final updatedAt = _parseTimestamp(doc.data()['updated_at']);
        if (updatedAt != null && updatedAt.isBefore(cutoffDate)) count++;
      }
      return count;
    } catch (e) {
      DebugConfig.print('🔴 Count subcategories error: $e');
      return 0;
    }
  }

  Future<int> _cleanOldSubcategories(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subcategories')
          .where('deleted', isEqualTo: true)
          .get(const GetOptions(source: Source.server));

      int deleted = 0;
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        final updatedAt = _parseTimestamp(doc.data()['updated_at']);
        if (updatedAt != null && updatedAt.isBefore(cutoffDate)) {
          batch.delete(doc.reference);
          deleted++;
          if (deleted % 500 == 0) await batch.commit();
        }
      }
      if (deleted % 500 != 0) await batch.commit();
      return deleted;
    } catch (e) {
      DebugConfig.print('🔴 Clean subcategories error: $e');
      return 0;
    }
  }

  // ══════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}