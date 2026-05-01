# 📄 transaction_tags collection (Firestore)

Αυτός ο πίνακας χρησιμοποιείται για τη συσχέτιση συναλλαγών με tags, σε ένα many-to-many σχήμα.

---

## 🧱 Πεδία

| Πεδίο | Τύπος | Περιγραφή |
|-------|-------|-----------|
| `transaction_id` | `string` | ID της συναλλαγής |
| `tag_id` | `string` | ID του tag |

---

## 🧠 Παρατηρήσεις

- Κάθε εγγραφή δηλώνει ότι η συναλλαγή `transaction_id` έχει το tag `tag_id`
- Δεν υπάρχει `uuid` γιατί το πρωτεύον κλειδί είναι ο **συνδυασμός των δύο πεδίων**
- Δεν χρειάζονται `created_at` / `updated_at` εκτός αν θέλεις audit log
- Αν προσθέσεις custom timestamps, μπορείς να τους έχεις και στο Firestore schema

---

## 🔁 Εναλλακτική: Inline tags

Αν προτιμάς πιο απλό σχήμα, μπορείς να αποθηκεύεις tags μέσα στο transaction:

```json
"tags": ["Groceries", "Family"]
