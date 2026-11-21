# Session 18 (2026-11-21) — E26: αρχειοθέτηση λογαριασμού αντί διαγραφής

> **Κεφάλαιο 19/19** · **Ημερομηνία:** 2026-11-21 · **Σχετικά:** E26, E12, E16, E27, commit (βλ. `git log`)

### Πλαίσιο

- Η «διαγραφή λογαριασμού» (E11) έκρυβε **όλες** τις κινήσεις του λογαριασμού και αντέστρεφε το peer σκέλος μιας μεταφοράς. Άρα το ιστορικό εξαφανιζόταν και το συνολικό υπόλοιπο έπεφτε.
- Σενάριο αναφοράς: A=1.500, B=2.000, σύνολο 3.500· διαγραφή A → σύνολο 1.500 (λάθος).
- Επιπλέον: budget που έδειχνε διαγραμμένο λογαριασμό εμφανιζόταν «Όλοι» (E12) και δύο dropdowns είχαν orphan `initialValue` (E16).

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/core/utils/account_delete_guard.dart` | `AccountAction` + `AccountActionDecision` + `decide()` (E26)· `AccountDeletePlan.activeLegCount` / `pendingLegUuids` / `hasAnyTransaction` / `hasPendingScheduled` — υπολογίζονται από τα legs που **ήδη** διαβάζονται (0 νέα reads) |
| `lib/core/utils/account_totals.dart` **(νέο)** | `counted()` / `sum()`: ένα σημείο αλήθειας για το σύνολο (ενεργοί + αρχειοθετημένοι − εξαιρέσεις) |
| `lib/providers/accounts_provider.dart` | `AccountModel.archivedAt` + `countsInTotal` + `isArchived`· `allAccounts` / `archivedAccounts`· `getAccountByUuid` ψάχνει σε `_accounts` (E12/E16) |
| `lib/core/services/transactions_actions_service.dart` | `archiveAccount()` / `restoreArchivedAccount()`: 1 doc update, 0 reads, offline-safe· `archived_at` με client timestamp (σωστό τοπικό snapshot) |
| `lib/presentation/screens/accounts/accounts_page.dart` | Options ανά κατάσταση (Αρχειοθέτηση / Επαναφορά)· `_handleArchiveAccount` με φραγές· διαγραφή μόνο «καθαρού» λογαριασμού, αλλιώς προσφορά αρχειοθέτησης· συμπτυσσόμενη ενότητα «Αρχειοθετημένοι (N)»· σύνολο από `allAccounts` |
| `lib/presentation/screens/budget/input_budget_page.dart` | Το dropdown κρατά τον επιλεγμένο ακόμη κι αν αρχειοθετηθεί (E16) |
| `lib/presentation/screens/transactions/widgets/transaction_edit_sheet.dart` | Ίδιο fix στο dropdown λογαριασμού (E16) |
| `lib/presentation/screens/charts/graf_4_page.dart` | Σύνολο/μπάρες από `allAccounts` + `countsInTotal` (E26)· οι εξαιρέσεις χρήστη παραμένουν ασυμφωνία → **E27** |
| Tests | `account_delete_guard_test.dart` 26→**35**, `account_totals_test.dart` **6 νέα** → σύνολο **130** |
| Docs/version | `DESIGN.md` §1.5/§3/§5.13/§6.2/§7.3/§9, `docs/tables/accounts.md`, `pubspec.yaml` → **2.3.0+7** |

### Κανόνες που υλοποιήθηκαν

- **Διαγραφή** μόνο χωρίς κινήσεις **και** χωρίς budgets· αλλιώς **αρχειοθέτηση** (`is_active=false` + `archived_at`).
- **Φραγές:** τελευταίος ενεργός (όπως E7)· εκκρεμείς προγραμματισμένες (ο executor δεν ελέγχει `is_active`)· αρχειοθετημένος με ιστορικό δεν διαγράφεται.
- `countsInTotal = isActive || archivedAt != null` → οι legacy `is_active=false` **χωρίς** `archived_at` μένουν εκτός (μηδέν migration, ίδιο σύνολο).
- Επιβεβαιώσεις με πραγματικά στοιχεία πριν την υλοποίηση: `_updateAccount` δεν γράφει `is_active`· cleanup δεν αγγίζει `accounts`· rules χωρίς field validation· `BudgetsProvider` διαθέσιμο στο scope της σελίδας.

### Quality gates

- `flutter analyze` → **No issues found**
- `flutter test` → **130/130**
- Device test (POCO X3, `9593c01e`, `demo@yahoo.com`): βλ. `device test/README.md` § E26

### Εκκρεμότητες

- **E27** (νέο): το `graf_4` αγνοεί τις εξαιρέσεις λογαριασμών (χρειάζεται μία πηγή αλήθειας για τις εξαιρέσεις).
- **L25/L26** (`DESIGN.md` §7.3): offline έλεγχος εκκρεμών best-effort· το gate budgets βλέπει μόνο ενεργά budgets.
- E5, E10, E19 παραμένουν στην ουρά (`error_list.md`).

### Backups

- `backups/*_e26_20261121_190651.bak` (13 αρχεία, πριν από κάθε edit).
