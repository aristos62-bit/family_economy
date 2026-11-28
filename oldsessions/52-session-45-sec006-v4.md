# 52 — SEC-005c / SEC-006a / SEC-006b / E90–E92: ασφάλεια διαγραφής & διάλογοι

> **Ημερομηνία:** 28/11/2026 · **Session:** 45 · **Έκδοση:** `2.3.19+26` (PATCH)
> **Πηγή:** τελική πρόταση v4 του suggestions-agent (D1=B, D2=A, D3=B) — εγκρίθηκε ολόκληρη.

## Τι έγινε

Υλοποιήθηκαν μαζί τα 6 ευρήματα με τη σειρά **SEC-005c → SEC-006a → E90 → E91 → SEC-006b**, με backups στο `backups/2026-11-28-sec006-v4/`.

### SEC-005c — marker με επιβεβαίωση server

- **Πρόβλημα:** το `.timeout(20s)` στο `_writeMarker()` δεν ακυρώνει το write· σε timeout η διαγραφή δήλωνε αποτυχία, αλλά ο marker μπορούσε να γραφτεί αργότερα και να κλειδώσει τον λογαριασμό.
- **Λύση:** `_writeMarkerConfirmed()` — `runTransaction` + `Transaction.set(merge:true)` (δεν μπαίνει στην offline ουρά) και, σε timeout/σφάλμα, μία **server read** (`Source.server`) που επιστρέφει `true` μόνο αν το `deleted` είναι όντως `true`.
- Ο restore marker του SEC-005b (`_writeMarker()`) μένει **queued επίτηδες**: πρέπει να επιβιώσει restart/offline.
- Καμία νέα pure test (είναι I/O)· device test με airplane mode.

### SEC-006a — guard δεύτερης συσκευής

- **Πρόβλημα:** κανένας listener στο root doc· δεύτερη συσκευή με παλιό cache συνέχιζε να γράφει μετά τη διαγραφή.
- **Νέο pure:** `core/utils/deletion_guard_policy.dart` — `fromCache || hasPendingWrites` → `ignore`· server-confirmed `!exists || deleted` → `lock`.
- **Νέο service:** `core/services/deletion_guard_service.dart` — listener `users/{uid}`, `attach/suspend/resume/detach`, μία εκτέλεση ανά συνεδρία· lock = `cancelAllNotifications` (best effort) → `signOut` → `onLocked` (ορίζεται στο `main.dart` με τον `navigatorKey`) → σελίδα σύνδεσης με `AccountDeletionPolicy.remoteDeletionMessage`.
- **Σύνδεση:** `app_start.dart` (μετά το `ensureUserDocument`, πριν το βιομετρικό/scheduled) και `login_page.dart` (μετά το `ensureUserDocument`, πριν το onboarding).
- **Αναστολή:** `delete_account_page._performDelete` και `login_page._handlePendingDeletion` κάνουν `suspend()` πριν το cascade και `resume()` (ή `detach()` αν αποσυνδεθεί) στο τέλος — αλλιώς το root delete προκαλεί διπλή πλοήγηση/signOut.
- Γιατί όχι blocking startup read: θα χαλούσε το «cache hit = 0 δίκτυο» του E64· ο κανόνας SEC-006b κλείνει το παράθυρο.

### E90 — διάλογος κωδικού

- Νέο `core/widgets/account_password_dialog.dart`: inline `errorText`, μένει ανοιχτός σε κενό, έλεγχος και στο submit, επιστρέφει **raw** κείμενο.
- Το `delete_account_page` το χρησιμοποιεί· το `trim()` έμεινε μόνο για τον έλεγχο κενού· αφαιρέθηκε το info dialog.

### E91 — ορατότητα σφάλματος υπενθύμισης

- `GlobalKey` στο πεδίο μηνύματος και στο `_stopError`· μετά από κάθε αποτυχία validation → `Scrollable.ensureVisible` (post-frame, 250 ms).
- Αφαιρέθηκε ο νεκρός κλάδος `mo < 1`· τα βήματα +/- καθαρίζουν το `_stopError`.

### SEC-006b — rules guard γονέα

- `firestore.rules`: helper `parentActive()` = `exists(users/{uid})` && `get(...).data.get('deleted', false) != true`, **μόνο σε `create`** σε όλες τις υποσυλλογές (και στο recursive wildcard των categories).
- Γιατί create-only: τα updates σε διαγραμμένα docs αποτυγχάνουν με not-found· το cascade delete πρέπει να μείνει ελεύθερο· τα batched writes έχουν όριο **20 access calls**.
- `settings`: read/delete χωριστά από create/update.
- Emulator tests: `tools/rules_test/firestore.rules.test.js` + `npm run test:rules` (6/6 PASS: ενεργός γονέας allow, `deleted:true` deny, missing parent deny, cascade delete allow, root create allow, ξένο uid deny).
- Προστέθηκε `@firebase/rules-unit-testing` (devDependency) — τα `node_modules/` μένουν ignored.

## Quality gates

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | ✅ No issues found (0/0/0) |
| `flutter test` | ✅ **388/388** (374 + 14 νέα) |
| `npm run test:rules` | ✅ 6/6 checks passed |
| Device tests POCO X3 | βλ. παρακάτω |

## Νέα tests

| Αρχείο | Πλήθος | Τι καλύπτει |
|---|---|---|
| `test/unit/core/utils/deletion_guard_policy_test.dart` | 7 | cache/pending → ignore· server-confirmed missing/`deleted:true` → lock |
| `test/unit/core/widgets/account_password_dialog_test.dart` | 4 | κενό → inline σφάλμα, raw κωδικός, Άκυρο → null, καθαρισμός σφάλματος |
| `test/unit/core/widgets/notification_edit_dialog_test.dart` | 3 | κενό μήνυμα, έγκυρο μήνυμα, μικρή οθόνη → ορατό σφάλμα |

## Αρχεία

- **Νέα:** `deletion_guard_policy.dart`, `deletion_guard_service.dart`, `account_password_dialog.dart`, 3 test αρχεία, `tools/rules_test/firestore.rules.test.js`.
- **Τροποποιήθηκαν:** `account_deletion_service.dart`, `account_deletion_policy.dart`, `delete_account_page.dart`, `login_page.dart`, `app_start.dart`, `main.dart`, `notification_edit_dialog.dart`, `firestore.rules`, `package.json`/`package-lock.json`, `pubspec.yaml`, `DESIGN.md`, `error_list.md`.
- **Backups:** `backups/2026-11-28-sec006-v4/` (12 αρχεία + `package*.json`).

## Αποφάσεις / εκτός scope

- **E93** (`trim()` στον κωδικό σε login/change) μένει ⏳ OPEN (LOW) — καταγράφηκε, δεν διορθώθηκε εδώ.
- **E92** διαλύθηκε μέσα στα E90/E91 (κάθε fix έφερε το behavior test του).
- Residual του SEC-005b: αν χαθεί το restore marker, νέο login ξαναδημιουργεί κενό doc — στενό παράθυρο, παραμένει γνωστό.

## Device tests (POCO X3 NFC, Android 12)

Release `2.3.19+26` εγκατεστημένο με `adb install -r`· screenshots `device test/screenshots/sec006_*`.

| # | Έλεγχος | Αποτέλεσμα |
|---|---|---|
| 1 | Smoke demo: νέα έξοδος 1,00 € (Alfa / Διατροφή / Σούπερ Μάρκετ) → αποθήκευση | ✅ PASS — το create περνά με το `parentActive()` (create-only) |
| 2 | Διαγραφή ίδιας κίνησης από «Κινήσεις» | ✅ PASS — εξαφανίστηκε, υπόλοιπα/σύνολα επανήλθαν (Έξοδα 1.347,00 €) |
| 3 | E90 — κενός κωδικός | ✅ PASS — inline «Συμπληρώστε τον κωδικό πρόσβασης.», ο διάλογος μένει ανοιχτός |
| 4 | E90 — λάθος κωδικός | ✅ PASS — «Αποτυχία διαγραφής / Λάθος email ή κωδικός πρόσβασης», καμία διαγραφή |
| 5 | E90 — Άκυρο | ✅ PASS — επιστροφή στη σελίδα διαγραφής, λογαριασμός ανέπαφος |
| 6 | E91 — landscape + `font_scale 1.3`, Save με κενό μήνυμα | ✅ PASS — «Παρακαλώ γράψτε ένα μήνυμα υπενθύμισης» ορατό με auto-scroll· δημιουργία/διαγραφή υπενθύμισης OK |
| 7 | SEC-005c — temp user με root doc + child `notifications/cascade_test`, διαγραφή μέσω UI | ✅ PASS — επιστροφή στη σύνδεση χωρίς σφάλμα· `signInWithPassword` πλέον αποτυγχάνει (auth deleted) |
| 8 | SEC-006a — temp user συνδεδεμένος, REST `PATCH deleted=true` στο root doc | ✅ PASS — σε ~5 s μήνυμα «Ο λογαριασμός διαγράφηκε σε άλλη συσκευή…» και επιστροφή στη σύνδεση |
| 9 | Cleanup | ✅ PASS — temp users διαγράφηκαν (Auth + Firestore), demo ξανά συνδεδεμένο, `font_scale 1.0`, rotation auto |

Σημειώσεις:

- Το root doc του SEC-005c δεν μπορεί να ελεγχθεί unauthenticated (403 από rules)· η επιτυχής ολοκλήρωση του `finalizeDeletion` (επιστροφή στη σύνδεση χωρίς σφάλμα) καλύπτει τη σειρά marker → cascade → root delete → auth delete.
- Το timeout/server-read path του `_writeMarkerConfirmed()` δεν προσομοιώθηκε σε συσκευή (απαιτεί τεχνητό κόψιμο δικτύου στη μέση του transaction)· καλύπτεται σχεδιαστικά από το transaction και τα unit tests της πολιτικής.
- Η συσκευή γύρισε σε landscape κατά τη διάρκεια των tests (app + κλείδωμα περιστροφής)· στο τέλος επαναφέρθηκε `accelerometer_rotation=1`, `wm user-rotation free`.

## Κατάσταση

✅ SEC-005c, SEC-006a, SEC-006b, E90, E91, E92 FIXED 28/11/2026.
