# 📄 recurring_schedules collection (Firestore)

Περιέχει επαναλαμβανόμενα προγράμματα συναλλαγών (έσοδα, έξοδα ή μεταφορές) με συγκεκριμένη συχνότητα.

---

## 🧱 Πεδία

| Πεδίο | Τύπος | Περιγραφή |
|-------|-------|-----------|
| `uuid` | `string` | Μοναδικό ID της επαναλαμβανόμενης κίνησης |
| `user_id` | `string` | ID χρήστη |
| `account_id` | `string` | Σε ποιον λογαριασμό εφαρμόζεται |
| `category_id` | `string` | Κατηγορία της συναλλαγής |
| `subcategory_id` | `string \| null` | Προαιρετική υποκατηγορία |
| `schedule_name` | `string` | Όνομα του recurring (π.χ. "Netflix") |
| `amount` | `number` | Ποσό (αρνητικό για έξοδα) |
| `currency` | `string` | ISO κωδικός νομίσματος |
| `notes` | `string` | Περιγραφή ή σχόλιο |
| `transaction_type` | `string` | `"income"`, `"expense"`, `"transfer"` |
| `transfer_group_id` | `string \| null` | Αν είναι μεταφορά |
| `frequency` | `string` | `"daily"`, `"weekly"`, `"monthly"`, `"yearly"`, κ.ά. |
| `frequency_interval` | `number` | Κάθε πόσο συχνά (π.χ. `1` κάθε μήνα, `2` κάθε 2 μήνες) |
| `start_date` | `string` | Από πότε ξεκινά |
| `end_date` | `string \| null` | Μέχρι πότε ισχύει (ή null για πάντα) |
| `next_occurrence` | `string` | Πότε θα παραχθεί η επόμενη κίνηση |
| `last_generated_date` | `string` | Πότε δημιουργήθηκε τελευταία |
| `is_active` | `boolean` | Αν είναι ενεργή |
| `auto_generate` | `boolean` | Αν δημιουργεί αυτόματα νέα transactions |
| `skip_weekends` | `boolean` | Αν παραλείπει Σαββατοκύριακα |
| `skip_holidays` | `boolean` | Αν παραλείπει αργίες (δεν έχει σύστημα αργιών ακόμα) |
| `created_at` | `string` | Πότε δημιουργήθηκε |
| `updated_at` | `string` | Πότε τροποποιήθηκε |
| `last_modified_device_id` | `string` | Για συγχρονισμό |
| `deleted` | `boolean` | Soft delete |

---

## 🔁 Συγχρονισμός

Απαραίτητα:
- `uuid`, `updated_at`, `last_modified_device_id`, `deleted`

---

## 🧠 Σημειώσεις

- Οι εγγραφές recurring **δεν είναι οι ίδιες** με τις actual transactions — απλώς **παράγουν** συναλλαγές.
- Αν `auto_generate` είναι `false`, τότε ο χρήστης τις ενεργοποιεί χειροκίνητα.

---

## ✅ Παράδειγμα εμφάνισης

```json
{
  "uuid": "rec_001",
  "schedule_name": "Monthly Salary",
  "amount": 1500,
  "frequency": "monthly",
  "next_occurrence": "2024-02-01"
}
