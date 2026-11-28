# 54 — E94–E96: διάταξη γραφημάτων & deletion guard

> **Ημερομηνία:** 28/11/2026 · **Session:** 47 · **Έκδοση:** `2.3.19+26` (χωρίς version bump)
> **Σχετικά:** E94, E95, E96

## Πλαίσιο

Τρία ανεξάρτητα ευρήματα μετά το E93:

- **E94:** η Αρχική έδειχνε παλιά διάταξη γραφημάτων μετά από αλλαγή καρτέλας.
- **E95:** ο guard της δεύτερης συσκευής έμενε «απενεργοποιημένος» μετά από κανονική αποσύνδεση.
- **E96:** ψευδές «διαγράφηκε σε άλλη συσκευή» για νέο λογαριασμό χωρίς επιβεβαιωμένο user doc.

## Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/presentation/screens/charts/general_view_page.dart` | E94: `_prefsRequested` ανά instance· νέα ανάγνωση prefs σε κάθε νέα σελίδα· fallback μόνο χωρίς έτοιμη διάταξη |
| `lib/core/services/deletion_guard_service.dart` | E95: self-healing `_forgetSubscription` σε `onError`/`onDone` |
| `lib/core/services/auth_service.dart` | E95: `signOut()` → `detach()` πριν το `_auth.signOut()` |
| `lib/presentation/auth/app_start.dart` | E95: `_logout()` μέσω `AuthService`· E96: `attach()` μόνο με `ensured.exists` |
| `lib/presentation/screens/options/options_page.dart` | E95: και τα δύο signOut μέσω `AuthService` |
| `lib/presentation/auth/login_page.dart` | E96: `attach()` μόνο με `ensured.exists` |

## Γιατί έτσι

### E94 — stale διάταξη

Το `PageView` της `HomePage` δεν κρατά alive τη `GeneralViewPage`· σε κάθε επιστροφή η σελίδα ξαναχτίζεται, εφαρμόζει το `initialLayout` της εκκίνησης και το `_layoutReady` μπλοκάρει τη νέα ανάγνωση. Η λύση κρατά το `initialLayout` για το πρώτο καρέ (E87) αλλά κάνει **μία** νέα ανάγνωση ανά instance· το fallback εφαρμόζεται μόνο όταν δεν υπάρχει έτοιμη διάταξη.

### E95 — guard μετά από logout

Το `attach()` είναι idempotent μόνο όταν ο listener είναι ζωντανός. Μετά το `signOut` ο listener πεθαίνει με permission-denied, αλλά το `_subscription` έμενε μη-`null`. Η λύση έχει δύο επίπεδα: `detach()` σε κάθε κανονική αποσύνδεση (κεντρικά στο `AuthService`) και καθαρισμό του `_subscription` όταν ο listener κλείσει. Το `_lock()` του guard μένει με απευθείας `FirebaseAuth.signOut()` για να μη χαθεί το `_pendingMessage` που διαβάζει η σελίδα σύνδεσης.

### E96 — attach μόνο με επιβεβαιωμένο doc

Το `ensureUserDocument` επιστρέφει `exists:false` μόνο για `skippedOffline`/`skippedError`. Το `attach()` σε αυτές τις περιπτώσεις άκουγε ένα doc που δεν είχε δημιουργηθεί· μόλις ο server απαντούσε «δεν υπάρχει», ο guard έκλεινε τη συνεδρία με λάθος μήνυμα. Το `deletionPending` χειρίζεται πριν το attach· τα `cache hit`, `server hit` και `created` έχουν `exists:true`.

**Trade-off:** αν υπάρχων χρήστης με άδειο cache αποτύχει προσωρινά στο `ensureUserDocument`, ο guard δεν ενεργοποιείται σε αυτή τη συνεδρία· ενεργοποιείται στο επόμενο retry/εκκίνηση.

## Quality gates

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | ✅ No issues found (0/0/0) |
| `flutter test` (πλήρες) | ✅ **400/400** |
| `git diff --check` | ✅ καθαρό |

## Device tests (POCO X3 NFC, Android 12)

| Έλεγχος | Αποτέλεσμα |
|---|---|
| E94: αλλαγή διάταξης/περιόδου → «Λογαριασμοί» → επιστροφή | ✅ νέα διάταξη |
| E95: logout → login ίδιου χρήστη → remote deletion | ✅ lock |
| E96: νέος λογαριασμός με κακό δίκτυο → κανένα ψευδές μήνυμα | ⏳ δεν εκτελέστηκε |

## Backups

`backups/2026-11-28-guard-detach/` — `deletion_guard_service.dart`, `auth_service.dart`, `app_start.dart`, `options_page.dart`.
`backups/2026-11-28-guard-exists/` — `app_start.dart`, `login_page.dart`.
`backups/2026-11-28-e94-e96-docs/` — `error_list.md`, `oldsessions.md`, `DESIGN.md` (πριν τη συμπλήρωση).

> E94: η αλλαγή εφαρμόστηκε από τον χρήστη· δεν δημιουργήθηκε backup στο repo.

## Εκκρεμότητες

- Καμία ανοιχτή στο `error_list.md`.
- Device test E96: δεν εκτελέστηκε σε αυτό το session.
