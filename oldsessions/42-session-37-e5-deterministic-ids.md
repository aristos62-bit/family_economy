# Session 37 (2026-11-26) — E5: ντετερμινιστικά IDs onboarding & server-truth gate

> **Κεφάλαιο 42/42** · **Ημερομηνία:** 2026-11-26 · **Σχετικά:** E5, E63, E64, `2.3.11+18`, commit `1254fed` (πριν)

### Πλαίσιο

- Συνέχεια από το κεφ. 41· πρώτη εκκρεμότητα στη σειρά: **E5** — offline onboarding σε 2 συσκευές με `onboarding_completed=false` παρήγαγε διπλότυπα (τυχαία doc IDs: 2 accounts, 28 categories, ~190 subcategories).
- Απόφαση χρήστη **1Α**: σταθερά IDs + server-truth gate **και** guards βασισμένα στο `Source.server` (όχι μόνο στα IDs).
- Απόφαση **2Α**: offline onboarding → **καμία εγγραφή**, ορατό μήνυμα, η είσοδος συνεχίζει.
- Απόφαση **3Α**: το `cat-transfer` διορθώνεται μαζί με το E5· το `createUserDocumentIfNeeded` καταγράφεται ως ξεχωριστό **E64** (δεν διορθώνεται τώρα).
- Απόφαση **4Α**: version bump `2.3.11+18` + ενημέρωση `DESIGN.md` / `error_list.md` / κεφαλαίου 42.
- Υλοποίηση αποκλειστικά με edit tool (προστασία ελληνικών)· backups πριν από κάθε αλλαγή.

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/core/data/onboarding_defaults.dart` (νέο) | Καθαρό Dart: σταθερά IDs (`default-account`, `cat-income-1…6`, `cat-expense-1…8`, `sub-N` ανά γονέα, `cat-transfer`) + 14 κατηγορίες / 95 υποκατηγορίες — μία πηγή αλήθειας |
| `test/unit/core/data/onboarding_defaults_test.dart` (νέο) | 18 tests: μοναδικότητα IDs, πλήθη 14/95, σχήμα `cat-income-*`/`cat-expense-*`/`sub-*`, αντιστοίχιση γονέα–παιδιών |
| `lib/services/onboarding_service.dart` | `OnboardingOfflineException` + `_serverTimeout` 8s· ανάγνωση root doc & queries με **`Source.server`**· σταθερά IDs + `SetOptions(merge: true)`· guards κατά overwrite μετονομασμένων docs (σύγκριση και με υπάρχοντα category/subcategory **ids**, fallback σε uuid v4) |
| `lib/presentation/auth/login_page.dart` | Gate επιπέδου 1 (`ConnectivityService.isConfirmedOffline`) πριν το onboarding· `_showOnboardingOfflineNotice()` (overlay μήνυμα + SnackBar 8s + polite announce)· typed catch `OnboardingOfflineException` |
| `lib/presentation/auth/app_start.dart` | Fast offline gate + typed catch στο resume (σιωπηλή αναμονή για την επόμενη εκκίνηση, δεν μπλοκάρει την είσοδο) |
| `lib/core/services/transactions_actions_service.dart` | `_getOrCreateTransferCategory`: σταθερό `OnboardingDefaults.transferCategoryId` + merge (γραμμή ~1133) |
| `lib/services/scheduled_transactions_service.dart` | Ίδιο `cat-transfer` για τις προγραμματισμένες μεταφορές (γραμμή ~787) |
| `pubspec.yaml` | `2.3.10+17` → **`2.3.11+18`** |
| `DESIGN.md` | §0.3 278 tests· §1.1/§1.5.2 version· §2.7 278/278· §3.1 108 Dart/18 test files· §3.2 `onboarding_defaults.dart`· §6.2 E5 note· §8.3 offline exception· §8.4 document-id row· §9.1–§9.3 |
| `error_list.md` | E5 → ✅ FIXED· E63 (transfer) → ✅ FIXED· **E64** → 🔵 OPEN (LOW)· σειρά εκκρεμοτήτων: L23, E64 |

### Επαληθεύσεις (26/11/2026, POCO X3 `9593c01e`)

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | **No issues found** (0/0/0) |
| `flutter test` | **278/278** (260 + 18 νέα) |
| `flutter build apk --debug` | ✅ `app-debug.apk` |
| Fresh account online (D1) | 1 account (`default-account`), **14** categories σταθερά IDs, **95** subcategories — 0 διπλότυπα |
| Idempotent re-run (D1β) | Μετά από kill στο 30% και resume: ίδια 15/95, καμία διπλή εγγραφή |
| Transfer (E63) | Δημιουργήθηκε **1** μόνο `cat-transfer` (έλεγχος σε local cache + server) |
| Offline launch (D2) | Καμία εγγραφή: `document_overlays=0`, `mutations=0`· server flag έμεινε `false`· Home με badge «OFFLINE» |
| Resume online (D3) | `onboarding_completed=true`, 2 accounts, 15 categories, 95 subcategories, 1 transfer category |
| Καθαρισμός | Διαγραφή test account (docs + auth) μέσω REST· το test transfer του demo αφαιρέθηκε και τα balances επανήλθαν (Alfa 11.200, E11-A 1.560) |
| Demo λογαριασμός | Ακέραιος: 3.500 έσοδα / 800 έξοδα εβδομάδας, χωρίς test artifacts |
| Συσκευή | `pm clear` + νέα σύνδεση demo· επιστροφή στην αρχική κατάσταση (airplane off, portrait) |

- Σημείωση: το ορατό μήνυμα offline εμφανίζεται στη ροή **login** (overlay + SnackBar)· στην εκκίνηση με persisted session το gate είναι σιωπηλό (απόφαση: δεν μπλοκάρει την είσοδο). Η offline σύνδεση δεν είναι εφικτή (το `signInWithEmailAndPassword` απαιτεί δίκτυο), άρα το σενάριο επαληθεύτηκε μέσω AppStart.
- Τα PNG των device tests βρίσκονται στο `device test/screenshots/` (untracked) και η σύνοψη στο `device test/E5_device_tests.md`.

### Εκκρεμότητες

- **L23** — θωράκιση μη ταυτοποιήσιμου peer (fail-closed), αμυντικό κενό.
- **E64** (LOW) — `createUserDocumentIfNeeded` τρέχει πριν το gate: offline `set` + poll ~7.5s, χωρίς κίνδυνο διπλότυπων (doc id = uid).
- E55/E60/L11 — INFO/χρέος.

### Backups

- `backups/2026-11-26-e5-deterministic-ids/` — 9 αρχεία (τα 7 τροποποιημένα `.dart`/`pubspec.yaml`, `DESIGN.md`, `error_list.md`).
