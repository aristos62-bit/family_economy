// ============================================================
// FILE: account_deletion_policy.dart
// Path: lib/core/utils/account_deletion_policy.dart
// Ρόλος: ΕΝΑΣ κανόνας για την πλήρη διαγραφή λογαριασμού (SEC-005).
// - Καθαρό Dart (0 Firebase) → ελέγξιμο με unit tests.
// - Marker «διαγραφή σε εξέλιξη», σειρά συλλογών, chunks ≤499, μηνύματα.
// ============================================================

import 'package:family_economy/core/data/user_doc_policy.dart';
import 'package:family_economy/core/utils/account_delete_guard.dart';

/// Αποτέλεσμα της πλήρους διαγραφής δεδομένων.
enum AccountDeletionOutcome {
  /// Marker + όλες οι συλλογές + root doc ολοκληρώθηκαν.
  complete,

  /// Κάποια συλλογή απέτυχε· το root doc **δεν** διαγράφηκε.
  partial,

  /// Ούτε ο marker δεν γράφτηκε — καμία αλλαγή.
  failed,
}

/// SEC-005: κανόνες, σειρά και μηνύματα της διαγραφής λογαριασμού.
class AccountDeletionPolicy {
  AccountDeletionPolicy._();

  /// Firestore όριο 500 writes/batch — κρατάμε 499 (πρότυπο project).
  static const int maxWritesPerBatch = AccountDeleteGuard.maxWritesPerBatch;

  /// Ανώτατο όριο για κάθε ανάγνωση / batch της διαγραφής.
  static const Duration operationTimeout = Duration(seconds: 20);

  static const String usersCollection = 'users';
  static const String categoriesCollection = 'categories';
  static const String subcategoriesCollection = 'subcategories';

  /// Marker στο root doc: `deleted: true` + `deleted_at`.
  static const String markerField = 'deleted';
  static const String markerTimestampField = 'deleted_at';

  /// Σειρά cascade: φύλλα πρώτα, γονείς μετά.
  ///
  /// Οι υποκατηγορίες της κάθε κατηγορίας διαγράφονται πριν από τις
  /// κατηγορίες (βλ. `AccountDeletionService`). Το `categories` μένει
  /// τελευταίο από τις συλλογές, ώστε το root doc να είναι το τελευταίο
  /// write της όλης ροής.
  static const List<String> collections = <String>[
    'transaction_tags',
    'transaction_splits',
    'attachments',
    'account_snapshots',
    'settings',
    'oil_purchases',
    'tags',
    'accounts',
    'budgets',
    'transactions',
    'notifications',
    categoriesCollection,
  ];

  /// true όταν το user doc έχει σημανθεί για διαγραφή (SEC-005).
  static bool isDeletionPending(Map<String, dynamic>? data) =>
      UserDocPolicy.isDeletionPending(data);

  /// Σπάει λίστα σε chunks ≤ [maxWrites] (πάντα **νέο** batch ανά chunk).
  static List<List<T>> chunk<T>(
    List<T> items, {
    int maxWrites = maxWritesPerBatch,
  }) {
    if (items.isEmpty) return <List<T>>[];
    final size = maxWrites < 1 ? 1 : maxWrites;
    final chunks = <List<T>>[];
    for (var i = 0; i < items.length; i += size) {
      final end = (i + size < items.length) ? i + size : items.length;
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }

  // ============================================================
  // ΜΗΝΥΜΑΤΑ (ένα σημείο αλήθειας για UI + tests)
  // ============================================================

  /// Εκκίνηση με ημιτελή διαγραφή: το `AppStart` δείχνει αυτό το μήνυμα.
  static const String pendingStartupMessage =
      'Η διαγραφή του λογαριασμού δεν ολοκληρώθηκε. '
      'Πατήστε «Αποσύνδεση» και συνδεθείτε ξανά για να τη συνεχίσετε.';

  static const String pendingLoginTitle = 'Εκκρεμεί διαγραφή λογαριασμού';

  static const String pendingLoginMessage =
      'Η διαγραφή του λογαριασμού σας δεν ολοκληρώθηκε σε προηγούμενη '
      'προσπάθεια. Θέλετε να συνεχίσετε τη διαγραφή;';

  static const String pendingCancelMessage =
      'Η διαγραφή δεν ολοκληρώθηκε. Συνδεθείτε ξανά για να τη συνεχίσετε.';

  static const String partialTitle = 'Η διαγραφή ολοκληρώθηκε μερικώς';

  static const String partialMessage =
      'Κάποια δεδομένα δεν διαγράφηκαν. Ο λογαριασμός παραμένει κλειδωμένος '
      'μέχρι να ολοκληρωθεί η διαγραφή.';

  static const String partialFailuresLabel = 'Αποτυχίες';

  static const String retryAction = 'Συνέχισε τη διαγραφή';

  static const String closeAction = 'Κλείσιμο';

  static const String cancelAction = 'Άκυρο';

  static const String deleteAction = 'Διαγραφή';

  static const String failedTitle = 'Αποτυχία διαγραφής';

  static const String failedMessage =
      'Δεν ήταν δυνατή η έναρξη της διαγραφής. Ελέγξτε τη σύνδεση και '
      'δοκιμάστε ξανά.';

  static const String completedMessage =
      '✅ Ο λογαριασμός διαγράφηκε οριστικά.';

  // SEC-005b: τα δεδομένα σβήστηκαν αλλά ο Auth λογαριασμός υπάρχει ακόμη.
  static const String authPendingTitle = 'Η διαγραφή δεν ολοκληρώθηκε';

  static const String authPendingMessage =
      'Τα δεδομένα σας διαγράφηκαν, αλλά ο λογαριασμός σύνδεσης υπάρχει '
      'ακόμη. Ελέγξτε τη σύνδεση και δοκιμάστε ξανά.';

  static const String authPendingClosedMessage =
      'Τα δεδομένα διαγράφηκαν. Συνδεθείτε ξανά για να ολοκληρωθεί η '
      'διαγραφή του λογαριασμού.';

  static const String passwordPromptTitle = 'Επιβεβαίωση ταυτότητας';

  static const String passwordPromptMessage =
      'Για λόγους ασφαλείας, εισάγετε τον κωδικό πρόσβασης του λογαριασμού '
      'σας.';

  static const String passwordLabel = 'Κωδικός πρόσβασης';

  static const String passwordEmptyMessage =
      'Συμπληρώστε τον κωδικό πρόσβασης.';

  static const String runningMessage =
      'Η διαγραφή εκτελείται. Περιμένετε να ολοκληρωθεί.';

  static const String recentLoginMessage =
      'Για λόγους ασφαλείας απαιτείται πρόσφατη σύνδεση. '
      'Συνδεθείτε ξανά και δοκιμάστε ξανά.';

  // SEC-006a: ο server επιβεβαίωσε διαγραφή ενώ η συσκευή ήταν συνδεδεμένη.
  static const String remoteDeletionMessage =
      'Ο λογαριασμός διαγράφηκε σε άλλη συσκευή. '
      'Η συνεδρία έκλεισε για λόγους ασφαλείας.';
}
