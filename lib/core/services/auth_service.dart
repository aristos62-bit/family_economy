import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/core/data/schema.dart';
import 'package:family_economy/core/data/user_doc_policy.dart';
import 'package:family_economy/core/errors/user_message_exception.dart';
import 'package:family_economy/core/services/deletion_guard_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';

/// E64: αποτέλεσμα της εξασφάλισης του user document.
class UserDocumentResult {
  const UserDocumentResult({
    required this.outcome,
    required this.exists,
    this.data,
    this.errorCode,
  });

  final UserDocOutcome outcome;
  final bool exists;
  final Map<String, dynamic>? data;
  final String? errorCode;
}

/// Σφάλμα ροής Auth με κωδικό, πάντα με μήνυμα ασφαλές για εμφάνιση (L11).
///
/// Χρησιμοποιείται από τη διαγραφή λογαριασμού (SEC-005) για να ξεχωρίζει
/// το `requires-recent-login` χωρίς να φτάνει raw σφάλμα στο UI.
class AuthFlowException extends UserMessageException {
  const AuthFlowException(super.message, {required this.code});

  final String code;

  bool get requiresRecentLogin => code == 'requires-recent-login';
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Σύνδεση με email/κωδικό
  Future<User?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw UserMessageException(mapFirebaseError(e));
    }
  }

  /// Εγγραφή χρήστη (register)
  Future<User?> register(String email, String password) async {
    try {
      DebugConfig.print('→ Ξεκινάει register για email: $email');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw UserMessageException(mapFirebaseError(e));
    }
  }

  /// E64: εξασφαλίζει το user document **χωρίς εγγραφή offline**.
  ///
  /// Σειρά: cache → (offline gate) → server → create.
  /// - Cache hit: 0 δίκτυο, 0 εγγραφές.
  /// - Cache miss + επιβεβαιωμένα offline: καμία κλήση, καμία εγγραφή.
  /// - Cache miss online: server-truth με timeout 8s· εγγραφή μόνο αν ο
  ///   server επιβεβαιώσει ότι το doc λείπει.
  /// - Timeout/offline/σφάλμα: καμία εγγραφή, η ροή συνεχίζει.
  ///
  /// Επιστρέφει και τα δεδομένα, ώστε η οθόνη να μη χρειάζεται δεύτερη
  /// ανάγνωση (και να μη χάνει χρόνο με poll).
  Future<UserDocumentResult> ensureUserDocument(
    User user, {
    bool confirmedOffline = false,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final stopwatch = Stopwatch()..start();

    // 1) Cache — γρήγορο μονοπάτι.
    try {
      final cached = await docRef.get(const GetOptions(source: Source.cache));
      if (cached.exists) {
        final data = cached.data();
        DebugConfig.print(
          '→ user doc: cache hit (${stopwatch.elapsedMilliseconds}ms)',
        );
        return UserDocumentResult(
          outcome: UserDocPolicy.isDeletionPending(data)
              ? UserDocOutcome.deletionPending
              : UserDocOutcome.exists,
          exists: true,
          data: data,
        );
      }
    } catch (e) {
      DebugConfig.print('→ user doc: cache miss ($e)');
    }

    final cacheDecision = UserDocPolicy.afterCache(
      cacheExists: false,
      confirmedOffline: confirmedOffline,
    );

    if (cacheDecision == UserDocAction.skipOffline) {
      DebugConfig.print(
        '→ user doc: skip (offline, ${stopwatch.elapsedMilliseconds}ms)',
      );
      return const UserDocumentResult(
        outcome: UserDocOutcome.skippedOffline,
        exists: false,
      );
    }

    // 2) Server — η αλήθεια· καμία εγγραφή αν δεν απαντήσει.
    try {
      final serverDoc = await docRef
          .get(const GetOptions(source: Source.server))
          .timeout(UserDocPolicy.serverTimeout);

      if (serverDoc.exists) {
        final data = serverDoc.data();
        DebugConfig.print(
          '→ user doc: server hit (${stopwatch.elapsedMilliseconds}ms)',
        );
        return UserDocumentResult(
          outcome: UserDocPolicy.isDeletionPending(data)
              ? UserDocOutcome.deletionPending
              : UserDocOutcome.exists,
          exists: true,
          data: data,
        );
      }

      // 3) Ο server επιβεβαίωσε ότι λείπει — μόνο τώρα επιτρέπεται εγγραφή.
      final payload = _newUserDocumentPayload(user);
      await docRef.set(payload, SetOptions(merge: true));
      DebugConfig.print(
        '→ user doc: created (${stopwatch.elapsedMilliseconds}ms)',
      );
      return UserDocumentResult(
        outcome: UserDocOutcome.created,
        exists: true,
        data: payload,
      );
    } on TimeoutException {
      DebugConfig.print(
        '→ user doc: skip (timeout, ${stopwatch.elapsedMilliseconds}ms)',
      );
      return const UserDocumentResult(
        outcome: UserDocOutcome.skippedOffline,
        exists: false,
      );
    } on FirebaseException catch (e) {
      final failure = UserDocPolicy.afterFailure(
        timedOut: false,
        code: e.code,
      );
      DebugConfig.print(
        '→ user doc: skip (${e.code}, '
        '${stopwatch.elapsedMilliseconds}ms)',
      );
      return UserDocumentResult(
        outcome: failure == UserDocAction.skipOffline
            ? UserDocOutcome.skippedOffline
            : UserDocOutcome.skippedError,
        exists: false,
        errorCode: e.code,
      );
    } catch (e) {
      DebugConfig.print(
        '→ user doc: skip (error, ${stopwatch.elapsedMilliseconds}ms)',
      );
      return const UserDocumentResult(
        outcome: UserDocOutcome.skippedError,
        exists: false,
      );
    }
  }

  /// E64: το πλήρες payload του νέου user document (ίδιο με πριν).
  Map<String, dynamic> _newUserDocumentPayload(User user) {
    final now = Timestamp.now();
    return <String, dynamic>{
      'uuid': user.uid,
      'user_id': user.uid,
      'username': user.email?.split('@')[0] ?? 'user',
      'email': user.email ?? '',
      'display_name': '',
      'is_guest': false,
      'auth_provider': user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'password',
      'default_currency': 'EUR',
      'preferred_language': 'el',
      'fingerprint_enabled': false,
      'biometric_mode': 'always', // ✅ 'always' ή 'on_demand'
      'biometric_remember': false, // ✅ αν θες "θυμήσου/μη θυμάσαι"
      'onboarding_completed': false,

      // ✅ E4: Σφράγισμα έκδοσης δεδομένων — ο νέος χρήστης
      // ξεκινά κατευθείαν στην τρέχουσα έκδοση (καμία migration).
      'schema_version': Schema.current,
      'schema_updated_at': now,

      'last_sync_at': now,
      'created_at': now,
      'updated_at': now,

      'last_modified_device_id': '',
      'deleted': false,
    };
  }

  /// Αποστολή email επαναφοράς κωδικού
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw UserMessageException(mapFirebaseError(e));
    }
  }

  /// Αποσύνδεση — σταματά πρώτα τον guard (SEC-006a), ώστε να μη μείνει
  /// «ενεργός» listener μετά το signOut.
  Future<void> signOut() async {
    await DeletionGuardService.instance.detach();
    await _auth.signOut();
  }

  /// SEC-005: επαλήθευση ταυτότητας πριν από ευαίσθητη ενέργεια.
  ///
  /// Πετάει [UserMessageException] (μέσω [AuthFlowException]) με μήνυμα
  /// ασφαλές για το UI· ποτέ raw κωδικό σφάλματος.
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const UserMessageException(
        'Η συνεδρία έληξε. Συνδεθείτε ξανά.',
      );
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const UserMessageException(
        'Δεν είναι δυνατή η επιβεβαίωση ταυτότητας. Συνδεθείτε ξανά.',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthFlowException(mapFirebaseError(e), code: e.code);
    }
  }

  /// SEC-005: οριστική διαγραφή του Auth λογαριασμού.
  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const UserMessageException(
        'Η συνεδρία έληξε. Συνδεθείτε ξανά.',
      );
    }

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthFlowException(mapFirebaseError(e), code: e.code);
    }
  }

  /// Επιστρέφει τον τρέχοντα χρήστη
  User? get currentUser => _auth.currentUser;

  /// Παρακολούθηση κατάστασης σύνδεσης
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Μετατροπή FirebaseAuthException σε φιλικό μήνυμα
  String mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Μη έγκυρη διεύθυνση email.';
      case 'user-disabled':
        return 'Ο λογαριασμός είναι απενεργοποιημένος.';
      case 'invalid-credential':
      case 'ERROR_INVALID_CREDENTIAL':
        return 'Λάθος email ή κωδικός πρόσβασης.';
      case 'user-not-found':
        return 'Δεν βρέθηκε χρήστης με αυτό το email.';
      case 'wrong-password':
        return 'Λάθος κωδικός πρόσβασης.';
      case 'email-already-in-use':
        return 'Το email χρησιμοποιείται ήδη.';
      case 'weak-password':
        return 'Ο κωδικός πρέπει να έχει τουλάχιστον 6 χαρακτήρες.';
      case 'too-many-requests':
        return 'Πάρα πολλές προσπάθειες. Δοκιμάστε ξανά αργότερα.';
      case 'operation-not-allowed':
        return 'Η λειτουργία δεν επιτρέπεται. Επικοινωνήστε με τον διαχειριστή.';
      case 'network-request-failed':
        return 'Πρόβλημα σύνδεσης. Ελέγξτε το διαδίκτυο σας.';
      case 'requires-recent-login':
        return 'Για λόγους ασφαλείας απαιτείται πρόσφατη σύνδεση.';
      default:
        return 'Αποτυχία ελέγχου ταυτότητας. Δοκιμάστε ξανά.';
    }
  }
}