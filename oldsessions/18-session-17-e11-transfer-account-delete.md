# Session 17 (2026-11-21) — E11: διαγραφή λογαριασμού που μετέχει σε μεταφορά

> **Κεφάλαιο 18/18** · **Ημερομηνία:** 2026-11-21 · **Σχετικά:** E11, E13, E24, E23, `2.2.0+6`, commit `1b5eabc`

### Πλαίσιο

- Το `_deleteAccount` (E7) έκρυβε μόνο τα docs με `account_id == uuid`. Σε μεταφορά το άλλο σκέλος ανήκει στον **peer** λογαριασμό → έμενε ενεργό και το ποσό παρέμενε στο peer υπόλοιπο χωρίς «ταιριαστό» σκέλος.
- Απόφαση (D2): η διαγραφή λογαριασμού **ακυρώνει ολόκληρο το ζεύγος** με την ίδια σημασιολογία όπως η διαγραφή μεταφοράς (αντιστροφή υπολοίπων), ώστε να μην υπάρχουν μισά ζεύγη.
- Η επαναφορά λογαριασμού έπρεπε να είναι **συμμετρική**: να επιστρέφει μόνο ό,τι ακύρωσε η διαγραφή, όχι ό,τι διέγραψε ο χρήστης.
- Παράλληλα κλείστηκαν το **E13** (restore >499 writes σε ένα batch) και το **E24** (offline διαγραφή με ατελή cache).

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/core/utils/account_delete_guard.dart` | `AccountDeletePlan` / `TransferAnnulmentPair` / chunks ≤499 writes / `peerDeltas` / `TransferRestoreUnit` + `buildRestoreUnits` (καθαρή λογική, 0 reads) |
| `lib/core/services/transactions_actions_service.dart` | `previewAccountDelete` (0 reads για peer δείκτες) + `applyAccountDeletePlan` (ένα batch ή plain chunks → pair chunks με deltas ανά chunk → λογαριασμός **τελευταίος**) |
| `lib/presentation/screens/accounts/accounts_page.dart` | Φραγή offline πριν το preflight· διάλογος με επίπτωση μεταφορών (ολοκληρωμένες/εκκρεμείς)· φρέσκο preflight πριν τη γραφή |
| `lib/services/scheduled_transactions_service.dart` | Peer πεδία (`transfer_peer_uuid`, `transfer_peer_account_id`) στο `createScheduledTransfer` + `_isTransferPairIntact` πριν το balance check του executor |
| `lib/services/account_duplicate_service.dart` | `restoreAccountWithBalance` από την αρχή: restore units, marked legs, chunking ≤499, deltas μόνο για ολοκληρωμένα, `FieldValue.delete()` του marker |
| `test/unit/core/utils/account_delete_guard_test.dart` | 8 → **26** tests (πλάνο, chunks, restore units, αναστροφή deltas) |
| `pubspec.yaml` · `DESIGN.md` | `2.2.0+6`· §1.5.2, §5.13, §6.2, §8.1, §9, §11 L22–L24 |

### Κανόνες που υλοποιήθηκαν

- **Ολοκληρωμένο ζεύγος** → κρύψιμο 2 legs + 2 deltas (επιστροφή ποσού σε κάθε πλευρά).
- **Εκκρεμές ζεύγος** → κρύψιμο 2 legs, **0 deltas** (δεν είχαν επηρεάσει υπόλοιπα).
- **Μερικό/άγνωστο** → κρύψιμο μόνο του ενεργού leg, 0 deltas, **χωρίς** marker.
- Marker `annulled_by_account_deleted` σε κάθε πλήρως ακυρωμένο leg → η επαναφορά ξέρει τι να επαναφέρει.
- Ένα ζεύγος = **ένα** batch· deltas **ανά chunk** (σωστό retry)· όριο **499 writes**· λογαριασμός τελευταίος.
- Offline: `ConnectivityService.isInitialized && isOffline` → φραγή με μήνυμα, πριν από κάθε ανάγνωση/εγγραφή.
- Executor: αν το ζεύγος δεν είναι ακέραιο → **skip + log** (όχι `execution_failed`, γιατί ο διάλογος του `home_page` είναι blocking).

### Device tests (POCO X3 NFC, API 31, `9593c01e`)

Έκδοση `2.2.0+6` (versionName 2.2.0 / versionCode 6), portrait, χρήστης **demo@yahoo.com**. Τα δεδομένα δοκιμής **δεν** καθαρίστηκαν (οδηγία χρήστη).

| # | Σενάριο | Αποτέλεσμα |
|---|---|---|
| 1 | Δημιουργία `E11-A` 1.000,00 € και `E11-B` 500,00 € από το UI | ✅ `e11_25`, `e11_29` |
| 2 | Ολοκληρωμένη μεταφορά 200 A→B | ✅ A 800,00 / B 700,00 (`e11_38`) |
| 3 | Διαγραφή B → διάλογος με προειδοποίηση «1 ολοκληρωμένες…» | ✅ `e11_40` |
| 4 | Μετά τη διαγραφή: A 1.000,00, B κρυφό· Firestore 2 legs `deleted=true` με marker B | ✅ `e11_41` |
| 5 | Επαναφορά B «Με Υπόλοιπο» | ✅ A 800,00 / B 700,00· marker καθαρίστηκε, `deleted=false` (`e11_44`, `e11_45`, `e11_60`) |
| 6 | Εκκρεμής μεταφορά 50 (25/11) → διαγραφή A: διάλογος «1 ολοκληρωμένες + 1 εκκρεμείς» | ✅ `e11_55` |
| 7 | Μετά τη διαγραφή: B 500,00, Π.Κ. κενή· legs `deleted=true` με marker A, `is_executed=false` | ✅ `e11_57` |
| 8 | Επαναφορά A → ζεύγη πίσω· Π.Κ. ξανά με τη μεταφορά 50, marker καθαρισμένος | ✅ `e11_60`, `e11_61` |
| 9 | Offline (airplane mode) → διαγραφή | ✅ κόκκινο snackbar «Η διαγραφή λογαριασμού απαιτεί σύνδεση στο internet», καμία εγγραφή (`e11_79`) |

**Επιπλέον παρατηρήσεις από τη συσκευή:**

- Η λίστα «Προγραμματισμένες Κινήσεις» δείχνει **2 γραμμές** για 1 εκκρεμή μεταφορά → επιβεβαιώθηκε το γνωστό **E23** (ℹ️ INFO, `getScheduledTransactions` χωρίς dedupe ανά `transfer_group_id`).
- Κατά τη διάρκεια των tests εκτελέστηκε και μία κανονική μεταφορά 50 A→B (ομάδα `df683c37`) → υπόλοιπα 750,00/750,00. Έμεινε ως δεδομένο demo.
- `uiautomator dump` εμφανίζει `MiuiFreeform`/theme warning αλλά γράφει κανονικά το XML· τα ελληνικά στο console διαβάζονται UTF-8 (νέο helper `device test/tools/e11_ui.ps1`).

### Quality gates

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | ✅ No issues found (83,6s, επανέλεγχος πριν το commit) |
| `flutter test` | ✅ **115/115** (97 + 18 νέα) |
| `flutter build apk --release` | ✅ APK 85,5 MB· εγκατάσταση με `adb install -r` |

### Τι **δεν** άλλαξε

- Καμία αλλαγή σε indexes/rules· όλες οι νέες αναγνώσεις είναι equality-only (E17 δεν μπλοκάρει).
- `deleteTransaction` peer path (E18) έμεινε ως έχει — ℹ️ INFO.
- Ο πραγματικός χρήστης «Alfa» (12.610,00 €) δεν αγγίχτηκε· ο demo λογαριασμός δεν διαγράφηκε.

### Backups

`backups/`: `20261120_213237` (5 αρχεία κώδικα + test + `DESIGN` + `oldsessions` + `pubspec`), `error_list_20261120_212755.bak`, `error_list_20261121_112454.bak`, `oldsessions_20261121_112454.bak`, `device_test_README_20261121_112454.bak`.
