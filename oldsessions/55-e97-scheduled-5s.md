# 55 — E97: μήνυμα προγραμματισμένων κινήσεων 5″

> **Ημερομηνία:** 28/11/2026 · **Session:** 48 · **Έκδοση:** `2.3.19+26` (χωρίς version bump)
> **Σχετικά:** E97 · επαλήθευση deployed rules (SEC-006b)

## Πλαίσιο

Η ειδοποίηση «Εκτελέστηκε/Εκτελέστηκαν … προγραμματισμένες κινήσεις» έκλεινε σε **3″** αντί για **5″**. Η κλήση `AppMessenger.info` στο `home_page.dart` δεν περνούσε `duration`, οπότε ίσχυε το `MessagePolicy.infoDuration` (3″). Δεν ήταν regression του L11: και το παλιό `SnackBar` είχε 3″.

## Αλλαγή

| Αρχείο | Αλλαγή |
|---|---|
| `lib/presentation/screens/home/home_page.dart` | `duration: const Duration(seconds: 5)` στη μία κλήση του `_showScheduledTransactionsNotification` |

Καλύπτει και τον έλεγχο εκκίνησης (`_checkStartupExecutions`) και τον ωριαίο (`_checkScheduledTransactions`). Το global `MessagePolicy` μένει ως έχει (success/info 3″, warning 5″, error 6″), ώστε να μην αλλάξουν τα άλλα info μηνύματα. Το `persist: false` παραμένει: το μήνυμα κλείνει μόνο του στα 5″ ή με «ΟΚ».

## Quality gates

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | ✅ No issues found (0/0/0) |
| `flutter test` (πλήρες) | ✅ **400/400** |
| `git diff --check` | ✅ καθαρό |

## Device tests (POCO X3 NFC, Android 12)

| Έλεγχος | Αποτέλεσμα |
|---|---|
| E97: εκτέλεση προγραμματισμένης κίνησης → μήνυμα | ✅ μένει ~5″ και κλείνει μόνο του/με «ΟΚ» |
| E96: νέος λογαριασμός με κακό δίκτυο → κανένα ψευδές μήνυμα | ✅ (επιβεβαίωση χρήστη 28/11/2026 — ήταν εκκρεμές στο κεφ. 54) |

## Επαλήθευση deployed rules (ερώτηση για κεφ. 52)

Το κεφάλαιο 52 **δεν καταγράφει** `firebase deploy`, αλλά ο έλεγχος στο Firebase Rules API έδειξε:

- Release: `projects/family-economy-d1b4d/releases/cloud.firestore`
- Ruleset: `f89f2943-c206-4a69-bd52-134e4cb42ef7`
- `updateTime`: `2026-11-28T12:24:50Z` (14:24:50 τοπική — 16″ μετά το commit `6d44c64`)
- Το deployed αρχείο είναι **byte-identical** με το repo (`SHA256 65FB9704…D859E`, 139 γραμμές) και περιέχει `parentActive()` / `SEC-006b`.

Άρα το SEC-006b είναι ενεργό στην παραγωγή· λείπει μόνο η καταγραφή του deploy από το κεφ. 52 (docs gap, όχι λειτουργικό).

## Backups

- `backups/2026-11-28-e97-scheduled-5s/` — `home_page.dart`, `error_list.md` (πριν το E97).
- `backups/2026-11-28-e97-docs/` — `error_list.md`, `oldsessions.md` (πριν τη συμπλήρωση).

## Εκκρεμότητες

- Καμία ανοιχτή στο `error_list.md`.
