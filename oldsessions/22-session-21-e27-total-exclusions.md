# Session 21 (2026-11-22) — E27: ενιαίο σύνολο λογαριασμών

> **Κεφάλαιο 22/22** · **Ημερομηνία:** 2026-11-22 · **Έκδοση:** `2.3.3+10` (PATCH) · **Εύρημα:** E27

## Στόχος

Το γράφημα «Υπόλοιπα Λογαριασμών» (`graf_4`, εμφανίζεται και στην Αρχική) αγνοούσε
τις εξαιρέσεις λογαριασμών (`excluded_accounts_{uid}`) που εφαρμόζει η σελίδα
Λογαριασμών → δύο διαφορετικά «Συνολικά Υπόλοιπα» στην ίδια εφαρμογή.

## Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/providers/accounts_provider.dart` | Οι εξαιρέσεις γίνονται κατάσταση του provider: `excludedAccountUuids` (unmodifiable αντίγραφο), `isExcludedFromTotal`, `setExcludedFromTotal(uuid, {excluded})` — idempotent, ποτέ δεν πετάει· φόρτωση μία φορά ανά σύνδεση (`unawaited`, guards για κενό uid/`_disposed`, `try/catch`)· αποθήκευση στο **ίδιο** κλειδί `excluded_accounts_{uid}` (ταξινομημένη λίστα) |
| `lib/presentation/screens/accounts/accounts_page.dart` | Αφαιρέθηκαν `_excludedAccountUuids`, `_loadExcludedAccounts`, `_saveExcludedAccounts` και το `shared_preferences` import· το σύνολο, το checkbox και η διαγραφή διαβάζουν/γράφουν τον provider· ο provider κρατιέται **πριν** από τα async gaps στη διαγραφή (lint `use_build_context_synchronously`) |
| `lib/presentation/screens/charts/graf_4_page.dart` | `AccountTotals.counted/sum` με `excluded: provider.excludedAccountUuids`· το σύνολο υπολογίζεται από την **ίδια** λίστα με τις μπάρες· νέο κενό state «Όλοι οι λογαριασμοί είναι εξαιρεμένοι» (ξεχωριστά από «Δεν υπάρχουν λογαριασμοί»)· semantics/ανακοίνωση με πλήθος εξαιρεθέντων |
| `test/unit/core/utils/account_totals_test.dart` | +1 test: «όλοι εξαιρεμένοι → κενή λίστα και σύνολο μηδέν» |
| `pubspec.yaml` | `2.3.2+9` → **`2.3.3+10`** |

## Αποφάσεις

1. **Μία πηγή αλήθειας:** οι εξαιρέσεις ζουν στον `AccountsProvider` (όχι στο State της σελίδας) — έτσι τις βλέπουν και οι δύο οθόνες και επιβιώνουν όταν αλλάζει tab/route.
2. **Καμία νέα λογική υπολογισμού:** επαναχρησιμοποιείται το υπάρχον `core/utils/account_totals.dart` (E26). Δεν προστέθηκαν `countedAccounts`/`totalBalance` στον provider για να **αποφευχθεί κυκλικό import** (`accounts_provider.dart → account_totals.dart → accounts_provider.dart` για το `AccountModel`).
3. **Idempotent setter αντί toggle:** `setExcludedFromTotal(uuid, {excluded})` — ασφαλές σε διπλό πάτημα/επαναλαμβανόμενα events (μάθημα E20-6).
4. **Καμία αυτόματη εκκαθάριση UUIDs:** offline/μερικό cache θα μπορούσε να «σβήσει» τις προτιμήσεις· ο καθαρισμός γίνεται μόνο στην επιβεβαιωμένη διαγραφή λογαριασμού (ίδια συμπεριφορά με E7-7).
5. **Τοπική προτίμηση:** παραμένει ανά συσκευή (δεν συγχρονίζεται) — καταγράφεται ως **L28**· το ίδιο L28 καλύπτει και τον αρχειοθετημένο+εξαιρεμένο λογαριασμό (χωρίς checkbox, μόνο «Επαναφορά»).
6. **Διόρθωση τεκμηρίωσης:** το `error_list.md` περιέγραφε λάθος το `graf_4` ως `accountsProvider.accounts`/«όλα τα υπόλοιπα» — στην πραγματικότητα (μετά το E26) χρησιμοποιεί `allAccounts` + `countsInTotal`. Το `DESIGN.md` §5.8 έλεγε «εκτός στατιστικών» ενώ οι εξαιρέσεις αφορούν **μόνο** σύνολο/γράφημα.

## Παρενέργειες που ελέγχθηκαν

- `graf_4` κάνει `context.watch<AccountsProvider>()` → rebuild ακόμη και με το `_chartCache` του `general_view_page`.
- Τα χρώματα των μπαρών βγαίνουν από το **πρόσημο**, όχι από index → καμία «μετατόπιση» όταν φεύγει λογαριασμός.
- Provider instances στα `options_page` (Stats) είναι ξεχωριστά αλλά **δεν** δείχνουν σύνολο/γράφημα → καμία ασυμφωνία· μόνο 1 τοπική ανάγνωση prefs.
- Μηδέν Firestore reads/writes· E20/E26/E28/budget/stats ανέγγιχτα.
- Η αποτυχία αποθήκευσης prefs **δεν** εμφανίζεται πλέον ως «Σφάλμα Διαγραφής» μετά από επιτυχημένη διαγραφή (το `setExcludedFromTotal` δεν πετάει).

## Quality gates

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **152/152** |
| Baseline πριν την αλλαγή | analyze clean · 151/151 |

## Backups

`backups/accounts_provider_20261122_183228.bak`, `accounts_page_20261122_183228.bak`,
`graf_4_page_20261122_183228.bak`, `account_totals_test_20261122_183228.bak`,
`pubspec_20261122_183228.bak`, `error_list_20261122_183228.bak`,
`DESIGN_20261122_183228.bak`, `oldsessions_20261122_183228.bak`.

## Device tests (POCO X3 NFC, API 31)

`flutter build apk --debug --target-platform android-arm64` → `adb install -r` (2.3.2+9 → **2.3.3+10**).

| # | Σενάριο | Αποτέλεσμα |
|---|---|---|
| E27-1 | Εξαίρεση `E26-B` (2.500,00 €) | ✅ **14.760,00 €** σε Λογαριασμούς **και** γράφημα· το `E26-B` εξαφανίστηκε από τις μπάρες |
| E27-2 | Επαναφορά τσεκ | ✅ **17.260,00 €** και στις δύο οθόνες |
| E27-3 | Force-stop → επανεκκίνηση | ✅ Η εξαίρεση επιβιώνει (unchecked, 14.760,00 €) — μηδέν Firestore |
| E27-4 | Εξαίρεση όλων των ενεργών | ✅ **1.500,00 €**, μόνο ο αρχειοθετημένος `E26-A` στο γράφημα |
| E27-5 | Εξαίρεση και του αρχειοθετημένου (δοκιμαστικά via prefs) | ✅ **0,00 €** + «Όλοι οι λογαριασμοί είναι εξαιρεμένοι» |
| E27-6 | Επαναφορά prefs | ✅ **17.260,00 €**, 4 μπάρες, όλα τα τσεκ ενεργά |

REST πριν/μετά: `accounts=9`, `active=4`, `transactions=99` (καμία εγγραφή). Στοιχεία:
`device test/README.md` § E27, screenshots `e27_*`. Καθαρισμός: αφαίρεση κλειδιού
`excluded_accounts_{uid}`, `/sdcard/window_dump.xml`, `/data/local/tmp/e27_prefs*.xml`, force-stop,
`font_scale 1.0`· demo user και δεδομένα ανέπαφα.
