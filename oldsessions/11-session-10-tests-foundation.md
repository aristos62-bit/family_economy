# Session 10 (2026-10-02)

> **Κεφάλαιο 11/16** · **Ημερομηνία:** 2026-10-02 · **Πηγή:** `oldsessions.md` γρ. 223–244 (αρχείο πριν το refactor της 2026-11-20)

---

### Tests Βήμα 0+1 ✅ — 19/19 pass
- Baseline: `flutter test` FAIL (σπασμένο counter `widget_test.dart`, `ProviderNotFound`)
- Νέα δομή `test/unit/` (καθρέφτης του `lib/`): `currency_formatter_test.dart` (9 tests) + `chart_helpers_test.dart` (9 tests), pure-Dart χωρίς Firebase
- `widget_test.dart`: αντικατάσταση με `ErrorApp` smoke test (χωρίς tap στο restart — θέλει Phoenix ancestor)
- Backup: `backups/widget_test_20261002_124058.bak`

### Tests Βήμα 2 ✅ — 33/33 pass
- `test/unit/providers/transactions_provider_test.dart` (6 tests): `isTransfer/isIncome/isExpense`
- `test/unit/models/budget_model_test.dart` (8 tests): `matchesTransaction` (category/subcategory/total/account/inclusive όρια)
- Εύρημα: 1 αποτυχία από λάθος παραδοχή του test (πέρασε `'income'` με null id — ο provider περνά null resolved type, `transactions_provider.dart:400`). Ο κώδικας σωστός, διορθώθηκε το test

### Tests Βήμα 3 ✅ — 44/44 pass
- Νέο `lib/core/utils/monthly_trend.dart`: pure `computeMonthlyTrend` (εξαγωγή από Graf7, ίδια συμπεριφορά)
- `graf_7_monthly_trend_page.dart`: 446 γραμμές (<500), `_computeMonthly` → delegate, `_MonthPoint` → `MonthlyPoint`
- `test/unit/core/utils/monthly_trend_test.dart` (11 tests): zeros, abs sums, +50%, 0→X +100%, X→0 −100%, φίλτρα transfer/category/year/subcategory

### Tests — Firebase mocks ΑΝΑΒΟΛΗ
- Έλεγχος: `fake_cloud_firestore 4.3.0` + `firebase_auth_mocks 0.15.2` συμβατά, αλλά φέρνουν firebase_core 4.5→4.15 / firestore 6.1→6.10 / auth 6.2→6.7 (24 αλλαγές lock) + 93 σημεία καλούν singletons απευθείας (μόνο BudgetsProvider/TransactionsActionsService injectable)
- Απόφαση: αναβολή (ρίσκο/όφελος δεν βγαίνει). Παραμένουν 44 hermetic tests + manual QA. Dry-run only, καμία αλλαγή pubspec
