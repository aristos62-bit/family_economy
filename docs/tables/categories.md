# 📄 categories collection (Firestore)

Ο πίνακας `categories` περιέχει τις βασικές κατηγορίες για τις συναλλαγές (π.χ. Έξοδα, Έσοδα, Μεταφορές).

---

## 🧱 Πεδία

| Πεδίο | Τύπος | Περιγραφή |
|-------|-------|-----------|
| `uuid` | `string` | Μοναδικό ID για τη συγχρονισμένη κατηγορία |
| `user_id` | `string` | ID χρήστη στον οποίο ανήκει η κατηγορία |
| `name` | `string` | Όνομα κατηγορίας (π.χ. "Food", "Salary") |
| `type` | `string` | `"income"`, `"expense"`, ή `"transfer"` |
| `icon_index` | `number` | Δείκτης για εικονίδιο στην UI |
| `color` | `string` | Χρώμα σε μορφή HEX (π.χ. `"#FF5722"`) |
| `is_system` | `boolean` | `true` αν είναι προεγκατεστημένη από το σύστημα |
| `hidden` | `boolean` | Αν είναι κρυφή από τον χρήστη |
| `display_order` | `number` | Θέση εμφάνισης στις λίστες |
| `created_at` | `string` | Πότε δημιουργήθηκε |
| `updated_at` | `string` | Πότε έγινε η τελευταία αλλαγή |
| `last_modified_device_id` | `string` | Ποια συσκευή την επεξεργάστηκε |
| `deleted` | `boolean` | Αν είναι διαγραμμένη (soft delete) |

---

## 🔁 Συγχρονισμός

- `uuid`, `updated_at`, `last_modified_device_id`, `deleted` είναι απαραίτητα για offline sync
- Χρησιμοποιούμε `soft delete` για να μη χάνεται κατηγορία που έχει χρησιμοποιηθεί σε παλιές συναλλαγές

---

## 🔍 Παρατηρήσεις

- Οι **system κατηγορίες** (`is_system: true`) δεν πρέπει να διαγράφονται από τον χρήστη
- Αν η κατηγορία είναι `type: "transfer"` συνήθως δεν χρησιμοποιείται από τον χρήστη απευθείας, αλλά από το σύστημα για μεταφορές

---

## ✅ Παράδειγμα εμφάνισης

```json
{
  "uuid": "cat_001",
  "name": "Food",
  "type": "expense",
  "color": "#FF5722",
  "icon_index": 3
}
