# 53 — E93: κωδικός χωρίς trim σε login & αλλαγή

> **Ημερομηνία:** 28/11/2026 · **Session:** 46 · **Έκδοση:** `2.3.19+26` (χωρίς version bump)
> **Πηγή:** εγκεκριμένη πρόταση E93 (5 βήματα) — αναστολή του κανόνα #4 του `AGENTS.md`.

## Πλαίσιο

Το `trim()` στον κωδικό αλλοίωνε σιωπηλά την είσοδο:

- `login_page.dart`: `password`/`confirmPassword` περνούσαν `.trim()` πριν από `signIn`/`register` → κωδικός με κενά στις άκρες δεν συνδεόταν ποτέ· στο register αποθηκευόταν αλλοιωμένος.
- `change_password_page.dart`: `.trim()` σε validation, re-auth και `updatePassword` → «λάθος τρέχων κωδικός» για σωστό κωδικό με κενά και νέος κωδικός αποθηκευμένος αλλοιωμένος.

## Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/core/utils/password_change_policy.dart` (νέο) | Καθαρό Dart (0 Firebase): `minLength = 6`, `isBlank()` (trim μόνο για «μόνο κενά»), `validateLoginPassword`, `validateConfirmPassword`, `validateChange` + μηνύματα ως σταθερές |
| `lib/presentation/auth/login_page.dart` | `password`/`confirmPassword` **raw**· οι δύο validators χρησιμοποιούν την policy· μήκος ≥6 στο raw |
| `lib/presentation/screens/options/change_password_page.dart` | `_validate()` → `PasswordChangePolicy.validateChange`· re-auth και `updatePassword` με **raw** τιμές |
| `test/unit/core/utils/password_change_policy_test.dart` (νέο) | 12 tests: κενά στις άκρες, exact confirmation, μήκος raw, μόνο κενά, login validators + source guard (κανένα `.text.trim()` σε password) |

## Γιατί έτσι

- Ο κωδικός είναι **verbatim** credential: το trim επιτρέπεται μόνο για να απορριφθεί πεδίο με αποκλειστικά κενά.
- Το validation εξήχθη σε pure policy (pattern `AccountDeletionPolicy` / `DeletionGuardPolicy`), γιατί το `AuthService` στο `LoginPage` είναι static και δεν είναι injectable.
- **Αλλαγή συμπεριφοράς (αποδεκτή):** κενά στις άκρες δεν «συγχωρούνται» πλέον — σωστό κατά standard.
- **Καμία μετανάστευση:** οι υπάρχοντες in-app κωδικοί είναι ήδη trimmed (δημιουργήθηκαν από την προηγούμενη συμπεριφορά).
- `AuthService.signIn/register` trimάρουν μόνο το email· `reauthenticateWithPassword` και `AccountPasswordDialog` (E90) ήταν ήδη raw — δεν άλλαξαν.

## Quality gates

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | ✅ No issues found (0/0/0) |
| `flutter test` (νέο αρχείο) | ✅ 12/12 |
| `flutter test` (πλήρες) | ✅ **400/400** |

## Device tests (POCO X3 NFC, Android 12)

Release `2.3.19+26` (commit `ba2aed7`), disposable λογαριασμός `e93.dev@example.com`.

| Έλεγχος | Αποτέλεσμα | Απόδειξη |
|---|---|---|
| Εγκατάσταση + cold start | ✅ | `e93_01_after_install.png` |
| Login με ` e93pass1 ` (κενά στις άκρες) | ✅ | `e93_06_login_spaced_ok.png` |
| Mismatch raw (` zzzzzz9 ` vs `zzzzzz9`) → «Ο νέος κωδικός και η επιβεβαίωση δεν ταιριάζουν» | ✅ | `e93_14_mismatch_message.png` |
| Αλλαγή σε ` zzzzzz9 ` (raw) | ✅ — REST: `abcdef1` αποτυγχάνει, ` zzzzzz9 ` συνδέεται | — |
| Logout → login με ` zzzzzz9 ` | ✅ — μπήκε στην Αρχική | `e93_18_login_filled_new.png`, `e93_19_after_login_new_password.png` |
| Καθαρισμός temp user (Auth + root doc + 12 υποσυλλογές) | ✅ — 0 docs | — |
| Επανασύνδεση demo με τα δεδομένα του | ✅ | `e93_24_demo_home.png` |
| Επαναφορά συσκευής (font_scale 1.0, auto-rotation, airplane off) | ✅ | — |

> Screenshots/logs: untracked `device test/screenshots/e93_*` & `device test/logs/e93_*`.
> Το success snackbar της αλλαγής δεν φωτογραφήθηκε (το session έκλεισε πριν το submit)· η αλλαγή επιβεβαιώθηκε με REST sign-in και νέο login.

## Backups

`backups/2026-11-28-e93/` — `login_page.dart`, `change_password_page.dart`.
`backups/2026-11-28-e93-device-tests/` — `53-e93-password-trim.md`, `oldsessions.md`, `error_list.md` (πριν τη συμπλήρωση των device tests).

## Εκκρεμότητες

- Καμία ανοιχτή στο `error_list.md` μετά το E93.
