# Session 11 (2026-10-02)

> **Κεφάλαιο 12/16** · **Ημερομηνία:** 2026-10-02 · **Πηγή:** `oldsessions.md` γρ. 245–252 (αρχείο πριν το refactor της 2026-11-20)

---

### Fix υπολοίπου (float dust) ✅ — 50/50 tests, analyze clean
- Αιτία: `FieldValue.increment` μαζεύει σκόνη float — υπόλοιπο 99.9999 δείχνει 100,00€ αλλά `amount > balance` έκοβε αγορά 100€
- Έλεγχος όλης της εφαρμογής: μπλοκάρισμα μόνο σε `transaction_entry_details_step.dart:680,736` (+ ίδιας οικογένειας `budget_page.dart:972,1295` display υπέρβασης)
- Γενικευμένο fix: `CurrencyFormatter.covers/isOverspent` (σύγκριση στρογγυλοποιημένη στα cents) + 6 tests
- Backups: currency_formatter, details_step, budget_page
