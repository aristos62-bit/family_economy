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

_(συμπληρώνεται μετά την εκτέλεση)_

## Backups

`backups/2026-11-28-e93/` — `login_page.dart`, `change_password_page.dart`.

## Εκκρεμότητες

- Καμία ανοιχτή στο `error_list.md` μετά το E93.
