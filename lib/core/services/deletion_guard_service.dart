// ============================================================
// FILE: deletion_guard_service.dart
// Path: lib/core/services/deletion_guard_service.dart
// Ρόλος: Κλείδωμα συνεδρίας όταν ο server επιβεβαιώσει διαγραφή του
// λογαριασμού από άλλη συσκευή (SEC-006a).
// - Listener στο `users/{uid}`· μόνο server-confirmed snapshots.
// - suspend/resume γύρω από τη ροή διαγραφής (ίδια συσκευή).
// - Καμία εγγραφή: μόνο ανάγνωση, signOut και πλοήγηση.
// ============================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:family_economy/core/utils/account_deletion_policy.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/utils/deletion_guard_policy.dart';
import 'package:family_economy/services/notifications_service.dart';

/// SEC-006a: ο guard της δεύτερης συσκευής.
class DeletionGuardService {
  DeletionGuardService._();

  static final DeletionGuardService instance = DeletionGuardService._();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  String? _uid;
  String? _pendingMessage;
  bool _suspended = false;
  bool _locking = false;

  /// Καλείται μετά το signOut — το composition root (`main.dart`) το ορίζει,
  /// ώστε το `core/` να μη γνωρίζει σελίδες.
  Future<void> Function()? onLocked;

  bool get isAttached => _subscription != null;

  /// Ακούει το root doc του [uid]. Idempotent για τον ίδιο χρήστη.
  void attach(String uid) {
    if (uid.isEmpty) return;
    if (_uid == uid && _subscription != null) return;
    unawaited(_cancelListener());
    _uid = uid;
    _suspended = false;
    _locking = false;
    _listen(uid);
  }

  /// Σταματά προσωρινά το lock (η ίδια συσκευή εκτελεί διαγραφή).
  Future<void> suspend() async {
    _suspended = true;
    await _cancelListener();
  }

  /// Επαναφέρει τον listener μετά από αποτυχημένη/μερική διαγραφή.
  void resume() {
    _suspended = false;
    final uid = _uid;
    if (uid != null && _subscription == null) {
      _listen(uid);
    }
  }

  /// Οριστικός τερματισμός (logout, διαγραφή, αποσύνδεση).
  Future<void> detach() async {
    _uid = null;
    _pendingMessage = null;
    await _cancelListener();
  }

  /// Μήνυμα που περιμένει η σελίδα σύνδεσης (μία ανάγνωση).
  String? takeMessage() {
    final message = _pendingMessage;
    _pendingMessage = null;
    return message;
  }

  // ══════════════════════════════════════════════
  // ΕΣΩΤΕΡΙΚΑ
  // ══════════════════════════════════════════════

  void _listen(String uid) {
    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;
    sub = _rootRef(uid).snapshots().listen(
      _onSnapshot,
      onError: (Object error) {
        DebugConfig.print('⚠️ deletion guard listener error: $error');
        _forgetSubscription(sub);
      },
      onDone: () => _forgetSubscription(sub),
    );
    _subscription = sub;
  }

  /// Ο listener έκλεισε (π.χ. permission-denied μετά από logout) — σταματάμε
  /// να τον θεωρούμε ενεργό, ώστε το επόμενο `attach` να ξαναακούσει.
  void _forgetSubscription(
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub,
  ) {
    if (!identical(_subscription, sub)) return;
    _subscription = null;
    unawaited(sub.cancel());
  }

  Future<void> _cancelListener() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  DocumentReference<Map<String, dynamic>> _rootRef(String uid) =>
      FirebaseFirestore.instance
          .collection(AccountDeletionPolicy.usersCollection)
          .doc(uid);

  void _onSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final action = DeletionGuardPolicy.decide(
      fromCache: snapshot.metadata.isFromCache,
      hasPendingWrites: snapshot.metadata.hasPendingWrites,
      exists: snapshot.exists,
      deleted: AccountDeletionPolicy.isDeletionPending(snapshot.data()),
    );
    if (action == DeletionGuardAction.lock) {
      unawaited(_lock());
    }
  }

  Future<void> _lock() async {
    if (_suspended || _locking) return;
    if (FirebaseAuth.instance.currentUser == null) return;

    _locking = true;
    DebugConfig.print('🔒 deletion guard: server confirmed deletion');
    _pendingMessage = AccountDeletionPolicy.remoteDeletionMessage;

    // Πρώτα κόβουμε τον listener, ώστε να μην ξανατρέξει το lock.
    await _cancelListener();

    try {
      final notifications = NotificationsService();
      await notifications.initialize(requestPermissions: false);
      await notifications.cancelAllNotifications();
    } catch (e) {
      DebugConfig.print('⚠️ deletion guard cancelAll failed: $e');
    }

    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      DebugConfig.print('⚠️ deletion guard signOut failed: $e');
    }

    try {
      await onLocked?.call();
    } catch (e) {
      DebugConfig.print('⚠️ deletion guard navigation failed: $e');
    }
  }
}
