// ============================================================
// FILE: account_delete_guard.dart
// Path: lib/core/utils/account_delete_guard.dart
// Ρόλος: Καθαρή απόφαση για διαγραφή λογαριασμού (χωρίς Firebase).
// - Επιτρέπει τη διαγραφή μόνο όταν μένει ≥1 ενεργός λογαριασμός.
// - Τα μηνύματα ζουν εδώ, όπως στο Schema.failureFor (καθαρά, ελέγξιμα).
// ============================================================

/// Αιτία φραγής της διαγραφής λογαριασμού.
enum AccountDeleteBlock {
  /// Επιτρέπεται η διαγραφή.
  none,

  /// Δεν υπάρχει κανένας ενεργός λογαριασμός.
  noActiveAccount,

  /// Είναι ο τελευταίος ενεργός λογαριασμός.
  lastActiveAccount,
}

/// Αποτέλεσμα της απόφασης: επιτρέπεται ή όχι + αιτιολόγηση για τον χρήστη.
class AccountDeleteDecision {
  const AccountDeleteDecision({
    required this.block,
    required this.message,
  });

  final AccountDeleteBlock block;
  final String message;

  bool get canDelete => block == AccountDeleteBlock.none;
}

class AccountDeleteGuard {
  AccountDeleteGuard._();

  /// Αποφασίζει με βάση το πλήθος των **ενεργών** λογαριασμών
  /// (`AccountsProvider.accounts.length` — μηδέν επιπλέον reads).
  static AccountDeleteDecision evaluate(int activeAccountCount) {
    if (activeAccountCount <= 0) {
      return const AccountDeleteDecision(
        block: AccountDeleteBlock.noActiveAccount,
        message: 'Δεν υπάρχει ενεργός λογαριασμός για διαγραφή.',
      );
    }

    if (activeAccountCount == 1) {
      return const AccountDeleteDecision(
        block: AccountDeleteBlock.lastActiveAccount,
        message:
            'Δεν μπορεί να διαγραφεί ο τελευταίος ενεργός λογαριασμός. '
            'Δημιουργήστε πρώτα έναν νέο λογαριασμό.',
      );
    }

    return const AccountDeleteDecision(
      block: AccountDeleteBlock.none,
      message: '',
    );
  }
}
