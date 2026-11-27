# Session 41 (2026-11-27) — E67: contrast helper με εγγυημένη αντίθεση ≥ 4.5:1

> **Κεφάλαιο 48/48** · **Ημερομηνία:** 2026-11-27 · **Σχετικά:** E67, L37, E85, `2.3.15+22`

### Πλαίσιο

- Μετά το κεφ. 47 έμενε μόνο το **E67 / L37** ως ℹ️ INFO (και το E60). Το `ColorsUI.getAccessibleTextColor` (`ui_tokens.dart`) διάλεγε `textPrimaryLight`/`textPrimaryDark` με **threshold luminance 0.5**, χωρίς εγγύηση 4.5:1: π.χ. warning `#ED6C02` (light) → ~3.1:1, μεσαίο γκρι → ~3.5:1.
- Στο `stats_page.dart` υπήρχε **νεκρή έκφραση** `fg.withValues(alpha: 0.78);` — το αποτέλεσμα πετιόταν· αν ανατίθετο, θα **χαμήλωνε** την αντίθεση.
- Πρότυπο: το `MessagePolicy.foregroundFor` (`message_policy.dart:103-107`) — max contrast μεταξύ λευκού/μαύρου.
- Απόφαση χρήστη: διόρθωση του helper + διαγραφή της νεκρής γραμμής + επέκταση του `ui_tokens_test`. Τα follow-ups **E85** κλείνουν ως 🚫 **WON'T FIX**.

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `lib/core/theme/ui_tokens.dart` | Νέο `ColorsUI.minContrastRatio = 4.5`· `getAccessibleTextColor` δοκιμάζει **και** τα δύο tokens του theme και επιστρέφει όποιο περνά (το καλύτερο)· αν **κανένα** δεν φτάνει 4.5:1 → καθαρό `Colors.black`/`Colors.white` κατά max contrast (πάντα ≥ 4.58:1). Doc comment: η εγγύηση αφορά **αδιαφανές** background. |
| `lib/presentation/screens/stats/stats_page.dart` | Διαγραφή της νεκρής έκφρασης `fg.withValues(alpha: 0.78);` (γρ. 1707 πριν) — μηδενική οπτική αλλαγή. |
| `test/unit/core/theme/ui_tokens_test.dart` | 4 → **9** tests: λευκό/μαύρο φόντο, warning light (το παράδειγμα του E67), μεσαίο γκρι με fallback black/white, **sweep 256 αποχρώσεων γκρι** με έλεγχο ≥ 4.5:1. |

### Επαλήθευση

- `flutter analyze`: ✅ **No issues found** (0/0/0).
- `flutter test`: ✅ **336/336** (331 + 5 νέα).
- **Device test (27/11/2026):** ✅ release **`2.3.15+22`** (84,9 MB) → POCO X3 (`9593c01e`, `versionCode=22`, `versionName=2.3.15`)· footer «Έκδοση 2.3.15 (build 22)»· Ρυθμίσεις → Στατιστικά → «Ανάλυση Εσόδων Εξόδων»· επιλογή Έσοδα + λογαριασμού + υποκατηγορίας → η κάρτα «Περίληψη Επιλογών» εμφανίστηκε σωστά (περίοδος, τύπος, 1 λογαριασμός, 1 κατηγορία, 5 υποκατηγορίες, ταξινόμηση/ομαδοποίηση/σχόλια)· κανένα Flutter/Android σφάλμα στο logcat. Αναμενόμενη **μηδενική οπτική διαφορά** (βλ. E85).
- Ο χρήστης **απενεργοποίησε το βιομετρικό** στη συσκευή για να περάσει το gate — τοπική ρύθμιση, δεν αλλάζει κάτι στο repo.

### Ευρήματα E85 (🚫 WON'T FIX)

- **(α) Αδρανές `fg`:** στις κάρτες «Περίληψη Επιλογών» (`stats_page`, `tag_stats_page`) το `fg` περνά μόνο σε `IconTheme.merge`/`DefaultTextStyle.merge`, αλλά **κάθε** εσωτερικό `Text`/`Icon` ορίζει δικό του χρώμα (`cPrimary`, `cText2`) → κανένα ορατό στοιχείο δεν το χρησιμοποιεί· το E67 είχε μηδενική πραγματική επίπτωση.
- **(β) Ημιδιαφανές background:** τα 2 call sites περνούν `cPrimary.withValues(alpha: 0.08)` (light) — ο υπολογισμός γίνεται στα RGB χωρίς ανάμειξη με το υπόβαθρο. Ακίνδυνο σήμερα λόγω (α)· ο περιορισμός τεκμηριώνεται στο doc comment.
- **Απόφαση χρήστη:** κλείσιμο ως 🚫 **WON'T FIX** — καμία ορατή επίπτωση, δεν αξίζει αλλαγή κώδικα.

### Docs & έκδοση

- `DESIGN.md`: §1.1 `2.3.15+22`· §1.5.2 build/artifact· §2.7/§9.1/§9.2 **336**· §9.2 `ui_tokens_test` 9 tests· §5.5/§8 a11y εγγύηση 4.5:1· §11 L37 ✅ FIXED.
- `error_list.md`: E67 → ✅ FIXED· νέο **E85** → 🚫 WON'T FIX· ενημέρωση κεφαλίδας και «Σειρά εκκρεμοτήτων».
- `README.md`: έκδοση `2.3.15+22`, tests 336.
- `pubspec.yaml`: `2.3.14+21` → **`2.3.15+22`**.

### Εκκρεμότητες

- **E60** — ℹ️ INFO, παραμένει ως έχει (απόφαση χρήστη).
- Καμία άλλη ανοιχτή διόρθωση.

### Backups

- `backups/2026-11-27_e67/` — `ui_tokens.dart.bak`, `stats_page.dart.bak`, `ui_tokens_test.dart.bak`· `docs/` (DESIGN, README, oldsessions, error_list, pubspec)· screenshots device test (`device_01…16`).

### Κλείσιμο session

- **Commit:** _συμπληρώνεται μετά το commit/push._
