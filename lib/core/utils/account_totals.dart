// ============================================================
// FILE: account_totals.dart
// Path: lib/core/utils/account_totals.dart
// Ρόλος: Ένα σημείο αλήθειας για το «συνολικό υπόλοιπο» (E26).
// - Μετράει ενεργούς **και** αρχειοθετημένους (`countsInTotal`).
// - Αφαιρεί όσους έχει εξαιρέσει ο χρήστης (`excluded_accounts_{uid}`).
// Καθαρό Dart: καμία Firebase/UI εξάρτηση.
// ============================================================

import 'package:family_economy/providers/accounts_provider.dart';

class AccountTotals {
  AccountTotals._();

  /// Λογαριασμοί που συμμετέχουν στο σύνολο/γράφημα, με σταθερή σειρά.
  static List<AccountModel> counted(
    Iterable<AccountModel> accounts, {
    Set<String> excluded = const <String>{},
  }) {
    return accounts
        .where((a) => a.countsInTotal && !excluded.contains(a.uuid))
        .toList();
  }

  /// Άθροισμα υπολοίπων των λογαριασμών που μετράνε.
  static double sum(
    Iterable<AccountModel> accounts, {
    Set<String> excluded = const <String>{},
  }) {
    return counted(accounts, excluded: excluded)
        .fold<double>(0.0, (total, account) => total + account.currentBalance);
  }
}
