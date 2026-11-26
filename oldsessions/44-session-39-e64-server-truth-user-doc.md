# Session 39 (2026-11-26) — E64: server-truth user document

> **Κεφάλαιο 44/44** · **Ημερομηνία:** 2026-11-26 · **Σχετικά:** E64, commit `(νέο)`

### Πλαίσιο

- Το **E64** ήταν η μόνη ανοιχτή εκκρεμότητα: `createUserDocumentIfNeeded` έτρεχε πριν το E5 gate, με offline `set(merge:true)` και poll έως ~7.5s πριν την είσοδο.
- Απόφαση (E64 v4): το ensure βγαίνει **έξω** από `signIn`/`register` και γίνεται μία φορά από τα entry points:
  `Source.cache` → (offline gate) → `Source.server` (timeout 8s) → `set(merge:true)` **μόνο** μετά από server-confirmed missing. **Κανένα poll.**
- Offline/σφάλμα → **καμία εγγραφή**, η είσοδος συνεχίζει. Offline + doc που λείπει και από το cache → ορατό μήνυμα (απόφαση 1Α)· μόνο debug log για `skippedError` (όχι «χωρίς σύνδεση» σε permission-denied).
- Καθαρός κανόνας σε ξεχωριστό αρχείο (pure Dart) + unit tests, ώστε η απόφαση να μη ζει μέσα στο service (απόφαση 2Α/3Α).

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/core/data/user_doc_policy.dart` | **Νέο**: `UserDocAction` (6 τιμές), `UserDocOutcome`, `afterCache` / `afterServer` / `afterFailure`, `serverTimeout` 8s, 3 offline codes |
| `test/unit/core/data/user_doc_policy_test.dart` | **Νέο**: 14 tests (cache hit/miss, offline gate, server exists/create, timeout, offline codes, permission-denied, σταθερές) |
| `lib/core/services/auth_service.dart` | Νέο `ensureUserDocument(User, {confirmedOffline})` → `UserDocumentResult(outcome, exists, data, errorCode)`· `_newUserDocumentPayload` (ίδια 20 πεδία)· αφαίρεση `createUserDocumentIfNeeded`, `getUserDocument` και των κλήσεών τους σε `signIn`/`register` |
| `lib/presentation/auth/login_page.dart` | Μία κλήση ensure (cache→server→create)· `ensured.data/exists` για currency + E4 gate· notice μόνο σε `skippedOffline`· `mounted` check |
| `lib/presentation/auth/app_start.dart` | Μία κλήση ensure· `ensured.exists`/`data` στο E4 gate |
| `pubspec.yaml` | `2.3.11+18` → **`2.3.12+19`** |
| `README.md` | Συγχρονισμός έκδοσης |
| `DESIGN.md` | §1.4/§1.5 έκδοση, §3.1 (109 αρχεία / 19 test files / 292 tests), §3.2 δέντρο, §4.3 βήματα + σειρά, §8.3 E64, §9.1/§9.2 |
| `error_list.md` | E64 → ✅ FIXED· κενή «Σειρά εκκρεμοτήτων»· διόρθωση stale γραμμών (`:137` → `139-145`) |

### Quality gates

- `flutter analyze` → ✅ **No issues found** (0/0/0)
- `flutter test` → ✅ **292/292** (278 + 14 νέα)
- `flutter build apk --debug` → ✅ (βλ. Device tests)
- Device tests POCO X3 (`2.3.12+19`) → βλ. παρακάτω

### Device tests (POCO X3 — `9593c01e`)

- (συμπληρώνεται μετά τα device tests)

### Εκκρεμότητες

- **Καμία ανοιχτή** στη «Σειρά εκκρεμοτήτων».
- **E55**, **E60** — ℹ️ INFO, εκτός σειράς.

### Backups

- `backups/2026-11-26_e64/` — `auth_service.dart`, `login_page.dart`, `app_start.dart`, `pubspec.yaml`, `README.md`, `DESIGN.md`, `error_list.md`, `oldsessions.md`

### Κλείσιμο session

- Commit: **`(νέο)`** — `feat(auth): E64 server-truth user document (no poll, no offline writes)` · push.
