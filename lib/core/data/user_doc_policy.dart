// ============================================================
// FILE: user_doc_policy.dart
// Path: lib/core/data/user_doc_policy.dart
// Ρόλος: Καθαρός κανόνας για την εξασφάλιση του user document.
// - Καμία εξάρτηση από Firebase ή Flutter.
// - Αποφασίζει μόνο το επόμενο βήμα· η I/O μένει στο AuthService.
// ============================================================

/// Επόμενο βήμα για το user document κατά την είσοδο.
enum UserDocAction {
  /// Το cache έχει το doc — καμία κλήση δικτύου.
  cacheHit,

  /// Το cache δεν το έχει και δεν είμαστε επιβεβαιωμένα offline.
  readServer,

  /// Ο server επιβεβαίωσε ότι το doc υπάρχει.
  exists,

  /// Ο server επιβεβαίωσε ότι το doc λείπει — επιτρέπεται εγγραφή.
  create,

  /// Καμία εγγραφή: offline ή timeout.
  skipOffline,

  /// Καμία εγγραφή: άλλο σφάλμα (π.χ. permission-denied).
  skipError,
}

/// Αποτέλεσμα της ροής, όπως το βλέπει η οθόνη εισόδου.
enum UserDocOutcome { exists, created, skippedOffline, skippedError }

/// E64: ο κανόνας «τι κάνουμε με το user document» χωρίς I/O.
class UserDocPolicy {
  UserDocPolicy._();

  /// Ίδιο όριο με το E5 (`onboarding_service.dart`).
  static const Duration serverTimeout = Duration(seconds: 8);

  /// Ίδια λίστα με το E5 (`onboarding_service.dart`).
  static const Set<String> offlineCodes = <String>{
    'unavailable',
    'deadline-exceeded',
    'network-request-failed',
  };

  /// true όταν ο κωδικός σημαίνει «δεν έχουμε δίκτυο».
  static bool isOfflineCode(String? code) =>
      code != null && offlineCodes.contains(code);

  /// Απόφαση μετά την ανάγνωση του τοπικού cache.
  static UserDocAction afterCache({
    required bool cacheExists,
    required bool confirmedOffline,
  }) {
    if (cacheExists) return UserDocAction.cacheHit;
    if (confirmedOffline) return UserDocAction.skipOffline;
    return UserDocAction.readServer;
  }

  /// Απόφαση μετά την απάντηση του server.
  static UserDocAction afterServer({required bool serverExists}) {
    return serverExists ? UserDocAction.exists : UserDocAction.create;
  }

  /// Απόφαση μετά από αποτυχία (timeout ή σφάλμα Firestore).
  static UserDocAction afterFailure({
    required bool timedOut,
    required String? code,
  }) {
    if (timedOut || isOfflineCode(code)) {
      return UserDocAction.skipOffline;
    }
    return UserDocAction.skipError;
  }
}
