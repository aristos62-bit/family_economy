# 📄 tags collection (Firestore)

Ο πίνακας `tags` σου επιτρέπει να οργανώνεις και να φιλτράρεις συναλλαγές με λέξεις-κλειδιά.  
Κάθε χρήστης μπορεί να δημιουργήσει τα δικά του tags με προαιρετικό χρώμα.

---

## 🧱 Πεδία

| Πεδίο | Τύπος | Περιγραφή |
|-------|-------|-----------|
| `uuid` | `string` | Σταθερό ID του tag |
| `user_id` | `string` | ID χρήστη |
| `name` | `string` | Όνομα του tag (μοναδικό ανά χρήστη) |
| `color` | `string \| null` | HEX χρώμα για εμφάνιση |
| `created_at` | `string` | ISO timestamp δημιουργίας |
| `updated_at` | `string` | ISO timestamp τροποποίησης |
| `last_modified_device_id` | `string` | Για συγχρονισμό |
| `deleted` | `boolean` | Soft delete σημαία |

---

## 🔁 Συγχρονισμός

Απαραίτητα:
- `uuid`, `updated_at`, `last_modified_device_id`, `deleted`

---

## 🧠 Σημειώσεις

- Το `name` πρέπει να είναι **μοναδικό ανά χρήστη** για να αποφύγεις διπλό tag με ίδιο όνομα
- Αν χρησιμοποιείς autocomplete στη UI, αυτός ο πίνακας είναι η πηγή

---

## ✅ Παράδειγμα εμφάνισης

```json
{
  "uuid": "tag_001",
  "name": "Groceries",
  "color": "#4CAF50"
}
