// ============================================================
// FILE: deletion_guard_policy.dart
// Path: lib/core/utils/deletion_guard_policy.dart
// Ρόλος: Καθαρή απόφαση για το κλείδωμα συνεδρίας όταν ο λογαριασμός
// διαγράφηκε σε άλλη συσκευή (SEC-006a). 0 Firebase / 0 Flutter.
// ============================================================

/// Τι κάνουμε με ένα snapshot του root user document.
enum DeletionGuardAction {
  /// Snapshot από cache ή δικό μας pending write — δεν είναι απόδειξη.
  ignore,

  /// Ο server επιβεβαίωσε διαγραφή (missing doc ή `deleted: true`).
  lock,
}

/// SEC-006a: ο κανόνας «κλειδώνουμε ή όχι» χωρίς I/O.
///
/// Μόνο **server-confirmed** snapshots μετράνε: το cache-first `E64` δείχνει
/// παλιά κατάσταση και τα pending writes είναι δικές μας εγγραφές.
class DeletionGuardPolicy {
  DeletionGuardPolicy._();

  static DeletionGuardAction decide({
    required bool fromCache,
    required bool hasPendingWrites,
    required bool exists,
    required bool deleted,
  }) {
    if (fromCache || hasPendingWrites) return DeletionGuardAction.ignore;
    if (!exists || deleted) return DeletionGuardAction.lock;
    return DeletionGuardAction.ignore;
  }
}
