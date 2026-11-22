// ============================================================
// FILE: account_balance.dart
// Path: lib/core/utils/account_balance.dart
// Ρόλος: ΕΝΑΣ κανόνας για το «μετράει μια κίνηση στο υπόλοιπο;» (E20)
//        + καθαρός υπολογισμός υπολοίπου από αρχικό ποσό και κινήσεις.
// Χωρίς Firebase: ελέγξιμο με unit tests (όπως το account_delete_guard).
//
// Αρχή: μια κίνηση μετράει όταν το αποτέλεσμά της έχει **ήδη εφαρμοστεί**.
// Δεν εξαρτάται από την ημερομηνία (μελλοντική «Άμεση» κίνηση μετράει,
// μελλοντική προγραμματισμένη που δεν εκτελέστηκε ΔΕΝ μετράει).
// ============================================================

import 'package:family_economy/core/utils/currency_formatter.dart';

/// Κανόνας «μετράει στο υπόλοιπο;» — ένα σημείο αλήθειας για E20.
class AccountBalanceRules {
  AccountBalanceRules._();

  /// Εκκρεμής προγραμματισμένη: δεν έχει εκτελεστεί ακόμη.
  ///
  /// Λείπον πεδίο = `false` (legacy docs — E6). Ο έλεγχος γίνεται πάντα
  /// σε Dart, ποτέ σε query, ώστε να μη χάνονται docs χωρίς τα πεδία.
  static bool isPendingScheduled(Map<String, dynamic> tx) {
    final isScheduled = tx['is_scheduled'] as bool? ?? false;
    final isExecuted = tx['is_executed'] as bool? ?? false;
    return isScheduled && !isExecuted;
  }

  /// Soft-deleted κίνηση: δεν επηρεάζει υπόλοιπο.
  static bool isDeleted(Map<String, dynamic> tx) =>
      tx['deleted'] as bool? ?? false;

  /// Η κίνηση επηρεάζει το `current_balance`;
  static bool countsInBalance(Map<String, dynamic> tx) =>
      !isDeleted(tx) && !isPendingScheduled(tx);

  /// Ποσό σε cents (ακέραια) — μηδέν float dust.
  static int centsOf(dynamic rawAmount) {
    final value = (rawAmount as num?)?.toDouble() ?? 0.0;
    return (value * 100).round();
  }

  /// `initial_balance + Σ (ποσά κινήσεων που μετράνε)`.
  ///
  /// Το άθροισμα γίνεται σε cents· στρογγυλοποίηση μία φορά στο τέλος.
  static AccountBalanceResult compute({
    required double initialBalance,
    required Iterable<Map<String, dynamic>> transactions,
  }) {
    var totalCents = centsOf(initialBalance);
    var countedCount = 0;
    var pendingCount = 0;
    var pendingCents = 0;
    var deletedCount = 0;

    for (final tx in transactions) {
      final cents = centsOf(tx['amount']);

      if (isDeleted(tx)) {
        deletedCount++;
        continue;
      }

      if (isPendingScheduled(tx)) {
        pendingCount++;
        pendingCents += cents;
        continue;
      }

      countedCount++;
      totalCents += cents;
    }

    return AccountBalanceResult(
      newBalance: CurrencyFormatter.round(totalCents / 100),
      countedCount: countedCount,
      pendingExcludedCount: pendingCount,
      pendingExcludedAmount: pendingCents / 100,
      deletedSkippedCount: deletedCount,
    );
  }
}

/// Αποτέλεσμα καθαρού υπολογισμού (χωρίς I/O).
class AccountBalanceResult {
  const AccountBalanceResult({
    required this.newBalance,
    required this.countedCount,
    required this.pendingExcludedCount,
    required this.pendingExcludedAmount,
    required this.deletedSkippedCount,
  });

  /// `initial_balance + Σ` (στρογγυλοποιημένο σε cents).
  final double newBalance;

  /// Πόσες κινήσεις μετρήθηκαν.
  final int countedCount;

  /// Πόσες εκκρεμείς προγραμματισμένες εξαιρέθηκαν.
  final int pendingExcludedCount;

  /// Καθαρή επίδραση των εξαιρεθέντων (με πρόσημο).
  final double pendingExcludedAmount;

  /// Πόσες soft-deleted αγνοήθηκαν (μόνο για debug).
  final int deletedSkippedCount;

  bool get hasPendingExcluded => pendingExcludedCount > 0;
}

/// Αιτία αποτυχίας του επανυπολογισμού (για σαφές μήνυμα).
enum AccountBalanceRecalcFailure {
  /// Επιτυχία.
  none,

  /// Δεν υπάρχει συνδεδεμένος χρήστης.
  missingUser,

  /// Ο λογαριασμός δεν υπάρχει ή έχει διαγραφεί.
  accountMissing,

  /// Σφάλμα ανάγνωσης/εγγραφής.
  failed,
}

/// Αποτέλεσμα της πλήρους λειτουργίας (I/O + υπολογισμός).
class AccountBalanceRecalcOutcome {
  const AccountBalanceRecalcOutcome({
    required this.failure,
    this.beforeBalance = 0.0,
    this.afterBalance = 0.0,
    this.countedCount = 0,
    this.pendingExcludedCount = 0,
    this.pendingExcludedAmount = 0.0,
    this.changed = false,
  });

  final AccountBalanceRecalcFailure failure;
  final double beforeBalance;
  final double afterBalance;
  final int countedCount;
  final int pendingExcludedCount;
  final double pendingExcludedAmount;

  /// `true` αν γράφτηκε νέο υπόλοιπο.
  final bool changed;

  bool get isSuccess => failure == AccountBalanceRecalcFailure.none;

  /// Μήνυμα για τον χρήστη (σωστός ενικός/πληθυντικός — μάθημα E26).
  String message({required String currency}) {
    switch (failure) {
      case AccountBalanceRecalcFailure.missingUser:
        return 'Δεν βρέθηκε συνδεδεμένος χρήστης.';
      case AccountBalanceRecalcFailure.accountMissing:
        return 'Ο λογαριασμός δεν υπάρχει πλέον.';
      case AccountBalanceRecalcFailure.failed:
        return 'Ο επανυπολογισμός απέτυχε. Δεν άλλαξε κανένα υπόλοιπο.';
      case AccountBalanceRecalcFailure.none:
        break;
    }

    final after = CurrencyFormatter.format(afterBalance, currency: currency);

    if (!changed) {
      return 'Το υπόλοιπο ήταν ήδη σωστό ($after).';
    }

    final before = CurrencyFormatter.format(beforeBalance, currency: currency);
    final buffer = StringBuffer(
      'Επανυπολογισμός: $before → $after (${_countLabel(countedCount)})',
    );

    if (pendingExcludedCount > 0) {
      final label = pendingExcludedCount == 1
          ? '1 εκκρεμής'
          : '$pendingExcludedCount εκκρεμείς';
      final effect = CurrencyFormatter.format(
        pendingExcludedAmount,
        currency: currency,
      );
      buffer.write('. Εξαιρέθηκαν $label (επίδραση $effect)');
    }

    buffer.write('.');
    return buffer.toString();
  }

  static String _countLabel(int count) =>
      count == 1 ? '1 κίνηση' : '$count κινήσεις';
}
