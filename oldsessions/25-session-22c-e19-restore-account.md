# Session 22c (2026-11-23) — E19/E14: επαναφορά διαγραμμένου λογαριασμού

> **Κεφάλαιο 25/25** · **Ημερομηνία:** 2026-11-23 · **Σχετικά:** E14, E19, E29–E34

### Πλαίσιο

Το «Δημιουργία λογαριασμού με όνομα που ανήκει σε διαγραμμένο» εμφάνιζε διάλογο επαναφοράς
που **επαναφορούσε και ό,τι είχε διαγράψει ο χρήστης** (E19) και **εμπιστευόταν το
`current_balance`** που είχε μείνει λάθος μετά τη διαγραφή (E14). Ζητήθηκε πλήρης αναγραφή:
κανόνας σε καθαρό Dart, I/O χωριστά, offline φραγή, απόλυτο υπόλοιπο, 6 φάσεις, device tests.

### Αποφάσεις (εγκεκριμένες από τον χρήστη)

| # | Απόφαση |
|---|---|
| D1 | Επιστρέφουν **μόνο** ζεύγη μεταφορών με `annulled_by_account_deleted == <uuid>` |
| D2 | Μεμονωμένη κίνηση χωρίς marker (διαγραμμένη από τον χρήστη) μένει **κρυφή** |
| D3 | Υπόλοιπο **απόλυτο**: `initial_balance + ό,τι μετράει` σε **cents** (όχι `current_balance`) |
| D4 | Peers: **μόνο** αντιστρόφο delta της διαγραφής· ο επαναφερόμενος δεν παίρνει delta |
| D5 | Ενεργοποίηση **τελευταία** (commit point) — ξεχωριστό ατομικό batch |
| D6 | `archived_at: FieldValue.delete()` (όχι timestamp) |
| D7 | Marker cleanup σε κάθε επαναφερόμενο leg |
| D8 | Offline gate πριν από κάθε read (`isConfirmedOffline`) |
| D9 | Εκκρεμές (`is_scheduled && !is_executed`) ζεύγος **δεν** επανέρχεται |
| D10 | Επιτρέπεται restorable ζεύγος με διαγραμμένο-αλλά-υπαρκτό peer |
| D11 | Επανάγνωση πριν τη γραφή· **ματαίωση** σε drift (αντί transaction — L27/L29) |
| D12 | E34 (batch reuse) εκτός scope — μόνο καταγραφή |

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/core/utils/account_restore_policy.dart` | **Νέο** (καθαρό Dart, 0 I/O): `buildRestoreUnits`, skip reasons, chunks ≤499, απόλυτο υπόλοιπο, fingerprint, μηνύματα |
| `lib/core/services/account_restore_service.dart` | **Νέο**: `preview`, `restoreWithHistory`, `restoreWithoutBalance` — 4 reads (`Source.server`), επανέλεγχος, chunks, τελευταία ενεργοποίηση |
| `lib/services/account_duplicate_service.dart` | Αναγραφή: διάλογος 6 φάσεων, `CreateAccountOutcome {proceed, closeDialog, keepDialog}` (E33), ανεκτική `findDeletedAccountByName` χωρίς `AccountModel.fromFirestore` (E31) |
| `lib/core/services/connectivity_service.dart` | `isConfirmedOffline` (E19/§5.13) |
| `lib/core/utils/account_delete_guard.dart` | `decide(targetIsVisible:)` (E32), `buildRestoreUnits`, `maxWritesPerBatch = 499` |
| `lib/presentation/screens/accounts/accounts_page.dart` | Call sites E32/E33 + offline helper στο create flow |
| `test/unit/core/utils/account_restore_policy_test.dart` | **Νέο**: 23 tests (μόνο marked, κρυφές, εκκρεμή, peers, cents, chunks, fingerprint, μηνύματα) |
| `test/unit/core/utils/account_delete_guard_test.dart` | 36 → **38** (+2 E32 `targetIsVisible`) |
| `analysis_options.yaml` | `backups/**` στο `analyzer.exclude` (τα backups έβγαζαν 19 issues) |
| `pubspec.yaml` | `2.3.3+10` → **`2.3.4+11`** |
| `DESIGN.md` | §3.2 (2 νέα αρχεία) · §5.4 · §5.13 (γραμμές επαναφοράς) · §9 (178 tests) · §11 (L24 λύθηκε, L29/L30 νέα) |
| `error_list.md` | E14/E19 → ✅ FIXED · E29–E33 ✅ · E34 🔵 OPEN · E35/E36 ℹ️ INFO |

### Quality gates

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ **178/178** (baseline 152) |
| `build apk --release` | ✅ `2.3.4+11` → `adb install -r` OK |

### Device tests (POCO X3 `9593c01e`)

Fixture `e19-src` (διαγραμμένος+αρχειοθετημένος, λάθος `current=100`, `initial=1000`), peer
`e19-peer` (500), κινήσεις: t1 ολοκληρωμένο ζεύγος 200 με marker, t2 διαγραμμένη από χρήστη
χωρίς marker, t3 ορατό έσοδο 30, t4 **εκκρεμές** ζεύγος 70 με marker.

| Έλεγχος | Αποτέλεσμα |
|---|---|
| Preview | «Επιστρέφουν: 1 μεταφορά (2 κινήσεις) · Μένουν κρυφές: 2 κινήσεις · Επιστρέφουν ποσά σε: E19 Test Peer · Υπόλοιπο 100,00 € → 830,00 €» |
| Επαναφορά με ιστορικό | `initial=1000 current=830`, ενεργός, `archived_at` καθαρό· peer `700` (αντίστροφο delta 200 από 500) |
| t1 legs | `deleted=false`, markers **καθαρά** |
| t2 (χωρίς marker) | παραμένει `deleted=true` |
| t4 (εκκρεμές) | παραμένει κρυφό **και** με marker → δεν εκτελείται |
| Ακύρωση preview | Το «Νέος Λογαριασμός» μένει ανοιχτό με τα πεδία (`keepDialog`) |
| Offline | «Η επαναφορά απαιτεί σύνδεση στο internet. Ο λογαριασμός παραμένει όπως είναι.» + «Δοκιμή ξανά»· 0 reads |
| Text scale 1.45 | Preview + επιλογές πλήρως ορατά |
| «Χωρίς υπόλοιπο» | Επιβεβαίωση «Ναι, μηδενισμός» → `initial=current=0`, όλα τα legs κρυφά, **όλοι** οι markers καθαροί, peer **αμετάβλητο** (500) |

Σκρινσότς/logs: `device test/screenshots/e19_*`. Fixture **διαγράφηκε** μετά (8 docs) —
demo λογαριασμός και δεδομένα ανέπαφα (9 λογαριασμοί, 99 κινήσεις / 46 ενεργές, όπως πριν).

### Εκκρεμότητες

- **E5** (ντετερμινιστικά IDs onboarding) — επόμενο στη σειρά.
- **E34** (batch reuse >499 writes) — 🔵 OPEN.
- E35/E36 — ℹ️ INFO (καταγραφή).

### Backups

`backups/2026-11-23-e19-e14/` — pre-edit αντίγραφα όλων των αλλαγμένων αρχείων.
