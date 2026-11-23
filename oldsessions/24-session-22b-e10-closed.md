# Session 22b (2026-11-23) — E10: έλεγχος & κλείσιμο ως μη εφαρμόσιμο

> **Κεφάλαιο 24/24** · **Ημερομηνία:** 2026-11-23 · **Εύρημα:** E10 · **Καμία αλλαγή κώδικα**

## Ερώτημα

Χρειάζεται ακόμη το **E10** («MessageBubble layout παγώνει μετά από cold restart»);

## Έλεγχος

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `MessageBubble` / `ChatMessagesList` στο `lib/` | **0 αναφορές** |
| Αρχεία `*chat*` / `*message*` | Μόνο `core/services/message_service.dart` (snackbars, όχι bubbles) |
| Χρήση `MessageService` | Μόνο `main.dart:120` → `showSyncComplete` |
| `DESIGN.md` / `README.md` | Καμία αναφορά σε `MessageBubble` (το §3 περιγράφει μόνο snackbars) |
| Git history | Καμία ένδειξη — έχει γίνει rewrite history (19/11, κεφάλαιο 14) |

Δηλαδή το bug αφορά widget που **έχει αφαιρεθεί από την εφαρμογή**· δεν υπάρχει διαδρομή χρήστη
που να το φτάνει, άρα δεν είναι διορθώσιμο ή αναπαραγώγιμο ζήτημα.

## Ενέργειες

- `error_list.md`: E10 → **`🚫 WON'T FIX` (2026-11-23)** + αιτιολόγηση· αφαιρέθηκε από τη
  «Σειρά εκκρεμοτήτων» (μένουν **E5**, **E19**).
- `oldsessions/09-bubble-layout-cache-bug.md`: καταληκτική σημείωση κλεισίματος (χωρίς re-write).
- `DESIGN.md`: καμία αλλαγή (δεν ανέφερε E10).
