# Session 39b (2026-11-26) — E65: βιομετρικό από το doc του E64

> **Κεφάλαιο 45/45** · **Ημερομηνία:** 2026-11-26 · **Σχετικά:** E65, E64, commit `(νέο)`

### Πλαίσιο

- Το device test **D3** του E64 (offline + διαγραφή `databases/firestore.*`) έδειξε `StartupErrorView` με raw `[cloud_firestore/unavailable]` από το `BiometricSettingsService.load(uid)`.
- Το E64 ensure είχε ήδη κάνει σωστά skip (καμία εγγραφή, κανένα poll)· το δεύτερο `get()` στο **ίδιο** user doc ήταν το πρόβλημα.
- Απόφαση χρήστη: **επιλογή Α** — χρήση των πεδίων `fingerprint_enabled` / `biometric_mode` / `biometric_remember` από το `ensured.data` (**0 επιπλέον reads**), χωρίς δεύτερο `get()`.

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/presentation/auth/app_start.dart` | Αφαίρεση `BiometricSettingsService.instance.load(uid)`· βιομετρικά από το `userData` του E64· αν `userData == null` → fail-closed με καθαρό ελληνικό μήνυμα (offline vs generic)· import `user_doc_policy.dart` |
| `pubspec.yaml` | `2.3.12+19` → **`2.3.13+20`** |
| `README.md` | Συγχρονισμός έκδοσης |
| `DESIGN.md` | §1.4/§1.5 έκδοση, §4.3 βήματα/γραμμές + E65 σημείωση, §8.3 E65 |
| `error_list.md` | E65 → ✅ FIXED· κενή «Σειρά εκκρεμοτήτων»· λεπτομέρειες λύσης |
| `oldsessions.md` | Κεφάλαιο 45 + τρέχουσα κατάσταση |

### Quality gates

- `flutter analyze` → ✅ **No issues found** (0/0/0)
- `flutter test` → ✅ **292/292** (κανένα νέο test — καθαρή αλλαγή ροής)
- `flutter build apk --debug` → ✅
- Device tests POCO X3 (`2.3.13+20`) → βλ. παρακάτω

### Device tests (POCO X3 — `9593c01e`, `2.3.13+20`)

| # | Σενάριο | Αποτέλεσμα |
|---|---|---|
| D3 | Airplane mode ON + διαγραφή `databases/firestore.*` (`run-as`) → launch | ✅ `StartupErrorView` με **καθαρό ελληνικό μήνυμα** «Χωρίς σύνδεση δεν είναι δυνατός ο έλεγχος ασφαλείας. Συνδεθείτε στο internet και πατήστε «Ξανά».» — χωρίς `Exception:`/raw Firestore error, χωρίς bypass του βιομετρικού |
| D4 | Airplane mode OFF → force-stop → relaunch | ✅ Αρχική με πλήρη δεδομένα (server → cache), demo συνδεδεμένος |

- Screenshots: `device test/screenshots/e65_01…e65_05_*` (offline cold 3s/6s, τελικό μήνυμα, online restore).

### Εκκρεμότητες

- **Καμία ανοιχτή** στη «Σειρά εκκρεμοτήτων».
- **E55**, **E60** — ℹ️ INFO, εκτός σειράς.

### Backups

- `backups/2026-11-26_e65/` — `app_start.dart`, `pubspec.yaml`, `README.md`, `DESIGN.md`, `error_list.md`, `oldsessions.md`

### Κλείσιμο session

- Commit: **`(νέο)`** — `fix(auth): E65 read biometric settings from E64 user doc (0 extra reads)` · push.
