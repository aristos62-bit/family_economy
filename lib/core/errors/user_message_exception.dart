// ============================================================
// FILE: user_message_exception.dart
// Path: lib/core/errors/user_message_exception.dart
// Ρόλος: Σφάλμα με μήνυμα ασφαλές για εμφάνιση (L11).
// Καθαρό Dart — χωρίς Flutter.
// ============================================================

/// Σφάλμα που μεταφέρει **μόνο** κείμενο κατάλληλο για τον χρήστη.
///
/// Χρησιμοποιείται ως allowlist: το `MessagePolicy.fromError` εμφανίζει
/// το [message] μόνο όταν το σφάλμα είναι αυτού του τύπου. Οτιδήποτε άλλο
/// καταλήγει στο γενικό μήνυμα.
class UserMessageException implements Exception {
  const UserMessageException(this.message);

  final String message;

  @override
  String toString() => message;
}
