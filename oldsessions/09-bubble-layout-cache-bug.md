# Session 201+ — Bubble Layout Cache Bug (UNRESOLVED)

> **Κεφάλαιο 09/16** · **Ημερομηνία:** 2026-07-16 · **Πηγή:** `oldsessions.md` γρ. 165–201 (αρχείο πριν το refactor της 2026-11-20)
> **Κατάσταση:** UNRESOLVED — παρακολουθείται ως **E10** στο `error_list.md`.

---

### Περιγραφή
- Bug: MessageBubble layout παγώνει σε λάθος κατάσταση μετά από cold restart
- navigate-away-and-back διορθώνει το layout (γιατί dispose() καθαρίζει το cache)
- Η αρχική θεωρία ήταν ότι το `_obtainBubble` cache κάνει identity skip (`child.widget == newWidget`) και δεν καλεί build(), παγώνοντας το layout

### Attempt #1 — Επέκταση ValueKey (Session 202)
- `ValueKey(msgId)` → `ValueKey('$msgId|${bubbleMaxWidth.toStringAsFixed(0)}')`
- **Απέτυχε:** bubbleMaxWidth είναι ίδιο σε κάθε build, οπότε το key δεν άλλαζε
- **REVERTED**

### Attempt #2 — Αφαίρεση cache entirely (Session 202)
- Αφαιρέθηκαν `_MessageBubbleSignature`, `_bubbleCache`, `_bubbleSignatures`, `_obtainBubble`
- `MessageBubble(...)` direct στο itemBuilder
- **Απέτυχε:** layout ακόμα λάθος, πρόβλημα αλλού
- **REVERTED**

### Debug investigation (Session 202-debugs)
Προστέθηκαν 3 debug log points (DebugsConfig.log):
1. `ChatMessagesList.build()` — loggtarei screenW, textScale, itemCount
2. `_obtainBubble()` — loggtarei cache HIT (identityHashCode) ή cache MISS (existingSig)
3. `MessageBubble.build()` — loggtarei build counter, key.hashCode, identity, mediaW, textScale, bubbleMaxWidth

### Αποτελέσματα debugs
- **Το build() καλείται ακόμα και με cache HIT** (ίδιο identity). Π.χ. `BUILD #3` και `BUILD #8` με ίδιο `identity=820304279` — ο Flutter καλεί build() κανονικά, ΔΕΝ γίνεται identity skip
- `screenW` = **384.0 σε ΟΛΑ τα builds** (σταθερό, όχι transition)
- `textScale` = **1.00 σε ΟΛΑ** (σταθερό)
- `bubbleMaxWidth` = **288.0 σε ΟΛΑ** (`384 * 0.75`)
- Παρατηρήθηκε μαζικό rebuild cascade: `MsgBubble BUILD #1→#538+` σε ένα session

### Συμπέρασμα
- Η αρχική θεωρία (cache identity skip) **καταρρίφθηκε** — το cache ΔΕΝ παγώνει το layout
- Όλες οι μετρήσεις (screenW, textScale, bubbleMaxWidth) είναι ίδιες σε κάθε build
- Το πρόβλημα βρίσκεται **αλλού** (ListView reconciliation, parent constraints, ή MediaQuery propagation)
- Το bug παραμένει **UNRESOLVED**

---

### 🚫 Κλείσιμο (2026-11-23)

Έλεγχος κώδικα: τα `MessageBubble` / `ChatMessagesList` **δεν υπάρχουν πλέον** στο `lib/`
(ούτε αρχείο `*chat*`/`*message*` πέρα από το `message_service.dart`, που είναι μόνο snackbar helper
και καλείται μία φορά από το `main.dart`). Το git history δεν βοηθά (rewrite 19/11, κεφάλαιο 14).
Δεν υπάρχει διαδρομή χρήστη που να αναπαράγει το layout bug → το **E10** έκλεισε ως
**WON'T FIX (feature removed)** στο `error_list.md`.
