# 57 — E100: φραγή αποθήκευσης διάταξης πριν την ανάγνωση

> **Ημερομηνία:** 28/11/2026 · **Session:** 50 · **Έκδοση:** `2.3.19+26` (χωρίς version bump)
> **Σχετικά:** E100 · E94 (refresh διάταξης)

## Πλαίσιο

Ο χρήστης εντόπισε θεωρητικό κίνδυνο στον editor διάταξης (`view_option_page.dart`): αν λήξει το όριο των 2″ της `ChartLayoutPrefs.loadWithin`, εφαρμοζόταν το `fallback()` και μια αποθήκευση θα έγραφε προεπιλογές πάνω από την πραγματική διάταξη.

Η έρευνα έδειξε ότι το κενό ήταν ευρύτερο:

| # | Διαδρομή | Αποτέλεσμα |
|---|---|---|
| 1 | Αποθήκευση πριν ολοκληρωθεί η ανάγνωση (η λίστα ξεκινά με προεπιλογές στο `initState`, το κουμπί είναι ενεργό από το πρώτο frame) | εγγραφή προεπιλογών |
| 2 | Μετά το timeout 2″ → `loadWithin` επιστρέφει `null` → `fallback()` | εγγραφή προεπιλογών |
| 3 | Drag ή toggle ορατότητας → άμεσο `_saveOrderAndVisibilityOnly` | εγγραφή προεπιλογών χωρίς «Αποθήκευση» |

Το #2 ήταν αυτό που περιέγραψε ο χρήστης· τα #1 και #3 δεν χρειάζονταν καν timeout.

## Διόρθωση

Νέο gate `_layoutLoaded` — γίνεται `true` **μόνο** μετά από επιτυχή ανάγνωση:

- `_loadPreferences`: καμία χρήση `fallback()`· σε `null` → `_layoutLoadFailed` και τίποτα άλλο.
- «Αποθήκευση» disabled μέχρι να φορτώσει· disabled και drag/toggle/περίοδος.
- Μήνυμα «Φόρτωση διάταξης…»· σε αποτυχία «Δεν φορτώθηκε η διάταξη. Δεν γίνεται αποθήκευση.» + «Δοκιμάστε ξανά».
- Αμυντικοί έλεγχοι `if (!_layoutLoaded) return;` στις `_savePreferences`, `_saveOrderAndVisibilityOnly`, `_saveChartPeriod`.
- Το `_saveAndReturn` αποσπάστηκε από το `onPressed`· το `Semantics` πήρε `enabled: _layoutLoaded` για σωστή ανακοίνωση από TalkBack.

| Αρχείο | Αλλαγή |
|---|---|
| `lib/presentation/screens/charts/view_option_page.dart` | gate ανάγνωσης/εγγραφής + disabled καταστάσεις + retry |

Δεν άλλαξαν: το όριο 2″, τα prefs keys, η `GeneralViewPage` (fallback μόνο για εμφάνιση), το `ChartLayoutPrefs`.

## Quality gates

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | ✅ No issues found (0/0/0) |
| `flutter test` (πλήρες) | ✅ **400/400** |
| `git diff --check` | ✅ καθαρό |

## Device test (POCO X3 NFC, Android 12)

| Έλεγχος | Αποτέλεσμα |
|---|---|
| Άνοιγμα editor → στιγμιαίο «Φόρτωση διάταξης…» → πραγματική διάταξη | ✅ |
| Αλλαγή σειράς/ορατότητας/περιόδου → «Αποθήκευση & Επιστροφή» | ✅ οι αλλαγές διατηρούνται |
| Επιστροφή στη Γενική εικόνα μετά την αποθήκευση | ✅ σωστή σειρά/ορατότητα |

## Backups

- `backups/2026-11-28-e100-layout-save-guard/` — `view_option_page.dart`, `error_list.md` (πριν το E100).
- `backups/2026-11-28-e100-docs/` — `error_list.md`, `oldsessions.md` (πριν τη συμπλήρωση).

## Σημειώσεις

- Καμία αλλαγή σε `DESIGN.md`: συμπεριφορά UI, όχι αρχιτεκτονική.
- Καμία αλλαγή έκδοσης (`2.3.19+26`).
- Καμία ανοιχτή εκκρεμότητα στο `error_list.md`.
