# Session 6 (2026-05-26)

> **Κεφάλαιο 06/16** · **Ημερομηνία:** 2026-05-26 · **Πηγή:** `oldsessions.md` γρ. 101–124 (αρχείο πριν το refactor της 2026-11-20)

---

### Bug: Phantom subcategories μετά από Μετακίνηση — budget_page.dart
**Περιγραφή:** Δημιουργία νέου προϋπολογισμού με 1 κατηγορία (Διατροφή €100, χωρίς ποσά υποκατηγοριών). Η κάρτα εμφανίζεται σωστά χωρίς down arrow. Μετά από "Μετακίνηση" στον επόμενο μήνα, η κάρτα δείχνει phantom υποκατηγορίες (Χωρίς Κατηγορία €100, Σούπερ Μάρκετ €100) με down arrow.

**Αιτία:**
1. `_deleteGroupedBudget` διέγραφε μόνο category-level budgets — οι subcategory budgets έμεναν orphaned (`deleted: false`)
2. `_moveGroupedBudget` δεν φιλτράριζε `budgetType` ή `categoryId`, οπότε τα orphaned subcats με ίδιο όνομα/ημερομηνίες μαζεύονταν και μετακινούνταν κι αυτά
3. `_editGroupedBudget` είχε ήδη το σωστό query pattern (από Session 5 fix)

### Διορθώσεις που εφαρμόστηκαν ✅

1. **`budget_page.dart` — `_deleteGroupedBudget`**: Query όλων των budgets (category + subcategory) matching name/accountId/startDate/endDate, και διαγραφή όλων — ίδια λογική με `_editGroupedBudget`

2. **`budget_page.dart` — `_moveGroupedBudget`**: Αντικατάσταση `groupBudgets.map((e) => e.model)` με το ίδιο query pattern (category + subcategory)

3. **`budgets_provider.dart`**: Νέο `_cleanupOrphanedSubcategoryBudgets()` — τρέχει μία φορά στο πρώτο load, εντοπίζει subcategory budgets χωρίς parent category budget και τα διαγράφει

4. **`custom_currency_field.dart` — `didUpdateWidget`**: Προσθήκη controller update όταν αλλάζει `widget.controller` (από Session 4)

5. **`input_budget_page.dart`**: Pie chart & legend φιλτράρισμα με `_selectedCategoryFilter` (από Session 3)

6. **`purchase_card.dart`**: Προσθήκη `mounted` checks πριν από SnackBar
