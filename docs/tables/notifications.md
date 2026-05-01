# 📄 notifications collection (Firestore)

Η συλλογή `notifications` διαχειρίζεται ειδοποιήσεις για τον χρήστη.  
Στόχος της είναι να αποθηκεύει **πραγματικές ειδοποιήσεις** που μπορούν να σταλούν ως push notifications, να εμφανιστούν στην εφαρμογή, και να συγχρονιστούν ανάμεσα σε συσκευές.

---

## 🧱 Πεδία

| Πεδίο | Τύπος | Περιγραφή |
|-------|-------|-----------|
| `uuid` | `string` | Μοναδικό αναγνωριστικό της ειδοποίησης |
| `user_id` | `string` | Σε ποιον χρήστη ανήκει |
| `device_id` | `string \| null` | Αν στοχεύει συγκεκριμένη συσκευή |
| `type` | `string` | Τύπος ειδοποίησης (`budget_alert`, `reminder`, `custom`, `system`) |
| `title` | `string` | Τίτλος που εμφανίζεται στον χρήστη |
| `message` | `string` | Το μήνυμα της ειδοποίησης |
| `related_id` | `string \| null` | Το σχετικό αντικείμενο (budget, transaction, κ.λπ.) |
| `related_type` | `string \| null` | Πίνακας του related αντικειμένου (π.χ. `"budget"`, `"event"`) |
| `delivered_at` | `string \| null` | Πότε παραδόθηκε |
| `read_at` | `string \| null` | Πότε διαβάστηκε |
| `dismissed_at` | `string \| null` | Πότε απορρίφθηκε |
| `created_at` | `string` | Πότε δημιουργήθηκε |
| `updated_at` | `string` | Πότε τροποποιήθηκε |
| `last_modified_device_id` | `string` | Συσκευή που την δημιούργησε/τροποποίησε |
| `deleted` | `boolean` | Soft delete flag |

---

## 🔁 Συγχρονισμός

Απαραίτητα πεδία για sync:
- `uuid`, `updated_at`, `deleted`, `last_modified_device_id`

---

## 🔔 Λειτουργία με Push Notifications

- Αυτή η συλλογή μπορεί να συνδεθεί με Firebase Cloud Messaging (FCM)
- Μπορείς να τη χρησιμοποιείς για:
    - **Αποστολή push notification**
    - **Εμφάνιση in-app ειδοποιήσεων**
    - **Συγχρονισμό κατάστασης ειδοποίησης (read, dismissed)**

---

## ✅ Παράδειγμα εμφάνισης

```json
{
  "uuid": "notif_001",
  "type": "budget_alert",
  "title": "Budget Reached",
  "message": "You've spent 100% of your budget.",
  "related_type": "budget"
}
