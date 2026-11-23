# Session 26 (2026-11-23) — L26: gate budgets στη διαγραφή λογαριασμού

## Πλαίσιο

Το `AccountDeleteGuard.decide` αρχειοθετεί λογαριασμό όταν έχει έστω ένα
budget. Το `budgetsCount` όμως ερχόταν από τον `BudgetsProvider`, του οποίου
ο listener φιλτράρει `deleted=false & is_active=true` → **ανενεργά** και
**legacy** budgets (χωρίς `is_active`) δεν μετριούνταν ποτέ. Αποτέλεσμα:
λογαριασμός με τέτοιο budget μπορούσε να **διαγραφεί**, αφήνοντας orphan
budget που εμφανίζεται «Όλοι» με λάθος spent (ή πουθενά, αν είναι ανενεργό).

Επιπλέον, το φρέσκο preflight πριν τη γραφή **δεν** επαναξιολογούσε την
απόφαση → νέο budget/κίνηση στο μεταξύ διαγραφόταν σιωπηλά (E50).

## Απόφαση

Το L26 είναι **σωστή μέτρηση**, όχι επισκευή δεδομένων:
- καμία αλλαγή σε provider/rules/indexes/schema,
- καμία νέα υπηρεσία — η μέτρηση μπαίνει στο υπάρχον `previewAccountDelete`,
- η αρχειοθέτηση μένει offline-safe (L25) και η διαγραφή φράσσει μόνο όταν
  δεν διαβάστηκαν τα budgets.

## Αλλαγές

| Αρχείο | Τι έγινε |
|---|---|
| `lib/core/utils/account_budget_usage.dart` **(νέο, 63 γρ.)** | `AccountBudgetUsage { total, inactive }` + `count(docs, accountUuid)`: `account_id == uuid`, `deleted != true`, `inactive` όταν `is_active == false`. Διαβάζει **raw maps** (αντέχει σε legacy docs — E53). |
| `lib/core/utils/account_delete_guard.dart` | `AccountDeletePlan` + `budgetsCount` / `inactiveBudgetsCount` / `budgetsUnknown` (defaults 0/0/false)· `buildPlan` τα περνά· ενημερώθηκε το doc του `decide` («όλα τα μη διαγραμμένα»). |
| `lib/core/services/transactions_actions_service.dart` | Στο `previewAccountDelete`: 1 query `budgets where account_id == uuid` (single-field, **κανένα index**) σε δικό του try/catch· αποτυχία → `budgetsUnknown=true` (δεν ρίχνει το preflight). Debug log gate. |
| `lib/presentation/screens/accounts/accounts_page.dart` | Κατάργηση `_activeBudgetsFor` + import `budgets_provider`· `decide` με `plan.budgetsCount`· φραγή διαγραφής αν `budgetsUnknown`· **επαναξιολόγηση** μετά το φρέσκο preflight (E50)· μήνυμα αρχειοθετημένου «X κινήσεις, Y προϋπολογισμοί»· διάλογος «N προϋπολογισμοί (M ανενεργοί)»· `_showArchiveBlockedDialog(title:)`· ακριβές μήνυμα σφάλματος ανάγνωσης. |
| `pubspec.yaml` | `2.3.5+12` → **`2.3.6+13`** (PATCH). |
| `test/unit/core/utils/account_budget_usage_test.dart` **(νέο)** | 13 tests (deleted/legacy/null/άλλος λογαριασμός/ανενεργό/μικτό/trim/κενά). |
| `test/unit/core/utils/account_delete_guard_test.dart` | +3 tests (defaults, μεταφορά πεδίων, budgets-only → archive). |

## Ροή μετά την αλλαγή

1. Offline gate (E24) → διαγραφή απαιτεί σύνδεση.
2. `previewAccountDelete`: κινήσεις + **budgets** (serverAndCache) → πλάνο.
3. `decide`: καθαρός → delete· αλλιώς archive· φραγές (τελευταίος/εκκρεμείς).
4. `budgetsUnknown` + απόφαση delete → **φραγή** («Διαγραφή μη διαθέσιμη»).
5. Επιβεβαίωση → **φρέσκο** preflight → **νέο `decide`**: αν δεν βγαίνει
   delete ή αν unknown → ματαίωση, **καμία εγγραφή**.
6. Εφαρμογή batch/chunks (αμετάβλητη).

## Edge cases / αποφάσεις

- Ανενεργό ή legacy budget → **αρχειοθέτηση** (αναστρέψιμη, κανένα orphan).
- Budget «Όλοι» (`account_id = null`) → δεν μετράει (σωστά).
- Soft-deleted budget → εκτός (αόρατο + purgeable).
- Legacy χωρίς `deleted` → **μέσα** (συντηρητικό· ο καθαρισμός το purga με `end_date`).
- `budgetsUnknown` → φράσσει **μόνο** τη διαγραφή· η αρχειοθέτηση προχωρά.
- Υπολειπόμενο ρίσκο: παράθυρο preflight→commit (ίδια κλάση με L27/L29).

## Νέα ευρήματα

- **E50** (FIXED εδώ): καμία επαναξιολόγηση μετά το φρέσκο preflight.
- **E51** (INFO): ανενεργά budgets αόρατα σε όλη την εφαρμογή.
- **E52** (INFO): legacy budgets χωρίς `is_active`/`deleted` αόρατα.
- **E53** (LOW): `BudgetModel.fromFirestore` `amount as num` → legacy doc ρίχνει τον listener.

## Quality gates

- `flutter analyze` → **No issues found**.
- `flutter test` → **238/238** (222 + 13 + 3).
- Device tests (POCO X3, demo@yahoo.com): βλ. `device test/` και §επόμενο.

## Backups

`backups/`: `account_delete_guard_*`, `transactions_actions_service_*`,
`accounts_page_*`, `account_delete_guard_test_*`, `pubspec_*`, `DESIGN_*`,
`error_list_*`, `oldsessions_*` (timestamp `20261123_190701`).

## Docs

- `DESIGN.md` §1/§3/§9 (έκδοση, 238 tests), §5.13 (νέα γραμμή gate budgets),
  §11 L26 → ✅ διορθώθηκε.
- `error_list.md`: σειρά εκκρεμοτήτων χωρίς L26· E50–E53 + λεπτομέρειες.
