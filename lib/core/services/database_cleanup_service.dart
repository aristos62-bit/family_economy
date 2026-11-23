// ============================================================
// FILE: database_cleanup_service.dart
// Path: lib/core/services/database_cleanup_service.dart
// Ρόλος: Καθαρισμός παλιών/αχρήστων δεδομένων από Firestore.
// ✅ Νέο batch ανά chunk (E34 — ποτέ επανάχρηση μετά το commit)
// ✅ Μόνο single-field equality reads + client-side φίλτρο ηλικίας (0 indexes)
// ✅ Nested υποκατηγορίες (categories/{id}/subcategories) + cascade
// ✅ Συνέχεια μετά από μερική αποτυχία (3-κατάστατο αποτέλεσμα)
// ✅ Όλα τα μηνύματα/κανόνες στο database_cleanup_policy.dart
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:family_economy/core/utils/database_cleanup_policy.dart';
import 'package:family_economy/core/utils/debug_config.dart';

// ─────────────────────────────────────────────
// Cleanup Report Model
// ─────────────────────────────────────────────
class CleanupReport {
  const CleanupReport({
    required this.notificationsDeleted,
    required this.budgetsDeleted,
    required this.transactionsDeleted,
    required this.categoriesDeleted,
    required this.subcategoriesDeleted,
    required this.oilTankDeleted,
    required this.duration,
    required this.timestamp,
    required this.outcome,
    this.failures = const <String>[],
  });

  final int notificationsDeleted;
  final int budgetsDeleted;
  final int transactionsDeleted;
  final int categoriesDeleted;
  final int subcategoriesDeleted;
  final int oilTankDeleted;
  final Duration duration;
  final DateTime timestamp;
  final CleanupOutcome outcome;

  /// Ονόματα εργασιών που απέτυχαν (για το μερικό αποτέλεσμα).
  final List<String> failures;

  int get totalDeleted =>
      notificationsDeleted +
      budgetsDeleted +
      transactionsDeleted +
      categoriesDeleted +
      subcategoriesDeleted +
      oilTankDeleted;

  bool get hasDeleted => totalDeleted > 0;

  bool get success => outcome == CleanupOutcome.complete;

  bool get isPartial => outcome == CleanupOutcome.partial;
}

// ─────────────────────────────────────────────
// Cleanup Options
// ─────────────────────────────────────────────
class CleanupOptions {
  const CleanupOptions({
    this.cleanNotifications = true,
    this.cleanBudgets = true,
    this.cleanTransactions = true,
    this.cleanCategories = false,
    this.cleanOilTank = false,
    this.notificationsDaysOld = 90,
    this.budgetsDaysOld = 365,
    this.transactionsDaysOld = 30,
    this.categoriesDaysOld = 180,
  });

  final bool cleanNotifications;
  final bool cleanBudgets;
  final bool cleanTransactions;

  /// Κατηγορίες **και** οι υποκατηγορίες τους (μία εργασία).
  final bool cleanCategories;

  final bool cleanOilTank;

  final int notificationsDaysOld;
  final int budgetsDaysOld;
  final int transactionsDaysOld;
  final int categoriesDaysOld;

  bool get hasSelection =>
      cleanNotifications ||
      cleanBudgets ||
      cleanTransactions ||
      cleanCategories ||
      cleanOilTank;
}

// ─────────────────────────────────────────────
// Preview Report (πόσα θα διαγραφούν)
// ─────────────────────────────────────────────
class CleanupPreview {
  const CleanupPreview({
    required this.notificationsCount,
    required this.budgetsCount,
    required this.transactionsCount,
    required this.categoriesCount,
    required this.subcategoriesCount,
    required this.oilTankCount,
  });

  final int notificationsCount;
  final int budgetsCount;
  final int transactionsCount;
  final int categoriesCount;
  final int subcategoriesCount;
  final int oilTankCount;

  int get totalCount =>
      notificationsCount +
      budgetsCount +
      transactionsCount +
      categoriesCount +
      subcategoriesCount +
      oilTankCount;

  bool get isEmpty => totalCount == 0;
}

// ═════════════════════════════════════════════
// DATABASE CLEANUP SERVICE
// ═════════════════════════════════════════════
class DatabaseCleanupService {
  DatabaseCleanupService({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _db;

  static const GetOptions _server = GetOptions(source: Source.server);

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(userId).collection(name);

  // ══════════════════════════════════════════════
  // PREVIEW MODE
  // ══════════════════════════════════════════════
  Future<CleanupPreview> previewCleanup(CleanupOptions options) async {
    final now = DateTime.now();
    DebugConfig.print('🔍 Preview cleanup for user: $userId');

    var notifications = 0;
    var budgets = 0;
    var transactions = 0;
    var categories = 0;
    var subcategories = 0;
    var oilTank = 0;

    if (options.cleanNotifications) {
      notifications =
          (await _oldNotificationRefs(now, options.notificationsDaysOld))
              .length;
    }
    if (options.cleanBudgets) {
      budgets = (await _oldBudgetRefs(now, options.budgetsDaysOld)).length;
    }
    if (options.cleanTransactions) {
      transactions =
          (await _oldTransactionRefs(now, options.transactionsDaysOld)).length;
    }
    if (options.cleanCategories) {
      final plan = await _collectCategoryDeletions(
        now,
        options.categoriesDaysOld,
      );
      categories = plan.categories;
      subcategories = plan.subcategories;
    }
    if (options.cleanOilTank) {
      oilTank = await _countOilTankData();
    }

    return CleanupPreview(
      notificationsCount: notifications,
      budgetsCount: budgets,
      transactionsCount: transactions,
      categoriesCount: categories,
      subcategoriesCount: subcategories,
      oilTankCount: oilTank,
    );
  }

  // ══════════════════════════════════════════════
  // FULL CLEANUP
  // ══════════════════════════════════════════════
  Future<CleanupReport> performCleanup(CleanupOptions options) async {
    final startTime = DateTime.now();
    final now = DateTime.now();
    DebugConfig.print('🗑️ Starting cleanup for user: $userId');

    var notifications = 0;
    var budgets = 0;
    var transactions = 0;
    var categories = 0;
    var subcategories = 0;
    var oilTank = 0;
    final failures = <String>[];

    if (!options.hasSelection) {
      return CleanupReport(
        notificationsDeleted: 0,
        budgetsDeleted: 0,
        transactionsDeleted: 0,
        categoriesDeleted: 0,
        subcategoriesDeleted: 0,
        oilTankDeleted: 0,
        duration: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
        outcome: CleanupOutcome.cancelled,
      );
    }

    Future<void> run(
      String label,
      Future<_TaskResult> Function() task,
      void Function(int) assign,
    ) async {
      try {
        final result = await task();
        assign(result.committed);
        if (result.error != null) {
          failures.add(label);
          DebugConfig.print('🔴 $label cleanup failed: ${result.error}');
        } else {
          DebugConfig.print('✅ $label cleaned: ${result.committed}');
        }
      } catch (error) {
        failures.add(label);
        DebugConfig.print('🔴 $label cleanup failed: $error');
      }
    }

    if (options.cleanNotifications) {
      await run(
        'Υπενθυμίσεις',
        () async => _deleteRefs(
          await _oldNotificationRefs(now, options.notificationsDaysOld),
        ),
        (v) => notifications = v,
      );
    }

    if (options.cleanBudgets) {
      await run(
        'Προϋπολογισμοί',
        () async => _deleteRefs(
          await _oldBudgetRefs(now, options.budgetsDaysOld),
        ),
        (v) => budgets = v,
      );
    }

    if (options.cleanTransactions) {
      await run(
        'Συναλλαγές',
        () async => _deleteRefs(
          await _oldTransactionRefs(now, options.transactionsDaysOld),
        ),
        (v) => transactions = v,
      );
    }

    if (options.cleanCategories) {
      await run(
        'Κατηγορίες',
        () async {
          final plan = await _collectCategoryDeletions(
            now,
            options.categoriesDaysOld,
          );
          final result = await _deleteRefs(plan.refs);

          // Μετράμε μόνο ό,τι έχει πραγματικά committed.
          final applied = plan.kinds.take(result.committed);
          categories = applied.where((kind) => kind == _WriteKind.category).length;
          subcategories = applied
              .where((kind) => kind == _WriteKind.subcategory)
              .length;
          return result;
        },
        (_) {},
      );
    }

    if (options.cleanOilTank) {
      await run(
        'Δεξαμενή Πετρελαίου',
        _cleanOilTank,
        (v) => oilTank = v,
      );
    }

    return CleanupReport(
      notificationsDeleted: notifications,
      budgetsDeleted: budgets,
      transactionsDeleted: transactions,
      categoriesDeleted: categories,
      subcategoriesDeleted: subcategories,
      oilTankDeleted: oilTank,
      duration: DateTime.now().difference(startTime),
      timestamp: DateTime.now(),
      outcome: failures.isEmpty
          ? CleanupOutcome.complete
          : CleanupOutcome.partial,
      failures: List<String>.unmodifiable(failures),
    );
  }

  // ══════════════════════════════════════════════
  // CHUNKED DELETE (E34)
  // ══════════════════════════════════════════════
  /// Διαγράφει σε chunks ≤499 με **νέο** batch ανά chunk.
  /// Δεν πετάει: επιστρέφει ό,τι έχει ήδη committed + το σφάλμα.
  Future<_TaskResult> _deleteRefs(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    var deleted = 0;
    for (final chunk in CleanupPolicy.chunk(refs)) {
      try {
        final batch = _db.batch();
        for (final ref in chunk) {
          batch.delete(ref);
        }
        await batch.commit();
        deleted += chunk.length;
      } catch (error) {
        return _TaskResult(committed: deleted, error: error);
      }
    }
    return _TaskResult(committed: deleted);
  }

  // ══════════════════════════════════════════════
  // NOTIFICATIONS
  // ══════════════════════════════════════════════
  Future<List<DocumentReference<Map<String, dynamic>>>> _oldNotificationRefs(
    DateTime now,
    int daysOld,
  ) async {
    // Χωρίς where: πιάνει και legacy docs χωρίς πεδίο `deleted`.
    final snapshot = await _col('notifications').get(_server);
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    for (final doc in snapshot.docs) {
      if (CleanupPolicy.shouldDeleteNotification(doc.data(), now, daysOld)) {
        refs.add(doc.reference);
      }
    }
    return refs;
  }

  // ══════════════════════════════════════════════
  // BUDGETS
  // ══════════════════════════════════════════════
  Future<List<DocumentReference<Map<String, dynamic>>>> _oldBudgetRefs(
    DateTime now,
    int daysOld,
  ) async {
    final snapshot = await _col('budgets').get(_server);
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    for (final doc in snapshot.docs) {
      if (CleanupPolicy.shouldDeleteBudget(doc.data(), now, daysOld)) {
        refs.add(doc.reference);
      }
    }
    return refs;
  }

  // ══════════════════════════════════════════════
  // TRANSACTIONS
  // ══════════════════════════════════════════════
  Future<List<DocumentReference<Map<String, dynamic>>>> _oldTransactionRefs(
    DateTime now,
    int daysOld,
  ) async {
    final cutoffDate = CleanupPolicy.cutoff(now, daysOld);
    final snapshot = await _col(
      'transactions',
    ).where('deleted', isEqualTo: true).get(_server);

    final refs = <DocumentReference<Map<String, dynamic>>>[];
    for (final doc in snapshot.docs) {
      if (CleanupPolicy.shouldDeleteAged(doc.data(), cutoffDate)) {
        refs.add(doc.reference);
      }
    }
    return refs;
  }

  // ══════════════════════════════════════════════
  // CATEGORIES + SUBCATEGORIES (nested, με cascade)
  // ══════════════════════════════════════════════
  Future<_CategoryDeletions> _collectCategoryDeletions(
    DateTime now,
    int daysOld,
  ) async {
    final cutoffDate = CleanupPolicy.cutoff(now, daysOld);
    final categoriesSnap = await _col('categories').get(_server);

    final refs = <DocumentReference<Map<String, dynamic>>>[];
    final kinds = <_WriteKind>[];
    var categories = 0;
    var subcategories = 0;

    for (final category in categoriesSnap.docs) {
      final data = category.data();
      final categoryIsOldDeleted =
          data['deleted'] == true &&
          CleanupPolicy.shouldDeleteAged(data, cutoffDate);

      final subsSnap = await category.reference
          .collection('subcategories')
          .get(_server);

      for (final sub in subsSnap.docs) {
        final subData = sub.data();
        final deleteSub =
            categoryIsOldDeleted ||
            (subData['deleted'] == true &&
                CleanupPolicy.shouldDeleteAged(subData, cutoffDate));
        if (deleteSub) {
          // Οι υποκατηγορίες μπαίνουν **πριν** την κατηγορία.
          refs.add(sub.reference);
          kinds.add(_WriteKind.subcategory);
          subcategories++;
        }
      }

      if (categoryIsOldDeleted) {
        refs.add(category.reference);
        kinds.add(_WriteKind.category);
        categories++;
      }
    }

    return _CategoryDeletions(
      refs: refs,
      kinds: kinds,
      categories: categories,
      subcategories: subcategories,
    );
  }

  // ══════════════════════════════════════════════
  // OIL TANK (πλήρης επαναφορά)
  // ══════════════════════════════════════════════
  DocumentReference<Map<String, dynamic>> get _oilTankRef =>
      _col('settings').doc('oil_tank');

  Future<int> _countOilTankData() async {
    final purchases = await _col('oil_purchases').get(_server);
    final settings = await _oilTankRef.get(_server);
    return purchases.docs.length + (settings.exists ? 1 : 0);
  }

  Future<_TaskResult> _cleanOilTank() async {
    final purchases = await _col('oil_purchases').get(_server);
    final settings = await _oilTankRef.get(_server);

    final first = await _deleteRefs(
      purchases.docs.map((doc) => doc.reference).toList(growable: false),
    );
    if (first.error != null || !settings.exists) return first;

    // Ξεχωριστό (νέο) batch — όχι επανάχρηση του προηγούμενου.
    final second = await _deleteRefs(
      <DocumentReference<Map<String, dynamic>>>[_oilTankRef],
    );
    return _TaskResult(
      committed: first.committed + second.committed,
      error: second.error,
    );
  }
}

/// Αποτέλεσμα εργασίας: ό,τι committed + τυχόν σφάλμα (χωρίς exception).
class _TaskResult {
  const _TaskResult({required this.committed, this.error});

  final int committed;
  final Object? error;
}

enum _WriteKind { category, subcategory }

class _CategoryDeletions {
  const _CategoryDeletions({
    required this.refs,
    required this.kinds,
    required this.categories,
    required this.subcategories,
  });

  final List<DocumentReference<Map<String, dynamic>>> refs;

  /// Παράλληλη λίστα με [refs] — τι είναι κάθε write.
  final List<_WriteKind> kinds;
  final int categories;
  final int subcategories;
}
