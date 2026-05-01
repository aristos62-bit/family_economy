# 📄 exchange_rates collection (Firestore)

Ο πίνακας `exchange_rates` αποθηκεύει ισοτιμίες νομισμάτων για χρήση σε συναλλαγές, μετατροπές και αναφορές.

---

## 🧱 Πεδία

| Πεδίο | Τύπος | Περιγραφή |
|-------|-------|-----------|
| `uuid` | `string` | Μοναδικό ID εγγραφής ισοτιμίας |
| `from_currency` | `string` | ISO νόμισμα πηγής (π.χ. `"EUR"`) |
| `to_currency` | `string` | ISO νόμισμα προορισμού (π.χ. `"USD"`) |
| `rate` | `number` | Πόσα `to_currency` αντιστοιχούν σε 1 `from_currency` |
| `valid_from` | `string` | Από πότε ισχύει αυτή η ισοτιμία (YYYY-MM-DD) |
| `valid_to` | `string \| null` | Μέχρι πότε ισχύει (ή `null` για ενεργή) |
| `source` | `string \| null` | Πηγή της ισοτιμίας (π.χ. `"ECB"`, `"Manual"`) |
| `created_at` | `string` | Πότε δημιουργήθηκε |

---

## 🔁 Συγχρονισμός

- Συνήθως **δεν συγχρονίζεται ανά χρήστη** — είναι global (shared για όλους)
- Δεν χρειάζεται `deleted` ή `last_modified_device_id`, εκτός αν επιλέξεις να τον επεκτείνεις

---

## 🔁 Παράδειγμα υπολογισμού

Αν έχεις συναλλαγή σε USD:

```js
amount_in_eur = amount_in_usd / exchange_rate_EUR_to_USD;
