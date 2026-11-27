// ============================================================
// FILE: account_deletion_service.dart
// Path: lib/core/services/account_deletion_service.dart
// Ρόλος: Πλήρης διαγραφή των δεδομένων λογαριασμού (SEC-005).
// - Marker πρώτα (resume guard), μετά cascade όλων των συλλογών.
// - Νέο batch ανά chunk ≤499· timeout 20s ανά ανάγνωση/batch.
// - Root doc **μόνο** όταν όλες οι συλλογές ολοκληρωθούν.
// - Δεν πετάει: επιστρέφει complete / partial / failed report.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:family_economy/core/utils/account_deletion_policy.dart';
import 'package:family_economy/core/utils/debug_config.dart';

/// Αποτέλεσμα της πλήρους διαγραφής δεδομένων.
class AccountDeletionReport {
  const AccountDeletionReport({
    required this.outcome,
    required this.totalDeleted,
    required this.failures,
    required this.duration,
    required this.timestamp,
  });

  final AccountDeletionOutcome outcome;
  final int totalDeleted;

  /// Ονόματα συλλογών που απέτυχαν (για το μερικό αποτέλεσμα).
  final List<String> failures;
  final Duration duration;
  final DateTime timestamp;

  bool get isComplete => outcome == AccountDeletionOutcome.complete;

  bool get isPartial => outcome == AccountDeletionOutcome.partial;

  bool get isFailed => outcome == AccountDeletionOutcome.failed;
}

// ═════════════════════════════════════════════
// ACCOUNT DELETION SERVICE
// ═════════════════════════════════════════════
class AccountDeletionService {
  AccountDeletionService({required this.userId, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _db;

  static const GetOptions _server = GetOptions(source: Source.server);

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _db.collection(AccountDeletionPolicy.usersCollection).doc(userId);

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _userRef.collection(name);

  /// Marker → cascade → root doc.
  ///
  /// Αν αποτύχει ο marker, δεν αγγίζεται τίποτα (`failed`).
  /// Αν αποτύχει οποιαδήποτε συλλογή, το root doc μένει (`partial`) και η
  /// επόμενη προσπάθεια συνεχίζει από εκεί (idempotent διαγραφή).
  Future<AccountDeletionReport> deleteAccountData() async {
    final started = DateTime.now();
    final failures = <String>[];
    var totalDeleted = 0;

    // 1) Marker — χωρίς αυτό δεν ξεκινά καμία διαγραφή.
    try {
      await _userRef
          .set(<String, dynamic>{
            AccountDeletionPolicy.markerField: true,
            AccountDeletionPolicy.markerTimestampField:
                FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(AccountDeletionPolicy.operationTimeout);
      DebugConfig.print('🗑️ deletion marker set for uid=$userId');
    } catch (e) {
      DebugConfig.print('🔴 deletion marker failed: $e');
      return AccountDeletionReport(
        outcome: AccountDeletionOutcome.failed,
        totalDeleted: 0,
        failures: const <String>[AccountDeletionPolicy.usersCollection],
        duration: DateTime.now().difference(started),
        timestamp: DateTime.now(),
      );
    }

    // 2) Cascade — κάθε συλλογή ανεξάρτητα, ώστε μία αποτυχία να μη
    // σταματά τις υπόλοιπες.
    for (final name in AccountDeletionPolicy.collections) {
      try {
        final deleted = name == AccountDeletionPolicy.categoriesCollection
            ? await _deleteCategories()
            : await _deleteCollection(name);
        totalDeleted += deleted;
        DebugConfig.print('✅ deletion $name: $deleted');
      } catch (e) {
        failures.add(name);
        DebugConfig.print('🔴 deletion failed for $name: $e');
      }
    }

    if (failures.isNotEmpty) {
      return AccountDeletionReport(
        outcome: AccountDeletionOutcome.partial,
        totalDeleted: totalDeleted,
        failures: List<String>.unmodifiable(failures),
        duration: DateTime.now().difference(started),
        timestamp: DateTime.now(),
      );
    }

    // 3) Root doc — μόνο μετά από πλήρη cascade.
    try {
      await _userRef
          .delete()
          .timeout(AccountDeletionPolicy.operationTimeout);
      DebugConfig.print('✅ deletion root doc for uid=$userId');
    } catch (e) {
      DebugConfig.print('🔴 root user doc delete failed: $e');
      return AccountDeletionReport(
        outcome: AccountDeletionOutcome.partial,
        totalDeleted: totalDeleted,
        failures: const <String>[AccountDeletionPolicy.usersCollection],
        duration: DateTime.now().difference(started),
        timestamp: DateTime.now(),
      );
    }

    return AccountDeletionReport(
      outcome: AccountDeletionOutcome.complete,
      totalDeleted: totalDeleted,
      failures: const <String>[],
      duration: DateTime.now().difference(started),
      timestamp: DateTime.now(),
    );
  }

  // ══════════════════════════════════════════════
  // COLLECTIONS
  // ══════════════════════════════════════════════
  Future<int> _deleteCollection(String name) async {
    final snapshot = await _col(name)
        .get(_server)
        .timeout(AccountDeletionPolicy.operationTimeout);
    return _deleteRefs(
      snapshot.docs.map((doc) => doc.reference).toList(growable: false),
    );
  }

  /// Υποκατηγορίες **πρώτα**, μετά οι κατηγορίες (νέο batch ανά chunk).
  Future<int> _deleteCategories() async {
    final categories = await _col(AccountDeletionPolicy.categoriesCollection)
        .get(_server)
        .timeout(AccountDeletionPolicy.operationTimeout);

    final subcategoryRefs = <DocumentReference<Map<String, dynamic>>>[];
    for (final category in categories.docs) {
      final subs = await category.reference
          .collection(AccountDeletionPolicy.subcategoriesCollection)
          .get(_server)
          .timeout(AccountDeletionPolicy.operationTimeout);
      subcategoryRefs.addAll(subs.docs.map((doc) => doc.reference));
    }

    var deleted = await _deleteRefs(subcategoryRefs);
    deleted += await _deleteRefs(
      categories.docs.map((doc) => doc.reference).toList(growable: false),
    );
    return deleted;
  }

  // ══════════════════════════════════════════════
  // CHUNKED DELETE
  // ══════════════════════════════════════════════
  /// Διαγράφει σε chunks ≤499 με **νέο** batch ανά chunk.
  /// Πετάει στο πρώτο σφάλμα — το `deleteAccountData` το μετατρέπει σε
  /// `partial` report.
  Future<int> _deleteRefs(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    var deleted = 0;
    for (final chunk in AccountDeletionPolicy.chunk(refs)) {
      final batch = _db.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit().timeout(AccountDeletionPolicy.operationTimeout);
      deleted += chunk.length;
    }
    return deleted;
  }
}
