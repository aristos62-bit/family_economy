# 📄 users collection (Firestore)

Η συλλογή `users` αποθηκεύει επιπλέον στοιχεία για κάθε χρήστη πέρα από όσα καλύπτει η Firebase Authentication.

---

## 🧱 Πεδία

| Πεδίο | Τύπος | Περιγραφή |
|-------|-------|-----------|
| `uuid` | `string` | Πρέπει να είναι ίδιο με το Firebase UID |
| `user_id` | `string` | Ίδιο με το `uuid` — γράφεται από την εφαρμογή (το legacy `data/users.json` δεν το περιέχει) |
| `username` | `string \| null` | Optional, για εσωτερική χρήση |
| `email` | `string \| null` | Προαιρετικά, για εμφάνιση ή filtering |
| `display_name` | `string \| null` | Όνομα προβολής |
| `is_guest` | `boolean` | True αν ο χρήστης είναι guest χωρίς κανονικό login |
| `auth_provider` | `string` | Πηγή σύνδεσης (`password`, `google`, `facebook`, `anonymous`, `fingerprint`) |
| `fingerprint_enabled` | `boolean` | Αν έχει ενεργοποιηθεί το biometric login |
| `default_currency` | `string` | Προτίμηση νομίσματος (π.χ. `"EUR"`) |
| `preferred_language` | `string \| null` | Προτίμηση γλώσσας (π.χ. `"el"`) |
| `onboarding_completed` | `boolean` | Αν έχει ολοκληρωθεί η αρχική ρύθμιση |
| `last_sync_at` | `timestamp \| null` | Firestore Timestamp τελευταίου συγχρονισμού |
| `created_at` | `timestamp` | Πότε δημιουργήθηκε το προφίλ |
| `updated_at` | `timestamp` | Πότε τροποποιήθηκε |
| `last_modified_device_id` | `string` | Από ποια συσκευή έγινε η τελευταία αλλαγή |
| `deleted` | `boolean` | Soft delete |
| `schema_version` | `number` | **E4:** έκδοση **δεδομένων** ανά χρήστη — σήμερα `1` (baseline = current) |
| `schema_updated_at` | `timestamp` | Πότε γράφτηκε η έκδοση (πληροφοριακό, δεν παίρνονται αποφάσεις από αυτό) |

> ⚠️ Τα `created_at` / `updated_at` / `last_sync_at` γράφονται από την εφαρμογή ως Firestore `Timestamp`, όχι ως ISO string. Τα `schema_version` / `schema_updated_at` γράφονται **μόνο** από την εφαρμογή (η εφαρμογή τα προσθέτει σε νέο χρήστη· σε υπάρχοντα docs λείπουν και θεωρούνται baseline).

---

## 🔁 Συγχρονισμός

- Το `last_sync_at`, `updated_at`, `last_modified_device_id` είναι απαραίτητα για conflict resolution
- Το `deleted` επιτρέπει soft delete για reset ή αποσύνδεση

---

## 🧠 Guest + Biometric login

- Για guest χρήστες, ορίζεις `is_guest = true` και `auth_provider = anonymous` ή `fingerprint`
- Με fingerprint login, μπορείς να μην έχεις `email`, αλλά θα χρειαστεί **local UID με σύνδεση στο Firestore**

---

## 🛡️ Σημαντική σημείωση

Ο χρήστης **δεν πρέπει να μπορεί να διαβάσει άλλους χρήστες**, ούτε να αλλάξει πεδία ασφαλείας (`auth_provider`, `is_guest`) αν δεν είναι δικά του.

---
