# Session 40 (2026-11-27) — L11: κεντρικός presenter μηνυμάτων & καθαρά σφάλματα

> **Κεφάλαιο 47/47** · **Ημερομηνία:** 2026-11-27 · **Σχετικά:** E66, E68–E76, E67 (INFO), `2.3.14+21`

### Πλαίσιο

- Το **L11/E66** ήταν το τελευταίο μεγάλο χρέος: **89 άμεσα `SnackBar(...)` σε 28 αρχεία**, χωρίς ενιαίο χρόνο/χρώμα/a11y.
- Παράλληλα εντοπίστηκαν raw τεχνικά σφάλματα προς χρήστη (`e.toString()`, `provider.error`, stack traces), διπλές ανακοινώσεις screen reader δίπλα σε snackbar και ασυνεπές inline validation στους διαλόγους.
- Η δουλειά έγινε **βήμα-βήμα** με backup πριν από κάθε αλλαγή και έλεγχο (`dart format`, `flutter analyze`, `flutter test`, μέτρηση `SnackBar(`) μετά από κάθε βήμα.
- Βάση: **v7 + D1–D12** (αποφάσεις συνεδρίας). Βασικές: D1 typed `CreateAccountCheck` + pop πριν το μήνυμα, D2 ουρά ανά `ScaffoldMessengerState`, D3 `UserMessageException`, D4 αφαίρεση όλων των `hideCurrentSnackBar`, D5 αφαίρεση μόνο των διπλών `announce`, D6 `ErrorApp` χωρίς raw error, D9 στοχευμένοι χρόνοι, D10 στενός guard, D11 helpers `accounts_page` μένουν, D12 exact hunks στα μεγάλα αρχεία.

### Νέα αρχεία

| Αρχείο | Ρόλος |
|---|---|
| `lib/core/errors/user_message_exception.dart` | Εξαίρεση με μήνυμα **ασφαλές για χρήστη**· οτιδήποτε άλλο → generic |
| `lib/core/utils/message_policy.dart` | `MessageKind`, χρόνοι **3/3/5/6s**, semantic χρώματα + max-contrast foreground, πλάτος **560** >600px, `fromError`, `fromProvider` (allowlist `TagsProvider`), `genericError` |
| `lib/core/messaging/app_messenger.dart` | Presenter `success/info/warning/error`, `actionLabel`/`onAction`, `persist`, `messenger:`, ουρά ανά messenger (`Expando`), `liveRegion: true` |
| `test/unit/core/messaging/l11_guard_test.dart` | Guard D10: 0 άμεσα `SnackBar(` έξω από τον presenter· 0 raw `$e`/`$error` σε `Text(`/`content:`/`label:`/`hintText:` |

### Αλλαγές

| Περιοχή | Αλλαγή |
|---|---|
| `core/theme/ui_tokens.dart` | Νέο δημόσιο `ColorsUI.contrastRatio` (E67: επιτρέπει έλεγχο, δεν αλλάζει τον helper) |
| 28 αρχεία UI | Όλα τα μηνύματα → `AppMessenger`· **0** άμεσα `SnackBar(` στο `lib/` (μόνο η κατασκευή στον presenter) |
| `accounts_page.dart` + `account_duplicate_service.dart` | `CreateAccountCheck {outcome, message, kind}`· create duplicate → pop + page-level error, edit duplicate → inline `errorText` με ανοιχτό διάλογο (E33)· helpers 338/550 inline |
| Διάλογοι / φόρμες | Inline validation αντί snackbar· αφαίρεση **5** `hideCurrentSnackBar` και **6** διπλών `announce` δίπλα σε snackbar |
| `main.dart` / `startup_error_view` | `ErrorApp` χωρίς raw `error`· σταθερό «Η επανάληψη απέτυχε.» + πλήθος προσπαθειών· 4 widget tests προσαρμόστηκαν |
| E68–E76 | `accounts_page`, `change_password_page`, `options_page`, `oil_page`, `database_cleanup_page`, `user_details_option`, `app_start.dart`, `delete_account_page` → σταθερά μηνύματα στην UI, raw **μόνο** σε `DebugConfig.print` |
| `message_policy.dart` (E69/E72) | `MessagePolicy.fromError(e, action: ...)` για cleanup/αλλαγή κωδικού |

### Επαλήθευση

- `flutter analyze`: ✅ **No issues found** (0/0/0).
- `flutter test`: ✅ **328/328** (292 πριν· +20 `message_policy`, +10 `app_messenger`, +4 `ui_tokens`, +2 guard).
- `SnackBar(` στο `lib/`: **0** εκτός `app_messenger.dart`· αρχεία που καλούν `AppMessenger`: **28**.
- `lib/`: **112** Dart αρχεία (109 + 3 νέα)· tests: **23** αρχεία.
- **Device test (27/11/2026):** ✅ όλα σωστά (εκτέλεση από τον χρήστη)· build/installer δεν έγιναν σε αυτό το στάδιο.

### Docs & έκδοση

- `DESIGN.md`: §1.1/§1.5.2 `2.3.14+21`· §2.7/§9.1/§9.2 **328**· §3.1 112 αρχεία / 23 test files· §3.3 χρέος L11 κλειστό· §4.3 + §5.5 νέα αρχιτεκτονική μηνυμάτων· §11 L11 ✅, νέο **L37** (E67 INFO).
- `error_list.md`: E66 + E68–E76 → ✅ FIXED· «Σειρά εκκρεμοτήτων» κενή· μένει μόνο E67 ℹ️ INFO.
- `README.md`: έκδοση `2.3.14+21`.
- `pubspec.yaml`: `2.3.13+20` → **`2.3.14+21`**.

### Εκκρεμότητες

- **Καμία** στη «Σειρά εκκρεμοτήτων».
- **E67 / L37** — ℹ️ INFO: `getAccessibleTextColor` με threshold 0.5 (2 call sites stats)· δεν αλλάζει.
- **E60** — ℹ️ INFO, παραμένει ως έχει (απόφαση χρήστη).
- Καμία αλλαγή σε `debug_config.dart` (τοπική ρύθμιση χρήστη).

### Backups

- `backups/L11-2026-11-27/` — `step-0`, `step-2`, `step-3a/3b`, `step-4a…4i` (+ `4f-fix`, `4i-fix`), `step-5a/5b/5c`, docs στάδια, `step-6-docs`.

### Κλείσιμο session

- **Χωρίς commit** — όλες οι αλλαγές παραμένουν uncommitted στο working tree.
