# 📄 transactions collection (Firestore)

Η βασική συλλογή που καταγράφει κάθε οικονομική κίνηση: έσοδα, έξοδα, μεταφορές, επαναλαμβανόμενα, split κινήσεις, κ.λπ.

---

## 🧱 Πεδία

| Πεδίο | Τύπος | Περιγραφή |
|-------|-------|-----------|
| `uuid` | `string` | Σταθερό ID για συγχρονισμό |
| `user_id` | `string` | ID χρήστη |
| `account_id` | `string` | ID λογαριασμού |
| `category_id` | `string` | ID κατηγορίας |
| `subcategory_id` | `string \| null` | ID υποκατηγορίας (προαιρετικό) |
| `date` | `string` | Ημερομηνία και ώρα συναλλαγής |
| `amount` | `number` | Ποσό (αρνητικό για έξοδα, θετικό για έσοδα) |
| `currency` | `string` | ISO κωδικός (π.χ. "EUR") |
| `exchange_rate` | `number` | Συναλλαγματική ισοτιμία |
| `notes` | `string` | Περιγραφή / σχόλια |
| `attachment_path` | `string \| null` | Σύνδεσμος σε αποθηκευμένο αρχείο |
| `transaction_type` | `string` | `income`, `expense`, `transfer` |
| `transfer_group_id` | `string \| null` | Κοινό ID για ζευγάρια μεταφοράς (π.χ. από acc1 σε acc2) |
| `is_recurring` | `boolean` | Αν είναι επαναλαμβανόμενη |
| `recurring_schedule_id` | `string \| null` | Ανήκει σε recurring schedule |
| `tags` | `array[string]` | Tags όπως `["food", "family"]` |
| `location_lat` | `number \| null` | Γεωγραφικό πλάτος |
| `location_lng` | `number \| null` | Γεωγραφικό μήκος |
| `is_split` | `boolean` | Αν είναι split συναλλαγή |
| `created_at` | `string` | ISO timestamp δημιουργίας |
| `updated_at` | `string` | ISO timestamp τροποποίησης |
| `last_modified_device_id` | `string` | Ποια συσκευή έκανε την αλλαγή |
| `deleted` | `boolean` | Soft delete |

---

## 🔁 Συγχρονισμός

Απαραίτητα για sync:
- `uuid`, `updated_at`, `last_modified_device_id`, `deleted`
- Οι μεταφορές έχουν **2 κινήσεις με ίδιο `transfer_group_id`**

---

## 🔁 Παρατηρήσεις

- Πρέπει να εξασφαλίζεται `amount ≠ 0`
- Οι recurring δημιουργούνται είτε χειροκίνητα είτε αυτόματα από τον scheduler
- Χρησιμοποιείται `soft delete` για να μην χαθούν ιστορικά δεδομένα

---

## ✅ Παράδειγμα εμφάνισης

```json
{
  "uuid": "txn_0001",
  "amount": -25.90,
  "transaction_type": "expense",
  "category_id": "cat_001",
  "subcategory_id": "subcat_001",
  "date": "2024-01-10T15:30:00Z"
}
