// ============================================================
// FILE: schema.dart
// Path: lib/core/data/schema.dart
// Ρόλος: Έκδοση δεδομένων (versioning) — σταθερές, parser, αποφάσεις.
// Καθαρό Dart: καμία εξάρτηση από Firebase, ώστε να ελέγχεται
// με unit tests χωρίς mocks.
// ============================================================

/// Κατάσταση των δεδομένων σε σχέση με την έκδοση της εφαρμογής.
enum SchemaStatus {
  /// Τα δεδομένα είναι στην τρέχουσα έκδοση (ή θεωρούνται baseline).
  upToDate,

  /// Τα δεδομένα είναι παλιότερα και χρειάζονται migration.
  pending,

  /// Τα δεδομένα γράφτηκαν από νεότερη έκδοση της εφαρμογής.
  newerThanApp,

  /// Δεν υπάρχουν δεδομένα (ανύπαρκτο ή διαγραμμένο έγγραφο).
  noData,
}

/// Αποτέλεσμα της απόφασης για την έκδοση των δεδομένων.
///
/// Είναι αμιγώς υπολογιστικό (χωρίς I/O), ώστε να ελέγχεται εύκολα.
class SchemaDecision {
  final SchemaStatus status;
  final int fromVersion;
  final int toVersion;

  /// true όταν το πεδίο υπάρχει αλλά δεν διαβάζεται (π.χ. "abc").
  final bool versionUnreadable;

  const SchemaDecision({
    required this.status,
    required this.fromVersion,
    required this.toVersion,
    this.versionUnreadable = false,
  });

  bool get needsMigration => status == SchemaStatus.pending;
  bool get isBlocked => status == SchemaStatus.newerThanApp;
}

/// Τίτλος + μήνυμα για οθόνη σφάλματος (ελληνικά).
class SchemaFailure {
  final String title;
  final String message;

  const SchemaFailure({required this.title, required this.message});
}

/// Σταματά την είσοδο όταν τα δεδομένα δεν είναι συμβατά.
///
/// Το [toString] επιστρέφει μόνο το μήνυμα, χωρίς πρόθεμα "Exception:",
/// γιατί το login_page εμφανίζει απευθείας το κείμενο του σφάλματος.
class SchemaBlockedException implements Exception {
  final String title;
  final String message;
  final String? code;

  const SchemaBlockedException({
    required this.title,
    required this.message,
    this.code,
  });

  @override
  String toString() => message;
}

/// Έκβαση της εγγραφής της έκδοσης.
enum SchemaWriteOutcome {
  /// Επιβεβαιώθηκε από τον server.
  applied,

  /// Δεν επιβεβαιώθηκε εγκαίρως, αλλά το τοπικό cache δείχνει τη νέα
  /// έκδοση (η εγγραφή είναι στην ουρά και θα συγχρονιστεί).
  appliedLocally,

  /// Αποτυχία — χρειάζεται φραγή/επανάληψη.
  failed,
}

/// Κανόνες έκδοσης δεδομένων.
class Schema {
  const Schema._();

  /// Η έκδοση που γράφει αυτή η έκδοση της εφαρμογής.
  static const int current = 1;

  /// Έκδοση που θεωρείται ότι έχουν τα δεδομένα όταν το πεδίο λείπει.
  /// Δεν ξεκινάμε από 0: τα υπάρχοντα δεδομένα είναι ήδη λειτουργικά.
  static const int baseline = 1;

  /// Άνω όριο λογικής τιμής· μεγαλύτερη τιμή θεωρείται μη αναγνώσιμη.
  /// (Πρέπει να αυξάνεται μαζί με το [current] αν ποτέ χρειαστεί.)
  static const int maxReasonableVersion = 1000;

  static const String versionField = 'schema_version';
  static const String updatedAtField = 'schema_updated_at';
  static const String deletedField = 'deleted';

  // Μηνύματα (χωρίς πρόθεμα «Σφάλμα:» — το προσθέτει το
  // AccessibilityService.announceError).
  static const String blockedTitle = 'Απαιτείται ενημέρωση δεδομένων';
  static const String newerTitle = 'Νεότερη έκδοση δεδομένων';
  static const String permissionTitle = 'Πρόβλημα πρόσβασης';

  static const String updateFailedMessage =
      'Δεν ήταν δυνατή η ενημέρωση των δεδομένων. '
      'Ελέγξτε τη σύνδεση και δοκιμάστε ξανά.';

  static const String newerMessage =
      'Τα δεδομένα σας ανήκουν σε νεότερη έκδοση της εφαρμογής. '
      'Ενημερώστε την εφαρμογή και δοκιμάστε ξανά.';

  static const String permissionMessage =
      'Δεν έχετε πρόσβαση στα δεδομένα σας. '
      'Δοκιμάστε να συνδεθείτε ξανά.';

  static const String genericFailureMessage =
      'Δεν ήταν δυνατή η ενημέρωση των δεδομένων. Δοκιμάστε ξανά.';

  /// Διαβάζει την έκδοση ανεκτικά.
  ///
  /// Δέχεται int, ολοκληρωμένο double και αριθμητικό String.
  /// Επιστρέφει null όταν η τιμή λείπει ή δεν είναι λογική.
  static int? readVersion(Object? raw) {
    if (raw == null) return null;

    int? parsed;

    if (raw is int) {
      parsed = raw;
    } else if (raw is double) {
      if (raw.isFinite && raw == raw.roundToDouble()) {
        parsed = raw.toInt();
      }
    } else if (raw is String) {
      final text = raw.trim();
      if (text.isNotEmpty) {
        parsed = int.tryParse(text);
        if (parsed == null) {
          final asDouble = double.tryParse(text);
          if (asDouble != null &&
              asDouble.isFinite &&
              asDouble == asDouble.roundToDouble()) {
            parsed = asDouble.toInt();
          }
        }
      }
    }

    if (parsed == null) return null;
    if (parsed < baseline || parsed > maxReasonableVersion) return null;
    return parsed;
  }

  /// Αποφασίζει τι θα γίνει με τα δεδομένα.
  /// Καμία εγγραφή, κανένα δίκτυο, κανένα side effect.
  static SchemaDecision decide({
    required bool exists,
    Map<String, dynamic>? data,
  }) {
    if (!exists || data == null || data[deletedField] == true) {
      return const SchemaDecision(
        status: SchemaStatus.noData,
        fromVersion: baseline,
        toVersion: current,
      );
    }

    final raw = data[versionField];
    final parsed = readVersion(raw);
    final unreadable = raw != null && parsed == null;
    final from = parsed ?? baseline;

    if (from > current) {
      return SchemaDecision(
        status: SchemaStatus.newerThanApp,
        fromVersion: from,
        toVersion: current,
        versionUnreadable: unreadable,
      );
    }

    if (from < current) {
      return SchemaDecision(
        status: SchemaStatus.pending,
        fromVersion: from,
        toVersion: current,
        versionUnreadable: unreadable,
      );
    }

    return SchemaDecision(
      status: SchemaStatus.upToDate,
      fromVersion: from,
      toVersion: current,
      versionUnreadable: unreadable,
    );
  }

  /// Μετατρέπει κωδικό σφάλματος Firestore σε τίτλο + ελληνικό μήνυμα.
  static SchemaFailure failureFor(String? code) {
    switch (code) {
      case 'permission-denied':
        return const SchemaFailure(
          title: permissionTitle,
          message: permissionMessage,
        );
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return const SchemaFailure(
          title: blockedTitle,
          message: updateFailedMessage,
        );
      default:
        return const SchemaFailure(
          title: blockedTitle,
          message: genericFailureMessage,
        );
    }
  }

  /// Αποφασίζει αν η εγγραφή της έκδοσης πέτυχε.
  ///
  /// - Πραγματικό σφάλμα -> failed.
  /// - Χωρίς timeout -> applied (ο server επιβεβαίωσε).
  /// - Με timeout -> appliedLocally μόνο αν το τοπικό cache δείχνει ήδη
  ///   τη νέα έκδοση· αλλιώς failed.
  static SchemaWriteOutcome resolveWrite({
    required int targetVersion,
    bool timedOut = false,
    String? errorCode,
    int? verifiedVersion,
  }) {
    if (errorCode != null && errorCode.isNotEmpty) {
      return SchemaWriteOutcome.failed;
    }
    if (!timedOut) return SchemaWriteOutcome.applied;
    return verifiedVersion == targetVersion
        ? SchemaWriteOutcome.appliedLocally
        : SchemaWriteOutcome.failed;
  }
}