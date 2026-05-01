# 📄 budgets collection (Firestore)

Ο πίνακας `budgets` χρησιμοποιείται για να ορίσεις οικονομικά όρια (προϋπολογισμούς) με βάση κατηγορίες, υποκατηγορίες, λογαριασμούς ή συνολικά.

---

## 🧱 Πεδία

| Πεδίο | Τύπος | Περιγραφή |
|-------|-------|-----------|
| `uuid` | `string` | Μοναδικό ID του προϋπολογισμού |
| `user_id` | `string` | Σε ποιον χρήστη ανήκει |
| `name` | `string` | Όνομα του budget (π.χ. "Food", "Monthly Total") |
| `budget_type` | `string` | `"category"`, `"subcategory"`, `"account"`, `"total"` |
| `category_id` | `string \| null` | Αν το budget είναι για κατηγορία |
| `subcategory_id` | `string \| null` | Αν είναι για υποκατηγορία |
| `account_id` | `string \| null` | Αν είναι για λογαριασμό |
| `period_type` | `string` | `"weekly"`, `"monthly"`, `"quarterly"`, `"yearly"`, `"custom"` |
| `start_date` | `string` | Πότε ξεκινά |
| `end_date` | `string \| null` | Πότε τελειώνει (ή `null` για χωρίς τέλος) |
| `amount` | `number` | Ποσό προϋπολογισμού |
| `currency` | `string` | ISO νομισματικός κωδικός |
| `alert_threshold` | `number` | Ποσοστό (π.χ. `80`) για ειδοποίηση overspending |
| `allow_overspend` | `boolean` | Αν επιτρέπεται υπέρβαση |
| `is_active` | `boolean` | Αν είναι ενεργό |
| `created_at` | `string` | Ημερομηνία δημιουργίας |
| `updated_at` | `string` | Ημερομηνία τελευταίας αλλαγής |
| `last_modified_device_id` | `string` | Για συγχρονισμό |
| `deleted` | `boolean` | Soft delete |

---

## 🔁 Συγχρονισμός

Απαραίτητα:
- `uuid`, `updated_at`, `deleted`, `last_modified_device_id`

---

## ✅ Επιτρεπόμενοι συνδυασμοί

| `budget_type` | Υποχρεωτικό πεδίο |
|---------------|-------------------|
| `category` | `category_id` |
| `subcategory` | `subcategory_id` |
| `account` | `account_id` |
| `total` | Κανένα από τα παραπάνω |

---

## 💡 Παρατηρήσεις

- Χρησιμοποιείται και από το σύστημα για **ειδοποιήσεις** (budget alerts)
- Μπορείς να έχεις πολλαπλά budgets με διαφορετικούς τύπους και περιόδους

---

## ✅ Παράδειγμα εμφάνισης

```json
{
  "uuid": "budget_001",
  "name": "Groceries Monthly",
  "budget_type": "subcategory",
  "amount": 250,
  "start_date": "2024-01-01",
  "end_date": "2024-01-31"
}
