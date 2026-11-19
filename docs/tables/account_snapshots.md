# 📄 account_snapshots collection (Firestore)

Ετήσιο «κλείδωμα» υπολοίπου ανά λογαριασμό. **Η εφαρμογή δεν τη χρησιμοποιεί σήμερα** (0 αναφορές στο `lib/`) — υπάρχει μόνο στους κανόνες, στο import script και στα legacy docs.

---

## 🧱 Πεδία

| Πεδίο | Τύπος | Περιγραφή |
|-------|-------|-----------|
| `uuid` | `string` | Μοναδικό ID του snapshot |
| `account_id` | `string` | ID του λογαριασμού |
| `user_id` | `string` | ID χρήστη |
| `year` | `number` | Έτος (για γρήγορα queries) |
| `currency` | `string` | Νομισματική μονάδα |
| `closing_balance` | `number` | Υπόλοιπο στο τέλος του έτους |
| `total_income` | `number` | Σύνολο εσόδων |
| `total_expense` | `number` | Σύνολο εξόδων |
| `generated_at` | `timestamp` | Πότε δημιουργήθηκε (business timestamp) |
| `created_at` | `timestamp` | Firestore timestamp για sync |
| `updated_at` | `timestamp` | Firestore timestamp για sync |
| `last_modified_device_id` | `string` | Για sync tracking |
| `deleted` | `boolean` | Soft delete flag |

---

## 📎 Παράδειγμα

```json
{
  "uuid": "snap_2023_acc0001",
  "account_id": "acc_0001",
  "user_id": "user_001",
  "year": 2023,
  "currency": "EUR",
  "closing_balance": 385.50,
  "total_income": 1200.00,
  "total_expense": 914.50,
  "generated_at": "2024-01-01T00:00:00Z",
  "created_at": "2024-01-01T00:00:01Z",
  "updated_at": "2024-01-01T00:00:01Z",
  "last_modified_device_id": "dev_001",
  "deleted": false
}
```
