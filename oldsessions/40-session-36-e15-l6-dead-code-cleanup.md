# Session 36 (2026-11-25) — E15/L6: καθαρισμός νεκρού κώδικα & ειλικρινής συγχρονισμός

> **Κεφάλαιο 40/40** · **Ημερομηνία:** 2026-11-25 · **Σχετικά:** E15, L6, L11, E61, E62

### Πλαίσιο

- Το **E15** (`MessageService` «ανενεργό») και το **L6** (νεκρά `biometric_gate.dart`, `recurring_notifications_service.dart`) ήταν τα πρώτα στην ουρά καθαρισμού.
- Η πρόταση πέρασε από 4 βήματα (v1 → v4) και κλείδωσε με 4 αποφάσεις (1Α–4Α). Κρίσιμο εύρημα: το μόνο call site (`main.dart` → `showSyncComplete`) ήταν **no-op** — ο μετρητής `_pendingOperations` αυξανόταν μόνο μέσα στο `show()`, που είχε **0** κλήσεις, άρα το «Συγχρονισμός ολοκληρώθηκε» δεν εμφανίστηκε **ποτέ**. Επιπλέον το `onSyncComplete` πυροδοτούσε σε κάθε offline→online, ανεξάρτητα από εκκρεμείς εγγραφές.
- Απόφαση: **διαγραφή**, όχι αναβίωση (η offline ένδειξη υπάρχει ήδη ως `OfflineAppBarChip`). Η αρχική ιδέα καταγράφηκε ως **E61** (INFO).

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/core/services/message_service.dart` | **Διαγράφηκε** (288 γρ., 1 no-op caller) |
| `lib/core/widgets/biometric_gate.dart` | **Διαγράφηκε** (195 γρ., 0 imports) |
| `lib/services/recurring_notifications_service.dart` | **Διαγράφηκε** (296 γρ., 0 imports) |
| `lib/main.dart` | Import, callback `onSyncComplete`, `dispose` και παράμετρος `connectivityService` αφαιρέθηκαν· `MyApp` → `StatelessWidget` |
| `lib/core/services/connectivity_service.dart` | Πεδίο + κλήση `onSyncComplete` αφαιρέθηκαν· 2s debounce & `notifyListeners()` ανέπαφα |
| `lib/core/widgets/offline_banner.dart` → `offline_appbar_chip.dart` | Αφαίρεση της αχρησιμοποίητης `OfflineBanner` (94 γρ.)· το `OfflineAppBarChip` έμεινε, μετονομασία αρχείου + 2 imports (`home_page`, `database_cleanup_page`) |
| `lib/presentation/auth/app_start.dart` | Αφαίρεση σχολιασμένου `generateAhead` |
| `lib/presentation/auth/login_page.dart` | Αφαίρεση κενού `try/catch` (σχολιασμένο `generateAhead`) |
| `test/unit/core/startup/prepare_startup_test.dart` | Το fake δεν δηλώνει πλέον το αφαιρεμένο `onSyncComplete` |
| `DESIGN.md` | §3.1 (107 αρχεία), §3.2, §3.3 (κανένα νεκρό αρχείο), §4.3, §4.4, §5.5, §5.9, §8.3, L6 ✅, L11 μερικώς, L36 |
| `error_list.md` | E15 → ✅ FIXED (με πλήρη αιτιολόγηση), E62 → ✅ FIXED (181/27 SnackBar), E61 παραμένει INFO |

**Αναμενόμενη συμπεριφορά:** **καμία αλλαγή για τον χρήστη** — η λειτουργία που αφαιρέθηκε ήταν ήδη αδύνατη. Γι' αυτό **χωρίς version bump** (`2.3.10+17`, ίδιο σκεπτικό με E56).

### Quality gates

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ **260/260** (ίδιο πλήθος — καμία δοκιμή δεν αφαιρέθηκε) |
| `flutter build apk --debug` | ✅ |
| Device tests (POCO X3, `9593c01e`) | ✅ βλ. `device test/` |

### Εκκρεμότητες

- **E61** (INFO): κεντρικά μηνύματα + διατύπωση «offline → θα συγχρονιστεί» — ιδέα χωρίς υλοποίηση.
- **L11**: 181 άμεσα `SnackBar(...)` σε 27 αρχεία — καμία κεντρική πολιτική μηνυμάτων/a11y.
- Επόμενη στη σειρά: **E5** (ντετερμινιστικά IDs onboarding).

### Backups

`backups/2026-11-25-e15-l6-cleanup/` — 11 αρχεία (κώδικας + DESIGN + error_list + oldsessions) πριν από κάθε αλλαγή.
