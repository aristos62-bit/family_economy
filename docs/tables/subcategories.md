# 📄 subcategories collection (Firestore)

Οι υποκατηγορίες ανήκουν σε συγκεκριμένες κατηγορίες και χρησιμοποιούνται για πιο αναλυτική καταγραφή των συναλλαγών.

---

## 🧱 Πεδία

| Πεδίο | Τύπος | Περιγραφή |
|-------|-------|-----------|
| `uuid` | `string` | Μοναδικό ID της υποκατηγορίας |
| `user_id` | `string` | Χρήστης στον οποίο ανήκει |
| `category_id` | `string` | ID κατηγορίας στην οποία υπάγεται |
| `name` | `string` | Όνομα της υποκατηγορίας (π.χ. "Supermarket") |
| `icon_index` | `number` | Προαιρετικό — για εικονίδιο |
| `color` | `string` | HEX χρώμα |
| `is_system` | `boolean` | Αν είναι υποκατηγορία συστήματος |
| `hidden` | `boolean` | Αν είναι κρυφή |
| `display_order` | `number` | Θέση εμφάνισης |
| `created_at` | `string` (ISO 8601) | Πότε δημιουργήθηκε |
| `updated_at` | `string` (ISO 8601) | Πότε τροποποιήθηκε |
| `last_modified_device_id` | `string` | ID της συσκευής που έκανε την αλλαγή |
| `deleted` | `boolean` | Soft delete flag |

---

## 🔁 Συγχρονισμός

- Τα πεδία `uuid`, `updated_at`, `deleted`, `last_modified_device_id` είναι κρίσιμα για offline-first συγχρονισμό
- Οι υποκατηγορίες δεν διαγράφονται εντελώς — χρησιμοποιούμε `deleted: true`

---

## 🔍 Σχέση με άλλους πίνακες

- Συνδέονται με τον πίνακα `categories` μέσω `category_id`
- Χρησιμοποιούνται στα `transactions`, `budgets`, `recurring_schedules`

---

## ✅ Παράδειγμα εμφάνισης

```json
{
  "uuid": "subcat_001",
  "name": "Supermarket",
  "category_id": "cat_001",
  "color": "#FFA726"
}
