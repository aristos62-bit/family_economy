# Session 27 (2026-11-23) — E22/E54: νεκρός κώδικας + κείμενο διαλόγου

> **Κεφάλαιο 30/30** · **Ημερομηνία:** 2026-11-23 · **Σχετικά:** E22, E54, `2.3.7+14`

### Πλαίσιο

Μετά το L26 (`2.3.6+13`), επιλέχθηκαν δύο εκκρεμότητες με **μηδενικό ρίσκο**:
E22 (νεκρή μέθοδος υπολοίπου) και E54 (γραμματικό λάθος «Οι 0 κινήσεις» στον
διάλογο αρχειοθέτησης). Καμία αλλαγή σε Firestore, rules, indexes ή schema.

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/providers/accounts_provider.dart` | Αφαίρεση `applyLocalBalanceDelta` (0 call sites σε `lib/`/`test/`)· η `updateAccountBalance` μένει **ενεργή** (E20) |
| `lib/presentation/screens/accounts/accounts_page.dart` | `_confirmArchiveDialog`: 0 κινήσεις → «Καμία κίνηση· το υπόλοιπο … διατηρείται»· 1/N διατηρούν σωστό ενικό/πληθυντικό |
| `pubspec.yaml` | `2.3.6+13` → **`2.3.7+14`** (PATCH: bug fix/κείμενο) |
| `DESIGN.md` | §1/§1.5 έκδοση· §3.3 αφαίρεση αναφοράς στη νεκρή μέθοδο |
| `error_list.md` | E22/E54 → ✅ FIXED· η σειρά εκκρεμοτήτων χωρίς E22 |

### Quality gates

- `flutter analyze` → **No issues found**.
- `flutter test` → **238/238** (αμετάβλητο — δεν άλλαξε συμπεριφορά).
- Καμία νέα ανάγνωση/εγγραφή· μόνο `lib/` + docs.

### Εκκρεμότητες

- Επόμενη στη σειρά: **L18** (`ErrorApp` «Επανεκκίνηση» → `Null check operator`).
- **E15/L6** παραμένουν εκτός σειράς (τεχνικό χρέος).
- E54: μόνο κείμενο· η ροή του διαλόγου καλύφθηκε από τα device tests του L26.

### Backups

- `backups/*_20261123_194504.bak`: `accounts_provider.dart`, `accounts_page.dart`,
  `pubspec.yaml`, `DESIGN.md`, `error_list.md`, `oldsessions.md`.
