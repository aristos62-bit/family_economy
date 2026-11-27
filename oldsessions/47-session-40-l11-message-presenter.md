# Session 40 (2026-11-27) — L11: κεντρικός presenter μηνυμάτων & καθαρά σφάλματα

> **Κεφάλαιο 47/47** · **Ημερομηνία:** 2026-11-27 · **Σχετικά:** E66, E68–E76, E67 (INFO), **E77–E84**, `2.3.14+21`

> ✅ **Post-commit έλεγχος (27/11/2026):** ο έλεγχος μετά τα commits `11a6bf8`/`880d616` βρήκε **E77–E83 ανοιχτά** (2 regressions, raw μέσω providers/μεταβλητών, ελλιπές inline validation, κενό guard, άκυρο device test). **Όλα διορθώθηκαν** την ίδια ημέρα· τα docs διορθώθηκαν με **E84** και το L11 έκλεισε ως **✅ FIXED** μετά το νέο device test σε `2.3.14+21`.

### Πλαίσιο

- Το **L11/E66** ήταν το τελευταίο μεγάλο χρέος: **89 άμεσα `SnackBar(...)` σε 28 αρχεία**, χωρίς ενιαίο χρόνο/χρώμα/a11y.
- Παράλληλα εντοπίστηκαν raw τεχνικά σφάλματα προς χρήστη (`e.toString()`, `provider.error`, stack traces), διπλές ανακοινώσεις screen reader δίπλα σε snackbar και ασυνεπές inline validation στους διαλόγους.
- Η δουλειά έγινε **βήμα-βήμα** με backup πριν από κάθε αλλαγή και έλεγχο (`dart format`, `flutter analyze`, `flutter test`, μέτρηση `SnackBar(`) μετά από κάθε βήμα.
- Βάση: **v7 + D1–D12** (αποφάσεις συνεδρίας). Βασικές: D1 typed `CreateAccountCheck` + pop πριν το μήνυμα, D2 ουρά ανά `ScaffoldMessengerState`, D3 `UserMessageException` (χρησιμοποιείται από το E77), D4 αφαίρεση όλων των `hideCurrentSnackBar`, D5 αφαίρεση μόνο των διπλών `announce`, D6 `ErrorApp` χωρίς raw error, D9 στοχευμένοι χρόνοι, D10 guard (v2 μετά το E82), D11 helpers `accounts_page` μένουν, D12 exact hunks στα μεγάλα αρχεία.

### Νέα αρχεία

| Αρχείο | Ρόλος |
|---|---|
| `lib/core/errors/user_message_exception.dart` | Εξαίρεση με μήνυμα **ασφαλές για χρήστη**· οτιδήποτε άλλο → generic |
| `lib/core/utils/message_policy.dart` | `MessageKind`, χρόνοι **3/3/5/6s**, semantic χρώματα + max-contrast foreground, πλάτος **560** >600px, `fromError`, `fromProvider` (allowlist `TagsProvider`), `genericError` |
| `lib/core/messaging/app_messenger.dart` | Presenter `success/info/warning/error`, `actionLabel`/`onAction`, `persist`, `messenger:`, ουρά ανά messenger (`Expando`), `liveRegion: true` |
| `test/unit/core/messaging/l11_guard_test.dart` | Guard v2 (D10/E82): 0 άμεσα `SnackBar(` έξω από τον presenter· taint tracking ανά αρχείο για raw `$e`/`$error` σε UI sinks (πιάνει και `_error = e.toString(); Text(_error)`)· fixtures αυτοελέγχου· guards E77/E81 |

### Αλλαγές

| Περιοχή | Αλλαγή |
|---|---|
| `core/theme/ui_tokens.dart` | Νέο δημόσιο `ColorsUI.contrastRatio` (E67: επιτρέπει έλεγχο, δεν αλλάζει τον helper) |
| 28 αρχεία UI | Όλα τα μηνύματα → `AppMessenger`· **0** άμεσα `SnackBar(` στο `lib/` (μόνο η κατασκευή στον presenter) |
| `accounts_page.dart` + `account_duplicate_service.dart` | `CreateAccountCheck {outcome, message, kind}`· create duplicate → pop + page-level error, edit duplicate → inline `errorText` με ανοιχτό διάλογο (E33)· helpers 338/550 inline |
| Διάλογοι / φόρμες | Inline validation σε λογαριασμούς, `edit_category`, `current_level`, `tags` (create+edit), `notification_edit`· αφαίρεση **5** `hideCurrentSnackBar` και **6** διπλών `announce` δίπλα σε snackbar |
| `main.dart` / `startup_error_view` | `ErrorApp` χωρίς raw `error`· σταθερό «Η επανάληψη απέτυχε.» + πλήθος προσπαθειών· 4 widget tests προσαρμόστηκαν |
| E68–E76 | `accounts_page`, `change_password_page`, `options_page`, `oil_page`, `database_cleanup_page`, `user_details_option`, `app_start.dart`, `delete_account_page` → σταθερά μηνύματα στην UI· τα υπόλοιπα raw σημεία διορθώθηκαν στα **E79/E80** |
| `message_policy.dart` (E69/E72) | `MessagePolicy.fromError(e, action: ...)` για cleanup/αλλαγή κωδικού |

### Επαλήθευση

- `flutter analyze`: ✅ **No issues found** (0/0/0).
- `flutter test`: ✅ **331/331** (292 πριν· +20 `message_policy`, +10 `app_messenger`, +4 `ui_tokens`, +5 guard v2/E77/E81).
- `SnackBar(` στο `lib/`: **0** εκτός `app_messenger.dart`· αρχεία που καλούν `AppMessenger`: **28**.
- `lib/`: **112** Dart αρχεία (109 + 3 νέα)· tests: **23** αρχεία.
- **Device test (27/11/2026):** ✅ νέο release `2.3.14+21` (89 MB) → POCO X3 (`9593c01e`, `versionCode=21`)· footer «Έκδοση 2.3.14 (build 21)»· E81 inline validation (κενό όνομα κατηγορίας, χωρίς αποθήκευση)· επιβεβαιώθηκαν από τον χρήστη E77/E78/E79/E80 και οι βασικές ροές.

### Post-commit fixes (E77–E84)

| ID | Διόρθωση |
|---|---|
| E77 | `UserMessageException` + `MessagePolicy.fromError` σε `app_start`/`change_password` — τα ειδικά μηνύματα E65/αλλαγής κωδικού δεν γίνονται generic |
| E78 | `home_page` προγραμματισμένη κίνηση: `persist: false` — δεν μένει μόνιμο μήνυμα |
| E79 | 11 σημεία σε 6 providers → σταθερά ελληνικά μηνύματα· raw μόνο σε `DebugConfig.print` |
| E80 | Raw σφάλματα σε 11 UI sinks (unit converter, transactions_show, scheduled, stats4, transaction_entry, categories, tags, login, auth_service) → σταθερά/`MessagePolicy` |
| E81 | Inline validation σε `edit_category`, `current_level`, `tags` (create+edit), `notification_edit` |
| E82 | Guard v2: taint tracking ανά αρχείο, `.error` unwrapped, allowlist `MessagePolicy`, fixtures αυτοελέγχου |
| E83 | Νέο release `2.3.14+21` + εγκατάσταση + device test |
| E84 | Docs: E66/L11 κατάσταση, test counts, «raw μόνο σε logs» |

### Docs & έκδοση

- `DESIGN.md`: §1.1/§1.5.2 `2.3.14+21`· §2.7/§9.1/§9.2 **331**· §3.1 112 αρχεία / 23 test files· §3.3 L11 **✅ FIXED**· §4.3 + §5.5 νέα αρχιτεκτονική μηνυμάτων· §11 L11 ✅ FIXED, **L37** (E67 INFO).
- `error_list.md`: E66 → ✅ FIXED· E68–E84 → ✅ FIXED· «Σειρά εκκρεμοτήτων» → καμία.
- `README.md`: έκδοση `2.3.14+21`.
- `pubspec.yaml`: `2.3.13+20` → **`2.3.14+21`**.

### Εκκρεμότητες

- **E67 / L37** — ℹ️ INFO· **E60** — ℹ️ INFO, παραμένει ως έχει.
- Καμία αλλαγή σε `debug_config.dart` (τοπική ρύθμιση χρήστη — δεν μπαίνει στο commit).

### Backups

- `backups/L11-2026-11-27/` — `step-0`, `step-2`, `step-3a/3b`, `step-4a…4i` (+ `4f-fix`, `4i-fix`), `step-5a/5b/5c`, docs στάδια, `step-6-docs`, `step-7-commit`, `step-8-review-docs`, `step-9-e77` … `step-14-e82`, `step-15-e83`.

### Κλείσιμο session

- **Commits:** `11a6bf8` (κώδικας + tests, 41 αρχεία) · `880d616` (docs).
- **Post-commit έλεγχος:** βρήκε **E77–E83**· διορθώθηκαν όλα + docs (E84) και ακολουθεί νέο commit.
