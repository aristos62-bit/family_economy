// ============================================================
// FILE: account_budget_usage.dart
// Path: lib/core/utils/account_budget_usage.dart
// Ρόλος: Πόσοι προϋπολογισμοί «δείχνουν» σε έναν λογαριασμό (L26).
// Καθαρό Dart, 0 I/O — ελέγξιμο χωρίς Firebase.
//
// Γιατί όχι `BudgetsProvider`: ο listener φιλτράρει
// `deleted == false && is_active == true`, άρα δεν βλέπει ανενεργά ή
// legacy docs (χωρίς `is_active`). Το gate της διαγραφής χρειάζεται
// **όλα** τα μη διαγραμμένα, αλλιώς ο λογαριασμός διαγράφεται και τα
// budgets μένουν ορφανά (L26).
// ============================================================

/// Αποτέλεσμα μέτρησης budgets για έναν λογαριασμό.
class AccountBudgetUsage {
  const AccountBudgetUsage({
    required this.total,
    required this.inactive,
  });

  /// Μηδενική χρήση (και για ασφαλή default).
  static const AccountBudgetUsage none = AccountBudgetUsage(
    total: 0,
    inactive: 0,
  );

  /// Όλοι οι μη διαγραμμένοι προϋπολογισμοί που δείχνουν στον λογαριασμό.
  final int total;

  /// Όσοι από αυτούς έχουν ρητά `is_active == false`.
  final int inactive;

  bool get hasAny => total > 0;

  /// Μετρά docs της συλλογής `budgets` **ως raw maps** (όχι `BudgetModel`,
  /// ώστε ένα legacy doc χωρίς `amount` να μη ρίξει τη μέτρηση).
  ///
  /// Κανόνας:
  /// - `account_id == accountUuid` (τα «Όλοι» έχουν `null` → εκτός)
  /// - `deleted != true` (λείπον = μη διαγραμμένο, όπως στο `BudgetModel`)
  /// - `inactive` όταν `is_active == false` (λείπον = ενεργό)
  static AccountBudgetUsage count(
    Iterable<Map<String, dynamic>> budgetDocs,
    String accountUuid,
  ) {
    final uuid = accountUuid.trim();
    if (uuid.isEmpty) return none;

    var total = 0;
    var inactive = 0;

    for (final data in budgetDocs) {
      final accountId = data['account_id'];
      if (accountId is! String || accountId.trim() != uuid) continue;
      if (data['deleted'] == true) continue;

      total++;
      if (data['is_active'] == false) inactive++;
    }

    return AccountBudgetUsage(total: total, inactive: inactive);
  }
}
