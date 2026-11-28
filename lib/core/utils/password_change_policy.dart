// ============================================================
// FILE: password_change_policy.dart
// Path: lib/core/utils/password_change_policy.dart
// Ρόλος: E93 — κανόνες κωδικού πρόσβασης χωρίς trim.
// - Καθαρό Dart (0 Firebase) → ελέγξιμο με unit tests.
// - Ο κωδικός χρησιμοποιείται πάντα ως έχει (raw), ποτέ trimmed.
// - Το trim() επιτρέπεται μόνο για τον έλεγχο «μόνο κενά».
// ============================================================

/// E93: ενιαίοι κανόνες για τα πεδία κωδικού σε σύνδεση/εγγραφή/αλλαγή.
class PasswordChangePolicy {
  PasswordChangePolicy._();

  /// Ελάχιστο μήκος κωδικού (Firebase + φόρμα).
  static const int minLength = 6;

  /// E93: «κενό» σημαίνει μόνο κενά διαστήματα· κατά τα άλλα ο κωδικός
  /// παραμένει αναλλοίωτος.
  static bool isBlank(String value) => value.trim().isEmpty;

  // ============================================================
  // ΜΗΝΥΜΑΤΑ (ένα σημείο αλήθειας για UI + tests)
  // ============================================================

  static const String loginPasswordEmptyMessage = 'Υποχρεωτικός κωδικός';

  static const String loginPasswordTooShortMessage = 'Τουλάχιστον 6 χαρακτήρες';

  static const String confirmPasswordEmptyMessage = 'Επιβεβαίωσε τον κωδικό';

  static const String currentEmptyMessage = 'Γράψτε τον τρέχοντα κωδικό';

  static const String newEmptyMessage = 'Γράψτε νέο κωδικό';

  static const String newTooShortMessage =
      'Ο νέος κωδικός πρέπει να έχει τουλάχιστον 6 χαρακτήρες';

  static const String confirmMismatchMessage =
      'Ο νέος κωδικός και η επιβεβαίωση δεν ταιριάζουν';

  static const String sameAsCurrentMessage =
      'Ο νέος κωδικός δεν μπορεί να είναι ίδιος με τον τρέχοντα';

  // ============================================================
  // ΚΑΝΟΝΕΣ
  // ============================================================

  /// E93: validator του πεδίου κωδικού στη σύνδεση/εγγραφή.
  ///
  /// Το μήκος μετριέται στο raw κείμενο· το trim χρησιμοποιείται μόνο
  /// για να απορριφθεί πεδίο με αποκλειστικά κενά.
  static String? validateLoginPassword(String? value) {
    if (value == null || isBlank(value)) {
      return loginPasswordEmptyMessage;
    }
    if (value.length < minLength) {
      return loginPasswordTooShortMessage;
    }
    return null;
  }

  /// E93: validator του πεδίου επιβεβαίωσης στην εγγραφή.
  static String? validateConfirmPassword(String? value) {
    if (value == null || isBlank(value)) {
      return confirmPasswordEmptyMessage;
    }
    return null;
  }

  /// E93: έλεγχος της φόρμας αλλαγής κωδικού με raw τιμές.
  ///
  /// Επιστρέφει μήνυμα σφάλματος ή `null` όταν η φόρμα είναι έγκυρη.
  static String? validateChange({
    required String current,
    required String next,
    required String confirm,
  }) {
    if (isBlank(current)) {
      return currentEmptyMessage;
    }
    if (isBlank(next)) {
      return newEmptyMessage;
    }
    if (next.length < minLength) {
      return newTooShortMessage;
    }
    if (next != confirm) {
      return confirmMismatchMessage;
    }
    if (current == next) {
      return sameAsCurrentMessage;
    }
    return null;
  }
}
