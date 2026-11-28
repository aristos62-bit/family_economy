# Session 44 (2026-11-28) — SEC-005b: ολοκλήρωση διαγραφής όταν αποτύχει το Auth delete

> **Κεφάλαιο 51/51** · **Ημερομηνία:** 2026-11-28 · **Σχετικά:** SEC-005b, E86 · `2.3.18+25`

### Πλαίσιο

Το SEC-005 (E86) έκλεισε τη διαγραφή των 12 συλλογών, αλλά άφησε ένα κενό:
το `deleteAccountData()` διαγράφει το root doc μετά το cascade και **μετά**
γίνεται το `user.delete()`. Αν το Auth delete αποτύχει, δεν μένει marker·
το επόμενο login βλέπει «doc λείπει» και δημιουργεί νέο άδειο λογαριασμό
αντί να συνεχίσει τη διαγραφή.

Η πρόταση εγκρίθηκε με τις εξής διευκρινίσεις:

- οι ειδοποιήσεις ακυρώνονται **πριν** το `deleteAccountData()` (μικρότερο
  παράθυρο root → marker restore),
- ID **SEC-005b** (το E89 είναι ήδη τα γραφήματα),
- `finalizeDeletion` με προϋπόθεση `report.isComplete` ώστε να μην μπορεί
  να ορφανέψει υποσυλλογές.

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `core/utils/account_deletion_policy.dart` | Νέα μηνύματα `authPendingTitle`, `authPendingMessage`, `authPendingClosedMessage`. |
| `core/services/account_deletion_service.dart` | `_writeMarker()` (κοινό σημείο)· νέο `finalizeDeletion(report, deleteAuthUser)`: έλεγχος `isComplete` → root delete → Auth delete· σε αποτυχία ξαναγράφει τον marker και επιστρέφει `false`. |
| `presentation/screens/options/delete_account_page.dart` | Οι ειδοποιήσεις μετακινήθηκαν πριν το cascade· το Auth delete περνά από `finalizeDeletion`· νέος διάλογος «Η διαγραφή δεν ολοκληρώθηκε» με «Συνέχισε τη διαγραφή»/«Κλείσιμο»· το «Κλείσιμο» κάνει signOut και πλοήγηση στο login. |
| `presentation/auth/login_page.dart` | Το resume της ημιτελούς διαγραφής χρησιμοποιεί το ίδιο `finalizeDeletion`· σε αποτυχία εμφανίζει `authPendingClosedMessage` και αποσυνδέει. |
| `test/unit/core/utils/account_deletion_policy_test.dart` | Έλεγχος και των 3 νέων μηνυμάτων. |
| `pubspec.yaml` | `2.3.18+25`. |
| `DESIGN.md` §5.15 | Νέα σειρά (notifications πριν το root), νέα γραμμή «Auth αποτυχία (SEC-005b)», έκδοση. |

### Γιατί έτσι

- **Root πριν το Auth:** μετά το `user.delete()` δεν υπάρχει auth για να
  διαγραφεί το root doc (rules: `request.auth.uid == userId`).
- **Marker restore:** κρατά την πληροφορία «εκκρεμεί διαγραφή» στο Firestore
  ώστε το επόμενο login να συνεχίσει αντί να δημιουργήσει νέο doc.
- **Προϋπόθεση `isComplete`:** το Firestore δεν κάνει cascade· root delete
  χωρίς cascade θα άφηνε ορφανές υποσυλλογές.
- **Notifications πριν το cascade:** best effort, δεν εξαρτώνται από τη
  διαγραφή· μειώνουν το χρονικό παράθυρο root → marker.

### Quality gates

- `flutter analyze`: **No issues found** (0/0/0).
- `flutter test`: **374/374**.
- Device tests POCO X3: ⏳ θα συμπληρωθούν μετά το build.

### Περιορισμοί

- Αν η εφαρμογή κλείσει βίαια ανάμεσα στο root delete και την επανεγγραφή
  του marker, το πρόβλημα μπορεί να εμφανιστεί ακόμη· το παράθυρο είναι
  μικρό αλλά όχι μηδενικό.
- Χωρίς δίκτυο, ο διάλογος μπορεί να αργήσει έως ~40″ (δύο timeouts 20″).
- Αν το `user.delete()` πετύχει αλλά πετάξει (π.χ. timeout), το marker restore
  αποτυγχάνει χωρίς auth και ο διάλογος λέει «εκκρεμεί» ενώ έχει ολοκληρωθεί·
  σπάνιο, η τελική κατάσταση είναι ασφαλής.

### Backups

`backups/*.bak-20261128-sec005b` — policy, service, delete page, login page,
pubspec, test, DESIGN, error_list, oldsessions.
