import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/core/utils/debug_config.dart';

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
      final user = credential.user;

      if (user != null) {
        await createUserDocumentIfNeeded(user);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(mapFirebaseError(e));
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
      final user = credential.user;

      if (user != null) {
        DebugConfig.print('→ User registered (uid: ${user.uid}) - δημιουργούμε document...');
        await createUserDocumentIfNeeded(user);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(mapFirebaseError(e));
    }
  }

  /// Δημιουργεί user doc αν δεν υπάρχει – και περιμένει να γίνει ορατό
  Future<void> createUserDocumentIfNeeded(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      DebugConfig.print('→ Δημιουργία user document ξεκινάει... ${DateTime.now().toIso8601String()}');

      // ✅ ΔΙΟΡΘΩΣΗ: Χρήση Timestamp.now() αντί για ISO string
      final now = Timestamp.now();

      await docRef.set({
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

        // ✅ ΔΙΟΡΘΩΣΗ: Χρήση Firestore Timestamp objects
        'last_sync_at': now,
        'created_at': now,
        'updated_at': now,

        'last_modified_device_id': '',
        'deleted': false,
      }, SetOptions(merge: true));

      DebugConfig.print('→ set() ολοκληρώθηκε - τώρα poll μέχρι να γίνει ορατό');

      // ΚΡΙΣΙΜΟ: Περιμένουμε μέχρι το document να είναι ορατό (poll)
      bool visible = false;
      for (int attempt = 0; attempt < 15; attempt++) {  // max ~7.5 δευτ – ασφαλές
        final check = await docRef.get();
        if (check.exists) {
          visible = true;
          DebugConfig.print('→ Document ορατό μετά από $attempt προσπάθειες (${DateTime.now().toIso8601String()})');
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!visible) {
        DebugConfig.print('→ CRITICAL: Το document δεν έγινε ορατό εγκαίρως - συνεχίζουμε με ρίσκο');
        // Προαιρετικά: throw Exception('User document creation timeout');
      }
    } else {
      DebugConfig.print('→ User document υπάρχει ήδη');
    }
  }

  /// Αποστολή email επαναφοράς κωδικού
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(mapFirebaseError(e));
    }
  }

  /// Αποσύνδεση
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Επιστρέφει τον τρέχοντα χρήστη
  User? get currentUser => _auth.currentUser;

  /// Παρακολούθηση κατάστασης σύνδεσης
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Φέρνει το έγγραφο χρήστη από Firestore
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDocument(String uid) {
    return _firestore.collection('users').doc(uid).get();
  }

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
      default:
        return 'Σφάλμα: ${e.message ?? 'Άγνωστο σφάλμα.'}';
    }
  }
}