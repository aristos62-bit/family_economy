# 📄 attachments collection (Firestore)

Η συλλογή `attachments` επιτρέπει την αποθήκευση εγγράφων ή αρχείων (π.χ. φωτογραφίες αποδείξεων) που σχετίζονται με συναλλαγές.

---

## 🧱 Πεδία

| Πεδίο | Τύπος | Περιγραφή |
|-------|-------|-----------|
| `uuid` | `string` | Σταθερό ID |
| `user_id` | `string` | ID χρήστη |
| `transaction_id` | `string \| null` | Συναλλαγή στην οποία συσχετίζεται |
| `file_name` | `string` | Όνομα αρχείου |
| `file_path` | `string` | Πλήρης διαδρομή ή URL του αρχείου |
| `file_type` | `string \| null` | MIME type (π.χ. `image/jpeg`, `application/pdf`) |
| `file_size` | `number \| null` | Μέγεθος σε bytes |
| `thumbnail_path` | `string \| null` | Μικρογραφία (για εικόνες) |
| `created_at` | `string` | ISO ημερομηνία δημιουργίας |
| `last_modified_device_id` | `string` | Ποια συσκευή το πρόσθεσε |
| `deleted` | `boolean` | Soft delete σημαία |

---

## 📎 Τι υποστηρίζει

- Φωτογραφίες αποδείξεων
- PDF, Word, TXT αρχεία
- Εικόνες που συνοδεύουν έσοδα/έξοδα

---

## 🔁 Συγχρονισμός

| Απαραίτητα | Περιγραφή |
|------------|-----------|
| `uuid` | Συγκεκριμένο ID για κάθε attachment |
| `last_modified_device_id` | Για conflict resolution |
| `deleted` | Soft delete |
| `created_at` | Χρήσιμο για sync & filtering |

---

## 🧠 Παρατηρήσεις

- Τα αρχεία **δεν αποθηκεύονται** μέσα στη Firestore, αλλά σε **Firebase Storage**
- Μπορείς να ορίσεις storage paths με βάση τον `user_id` ή `transaction_id`
- Χρήσιμο να δημιουργείς μικρογραφίες (thumbnails) για εικόνες

---

## ✅ Παράδειγμα εμφάνισης

```json
{
  "uuid": "attach_001",
  "file_name": "receipt.jpg",
  "file_path": "users/user_001/attachments/receipt.jpg"
}
