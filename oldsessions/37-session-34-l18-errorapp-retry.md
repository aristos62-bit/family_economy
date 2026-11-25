# Session 34 (2026-11-25) — L18: πραγματικό retry στην οθόνη σφάλματος εκκίνησης

> **Κεφάλαιο 37/37** · **Ημερομηνία:** 2026-11-25 · **Σχετικά:** L18, E58, E59, `2.3.8+15`

### Πλαίσιο

- **Εύρημα L18:** στην οθόνη «Σφάλμα Αρχικοποίησης» το κουμπί «Επανεκκίνηση» πετούσε `Null check operator`.
- **Αιτία:** το `ErrorApp` χτίζεται με `runApp` **έξω** από το `Phoenix` (το `runApp` γίνεται μόνο όταν το Firebase init αποτυγχάνει), άρα το `Phoenix.rebirth` → `findAncestorStateOfType<_PhoenixState>()!` επιστρέφει `null`.
- **Δεύτερο πρόβλημα:** ακόμη κι αν υπήρχε ancestor, το `rebirth` κάνει μόνο `setState` με νέο `Key` — **δεν** ξανατρέχει το `main()`, άρα δεν ξαναδοκιμάζει το `Firebase.initializeApp`.
- Η πρόταση πέρασε από 4 βήματα (v1→v4). Αποφάσεις χρήστη: **1Α** (πραγματικό retry, όχι μόνο κείμενο) και **2Α** (οι αρχικοποιήσεις πριν το `try` μένουν έξω → νέο εύρημα E58).

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/main.dart` | Το σώμα του παλιού `try` (`Firebase init` → `runApp`) εξήχθη σε `_bootstrap({themeProvider, connectivityService, isRetry})`. Η `main()` κρατά ό,τι ήταν πριν το `try` (theme, notifications, connectivity) και σε αποτυχία κάνει `runApp(ErrorApp(..., onRetry: …))`. Στο `_bootstrap`: guard `if (isRetry && Firebase.apps.isNotEmpty)` πριν το `initializeApp` (μη εγγυημένη idempotency) και τα `Settings(persistenceEnabled…)` σε **best-effort** `try/catch`. |
| `lib/main.dart` | `ErrorApp` από `StatelessWidget` → `StatefulWidget` με `onRetry`. Κατάσταση `_error` / `_retrying` / `_attempts`: guard διπλού πατήματος, `mounted` μετά το `await`, σε αποτυχία νέο μήνυμα + μετρητής + `AccessibilityService.announceError`, σε επιτυχία το `runApp` αντικαθιστά το δέντρο (κανένα `setState` μετά). Κουμπί «Δοκιμή ξανά» / «Νέα προσπάθεια…». |
| `lib/main.dart` | Μήνυμα ουδέτερο: «δεν μπόρεσε να ολοκληρώσει την αρχικοποίηση» (το `catch` πιάνει κάθε σφάλμα, όχι μόνο δικτύου). Αφαιρέθηκε το `Phoenix.rebirth`. |
| `test/widget_test.dart` | `onRetry` υποχρεωτικό → ενημερώθηκε η υπάρχουσα δοκιμή + 2 νέες: αποτυχημένη επανάληψη (νέο σφάλμα + «Προσπάθειες: 1») και guard διπλού πατήματος ( Completer). Σύνολο αρχείου: 3 tests. |
| `pubspec.yaml` | `2.3.7+14` → **`2.3.8+15`** (PATCH). |
| `DESIGN.md` | §4.4: περιγραφή νέου retry + `Phoenix` χωρίς χρήση· §11 L18 → ✅ διορθώθηκε· πίνακας startup με νέες γραμμές· πλήθος tests 251 → **253**· έκδοση/artifacts `2.3.8`. |
| `error_list.md` | L18 ✅ FIXED (βγήκε από τη σειρά)· νέα **E58** (🔵 OPEN, αρχικοποιήσεις εκτός `try` — `main.dart:34,38`) και **E59** (ℹ️ INFO, `Phoenix`/`flutter_phoenix` νεκρός κώδικας). |

**Τι δεν άλλαξε:** `StartupErrorView` (κοινό με `AppStart`), `AppStart` και η ροή login/biometric/schema/scheduled, σειρά εκκίνησης πριν το `try`, Firestore schema/rules/indexes, providers.

### Quality gates

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | ✅ **No issues found** (0 errors / 0 warnings / 0 info) |
| `flutter test` | ✅ **253/253** |
| `flutter build apk --debug` | ✅ |
| Device tests (POCO X3, `adb`) | ✅ (βλ. `device test/`) |

### Εκκρεμότητες

- **E58** 🔵 OPEN — `ThemeProvider.initialize()` / `NotificationsService().initialize()` εκτός δοχείου σφάλματος: αποτυχία εκεί = λευκή/μαύρη οθόνη, χωρίς `ErrorApp`. Δεν μπήκε εδώ γιατί το retry θα ξανάτρεχε singleton initialization.
- **E59** ℹ️ INFO — `Phoenix` (`main.dart:172`) + `flutter_phoenix` χωρίς καμία χρήση· αφαίρεση μόνο σε ξεχωριστή φάση (αγγίζει `pubspec`/`pubspec.lock`).
- Σειρά εκκρεμοτήτων μετά το L18: **E5 → E15/L6 → L23 → E58 → E59**.

### Backups

- `backups/2026-11-25-l18-errorapp-retry/`: `main.dart.bak`, `widget_test.dart.bak`, `DESIGN.md.bak`, `error_list.md.bak`, `oldsessions.md.bak`, `pubspec.yaml.bak`.
