# 39 — Session 35: E58 + E59 (startup error container & dead Phoenix)

**Ημερομηνία:** 2026-11-25 · **Έκδοση:** `2.3.10+17` · **Προηγούμενο:** `2.3.9+16`
**Πηγές:** πρόταση Suggestions Agent v4 (E58+E59) · `error_list.md` E58/E59

---

## 1. Τι ζητήθηκε

- E58: `ThemeProvider.initialize()`, `NotificationsService().initialize()` και `ConnectivityService()` έτρεχαν **πριν** το `try` της εκκίνησης → αποτυχία ή κόλλημα = καμία οθόνη (η native λευκή οθόνη του Flutter, αφού το `runApp` δεν είχε γίνει).
- E59: μετά το L18 δεν υπήρχε πουθενά `Phoenix.rebirth` → το `Phoenix` wrapper (`main.dart:172`) και η εξάρτηση `flutter_phoenix` ήταν νεκρός κώδικας.

## 2. Απόφαση (Suggestions Agent, 4 βήματα)

| Απόφαση | Επιλογή | Γιατί |
|---|---|---|
| Άδεια ειδοποιήσεων | **split**: `initialize(requestPermissions: false)` στην εκκίνηση, δημόσιο `requestPermissions()` μετά το πρώτο frame | η εκκίνηση δεν εξαρτάται από διάλογο του λειτουργικού |
| Πολιτική theme/notifications | **best-effort** με όρια 4s / 6s | ήδη καταπίνονται εσωτερικά· hang ήταν το πραγματικό ρίσκο |
| Connectivity | δημιουργία **μέσα** στη guarded ροή με `??=` (μία φορά ανά διεργασία) | πριν δημιουργούνταν πριν το `try`· το `dispose()` δεν καλείται έτσι κι αλλιώς (`.value` provider — L36) |
| E59 βάθος | **πλήρης αφαίρεση** wrapper + `pubspec.yaml` + lock | πακέτο 3 ετών, 70 pub points, μηδενική χρήση |

## 3. Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/main.dart` | `main()` = `ensureInitialized` + `try { _startApplication() } catch { runApp(ErrorApp(onRetry: _startApplication)) }`· νέο δημόσιο `prepareStartup()` (`:63`) με injectable βήματα/χρόνους· `_startApplication()` (`:103`) = prepare + `_bootstrap`· module-level `_themeProvider` / `_connectivityService` (`??=`) / `_startupAttempted`· `resetStartupForTest()` (`:116`)· αφαίρεση import & `Phoenix` wrapper (πλέον `MaterialApp` απευθείας) |
| `lib/services/notifications_service.dart` | `initialize({bool requestPermissions = true})` → ο μοναδικός άλλος καλών (`login_page.dart:184`, default `true`) μένει αμετάβλητος· `_initialized = true` πριν την άδεια· δημόσιο `requestPermissions()` (`:107`) |
| `lib/presentation/screens/splash/splash_screen.dart` | `unawaited(NotificationsService().requestPermissions())` στην αρχή του `_initializeApp` (post-frame) + `dart:async` |
| `pubspec.yaml` | αφαίρεση `flutter_phoenix: ^1.1.1`· version `2.3.10+17` |
| `pubspec.lock` | `flutter pub get` → «These packages are no longer being depended on: flutter_phoenix 1.1.1», `-8` γραμμές (μόνο αυτό· το transitive `nested` 1.0.0 προέρχεται από άλλο πακέτο) |
| `test/unit/core/startup/prepare_startup_test.dart` | **νέο**, 5 tests |
| `DESIGN.md` / `README.md` / `error_list.md` | έκδοση, §4.1 πίνακας, §4.4, §11 L18, πίνακας tests, E58/E59 → ✅, νέο E60 |

### Νέα σειρά εκκίνησης

```
WidgetsFlutterBinding.ensureInitialized()
try {
  prepareStartup():  theme (4s, best-effort) → notifications χωρίς διάλογο (6s, best-effort) → ConnectivityService() ??=
  _bootstrap():      Firebase.initializeApp → authStateChanges(timeout 2s) → Settings (best-effort) → runApp
} catch → ErrorApp(onRetry: _startApplication)
```

## 4. Tests

```
flutter analyze → No issues found! (6.6s)
flutter test    → +260: All tests passed!        (255 + 5 νέα)
```

5 νέα (όλα με injected fakes, χωρίς plugin):
1. σειρά theme → notifications → connectivity
2. theme κολλάει (όριο 10ms) → συνεχίζει
3. notifications πετούν → συνεχίζει
4. connectivity πετά → διαδίδεται (→ `ErrorApp`)
5. retry → **ίδιο** `ConnectivityService` (`created == 1`)

## 5. Device smoke (POCO X3)

- `app-release.apk` (85 MB) → install (`versionCode=17`), cold start online και **offline** (banner OFFLINE με cached δεδομένα), footer `2.3.10 (build 17)`, rotation χωρίς crash.
- Διάλογος άδειας ειδοποιήσεων: **δεν επαληθεύτηκε οπτικά** — η συσκευή τρέχει Android 12 (SDK 31), όπου το `POST_NOTIFICATIONS` δεν είναι runtime permission (υπάρχει από API 33). Η ροή καλύπτεται από κώδικα + unit tests.
- logcat: FATAL 0, `Null check` 0, `Phoenix` 0. Λεπτομέρειες: `device test/E58_E59_device_tests.md`.

## 6. Μάθημα

- Το «πριν το `runApp`» είναι το πραγματικό επικίνδυνο παράθυρο: εκεί δεν υπάρχει **τίποτα** να δείξει σφάλμα. Ό,τι δεν είναι αυστηρά απαραίτητο για το πρώτο frame ανήκει είτε σε `try` είτε μετά το frame.
- `??=` + `isInitialized`/`_initialized` κάνουν το retry δωρεάν: κανένα διπλό listener, κανένα διπλό plugin init.
- Μια εξάρτηση που δεν καλείται δεν «περιμένει ευκαιρία» — είναι επιφάνεια επίθεσης και κόστος συντήρησης.

## 7. Ανοιχτά

- **Docs audit 25/11/2026 (commit `985fcbf`):** E58/E59 → ✅ FIXED με λεπτομέρειες + commit, DESIGN §4.1 ακριβείς γραμμές / §4.2 άδεια post-frame / §4.4 διατύπωση / §5.9 / νέο L36 (`dispose` δεν καλείται) / §3.1 **17** test αρχεία, AGENTS/README χωρίς αλλαγές.
- **E60** (INFO): `DebugConfig._debug = false` σταθερό → `print`/`startup` δεν τυπώνουν τίποτα σε κανένα build (άρα και τα logs του L18 hardening είναι σιωπηλά). Πρόταση: `kDebugMode` ή `--dart-define`.
