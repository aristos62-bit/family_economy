// ============================================================
// FILE: database_cleanup_policy.dart
// Path: lib/core/utils/database_cleanup_policy.dart
// Ρόλος: ΕΝΑΣ κανόνας για το τι διαγράφει ο καθαρισμός βάσης (E34).
// - Καθαρό Dart (0 Firebase) → ελέγξιμο με unit tests.
// - «Παλιό» = ημερομηνία < όριο· φιλτράρισμα client-side (κανένα index).
// - Chunking ≤499 writes (νέο batch ανά chunk — ποτέ επανάχρηση).
// - Μηνύματα + 3-κατάστατο αποτέλεσμα ζουν εδώ, όχι στο UI.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:family_economy/core/utils/account_delete_guard.dart';

/// Αποτέλεσμα εκτέλεσης καθαρισμού.
enum CleanupOutcome {
  /// Όλες οι επιλεγμένες εργασίες ολοκληρώθηκαν χωρίς σφάλμα.
  complete,

  /// Κάποιες εργασίες απέτυχαν· οι υπόλοιπες ολοκληρώθηκαν.
  partial,

  /// Δεν εκτελέστηκε τίποτα (καμία επιλογή ή offline φραγή).
  cancelled,
}

class CleanupPolicy {
  CleanupPolicy._();

  /// Firestore όριο 500 writes/batch — κρατάμε 499 (πρότυπο project).
  static const int maxWritesPerBatch = AccountDeleteGuard.maxWritesPerBatch;

  /// Όρια slider «Παλαιότητα».
  static const int minDays = 7;
  static const int maxDays = 365;

  /// Βήμα slider «Παλαιότητα» (ημέρες).
  static const int dayStep = 1;

  // ============================================================
  // ΜΗΝΥΜΑΤΑ (ένα σημείο αλήθειας, όπως account_restore_policy)
  // ============================================================

  static const String offlineMessage =
      'Ο καθαρισμός απαιτεί σύνδεση στο internet. '
      'Δοκιμάστε ξανά όταν επανέλθει η σύνδεση.';

  static const String runningMessage =
      'Ο καθαρισμός εκτελείται. Περιμένετε να ολοκληρωθεί.';

  static const String nothingToDeleteMessage =
      'Δεν βρέθηκαν δεδομένα προς διαγραφή με τις επιλογές που κάνατε.';

  static const String completeTitle = 'Ο καθαρισμός ολοκληρώθηκε';

  static const String partialTitle = 'Ο καθαρισμός ολοκληρώθηκε μερικώς';

  static const String cancelledTitle = 'Ο καθαρισμός δεν εκτελέστηκε';

  static const String partialIntro =
      'Οι παρακάτω εργασίες απέτυχαν και δεν ολοκληρώθηκαν:';

  static const String partialNote =
      'Οι υπόλοιπες εργασίες ολοκληρώθηκαν κανονικά. '
      'Δοκιμάστε ξανά για τις αποτυχημένες.';

  static const String partialNothingDeleted =
      'Δεν διαγράφηκε καμία εγγραφή.';

  /// Γραμμή «εργασία: πλήθος» για τα αποτελέσματα.
  static String countLine(String label, int count) => '• $label: $count';

  /// Τίτλος αποτελέσματος ανά κατάσταση.
  static String titleOf(CleanupOutcome outcome) {
    switch (outcome) {
      case CleanupOutcome.complete:
        return completeTitle;
      case CleanupOutcome.partial:
        return partialTitle;
      case CleanupOutcome.cancelled:
        return cancelledTitle;
    }
  }

  // ============================================================
  // ΗΜΕΡΟΜΗΝΙΕΣ
  // ============================================================

  /// Περιορίζει τις ημέρες στα όρια του slider (7–365).
  static int clampDays(int days) {
    if (days < minDays) return minDays;
    if (days > maxDays) return maxDays;
    return days;
  }

  /// Όριο ηλικίας: ό,τι είναι **αυστηρά πριν** από αυτό διαγράφεται.
  static DateTime cutoff(DateTime now, int daysOld) =>
      now.subtract(Duration(days: clampDays(daysOld)));

  /// Ανεκτική ανάγνωση ημερομηνίας (Timestamp / int millis / String / DateTime).
  static DateTime? parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      try {
        return DateTime.parse(text);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Ηλικία doc που **δεν** φαίνεται πλέον στο UI (soft-deleted):
  /// `updated_at` (χρόνος διαγραφής) — αλλιώς `created_at`.
  static DateTime? docAge(Map<String, dynamic> data) =>
      parseTimestamp(data['updated_at']) ?? parseTimestamp(data['created_at']);

  /// Soft-deleted doc που είναι παλιό → μπορεί να διαγραφεί οριστικά.
  static bool shouldDeleteSoftDeleted(
    Map<String, dynamic> data,
    DateTime cutoffDate,
  ) {
    if (data['deleted'] != true) return false;
    final age = docAge(data);
    return age != null && age.isBefore(cutoffDate);
  }

  /// Doc με `updated_at` παλιό (κινήσεις / κατηγορίες).
  /// Χωρίς `updated_at` → **δεν** διαγράφεται (συντηρητικό).
  static bool shouldDeleteAged(
    Map<String, dynamic> data,
    DateTime cutoffDate,
  ) {
    final updatedAt = parseTimestamp(data['updated_at']);
    return updatedAt != null && updatedAt.isBefore(cutoffDate);
  }

  // ============================================================
  // ΥΠΕΝΘΥΜΙΣΕΙΣ
  // ============================================================

  static bool shouldDeleteNotification(
    Map<String, dynamic> data,
    DateTime now,
    int daysOld,
  ) {
    // 0. Ήδη soft-deleted (αόρατη στο UI) → μόνο με βάση την ηλικία.
    if (data['deleted'] == true) {
      return shouldDeleteSoftDeleted(data, cutoff(now, daysOld));
    }

    final cutoffDate = cutoff(now, daysOld);
    final deliveredAt = parseTimestamp(data['delivered_at']);
    final readAt = parseTimestamp(data['read_at']);
    final dismissedAt = parseTimestamp(data['dismissed_at']);
    final scheduledFor = parseTimestamp(data['scheduled_for']);
    final recurringEndAt = parseTimestamp(data['recurring_end_at']);
    final isRecurring = data['is_recurring'] as bool? ?? false;

    // 1. Διαβάστηκε και είναι παλιά.
    if (deliveredAt != null &&
        readAt != null &&
        readAt.isBefore(cutoffDate)) {
      return true;
    }
    // 2. Απορρίφθηκε και είναι παλιά.
    if (dismissedAt != null && dismissedAt.isBefore(cutoffDate)) return true;
    // 3. Παραδόθηκε και είναι παλιά.
    if (deliveredAt != null && deliveredAt.isBefore(cutoffDate)) return true;
    // 4. Ληγμένη επαναλαμβανόμενη σειρά — **το slider ισχύει και εδώ**.
    if (isRecurring &&
        recurringEndAt != null &&
        recurringEndAt.isBefore(cutoffDate)) {
      return true;
    }
    // 5. Προγραμματισμένη στο παρελθόν και δεν παραδόθηκε ποτέ.
    if (!isRecurring &&
        scheduledFor != null &&
        scheduledFor.isBefore(cutoffDate) &&
        deliveredAt == null) {
      return true;
    }
    return false;
  }

  // ============================================================
  // ΠΡΟΫΠΟΛΟΓΙΣΜΟΙ
  // ============================================================

  static bool shouldDeleteBudget(
    Map<String, dynamic> data,
    DateTime now,
    int daysOld,
  ) {
    final cutoffDate = cutoff(now, daysOld);

    // Ήδη soft-deleted (αόρατος στο UI) → μόνο με βάση την ηλικία.
    if (data['deleted'] == true) {
      return shouldDeleteSoftDeleted(data, cutoffDate);
    }

    final endDate = parseTimestamp(data['end_date']);
    final isActive = data['is_active'] as bool? ?? true;

    if (endDate != null && endDate.isBefore(cutoffDate)) return true;
    if (!isActive && endDate != null && endDate.isBefore(now)) return true;
    return false;
  }

  // ============================================================
  // CHUNKING
  // ============================================================

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
}
