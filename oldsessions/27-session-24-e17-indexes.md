# Session 24 (2026-11-23) — E17: indexes repo ↔ deployed

> **Κεφάλαιο 27/27** · **Ημερομηνία:** 2026-11-23 · **Σχετικά:** E17, E21, L3, L6

### Πλαίσιο

- Το `firestore.indexes.json` είχε **3** indexes· το deployed project είχε **7** (όλα `READY`, STANDARD, `SPARSE_ALL`).
- Έλειπαν 4: `account_id+deleted+date ASC`, `category_id+deleted+date ASC`, `deleted+date ASC`, `deleted+date DESC`.
- Ένα deploy θα πρότεινε **διαγραφή** των 4 (prompt/`--force`) → σιωπηλές αποτυχίες:
  - budgets spent **0,00 €** (`budgets_provider:270-275`),
  - `graf_6` κενή κατάσταση (`:636-639`),
  - Κινήσεις λογαριασμού από **cache** (`transactions_show_page:151-157`),
  - executor **`return []`** (`scheduled_transactions_service:419-422`).
- Επιβεβαίωση με τον matcher του CLI 15.28.1: repo→deployed 3/3, deployed→repo 4 EXTRA, 4 deletions.
- Rules: deployed = repo (**57=57** semantic) → έκλεισε το εκκρεμές (α).

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `firestore.indexes.json` | 3 → **7** indexes (D1–D7), ρητό `density: SPARSE_ALL` + `__name__`· legacy D3/D7 διατηρήθηκαν |
| `test/unit/core/data/firestore_indexes_test.dart` | **Νέο** guard, 3 tests: δομή, 5 required signatures (υπερσύνολο), κανένα διπλότυπο |
| `DESIGN.md` | §6.3 πίνακας 7 με «Χρήση»· §10.5 εντολές επαλήθευσης· §11 L6 σημείωση· §9/§2.5/§3.1 counts → 222 |
| `error_list.md` | E17 → **FIXED**· σειρά εκκρεμοτήτων χωρίς E17· (α) rules ✅ |
| `oldsessions.md` | Νέο κεφάλαιο 27 + ενημέρωση κατάστασης |

### Απόδειξη deploy no-op

- `firebase deploy --only firestore:indexes --project family-economy-d1b4d --non-interactive` → **Deploy complete**.
- Πριν/μετά: **7 → 7** indexes, **0 diffs**, ίδια `createTime` (καμία recreation), όλα `READY`.
- Ruleset αμετάβλητο: `76aa78a0-4172-40f0-95bd-752ca2caf7e5`.
- Field overrides/TTL: **0** → κανένα prompt.

### Quality gates

- `flutter analyze` → **No issues found**.
- `flutter test` → **222/222** (219 + 3 guard tests).
- CLI matcher: **7/7 MATCH, 0 deletions, 0 creations**.

### Αποφάσεις

- **Καμία διαγραφή** legacy D3/D7 τώρα (κανένα τρέχον query· ρίσκο σε παλιούς clients).
- **Κανένα νέο error ID** — το budgets→0 καλύπτεται από E21/E37· το `recurring_notifications` από L6.
- **Κανένα version bump** (δεν άλλαξε binary).

### Εκκρεμότητες

- Επόμενο: **L26** (orphan budgets) + διορθώσεις τεκμηρίωσης.
- Προαιρετικά, με ξεχωριστή έγκριση: καθαρισμός D3/D7 (repo + cloud).

### Backups

- `backups/2026-11-23-e17-indexes/`: `firestore.indexes.json`, `DESIGN.md`, `error_list.md`.
