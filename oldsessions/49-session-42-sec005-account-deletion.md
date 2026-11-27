# Session 42 (2026-11-27) — SEC-005: πλήρης διαγραφή λογαριασμού

> **Κεφάλαιο 49/49** · **Ημερομηνία:** 2026-11-27 · **Σχετικά:** SEC-005, E86, `2.3.16+23`

### Πλαίσιο

- Η παλιά ροή έγραφε μόνο `deleted:true` + `deleted_at` στο root doc και καλούσε `user.delete()`· οι **12 συλλογές** κάτω από `users/{uid}` έμεναν ορφανές μετά τη διαγραφή του Auth χρήστη.
- Σε `requires-recent-login` ο χρήστης έβλεπε μήνυμα χωρίς δυνατότητα συνέχισης.
- Κλεισμένη πρόταση **SEC-005 v4**: client cascade (χωρίς Cloud Function/Blaze), reauth-first, resume guard με κλείδωμα.

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `core/utils/account_deletion_policy.dart` | **Νέο**, καθαρό Dart: 12 συλλογές (φύλλα πρώτα, `categories` τελευταίο), chunks ≤499, timeout 20s, marker helpers, όλα τα μηνύματα |
| `core/services/account_deletion_service.dart` | **Νέο**: marker → cascade (νέο batch ανά chunk) → root **μόνο** αν όλα πετύχουν· report `complete/partial/failed` |
| `core/data/user_doc_policy.dart` | `UserDocOutcome.deletionPending` + `isDeletionPending` (single source of truth) |
| `core/services/auth_service.dart` | `AuthFlowException` (code + `requiresRecentLogin`), `reauthenticateWithPassword`, `deleteCurrentUser`, μήνυμα `requires-recent-login`, marker check σε cache/server |
| `presentation/auth/app_start.dart` | Guard πριν από βιομετρικό/schema· οδηγία «Αποσύνδεση» μέσω του υπάρχοντος `StartupErrorView` |
| `presentation/auth/login_page.dart` | «Συνέχισε τη διαγραφή» με τα credentials της φόρμας· cascade → `cancelAll` (χωρίς αίτημα άδειας) → Auth delete με μία επανάληψη reauth· signOut σε κάθε αποτυχία |
| `presentation/screens/options/delete_account_page.dart` | Reauth-first (κωδικός), cascade loop, partial dialog, root/Auth delete, best-effort notifications, `PopScope`, ενημερωμένα κείμενα |
| `pubspec.yaml` | `2.3.15+22` → **`2.3.16+23`** |

### Ροή (v4)

1. Offline guard → διπλή επιβεβαίωση → κωδικός → `reauthenticateWithPassword`.
2. Marker `deleted:true` + `deleted_at` (`serverTimestamp`).
3. Cascade 12 συλλογών· υποκατηγορίες πριν τις κατηγορίες· νέο batch ανά 499.
4. Root doc delete μόνο μετά από πλήρη cascade.
5. `cancelAllNotifications` best-effort → `user.delete()` (μία επανάληψη reauth).
6. Partial/failed: το root μένει ως κλείδωμα· retry χωρίς νέο login· σε επόμενη εκκίνηση `AppStart`/`LoginPage` προσφέρουν συνέχιση.

### Quality gates

- `flutter analyze`: ✅ **No issues found** (0/0/0).
- `flutter test`: ✅ **358/358** (336 + 19 νέα `account_deletion_policy_test` + 3 `user_doc_policy`).
- `flutter build apk --release`: ✅ `app-release.apk` (85.1 MB) — `versionCode=23`, `versionName=2.3.16`.
- Εγκατάσταση POCO X3 (`9593c01e`): ✅ footer «Έκδοση 2.3.16 (build 23)».

### Device tests (POCO X3)

| # | Έλεγχος | Αποτέλεσμα |
|---|---|---|
| 1 | Πλήρης διαγραφή disposable λογαριασμού (`accounts=1`, `categories=14`, `subcategories=95`) | ✅ root 404 + **όλες** οι συλλογές 0 docs + `subcategories=0` |
| 2 | Λάθος κωδικός στο reauth | ✅ «Λάθος email ή κωδικός πρόσβασης.» — **καμία** αλλαγή (root `deleted=false`, counts ίδια) |
| 3 | Επιτυχής διαγραφή → έξοδος | ✅ spinner/κλείδωμα κουμπιών → login page |
| 4 | Auth user μετά τη διαγραφή | ✅ `INVALID_LOGIN_CREDENTIALS` |
| 5 | Offline guard | ✅ «Χωρίς σύνδεση» πριν από κάθε επιβεβαίωση |
| 6 | Resume: marker από REST + login | ✅ «Εκκρεμεί διαγραφή λογαριασμού» → «Συνέχισε τη διαγραφή» → «✅ Ο λογαριασμός διαγράφηκε οριστικά.» → root 404 + 0 docs + Auth fails |
| 7 | Demo integrity | ✅ `demo@yahoo.com` login, δεδομένα ανέπαφα (500/1.347/4.000 κ.λπ.), παραμένει logged in· app σε background |

- Σημείωση: το resume test απαίτησε `pm clear` (κενό cache), γιατί εξωτερικό REST PATCH δεν ενημερώνει το SDK cache — ίδιος γνωστός περιορισμός cache-first (E64), καταγεγραμμένος στο DESIGN §5.15.
- Καθαρισμός: διαγράφηκαν τα disposable test accounts/δεδομένα και τα προσωρινά token files· ο demo λογαριασμός **δεν** αγγίχτηκε.

### Εκκρεμότητες

- **E86** ✅ FIXED — καμία νέα εκκρεμότητα.
- Γνωστός περιορισμός: cache-first (E64) με πιθανό stale cache σε **άλλη** συσκευή (DESIGN §5.15).

### Backups

- `backups/2026-11-27_sec005/` — 10 αρχεία πριν από τα edits (κώδικας, tests, docs).
