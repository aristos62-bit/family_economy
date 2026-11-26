# error_list.md — Ευρήματα & εκκρεμότητες

> **Ρόλος:** η μοναδική λίστα με τα προβλήματα που βρίσκουμε, τη σειρά διόρθωσης και την κατάστασή τους.
> **Πότε διαβάζεται:** στην **αρχή κάθε session** (μαζί με `AGENTS.md` και `oldsessions.md`).
> **Κανόνας:** τίποτα δεν διαγράφεται — αλλάζει μόνο η **Κατάσταση** και συμπληρώνεται η ημερομηνία.
> **Τεχνικές λεπτομέρειες:** `DESIGN.md` · ιστορικό ενεργειών: `oldsessions.md`.

## Σειρά εκκρεμοτήτων (τι κάνουμε μετά)

| # | Ενέργεια | ID |
|---|---|---|
| — | Καμία ανοιχτή εκκρεμότητα | — |

> **E5** ✅ διορθώθηκε 26/11/2026 (`2.3.11+18`): σταθερά ids onboarding + server-truth gate + καμία εγγραφή offline (λεπτομέρειες παρακάτω). **E63** ✅ διορθώθηκε μαζί του (σταθερό `cat-transfer`). **E64** ✅ διορθώθηκε 26/11/2026 (`2.3.12+19`): server-truth `ensureUserDocument`, καμία εγγραφή offline, χωρίς poll.

> **L18** ✅ διορθώθηκε 25/11/2026 (`2.3.8+15`) — το «Δοκιμή ξανά» ξανατρέχει την αρχικοποίηση (λεπτομέρειες: `DESIGN.md` §4.4, §11 L18). **Hardening `2.3.9+16`:** timeout 20s, disabled κουμπί όσο τρέχει, debug log σε αποτυχία/λήξη.
> **E58/E59** ✅ διορθώθηκαν 25/11/2026 (`2.3.10+17`): όλη η εκκίνηση (theme/notifications/connectivity) μπήκε σε δοχείο σφάλματος με per-step timeouts και η άδεια ειδοποιήσεων ζητείται μετά το πρώτο frame· το `Phoenix` + `flutter_phoenix` αφαιρέθηκαν.
> **E15/L6** ✅ διορθώθηκαν 25/11/2026 (χωρίς version bump, κεφ. 40): νεκρός κώδικας + no-op sync hook αφαιρέθηκαν· μένει μόνο το χρέος των άμεσων `SnackBar` (**L11**).

> Τα E6 και E8 είναι κλειστά (σκόπιμη συμπεριφορά / εγγενής περιορισμός) — δεν περιμένουν ενέργεια.
> Τα **E11**, **E13**, **E24** διορθώθηκαν μαζί (έκδοση `2.2.0+6`, 21/11/2026)· τα **E18/E21/E23/E25** είναι ℹ️ INFO.
> Τα **E12**, **E16**, **E26** διορθώθηκαν με την **αρχειοθέτηση λογαριασμών** (έκδοση `2.3.0+7`, 21/11/2026).
> Το **E28** διορθώθηκε με την **ίδια λογική στις αναφορές** — φίλτρο `stats_page`/`tag_stats_page` (έκδοση `2.3.1+8`, 22/11/2026).
> Το **E27** διορθώθηκε με **μία πηγή αλήθειας για τις εξαιρέσεις** (`AccountsProvider`) — γράφημα και Λογαριασμοί δείχνουν το ίδιο σύνολο (έκδοση `2.3.3+10`, 22/11/2026).
> Τα **E14, E19, E29–E33** διορθώθηκαν μαζί με την **επαναφορά λογαριασμού** (έκδοση `2.3.4+11`, 23/11/2026).
> Τα **E34, E37–E47** διορθώθηκαν με τον **καθαρισμό βάσης** (έκδοση `2.3.5+12`, 23/11/2026)· τα **E48/E49** είναι ℹ️ INFO.
> Το **E17** διορθώθηκε με **mirror των 7 indexes** + guard test (23/11/2026)· καμία αλλαγή cloud.
> Τα **L26/E50** διορθώθηκαν με το **gate budgets στη διαγραφή λογαριασμού** (έκδοση `2.3.6+13`, 23/11/2026)· τα **E51–E54** είναι ℹ️ INFO/LOW.
> Τα **E22/E54** διορθώθηκαν ως **καθαρισμός νεκρού κώδικα + κείμενο διαλόγου** (έκδοση `2.3.7+14`, 23/11/2026).
> Το **E56** διορθώθηκε με τη **migration σε `material_ui` 1.11.1** (70 imports + `GlobalMaterialLocalizations.delegates`, χωρίς version bump — 25/11/2026)· `flutter analyze` πλέον **0/0/0**.
> Το **E57** διορθώθηκε με **self-healing ανάγνωση της περιόδου γραφημάτων** (`PeriodPrefs`: επιδιόρθωση CP437/CP1252 + επανεγγραφή, 13 tests — 25/11/2026).
> **Εκτός σειράς (τεχνικό χρέος, χωρίς ορισμένη προτεραιότητα):** **E55**, **E60** — ℹ️ INFO · **E61** — 🚫 WON'T FIX (26/11/2026) · **L23** — 🚫 WON'T FIX / κλειστό (26/11/2026 — read-only έλεγχος: 0 ευρήματα).
> Το **E10** έκλεισε ως **μη εφαρμόσιμο** (η λειτουργία `MessageBubble`/`ChatMessagesList` αφαιρέθηκε από την εφαρμογή — 23/11/2026).
> Τα **E58/E59** προέκυψαν από την ανάλυση του **L18** (25/11/2026) και ✅ διορθώθηκαν στην `2.3.10+17` (λεπτομέρειες παρακάτω· νέο **E60** ℹ️ INFO από τον ίδιο έλεγχο).
> **L23** ✅ έκλεισε 26/11/2026 (🚫 WON'T FIX — κρίθηκε υπερβολή): read-only έλεγχος σε **όλα** τα δεδομένα (6 χρήστες, 2.312 κινήσεις, 146 transfer legs, 73 groups — μόνο GET) → **0** σπασμένα/ημιτελή ζεύγη μεταφοράς. Δεν χρειάζεται επισκευή δεδομένων ούτε fail-closed guard. Ισχύει: (α) ✅ deployed rules = repo rules (23/11/2026 — semantic diff 57=57).

## Ευρήματα

| ID | Πρόβλημα | Κωδικός | Κατάσταση | Ημ/νία |
|---|---|---|---|---|
| E1 | Το onboarding ξανατρέχει σε υπάρχοντα λογαριασμό (διπλότυπα) και γράφει λάθος `display_order` | F1 | ✅ FIXED | 2026-11-20 |
| E2 | Αν λείπει το user doc, schema/onboarding διαβάζουν κενό → μπλοκάρει η ροή | F2 | ✅ FIXED | 2026-11-20 |
| E3 | Σφάλμα στο onboarding μπλοκάρει το login | F3 | ✅ FIXED | 2026-11-20 |
| E4 | Resume μετά από kill αφήνει μισοτελειωμένη κατηγορία (92/95 subcategories) | F8 | ✅ FIXED | 2026-11-20 |
| E5 | Offline onboarding σε 2 συσκευές → διπλότυπα (τυχαία doc IDs) | F5 | ✅ FIXED | 2026-11-26 |
| E6 | Soft-deleted λογαριασμός «μπλοκάρει» τον default | F4 | 🚫 WON'T FIX | 2026-11-20 |
| E7 | Διαγραφή όλων των λογαριασμών → 0 ενεργοί λογαριασμοί | — | ✅ FIXED | 2026-11-20 |
| E8 | Restore app data δεν επαναφέρει session (Keystore) | — | ℹ️ INFO | 2026-11-20 |
| E9 | `users.created_at`/`updated_at` ως ISO string στο onboarding fallback (ασυμφωνία με `auth_service` & docs) | F6 | ✅ FIXED | 2026-11-20 |
| E10 | MessageBubble layout παγώνει σε λάθος κατάσταση μετά από cold restart (η θεωρία περί bubble cache καταρρίφθηκε) | — | 🚫 WON'T FIX | 2026-11-23 |
| E11 | Διαγραφή λογαριασμού που μετέχει σε μεταφορά: το άλλο σκέλος μένει ενεργό και τα υπόλοιπα δεν αναιρούνται | — | ✅ FIXED | 2026-11-21 |
| E12 | Budget που δείχνει διαγραμμένο λογαριασμό εμφανίζεται ως «Όλοι» και με `spent=0` | — | ✅ FIXED | 2026-11-21 |
| E13 | `restoreAccountWithBalance` γράφει όλες τις κινήσεις σε **ένα** batch (όριο 500) | — | ✅ FIXED | 2026-11-21 |
| E14 | Επαναφορά μετά τον cleanup 30 ημερών: επιστρέφει ο λογαριασμός χωρίς ιστορικό | — | ✅ FIXED | 2026-11-23 |
| E15 | `MessageService` πρακτικά ανενεργό (1 no-op call site, μετρητής ποτέ τροφοδοτημένος) + νεκρός κώδικας L6 | — | ✅ FIXED | 2026-11-25 |
| E16 | `transaction_edit_sheet` με λογαριασμό που διαγράφηκε → orphan επιλογή στο dropdown | — | ✅ FIXED | 2026-11-21 |
| E17 | `firestore.indexes.json` δεν είναι πλήρες σε σχέση με το deployed (π.χ. `deleted` + `date` range) | — | ✅ FIXED | 2026-11-23 |
| E18 | `deleteTransaction` peer path δεν ελέγχει `deleted` του peer → μη idempotent (μόνο με αλλοιωμένο δεδομένο) | — | ℹ️ INFO | 2026-11-20 |
| E19 | Επαναφορά λογαριασμού ανασταίνει και κινήσεις που διέγραψε ο χρήστης | — | ✅ FIXED | 2026-11-23 |
| E20 | Επαναϋπολογισμός υπολοίπου: λάθος άθροισμα (φίλτρο ημερομηνίας, εκκρεμείς, offline cache) | — | ✅ FIXED | 2026-11-22 |
| E21 | `_getQueryWithCacheFallback` / `_getDocWithCacheFallback` δεν κάνουν fallback | — | ℹ️ INFO | 2026-11-20 |
| E22 | `applyLocalBalanceDelta` + `updateAccountBalance` νεκρές· DESIGN §3.3 ελλιπές | — | ✅ FIXED | 2026-11-23 |
| E23 | `getScheduledTransactions` επιστρέφει 2 γραμμές ανά εκκρεμή μεταφορά | — | ℹ️ INFO | 2026-11-20 |
| E24 | Offline διαγραφή λογαριασμού με ατελή cache αφήνει ενεργές κινήσεις (και peer leg με E11) | — | ✅ FIXED | 2026-11-21 |
| E25 | Επαναφορά εκκρεμούς ζεύγους με παρελθούσα ημερομηνία → εκτελείται αμέσως | — | ℹ️ INFO | 2026-11-20 |
| E26 | Διαγραφή λογαριασμού με κινήσεις μηδενίζει το σύνολο (εξαφανίζει ιστορικό και peer ποσά) | — | ✅ FIXED | 2026-11-21 |
| E27 | Το γράφημα υπολοίπων (`graf_4`) αγνοεί τις εξαιρέσεις λογαριασμών (`excluded_accounts_{uid}`) | — | ✅ FIXED | 2026-11-22 |
| E28 | Οι αναφορές περιόδου (`stats_page`) και tags (`tag_stats_page`) δεν προσφέρουν αρχειοθετημένους λογαριασμούς στο φίλτρο → οι κινήσεις τους αποκλείονται από τις αναφορές | — | ✅ FIXED | 2026-11-22 |
| E29 | Επαναφορά λογαριασμού: το `archived_at` δεν καθαρίζεται → εμφανίζεται και ως ενεργός και ως αρχειοθετημένος | — | ✅ FIXED | 2026-11-23 |
| E30 | Επαναφορά: τα markers `annulled_by_account_deleted` μένουν στα legs → λάθος έλεγχος ακεραιότητας σε επόμενη διαγραφή | — | ✅ FIXED | 2026-11-23 |
| E31 | Ανάγνωση διαγραμμένου λογαριασμού με αυστηρά casts (`as String`, `as num`) → εξαίρεση σε legacy docs | — | ✅ FIXED | 2026-11-23 |
| E32 | Φραγή «τελευταίος ενεργός» μετράει και τον **αρχειοθετημένο** στόχο → αδικαιολόγητη φραγή | — | ✅ FIXED | 2026-11-23 |
| E33 | Ακύρωση/αποτυχία του διαλόγου επαναφοράς έκλεινε και τον διάλογο δημιουργίας λογαριασμού | — | ✅ FIXED | 2026-11-23 |
| E34 | `DatabaseCleanupService`: batch reused μετά το `commit()` → σε >500 εγγραφές καθαρίζονται μόνο οι πρώτες 500 | — | ✅ FIXED | 2026-11-23 |
| E35 | Chunked διαγραφή λογαριασμού (>499 writes) δεν εφαρμόζει το delta του ίδιου λογαριασμού | — | ℹ️ INFO | 2026-11-23 |
| E36 | Offline: `findDeletedAccountByName` μπορεί να επιστρέψει κενό cache → παράκαμψη του διαλόγου επαναφοράς | — | ℹ️ INFO | 2026-11-23 |
| E37 | Καθαρισμός υποκατηγοριών: διάβαζε **top-level** `subcategories` (δεν υπάρχει) αντί `categories/{id}/subcategories` → 0 διαγραφές | — | ✅ FIXED | 2026-11-23 |
| E38 | Hard delete κατηγορίας χωρίς cascade → ορφανές υποκατηγορίες στο Firestore | — | ✅ FIXED | 2026-11-23 |
| E39 | Soft-deleted υπενθυμίσεις/budgets δεν καθαρίζονταν ποτέ (`where deleted == false`) | — | ✅ FIXED | 2026-11-23 |
| E40 | Δεξαμενή Πετρελαίου: `commit()` μέσα στον βρόχο + δεύτερο `commit()` → `StateError`, το `settings/oil_tank` δεν διαγραφόταν | — | ✅ FIXED | 2026-11-23 |
| E41 | Προεπισκόπηση: positional indexing σε conditional `Future.wait` → λάθος πλήθη όταν έλειπε μεσαία επιλογή | — | ✅ FIXED | 2026-11-23 |
| E42 | Ο διάλογος επιβεβαίωσης έδειχνε **παλιά** πλήθη αν ο χρήστης άλλαζε slider μετά την προεπισκόπηση | — | ✅ FIXED | 2026-11-23 |
| E43 | Χωρίς offline gate: `Source.server` offline → catch → «επιτυχία» με 0 διαγραφές | — | ✅ FIXED | 2026-11-23 |
| E44 | Σφάλματα ανά εργασία καταπίνονταν → `success: true` ακόμη και με μερική/μηδενική διαγραφή | — | ✅ FIXED | 2026-11-23 |
| E45 | Χωρίς `PopScope`/κλείδωμα επιλογών κατά την εκτέλεση → αλλαγή slider ή έξοδος ενώ τρέχει | — | ✅ FIXED | 2026-11-23 |
| E46 | `_parseTimestamp` καθαρισμού δεν χειριζόταν `int` (millis) / `DateTime` σε αντίθεση με τα models | — | ✅ FIXED | 2026-11-23 |
| E47 | Δύο sliders «Παλαιότητα» (κατηγορίες/υποκατηγορίες) έγραφαν την **ίδια** μεταβλητή → σύγχυση | — | ✅ FIXED | 2026-11-23 |
| E48 | Hard delete κατηγορίας: το `ScheduledTransactionsService` δείχνει «Άγνωστη Κατηγορία/Υποκατηγορία» | — | ℹ️ INFO | 2026-11-23 |
| E49 | Καθαρισμός mid-run χωρίς σύνδεση: με persistence ON τα writes μπαίνουν σε **ουρά** (όχι σφάλμα) | — | ℹ️ INFO | 2026-11-23 |
| E50 | Καμία επαναξιολόγηση μετά το φρέσκο preflight → σιωπηλή διαγραφή με νέα δεδομένα | — | ✅ FIXED | 2026-11-23 |
| E51 | Ανενεργά budgets αόρατα σε όλη την εφαρμογή (query `is_active=true`) | — | ℹ️ INFO | 2026-11-23 |
| E52 | Legacy budgets χωρίς `is_active`/`deleted` αόρατα (ίδια ρίζα με E51) | — | ℹ️ INFO | 2026-11-23 |
| E53 | `BudgetModel.fromFirestore`: `amount as num` / `user_id as String` → legacy doc ρίχνει **όλο** τον listener | — | ℹ️ LOW | 2026-11-23 |
| E54 | Διάλογος αρχειοθέτησης: «Οι **0** κινήσεις … διατηρούνται» όταν δεν υπάρχουν κινήσεις | — | ✅ FIXED | 2026-11-23 |
| E55 | Windows artifact `assets/icons/subcategories/expense/desktop.ini` είναι **tracked** στο git (δεν ανήκει στο repo) | — | ℹ️ INFO | 2026-11-24 |
| E56 | 72 `info` deprecations: `package:flutter/material.dart` → Material ως ξεχωριστό πακέτο (`material_ui`) | — | ✅ FIXED | 2026-11-25 |
| E57 | Χαλασμένη τιμή περιόδου γραφήματος στο SharedPreferences (`╬£╬«╬╜╬▒╧é` αντί `Μήνας` — UTF-8 bytes ως CP437) | — | ✅ FIXED | 2026-11-25 |
| E58 | `ThemeProvider.initialize()` / `NotificationsService().initialize()` τρέχουν **έξω** από το `try` της εκκίνησης → αποτυχία = uncaught exception χωρίς οθόνη σφάλματος | — | ✅ FIXED | 2026-11-25 |
| E59 | Μετά τη διόρθωση του L18 το `Phoenix` (`main.dart`, πριν την αφαίρεση) και η εξάρτηση `flutter_phoenix` δεν είχαν καμία χρήση (νεκρός κώδικας) | — | ✅ FIXED | 2026-11-25 |
| E60 | `DebugConfig._debug = false` σταθερό → `DebugConfig.print/startup` δεν τυπώνουν τίποτα, σε κανένα build (και τα logs του L18 hardening) | — | ℹ️ INFO | 2026-11-25 |
| E61 | Αφαιρέθηκε το `MessageService` χωρίς αντικαταστάτη· η αρχική ιδέα «offline → θα συγχρονιστεί» και το κεντρικό μήνυμα συγχρονισμού δεν υλοποιήθηκαν ποτέ | — | 🚫 WON'T FIX | 2026-11-26 |
| E62 | `DESIGN.md` §5.5: «186 άμεσα SnackBar σε 28 αρχεία» έναντι μέτρησης 25/11/2026 | — | ✅ FIXED | 2026-11-25 |
| E63 | Διπλή κατηγορία «Μεταφορά» από 2 συσκευές: `_getOrCreateTransferCategory` έγραφε τυχαίο uuid | F5 | ✅ FIXED | 2026-11-26 |
| E64 | `createUserDocumentIfNeeded` τρέχει πριν το E5 gate: offline `set` + poll ~7.5s πριν την είσοδο | F5 | ✅ FIXED | 2026-11-26 |

### Λεπτομέρειες

**E1–E3 — Onboarding fixes**
- Η ροή οδηγείται από `onboarding_completed` (όχι από τη λειτουργία Εγγραφή/Σύνδεση).
- Δημιουργία user doc όταν λείπει (`createUserDocumentIfNeeded`) πριν από schema/onboarding.
- Σφάλμα onboarding δεν μπλοκάρει το login.
- `display_order` ανά τύπο: income 1–6, expense 1–8.
- Commit: `1df699a`.

**E4 — Resume ατελής κατηγορία**
- Αιτία: έλεγχος idempotency σε επίπεδο **κατηγορίας** (`type|name`), οπότε μια κατηγορία που γράφτηκε μισή παραλειπόταν ολόκληρη.
- Λύση: `_existingCategoryState` — map `type|name` → categoryId + υπάρχοντα subcategory names· συμπλήρωση **μόνο** των λείπουσων.
- Επαλήθευση στη συσκευή: 95/95, «Μισθοί» 5/5, μηδέν διπλότυπα.
- Commit: `1df699a` · στοιχεία: `device test/README.md`.

**E5 — Offline multi-device (FIXED 26/11/2026, `2.3.11+18`)**
- Πρόβλημα: δύο συσκευές με `onboarding_completed=false` (η μία με offline cache) έγραφαν διαφορετικά docs → 2 accounts, 28 categories, ~190 subcategories.
- Δεν λύνεται με `runTransaction`/batch: απαιτεί server (σπάει το offline-first) και δεν κάνει conflict detection σε διαφορετικά IDs.
- Λύση (v4): 
  - **Σταθερά ids** από `lib/core/data/onboarding_defaults.dart` (καθαρό Dart): `default-account`, `cat-income-1…6`, `cat-expense-1…8`, `sub-1…n` ανά γονέα → idempotent `set(..., merge:true)`.
  - **Server-truth gate 2 επιπέδων:** `login_page`/`AppStart` ελέγχουν πρώτα `ConnectivityService.isConfirmedOffline` (fast fail)· το `OnboardingService` διαβάζει το root doc **και** όλες τις κατηγορίες/υποκατηγορίες με `Source.server` + timeout 8s.
  - **Καμία εγγραφή offline:** `OnboardingOfflineException` → ορατό μήνυμα (overlay + SnackBar) και η είσοδος συνεχίζει· επανάληψη στην επόμενη εκκίνηση.
  - **Guards κατά overwrite:** αν το σταθερό id χρησιμοποιείται ήδη από άλλη (μετονομασμένη) κατηγορία/υποκατηγορία, το onboarding χρησιμοποιεί νέο uuid αντί να πατήσει το υπάρχον doc.
- Tests: `onboarding_defaults_test.dart` (18) → σύνολο **278/278**· `flutter analyze` 0/0/0.
- Χωρίς migration· αφορά μόνο νέους χρήστες και onboarding που ξανατρέχει.

**E63 — Διπλή «Μεταφορά» (FIXED 26/11/2026, `2.3.11+18`)**
- `_getOrCreateTransferCategory` σε `transactions_actions_service.dart:1133` και `scheduled_transactions_service.dart:787` έγραφε τυχαίο uuid σε κάθε συσκευή → 2 system categories `type=transfer`.
- Λύση: σταθερό `OnboardingDefaults.transferCategoryId` (`cat-transfer`) + `SetOptions(merge:true)`. Ο υπάρχων query (`type=transfer`, `is_system=true`) παραμένει πρώτος, άρα legacy docs συνεχίζουν να βρίσκονται.

**E64 — `createUserDocumentIfNeeded` πριν το gate (FIXED 26/11/2026, `2.3.12+19`)**
- Το `login_page.dart:139-145` και το `app_start.dart:80-89` καλούσαν `createUserDocumentIfNeeded` **πριν** το onboarding gate. Η μέθοδος έκανε cache-first `get()`, `set(merge:true)` και poll έως ~7.5s.
- Offline: η εγγραφή έμπαινε στην ουρά και η poll καθυστερούσε την είσοδο. Το doc id είναι `user.uid` (σταθερό) → **κανένας κίνδυνος διπλότυπων**· μόνο UX/καθαρότητα.
- Λύση: `AuthService.ensureUserDocument` (μία κλήση από τα δύο entry points) με καθαρό κανόνα `user_doc_policy.dart`:
  - `Source.cache` hit → επιστροφή δεδομένων, **0 δίκτυο**.
  - Cache miss + `isConfirmedOffline` → **καμία κλήση, καμία εγγραφή**, ορατό μήνυμα (`skippedOffline`).
  - Cache miss online → `Source.server` με timeout 8s· `set(merge:true)` **μόνο** αν ο server επιβεβαιώσει ότι λείπει.
  - Timeout/offline codes → `skippedOffline`· άλλο σφάλμα → `skippedError` (μόνο debug log, κανένα «χωρίς σύνδεση» μήνυμα).
  - Κατάργηση poll και της διπλής ανάγνωσης (`getUserDocument`).
- Tests: `user_doc_policy_test.dart` (14) → σύνολο **292/292**· `flutter analyze` 0/0/0.
- Δεν απαιτείται migration· επηρεάζει μόνο τη ροή εισόδου.

**E6 — Soft-deleted account (WON'T FIX)**
- Ο έλεγχος `accounts.limit(1)` δεν φιλτράρει `deleted` — **σκόπιμα**: αν λείπει το user doc αλλά μένουν accounts, η φραγή εμποδίζει διπλό default.
- Απαιτεί `onboarding_completed=false` + soft-deleted λογαριασμό → πρακτικά μη προσπελάσιμο.
- **Μην προστεθεί φίλτρο:** docs χωρίς πεδίο `deleted` δεν ταιριάζουν σε `where(..., isEqualTo: false)` → θα δημιουργούσε διπλό default.

**E7 — Μηδέν λογαριασμοί**
- Απόφαση (D1): **φραγή** διαγραφής του τελευταίου **ενεργού** λογαριασμού.
- `core/utils/account_delete_guard.dart` (νέο, καθαρό Dart): `evaluate(activeCount)` → `lastActiveAccount` / `noActiveAccount` / `none` + ελληνικό μήνυμα. **0 reads** — χρησιμοποιεί `AccountsProvider.accounts.length`.
- `accounts_page.dart`: warning panel αντί για tile όταν μένει 1· διαγραφή με **ατομικό batch** (≤499 κινήσεις, κινήσεις + λογαριασμός μαζί) ή chunks 500 με λογαριασμό **τελευταίο**· success μετά το commit· καθαρισμός `excluded_accounts_{uid}`.
- `transaction_entry_page.dart`: κενή κατάσταση + CTA «Δημιουργία λογαριασμού» (callback από `home_page._onTabTap(2)`).
- Tests: `account_delete_guard_test.dart` (8) → **97/97**· `flutter analyze` καθαρό.
- Περιορισμός: η φραγή είναι **τοπική** (βλ. `DESIGN.md` §11 L21 — multi-device race).
- Έκδοση: `2.1.2+5`.
- Device tests (POCO X3, build `2.1.2+5`): ✅ φραγή, κενή κατάσταση + CTA, διαγραφή με κίνηση (atomic batch) — βλ. `device test/README.md` § E7. Το chunked >499 δεν δοκιμάστηκε στη συσκευή.
- Commit: `b2b13a8`.

**E8 — Restore app data (INFO)**
- Το `pm clear` διαγράφει το Keystore key· το `com.google.firebase.auth.api.Store.*.xml` δεν αποκρυπτογραφείται μετά από restore.
- Τα δεδομένα/preferences επιστρέφουν, το login γίνεται μία φορά χειροκίνητα. Δεν είναι bug.

**E9 — Τύπος `users.updated_at` (F6)**
- `onboarding_service.dart` έγραφε ISO string (γρ. 34-35, 61), ενώ `auth_service.dart:59` γράφει `Timestamp.now()` και το `docs/tables/users.md:30` ορίζει Timestamp ρητά.
- Κανένας reader σήμερα· ο κίνδυνος είναι μελλοντικός: τα `_parseTimestamp` των models δεν χειρίζονται String (σιωπηλό `DateTime.now()`) και `orderBy`/range filters συγκρίνουν μόνο εντός τύπου.
- Λύση: `Timestamp.now()` και στα δύο σημεία (γραμμές 34-35, 61). `flutter analyze` ✅ · `flutter test` ✅ **89/89**.

**E10 — Bubble layout μετά από cold restart (OPEN)**
- Μετά από cold restart το `MessageBubble` κρατά λάθος layout· navigate-away-and-back το διορθώνει (το `dispose()` καθαρίζει το cache).
- **Καταρρίφθηκε:** η αρχική θεωρία ότι το `_obtainBubble` cache κάνει identity skip. Το `build()` καλείται κανονικά (ίδιο `identity`, `screenW`/`textScale`/`bubbleMaxWidth` σταθερά σε όλα τα builds). Τα δύο attempts (ValueKey, αφαίρεση cache) **αναιρέθηκαν**.
- Επόμενη κατεύθυνση: ListView reconciliation, parent constraints, `MediaQuery` propagation.
- **🚫 23/11/2026 — μη εφαρμόσιμο:** τα `MessageBubble`/`ChatMessagesList` **δεν υπάρχουν** στο `lib/` (η λειτουργία μηνυμάτων αφαιρέθηκε)· παραμένει μόνο το `MessageService` (snackbars — E15). Δεν υπάρχει διαδρομή χρήστη που να αναπαράγει το bug → **WON'T FIX**.
- Πλήρες ιστορικό ελέγχων: [`oldsessions/09-bubble-layout-cache-bug.md`](oldsessions/09-bubble-layout-cache-bug.md).

**E11 — Μεταφορές με διαγραμμένο λογαριασμό (FIXED)**
- Το `_deleteAccount` κρύβει μόνο τα docs με `account_id == uuid`. Σε μεταφορά, το άλλο σκέλος έχει `account_id` = **peer** λογαριασμό και δείχνει πίσω με `transfer_peer_account_id` → μένει ενεργό.
- Αποτέλεσμα: το ποσό παραμένει στο peer υπόλοιπο χωρίς «ταιριαστό» σκέλος· δεν υπάρχει έλεγχος ακεραιότητας.
- Επηρεάζει και προγραμματισμένες μεταφορές (`scheduled_transactions_service`).
- Εντοπίστηκε κατά τον έλεγχο του E7· **δεν** διορθώνεται εκεί.
- **Πλήρες scope (απόφαση Session 18):** (1) cascade ακύρωση ζεύγους + αντιστροφή υπολοίπων με την **ίδια** σημασιολογία όπως η διαγραφή μεταφοράς, (2) συμμετρική επαναφορά με marker `annulled_by_account_deleted`, (3) έλεγχος ακεραιότητας στον executor (skip + log — **όχι** `execution_failed`, γιατί ο διάλογος του `home_page` είναι blocking).
- **Κανόνες:** ολοκληρωμένο ζεύγος → κρύψιμο 2 legs + 2 deltas· εκκρεμές → κρύψιμο 2 legs, 0 deltas· μερικό → κρύψιμο μόνο του ενεργού, 0 deltas, **χωρίς** marker. Ένα ζεύγος = **ένα** batch· deltas **ανά chunk** (σωστό retry)· λογαριασμός τελευταίος· μετράμε **writes** (όχι docs).
- **Επαναφορά:** τα marked legs εξαιρούνται από τη γενική επαναφορά· ζεύγος επανέρχεται μόνο αν 2 legs, **και τα δύο** με marker, έγκυρο σχήμα και ενεργό peer· deltas μόνο για ολοκληρωμένα· chunking ≤499 (κλείνει και **E13**).
- **Αρχεία:** `account_delete_guard.dart` (pure πλάνο), `transactions_actions_service.dart` (+2 μέθοδοι I/O), `accounts_page.dart` (preflight + φραγή offline E24), `account_duplicate_service.dart` (restore), `scheduled_transactions_service.dart` (integrity guard). **0 νέα αρχεία κώδικα.**
- **Indexes/rules:** καμία αλλαγή· όλες οι νέες αναγνώσεις είναι equality-only (το E17 δεν το μπλόκαρε).
- **Έκδοση:** `2.2.0+6` (νέο προαιρετικό πεδίο → MINOR, `DESIGN.md` §1.5.3).
- **✅ Διορθώθηκε 21/11/2026 (`2.2.0+6`):** `account_delete_guard.dart` (πλάνο + chunks + restore units), `transactions_actions_service.dart` (`previewAccountDelete` / `applyAccountDeletePlan`), `accounts_page.dart` (preflight + διάλογος με επίπτωση + φραγή offline E24), `scheduled_transactions_service.dart` (peer πεδία + `_isTransferPairIntact`), `account_duplicate_service.dart` (συμμετρική επαναφορά + chunking E13). Tests: `account_delete_guard_test.dart` 8→26. `flutter analyze` καθαρό, `flutter test` 115/115.
- **✅ Device test 21/11/2026 (POCO X3, `demo@yahoo.com`):** ολοκληρωμένο ζεύγος 200 → ακύρωση + επιστροφή (A 1.000→800, B 700 μετά την επαναφορά)· εκκρεμές ζεύγος 50 → 0 deltas· offline φραγή. Λεπτομέρειες: `device test/README.md` § E11.

**E12 — Budget με διαγραμμένο λογαριασμό (FIXED)**
- `budget_page.dart:712–721` → `accountName = acc?.name` = `null` όταν ο λογαριασμός διαγραφεί· η ετικέτα πέφτει στο `?? 'Όλοι'` (`:100, 809, 906`).
- Το `calculateSpentAmount` φιλτράρει `deleted == false` → το budget δείχνει «Όλοι» με `spent = 0`, ενώ είναι δεσμευμένο σε άλλο λογαριασμό.
- Mislabel + λάθος ποσό, χωρίς crash.
- **✅ Διορθώθηκε 21/11/2026 (`2.3.0+7`):** το `getAccountByUuid` ψάχνει πλέον σε **όλους** τους μη διαγραμμένους (`_accounts`, μαζί με αρχειοθετημένους και legacy `is_active=false`) → το όνομα εμφανίζεται σωστά. Το `spent = 0` παραμένει **ορθό** για όσους είχαν ήδη διαγραφεί (οι κινήσεις τους διαγράφηκαν)· με την αρχειοθέτηση (**E26**) το πρόβλημα δεν ξαναδημιουργείται.

**E13 — Restore >500 κινήσεις (FIXED)**
- `account_duplicate_service.dart:121–130`: ένα `batch` για όλες τις κινήσεις του λογαριασμού → αποτυγχάνει πάνω από 500 εγγραφές.
- Υπάρχει ήδη chunking pattern στο `database_cleanup_service.dart:428,491`.
- **✅ Έκλεισε με το E11 (21/11/2026):** chunking ≤499 και στο restore (βλ. E11, «Επαναφορά»).

**E14 — Restore μετά τον cleanup (FIXED 23/11/2026)**
- Ο cleanup διαγράφει οριστικά soft-deleted κινήσεις μετά από 30 ημέρες (`database_cleanup_service.dart:473–499`) αλλά **δεν** αγγίζει `accounts`.
- Άρα «Με Υπόλοιπο» επαναφέρει τον λογαριασμό χωρίς ιστορικό· το `current_balance` μένει ως είχε → πιθανή ασυμφωνία με το ιστορικό.
- **✅ Διορθώθηκε 23/11/2026 (`2.3.4+11`):** η επαναφορά **δεν** εμπιστεύεται το αποθηκευμένο υπόλοιπο. Το πλάνο υπολογίζει απόλυτα `targetBalance = initial_balance + κινήσεις που μετράνε` (κανόνας `AccountBalanceRules`, σε cents) και η προεπισκόπηση δείχνει **X → Y**· αν δεν βρεθεί ιστορικό, το λέει ρητά («Δεν βρέθηκε ιστορικό προς επαναφορά») αντί να υπονοεί πλήρη επαναφορά. Επιπλέον, η επαναφορά γράφει **νέο `updated_at`** στα legs → νέο παράθυρο 30 ημερών για τον cleanup. **Καμία** εικασία τύπου «purged» (θα ήταν ψευδής μετά το E26).

**E15 — MessageService ανενεργό (FIXED 25/11/2026)**
- `core/services/message_service.dart` (offline-aware snackbars + a11y) είχε **1** call site (`main.dart` → `showSyncComplete`) και αυτό **no-op**: ο μετρητής `_pendingOperations` αυξανόταν μόνο μέσα στο `show()`, που είχε 0 κλήσεις → το μήνυμα «Συγχρονισμός ολοκληρώθηκε» δεν εμφανίστηκε ποτέ, σε καμία έκδοση.
- Επιπλέον το `onSyncComplete` πυροδοτούσε σε **κάθε** offline→online μετάβαση (ανεξάρτητα από εκκρεμείς εγγραφές) — άρα ούτε «αληθινό» θα ήταν το πλήθος.
- Οι οθόνες χρησιμοποιούν άμεσα `SnackBar` (181 σε 27 αρχεία) — βλ. L11 για το υπόλοιπο χρέος.
- **✅ Διορθώθηκε 25/11/2026 (χωρίς version bump — καμία αλλαγή συμπεριφοράς):**
  - διαγράφηκαν `core/services/message_service.dart`, `core/widgets/biometric_gate.dart`, `services/recurring_notifications_service.dart` και η αχρησιμοποίητη `OfflineBanner` (το `OfflineAppBarChip` έμεινε, αρχείο → `offline_appbar_chip.dart`) — L6 κλειστό
  - αφαιρέθηκε το `onSyncComplete` από το `ConnectivityService` και το callback/`dispose` από το `main.dart` (το `MyApp` είναι πλέον `StatelessWidget`)
  - αφαιρέθηκαν τα σχολιασμένα `generateAhead` (`app_start.dart`) και το κενό `try` (`login_page.dart`)
  - η ιδέα «offline → θα συγχρονιστεί» καταγράφηκε στο **E61** (INFO)
  - gates: `flutter analyze` 0/0/0 · `flutter test` **260/260**

**E16 — Transaction edit με διαγραμμένο λογαριασμό (FIXED)**
- `transaction_edit_sheet.dart:85` κρατά `_accountId` από το tx· το dropdown (`:235`) δεν περιέχει διαγραμμένους → orphan τιμή.
- Σχετίζεται με E11 (μεταφορές) αλλά αφορά οποιαδήποτε κίνηση.
- **✅ Διορθώθηκε 21/11/2026 (`2.3.0+7`):** το dropdown προσθέτει τον **επιλεγμένο** λογαριασμό ακόμη κι αν είναι αρχειοθετημένος/ανενεργός (ίδιο fix στο `input_budget_page`) → τέλος το assertion `items == value`.

**E17 — Indexes file vs deployed (FIXED 23/11/2026)**
- Το `firestore.indexes.json` είχε **3** indexes, ενώ το deployed είχε **7**· έλειπαν `account_id+deleted+date ASC`, `category_id+deleted+date ASC`, `deleted+date ASC`, `deleted+date DESC`.
- Κίνδυνος: deploy θα πρότεινε διαγραφή των 4 → σιωπηλές αποτυχίες (budgets 0,00 €, graf_6 κενό, Κινήσεις λογαριασμού από cache, executor `[]`).
- **✅ Διορθώθηκε 23/11/2026:** mirror **7/7** (CLI matcher: 7/7 MATCH, 0 deletions/creations)· guard `firestore_indexes_test.dart` (3 tests)· deploy no-op (7 READY, ίδια `createTime`, ίδιο ruleset `76aa78a0…`).
- Legacy D3 (`category_id`) / D7 (`user_id`) διατηρήθηκαν σκόπιμα (κανένα τρέχον query· ρίσκο σε παλιούς clients) — βλ. `DESIGN.md` §6.3.
- Rules: deployed = repo (57=57 semantic) → κλείνει το (α).

**E18 — Peer path μη idempotent (INFO)**
- `deleteTransaction` peer path (`transactions_actions_service.dart:367–406`) αντιστρέφει πάντα τα 2 υπόλοιπα χωρίς να ελέγχει `deleted` του peer· το group path (`:482–490`) φιλτράρει.
- **Απόφαση:** δεν διορθώνεται — ο έλεγχος απαιτεί ανάγνωση peer, που θα χαλούσε το offline-safe μονοπάτι (`:366`). Μετά το E11 η εφαρμογή δεν παράγει μισά ζεύγη.

**E19 — Ανάσταση κινήσεων χρήστη (FIXED 23/11/2026)**
- `restoreAccountWithBalance` (`account_duplicate_service.dart:112–130`) επαναφέρει **όλες** τις `deleted` κινήσεις του λογαριασμού, άρα και όσες διέγραψε ο χρήστης μεμονωμένα.
- Με το E11 καλύπτεται **μόνο** το τμήμα των ζευγών μεταφορών (marker + έλεγχος σχήματος)· οι μεμονωμένες κινήσεις παραμένουν → χρειάζεται χωριστή σημασιολογία (π.χ. `deleted_by`).
- **✅ Διορθώθηκε 23/11/2026 (`2.3.4+11`):** **απορρίφθηκε** νέο πεδίο `deleted_by` (legacy-only πρόβλημα· μετά το E26 δεν παράγονται νέα τέτοια δεδομένα). Ο κανόνας είναι πλέον καθαρός και ζει στο `core/utils/account_restore_policy.dart`: επανέρχεται **μόνο** ό,τι ακύρωσε η διαγραφή — **ολοκληρωμένα, έγκυρα ζεύγη μεταφορών** με marker `annulled_by_account_deleted`· κίνηση χωρίς marker ή εκκρεμές ζεύγος **μένει κρυφή** (με αιτία στο μήνυμα). Οι peers παίρνουν **μόνο** το ακριβώς αντίστροφο του delta της διαγραφής, ανά chunk (≤499 writes, ποτέ σπασμένο ζεύγος).
- **Ροή:** offline φραγή (0 reads) → 4 reads (`Source.server`) → πλάνο/προεπισκόπηση → **επανέλεγχος** πριν τη γραφή (ματαίωση αν άλλαξε το πλάνο) → chunks → **τελευταίο ατομικό batch** (`deleted:false`, `is_active:true`, `archived_at` delete, απόλυτο `current_balance`).
- **«Χωρίς Υπόλοιπο»:** κρύβει **όλα** τα ορατά legs, καθαρίζει markers, μηδενίζει αρχικό/τρέχον → 0 = 0 + τίποτα ορατό.
- **Αρχεία:** `core/utils/account_restore_policy.dart` (νέο, καθαρό), `core/services/account_restore_service.dart` (νέο, I/O), `services/account_duplicate_service.dart` (διάλογος + 3-κατάστατο + ανεκτική ανάγνωση), `core/services/connectivity_service.dart` (`isConfirmedOffline`), `core/utils/account_delete_guard.dart` (`targetIsVisible` — E32), `presentation/screens/accounts/accounts_page.dart`.
- **Tests:** `account_restore_policy_test.dart` (νέο, 23) + `account_delete_guard_test.dart` 36→38 → **178/178**, `flutter analyze` καθαρό.
- **Indexes/rules:** καμία αλλαγή (4 equality reads μόνο single-field· owner-only rules χωρίς field validation).
- **Περιορισμός:** L27 (παράθυρο read→write) — μετριάζεται από τον επανέλεγχο (D11).

**E20 — Επαναϋπολογισμός υπολοίπου (FIXED 22/11/2026)**
- **Πραγματικό αίτιο (όχι «έκλεισε η εφαρμογή 3 μέρες» — το startup εκτελεί πρώτα τις ληξιπρόθεσμες):**
  1. Φίλτρο `date < αύριο` + «Άμεση Εκτέλεση» με μελλοντική ημερομηνία → η κίνηση έχει **ήδη** αφαιρεθεί από το υπόλοιπο, αλλά ο recalc δεν τη βλέπει → το υπόλοιπο «φουσκώνει».
  2. Εκκρεμείς που **δεν** εκτελέστηκαν (ανεπαρκές υπόλοιπο → `execution_failed`, σπασμένο ζεύγος μεταφοράς) μετριούνταν σαν να είχαν εφαρμοστεί.
  3. Offline: `get()` με `serverAndCache` επιστρέφει κενό/μερικό cache χωρίς σφάλμα (E24) → λάθος εγγραφή.
  4. Καμία στρογγυλοποίηση σε cents· διπλό πάτημα = 2 writes· γενικό μήνυμα σφάλματος.
- **Λύση:** κανόνας **κατάστασης** (όχι ημερομηνίας): μετράει ό,τι έχει ήδη εφαρμοστεί — `!(is_scheduled && !is_executed)` και όχι `deleted`. Ο κανόνας ζει στο `core/utils/account_balance.dart` και **μοιράζεται** με το `account_delete_guard.dart` (μηδέν διπλότυπα). Ο υπολογισμός γίνεται σε cents.
- **I/O:** 1 ανάγνωση λογαριασμού + 1 query **μόνο** `account_id` (τα `deleted`/`is_scheduled` ελέγχονται σε Dart — E6) + 1 εγγραφή **τελευταία** μέσω της υπάρχουσας `AccountsProvider.updateAccountBalance` (παύει να είναι νεκρή — E22). Φραγή offline με το υπάρχον `_isOfflineConfirmed`.
- **UI:** ενημερωτικός διάλογος, scrollable, `PopScope` + loading (κανένα διπλό πάτημα), σύνοψη πριν→μετά + πλήθη εξαιρεθέντων, σωστός ενικός/πληθυντικός.
- **Αρχεία:** `core/utils/account_balance.dart` (νέο), `core/utils/account_delete_guard.dart`, `providers/accounts_provider.dart`, `presentation/screens/accounts/accounts_page.dart`, `test/unit/core/utils/account_balance_test.dart` (20 tests).
- **Περιορισμός:** L27 (παράθυρο read→write).
- **Έκδοση:** `2.3.2+9` (PATCH).
- **✅ Device test 22/11/2026 (POCO X3):** 6/6 σενάρια — (α) άμεση έξοδος 300,00 € με **μελλοντική** ημερομηνία → recalc «ήδη σωστό (11.700,00 €)» (με τον παλιό κανόνα θα γύριζε σε 12.000)· (β) **εκκρεμής** προγραμματισμένη 500,00 € → εξαιρείται· (γ) **offline** → «Ο επανυπολογισμός απαιτεί σύνδεση στο internet», καμία εγγραφή· (δ) χαλασμένο υπόλοιπο 99.999,00 € → «99.999,00 € → 11.700,00 € (39 κινήσεις). Εξαιρέθηκαν 1 εκκρεμής (επίδραση -500,00 €)», REST `current_balance=11700`· (ε) text scale 1.45 χωρίς overflow· (στ) διπλό πάτημα → ένα μήνυμα. Στοιχεία: `device test/README.md` § E20, screenshots `e20_*`.

**E21 — Cache fallback no-op (INFO)**
- `_getQueryWithCacheFallback` (`:836–839`) & `_getDocWithCacheFallback` (`:887–890`) καλούν **μόνο** `get()`· τα σχόλια περί fallback δεν ισχύουν. Το offline δουλεύει λόγω `persistenceEnabled` (`main.dart:65–68`).

**E22 — Νεκρές μέθοδοι υπολοίπου (FIXED)**
- Αρχικό εύρημα: `applyLocalBalanceDelta` & `updateAccountBalance` → **0** call sites· το `DESIGN.md` §3.3 ανέφερε μόνο τη δεύτερη.
- **✅ Διορθώθηκε 23/11/2026 (`2.3.7+14`):** η `updateAccountBalance` είναι **ενεργή** (τη χρησιμοποιεί ο επανυπολογισμός E20)· αφαιρέθηκε μόνο η νεκρή `applyLocalBalanceDelta` (~37 γρ., 0 call sites σε `lib/`/`test/`) και το §3.3 ενημερώθηκε. Καμία αλλαγή συμπεριφοράς.

**E23 — Διπλές γραμμές scheduled transfer (INFO)**
- `getScheduledTransactions` (`scheduled_transactions_service.dart:665–682`) επιστρέφει **2 γραμμές** ανά εκκρεμή μεταφορά (μία ανά leg).

**E24 — Offline διαγραφή με ατελή cache (FIXED)**
- Το default `Source.serverAndCache` επιστρέφει offline **κενό/μερικό** `QuerySnapshot` **χωρίς exception**. Άρα το `_deleteAccount` (`accounts_page.dart:1293–1299`) μπορεί να κρύψει μόνο τον λογαριασμό και να αφήσει **ενεργές** κινήσεις (αόρατες μόνο επειδή ο λογαριασμός κρύφτηκε)· με το E11 το ίδιο αφήνει **ενεργό peer σκέλος**.
- **Διόρθωση (στο πλαίσιο E11):** φραγή διαγραφής όταν `ConnectivityService.isInitialized && isOffline`, με σαφές μήνυμα. Το service είναι ήδη provider (`main.dart:83–85`, `connectivity_service.dart:27–29`).
- **✅ Device test 21/11/2026:** airplane mode → «OFFLINE» → διαγραφή → κόκκινο snackbar «Η διαγραφή λογαριασμού απαιτεί σύνδεση στο internet», καμία εγγραφή (`device test/screenshots/e11_79_offline_blocked.png`).

**E25 — Επαναφορά εκκρεμούς ζεύγους (INFO)**
- Μετά από επαναφορά, εκκρεμές ζεύγος με παρελθούσα `scheduled_for_date` εκτελείται στον επόμενο έλεγχο — υπάρχουσα συμπεριφορά για **όλες** τις εκκρεμείς κινήσεις, όχι νέα παρενέργεια.

**E26 — Διαγραφή λογαριασμού μηδενίζει το σύνολο (FIXED)**
- Σενάριο: A=1.500, B=2.000, σύνολο 3.500· διαγραφή A → 1.500, γιατί η διαγραφή κρύβει **όλες** τις κινήσεις του A και αντιστρέφει το peer σκέλος (E11).
- **Λύση:** η διαγραφή επιτρέπεται **μόνο** όταν ο λογαριασμός δεν έχει κινήσεις **και** budgets· σε κάθε άλλη περίπτωση → **αρχειοθέτηση** (`is_active=false` + `archived_at`), χωρίς να αγγίζεται καμία κίνηση.
- **Διακριτικό:** `countsInTotal = isActive || archivedAt != null` → οι legacy `is_active=false` **χωρίς** marker μένουν εκτός (μηδέν migration, ίδιο σύνολο).
- **Φραγές:** τελευταίος ενεργός λογαριασμός (όπως E7)· εκκρεμείς προγραμματισμένες κινήσεις (ο executor δεν ελέγχει `is_active`, άρα δεν πρέπει να μείνουν εκκρεμείς).
- **Αρχεία:** `account_delete_guard.dart` (καθαρή απόφαση + `pendingLegUuids` με 0 επιπλέον reads), `account_totals.dart` (νέο, ένα σημείο αλήθειας για το σύνολο), `accounts_provider.dart`, `transactions_actions_service.dart` (`archiveAccount` / `restoreArchivedAccount`, 1 write), `accounts_page.dart`, `input_budget_page.dart`, `transaction_edit_sheet.dart`, `graf_4_page.dart`.
- **Έκδοση:** `2.3.0+7` (προαιρετικό νέο πεδίο → MINOR).
- **✅ Device test 21/11/2026:** 12/12 σενάρια στο POCO X3 — σύνολο 17.560,00 € αμετάβλητο μετά την αρχειοθέτηση, διαγραφή «καθαρού» λογαριασμού OK, offline αρχειοθέτηση + sync OK, φραγή εκκρεμούς OK. Εύρημα: λάθος ενικός («1 εκκρεμείς») → διορθώθηκε + test (131/131). Στοιχεία: `device test/README.md` § E26, screenshots `e26_*`.

**E27 — graf_4 αγνοεί τις εξαιρέσεις (FIXED)**
- Αρχική περιγραφή (διόρθωση): το `graf_4_page.dart` χρησιμοποιούσε `accountsProvider.accounts` **πριν** το E26· μετά το E26 χρησιμοποιεί `allAccounts` + `countsInTotal` (ενεργοί + αρχειοθετημένοι, εκτός legacy `is_active=false`), αλλά **χωρίς** τις εξαιρέσεις του χρήστη.
- Οι εξαιρέσεις ζούσαν μόνο στο State της `accounts_page` (`excluded_accounts_{uid}`) → δύο διαφορετικά «Σύνολα» στην ίδια εφαρμογή.
- **✅ Διορθώθηκε 22/11/2026 (`2.3.3+10`):** οι εξαιρέσεις μεταφέρθηκαν στον `AccountsProvider` (`excludedAccountUuids`, `isExcludedFromTotal`, `setExcludedFromTotal` — idempotent, ποτέ δεν πετάει)· φορτώνονται μία φορά ανά σύνδεση από το **ίδιο** κλειδί (μηδέν migration). Σελίδα Λογαριασμών και `graf_4` καλούν το ίδιο `AccountTotals` με το ίδιο set· το γράφημα απέκτησε σωστό κενό state («Όλοι οι λογαριασμοί είναι εξαιρεμένοι») και ανακοίνωση πλήθους εξαιρεθέντων. Καμία εγγραφή Firestore, καμία νέα ανάγνωση.
- **Περιορισμός (L28):** τοπική προτίμηση ανά συσκευή· αρχειοθετημένος + εξαιρεμένος λογαριασμός δεν έχει checkbox επανένταξης (μόνο «Επαναφορά»).
- **Tests:** 152/152 (`account_totals_test.dart` +1: «όλοι εξαιρεμένοι → κενή λίστα, σύνολο 0»).
- **✅ Device test 22/11/2026:** 6/6 σενάρια στο POCO X3 (έκδοση `2.3.3+10`) — ίδιο σύνολο σε Λογαριασμούς/γράφημα (17.260 → 14.760 → 17.260), persistence μετά από restart, «όλοι εξαιρεμένοι» → 0,00 € + σωστό κενό state, μηδέν εγγραφές Firestore. Στοιχεία: φάκελος `device test/` (δεν υπάρχει πλέον στο repo), screenshots `e27_*`.

**E28 — Αρχειοθετημένοι λογαριασμοί στις αναφορές περιόδου/tags (FIXED)**
- Η κάρτα «Λογαριασμοί» σε `stats_page.dart:1114,1237` και `tag_stats_page.dart:1169,1439,1466` τροφοδοτείται από `accountsP.accounts` (μόνο ενεργοί) → οι κινήσεις αρχειοθετημένου λογαριασμού **δεν μπορούν να επιλεγούν** στο φίλτρο.
- Είναι φίλτρο επιλογής (checkbox ανά λογαριασμό), **όχι** άθροισμα → καμία σχέση με E27.
- **Διόρθωση:** ενιαία λίστα `[...accountsP.accounts, ...accountsP.archivedAccounts]` σε sync επιλογών **και** κάρτα (0 νέα reads)· ετικέτα «Αρχειοθετημένος» στον υπότιτλο· legacy `is_active=false` χωρίς `archived_at` μένουν εκτός (όπως στα σύνολα).
- Ο βρόχος `removeWhere` πρέπει να χρησιμοποιεί την ίδια λίστα, αλλιώς πετάει τους αρχειοθετημένους σε κάθε rebuild.
- **✅ Διορθώθηκε 22/11/2026 (`2.3.1+8`):** ενιαία λίστα `accounts + archivedAccounts` σε sync και κάρτα (0 νέα reads)· ετικέτα «· Αρχειοθετημένος» στον υπότιτλο· device test στη συσκευή (επιλογή αρχειοθετημένου σε αναφορά περιόδου & tags).

**E29–E33 — Διορθώσεις στην επαναφορά (FIXED 23/11/2026, `2.3.4+11`)**

- **E29 (`archived_at`):** αν ο λογαριασμός ήταν αρχειοθετημένος πριν διαγραφεί, η επαναφορά άφηνε το `archived_at` → `countsInTotal` τον μετρούσε **και** ως ενεργό **και** ως αρχειοθετημένο. Τώρα η ενεργοποίηση γράφει `archived_at: FieldValue.delete()` στο ίδιο τελευταίο batch.
- **E30 (markers):** τα `annulled_by_account_deleted` έμεναν στα legs → ο έλεγχος ακεραιότητας (`_isTransferPairIntact`) και μια νέα διαγραφή έβλεπαν «ήδη ακυρωμένο» ζεύγος. Τώρα τα markers καθαρίζονται **μαζί** με την επαναφορά (`FieldValue.delete()`)· στο «Χωρίς Υπόλοιπο» καθαρίζονται **όλοι** οι markers που δείχνουν στον λογαριασμό, **χωρίς** αλλαγή `updated_at`.
- **E31 (strict casts):** το `AccountModel.fromFirestore` και το `doc.data()['name'] as String` πετούσαν σε legacy docs (π.χ. `name` όχι String). Η επαναφορά χρησιμοποιεί **ανεκτική** ανάγνωση (`_text`/`_amount`) και **δεν** περνά από το factory.
- **E32 (guard):** το `decide` συγκρίνει `provider.accounts.length` (μόνο ενεργοί) με τον στόχο· για **αρχειοθετημένο** στόχο το μέτρημα ήταν λάθος (1 ενεργός + αρχειοθετημένος στόχος → «τελευταίος»). Προστέθηκε `targetIsVisible` (default `true` = καμία αλλαγή για ενεργούς)· 1 call site.
- **E33 (διάλογος):** κάθε `false` από τον έλεγχο ονόματος έκλεινε τον διάλογο δημιουργίας — και η **ακύρωση** της επαναφοράς. Τώρα `CreateAccountOutcome { proceed, closeDialog, keepDialog }`: μόνο `closeDialog` κλείνει, η ακύρωση/αποτυχία κρατά τον διάλογο ανοιχτό με τα δεδομένα του χρήστη.

**E34 — Batch reuse στο cleanup (FIXED 23/11/2026)**
- `database_cleanup_service.dart` κρατούσε **ένα** `WriteBatch` και το ξαναχρησιμοποιούσε μετά το `commit()` → το επόμενο `batch.delete()` πετάει, το catch επιστρέφει 0 και καθαρίζονται μόνο τα πρώτα 500 docs.
- **✅ Διορθώθηκε (`2.3.5+12`):** ο καθαρισμός ξαναγράφτηκε γύρω από **ένα** chunked helper (`CleanupPolicy.chunk` + **νέο** `WriteBatch` ανά chunk ≤499). Κάθε εργασία επιστρέφει **τι έχει πραγματικά committed** + τυχόν σφάλμα (χωρίς exception), ώστε να συνεχίζει στις υπόλοιπες.
- **Αρχεία:** `core/utils/database_cleanup_policy.dart` (νέο, καθαρό Dart), `core/services/database_cleanup_service.dart` (I/O), `presentation/screens/options/database_cleanup_page.dart` (UI).
- **Tests:** `database_cleanup_policy_test.dart` (νέο, 41) → **219/219**, `flutter analyze` καθαρό.
- **Indexes/rules:** **καμία** αλλαγή· μόνο single-field equality + client-side φίλτρο ηλικίας.
- **Περιορισμοί:** L31 (queued writes mid-run), L32 (όνομα κατηγορίας σε scheduled).

**E35 — Chunked διαγραφή χωρίς own delta (INFO)**
- `transactions_actions_service.dart:1012–1015`: στο single-batch μονοπάτι η διαγραφή εφαρμόζει και το delta του ίδιου λογαριασμού (`:975–982`)· στο chunked (>499) γράφει μόνο `deleted: true`. Άρα το αποθηκευμένο υπόλοιπο μεγάλων legacy λογαριασμών ήταν εξ ορισμού ασυνεπές.
- **Ουδετεροποιείται** πλήρως από το απόλυτο υπόλοιπο της επαναφοράς (D1) — δεν χρειάζεται αλλαγή στη διαγραφή.

**E36 — Offline αναζήτηση διαγραμμένου ονόματος (INFO)**
- `account_duplicate_service.dart:72–78`: το query τρέχει στην cache· offline με ελλιπή cache μπορεί να επιστρέψει κενό → παράκαμψη του διαλόγου επαναφοράς και δημιουργία νέου λογαριασμού. Είναι συνεπές με το offline-first μονοπάτι δημιουργίας· δεν αλλάζει.

**E37 — Λάθος διαδρομή υποκατηγοριών (FIXED 23/11/2026)**
- Ο καθαρισμός διάβαζε `users/{uid}/subcategories` (δεν υπάρχει· rules το αρνούνται) → το `catch` επέστρεφε 0 και οι υποκατηγορίες **δεν** καθαρίζονταν ποτέ.
- **✅** Πλέον διάβασμα **nested** `users/{uid}/categories/{id}/subcategories` (χωρίς `collectionGroup` — οι rules δεν το επιτρέπουν), ανά κατηγορία.

**E38 — Hard delete κατηγορίας χωρίς cascade (FIXED 23/11/2026)**
- Η διαγραφή κατηγορίας άφηνε πίσω τις υποκατηγορίες της ως ορφανά docs.
- **✅** Πριν από κάθε κατηγορία μπαίνουν **όλες** οι υποκατηγορίες της στο ίδιο chunk plan (πάντα πριν τη μητρική).

**E39 — Soft-deleted υπενθυμίσεις/budgets (FIXED 23/11/2026)**
- Τα queries είχαν `where('deleted', isEqualTo: false)` → ό,τι είχε ήδη soft-deleted έμενε για πάντα.
- **✅** Ανάγνωση χωρίς `where` (πιάνει και legacy docs χωρίς πεδίο `deleted`) + κανόνας ηλικίας `updated_at` (fallback `created_at`) μόνο για soft-deleted. Χωρίς ημερομηνία → **δεν** διαγράφεται.

**E40 — Oil tank: διπλό commit (FIXED 23/11/2026)**
- `commit()` μέσα στον βρόχο (`% 500`) και **δεύτερο** `commit()` στο τέλος → `StateError` και το `settings/oil_tank` δεν έφευγε ποτέ· τα σφάλματα καταπίνονταν (`return deleted`).
- **✅** `oil_purchases` με chunked helper + `settings/oil_tank` σε **ξεχωριστό** (νέο) batch· το σφάλμα επιστρέφεται ως μερικό αποτέλεσμα. Το `oil_page` ξαναδημιουργεί defaults όταν λείπει το doc.

**E41 — Positional indexing στην προεπισκόπηση (FIXED 23/11/2026)**
- Το `Future.wait` έχτιζε λίστα **με συνθήκες** και μετά διάβαζε `results[0..5]` → αν έλειπε μεσαία επιλογή, τα πλήθη μετατοπίζονταν (π.χ. budgets στο `notificationsCount`).
- **✅** Κάθε εργασία έχει **δική της** μεταβλητή· καμία θέση δεν εξαρτάται από τις υπόλοιπες.

**E42 — Παλιά πλήθη στον διάλογο (FIXED 23/11/2026)**
- Ο διάλογος επιβεβαίωσης χρησιμοποιούσε το `_preview` που μπορεί να είχε υπολογιστεί πριν αλλάξει ο χρήστης slider.
- **✅** Πριν από **κάθε** επιβεβαίωση γίνεται **φρέσκια** προεπισκόπηση· αν είναι κενή → ενημερωτικό μήνυμα, χωρίς διάλογο.

**E43 — Χωρίς offline gate (FIXED 23/11/2026)**
- Offline, κάθε `Source.server` read πετούσε, το `catch` γύριζε 0 → «Επιτυχής Καθαρισμός» με 0 διαγραφές.
- **✅** Φραγή με `ConnectivityService.isConfirmedOffline` πριν από προεπισκόπηση/εκτέλεση + μήνυμα (`CleanupPolicy.offlineMessage`) + `OfflineAppBarChip` στη μπάρα.

**E44 — Καταπνιγμένα σφάλματα (FIXED 23/11/2026)**
- Κάθε εργασία είχε `try/catch → 0` και το report έλεγε πάντα `success: true`.
- **✅** `CleanupOutcome {complete, partial, cancelled}`· μετά από αποτυχία **συνεχίζει** στις υπόλοιπες, κρατά τα committed πλήθη και εμφανίζει ποιες εργασίες απέτυχαν.

**E45 — Έξοδος/αλλαγές κατά την εκτέλεση (FIXED 23/11/2026)**
- Δεν υπήρχε `PopScope` και τα checkboxes/sliders έμεναν ενεργά όσο έτρεχε ο καθαρισμός.
- **✅** `PopScope(canPop: !isRunning)` με μήνυμα + `onChanged: null` σε επιλογές/sliders όσο εκτελείται.

**E46 — Parser ημερομηνιών (FIXED 23/11/2026)**
- Το `_parseTimestamp` του cleanup δεχόταν μόνο `Timestamp`/`String` (τα models δέχονται και `int` millis) → legacy docs αγνοούνταν σιωπηλά.
- **✅** `CleanupPolicy.parseTimestamp`: `Timestamp` / `DateTime` / `int` millis / ISO string.

**E47 — Διπλός slider κατηγοριών (FIXED 23/11/2026)**
- Δύο tiles («Κατηγορίες», «Υποκατηγορίες») έγραφαν την **ίδια** `_categoriesDays` → κινούσες το ένα, άλλαζε και το άλλο.
- **✅** Ενιαίο tile «Κατηγορίες & Υποκατηγορίες» (μία εργασία, ένα slider), όπως είχε εγκριθεί.

**E48 — Όνομα κατηγορίας σε scheduled (INFO)**
- Μετά από hard delete κατηγορίας, το `ScheduledTransactionsService.getCategoryName/getSubcategoryName` επιστρέφει «Άγνωστη Κατηγορία/Υποκατηγορία». Οι **ζωντανές** κινήσεις δείχνουν ήδη «Χωρίς κατηγορία» (τα providers φιλτράρουν `deleted == false`).
- **Απόφαση:** αποδεκτό — μόνο ετικέτα σε προγραμματισμένες· καμία διόρθωση (L32).

**E49 — Queued writes mid-run (INFO)**
- Με `persistenceEnabled: true`, αν χαθεί η σύνδεση **μέσα** στην εκτέλεση, τα `batch.commit()` δεν πετούν· μπαίνουν σε ουρά και εφαρμόζονται αργότερα. Η αναφορά μπορεί να δείξει μερικό αποτέλεσμα ενώ οι διαγραφές θα εφαρμοστούν.
- **Απόφαση:** αποδεκτό (L31) — αφορά δεδομένα που ο χρήστης έχει ήδη επιλέξει να διαγραφούν· η offline φραγή καλύπτει την **έναρξη**.

**E50 — Καμία επαναξιολόγηση μετά το φρέσκο preflight (FIXED 23/11/2026)**
- Το `_handleDeleteAccount` έκανε δεύτερο preflight πριν τη γραφή, αλλά **δεν** επαναξιολογούσε το `AccountDeleteGuard.decide`· αν στο μεταξύ προέκυπταν κινήσεις/budgets, η διαγραφή προχωρούσε σιωπηλά.
- **✅** Μετά το φρέσκο πλάνο γίνεται `decide` με τα νέα πλήθη· αν δεν βγαίνει `delete` (ή αν `budgetsUnknown`) → ματαίωση με «Τα δεδομένα άλλαξαν…» / «Σφάλμα ανάγνωσης…» και **καμία εγγραφή**.

**E51 — Ανενεργά budgets αόρατα (INFO)**
- Ο listener του `BudgetsProvider` φιλτράρει `deleted=false & is_active=true`· η σελίδα Προϋπολογισμών δεν δείχνει ποτέ ανενεργά. Το gate διαγραφής (L26) τα μετρά πλέον από το server, αλλά η **ορατότητα** παραμένει περιορισμένη.
- **Απόφαση:** δεν αλλάζει τώρα — καμία οθόνη δεν τα χρειάζεται· αν ζητηθεί, ξεχωριστή φάση (SPoT στον provider).

**E52 — Legacy budgets χωρίς `is_active`/`deleted` (INFO)**
- Docs χωρίς `is_active` δεν επιστρέφονται από το query (`isEqualTo: true`)· docs χωρίς `deleted` επίσης. Το `BudgetModel` τα θεωρεί ενεργά/μη διαγραμμένα, άρα υπάρχει ασυμφωνία model ↔ query.
- **Απόφαση:** το gate (L26) τα μετρά **συντηρητικά** (`deleted != true`) → αρχειοθέτηση αντί διαγραφής· ο καθαρισμός τα purga με βάση το `end_date`.

**E53 — Εύθραυστο parsing budget (LOW)**
- `budget_model.dart:71/80`: `user_id as String`, `amount as num` (χωρίς null-tolerance) → ένα legacy/ημιτελές doc ρίχνει **όλο** τον listener σε error state (`_onBudgetsChanged` catch).
- **Απόφαση:** δεν αγγίζεται τώρα· ο μετρητής του L26 διαβάζει raw maps, άρα δεν κληρονομεί το πρόβλημα. Αν εμφανιστεί, διόρθωση στο model με defaults.

**E54 — «Οι 0 κινήσεις» στον διάλογο αρχειοθέτησης (FIXED)**
- Όταν ο λογαριασμός έχει μόνο budgets (καμία κίνηση), ο διάλογος έγραφε «Οι **0** κινήσεις και το υπόλοιπο … διατηρούνται».
- **✅ Διορθώθηκε 23/11/2026 (`2.3.7+14`):** `0` → «Καμία κίνηση· το υπόλοιπο … διατηρείται» (σωστός ενικός/πληθυντικός για 0/1/N).

**E55 — Windows artifact στο git (INFO)**
- Το `assets/icons/subcategories/expense/desktop.ini` είναι **tracked** (`git ls-files`), δημιουργήθηκε από τον Explorer σε Windows. Δεν επηρεάζει build ή runtime.
- **Προτεινόμενη ενέργεια (δεν έγινε):** `git rm --cached "assets/icons/subcategories/expense/desktop.ini"` + γραμμή `desktop.ini` στο `.gitignore`. Απαιτεί έγκριση χρήστη (αλλαγή σε tracked αρχείο).

**E56 — 72 info deprecations: `material.dart` → `material_ui` (FIXED 25/11/2026)**
- **Αίτιο:** από τη Flutter 3.47 το Material αποσπάστηκε από το SDK σε ξεχωριστό πακέτο· το `package:flutter/material.dart` είναι `@Deprecated` (→ `package:material_ui/material_ui.dart`). Κάθε import έβγαζε 1 info, μαζί με τους 2 deprecated localization delegates του `main.dart` = **72 info** (70 αρχεία).
- **✅ Διόρθωση:** `material_ui: ^1.11.1` στο `pubspec.yaml` (transitive `cupertino_ui` 1.1.7)· `dart fix --apply --code=migrate_design_widgets` → **70 imports** σε 70 αρχεία· `main.dart`: `localizationsDelegates: GlobalMaterialLocalizations.delegates` (καλύπτει Material + Cupertino + Widgets) και αφαίρεση του πλέον άχρηστου import `flutter_localizations`.
- **Έλεγχος legacy εξαρτήσεων:** `fl_chart` (χρησιμοποιεί `Theme.of` μόνο στο `CandlestickChart`, που δεν χρησιμοποιούμε), `responsive_framework` (`Theme.of(context).platform` — σωστό fallback), `flutter_phoenix`/`nested` (καμία χρήση Material) → **κανένα** conflict τύπων (δύο αντίγραφα Material classes) και καμία ανάγκη για `MaterialUiCompatibilityBridge` (άλλωστε είναι deprecated).
- **Επαλήθευση:** `flutter analyze` → **No issues found** (0/0/0)· `flutter test` → **238/238**· `build apk --debug` ✅ · `build web --release` ✅ · `build windows --release` ✅.
- **Καμία** αλλαγή σε λογική/Firestore/έκδοση (`2.3.7+14` παραμένει)· backups: `backups/2026-11-25-material-ui/`.

**E57 — Χαλασμένη περίοδος γραφήματος (FIXED 25/11/2026)**
- **Εύρημα (smoke test POCO X3, release):** η κάρτα «Έσοδα / Έξοδα» έδειχνε `Τρέχουσα: ╬£╬«╬╜╬▒╧é` αντί `Μήνας`. Το accessibility tree επιβεβαίωσε ότι η **αποθηκευμένη** τιμή (`graf1_period_<uid>`) ήταν UTF-8 bytes διαβασμένα ως **CP437** (`CE 9C CE AE CE BD CE B1 CF 82`), δηλαδή πρόβλημα δεδομένων παλιάς εγκατάστασης — όχι κώδικα ή localization (καμία ένδειξη σε analyze/test/build/logcat).
- **Επίπτωση:** λάθος ετικέτα· η τιμή δεν ταίριαζε με τις επιλογές, άρα τα γραφήματα έπεφταν στο προεπιλεγμένο εύρος και η «Προβολή γραφημάτων» δεν έδειχνε επιλεγμένη περίοδο.
- **✅ Διόρθωση:** νέο `core/utils/period_prefs.dart` (`PeriodPrefs`): `isValid` (γνωστές επιλογές + `Custom_YYYY-MM-DD_YYYY-MM-DD`), `repairEncoding` (CP437 → UTF-8, Latin-1/CP1252 → UTF-8, αποδοχή **μόνο** αν βγει έγκυρη περίοδος) και `load` που **ξαναγράφει** τη διορθωμένη τιμή (self-healing). Χρήση στα 2 σημεία ανάγνωσης: `general_view_page` (5 γραφήματα) και `view_option_page`.
- **Επαλήθευση:** `flutter analyze` → **No issues found**· `flutter test` → **251/251** (+13 `period_prefs_test.dart`, με το πραγματικό χαλασμένο string)· `flutter build apk --debug` ✅· καμία αλλαγή σε Firestore/έκδοση· backups: `backups/2026-11-25-e57-period-repair/`.

**E58 — Αρχικοποιήσεις εκτός δοχείου σφάλματος (FIXED 25/11/2026, `2.3.10+17`, commit `5cd74c3`)**
- Πριν: το `themeProvider.initialize()`, το `NotificationsService().initialize()` και το `ConnectivityService()` εκτελούνταν **πριν** το `try` της εκκίνησης → εξαίρεση ή κόλλημα = uncaught exception/κενή οθόνη, χωρίς «Σφάλμα Αρχικοποίησης» και κουμπί επανάληψης.
- Διόρθωση: `main()` = `WidgetsFlutterBinding.ensureInitialized()` + `try { _startApplication() } catch { runApp(ErrorApp(onRetry: _startApplication)) }`· νέο `prepareStartup()` (`lib/main.dart:63`) τρέχει theme (όριο **4s**) και notifications (όριο **6s**) **best-effort** και δημιουργεί το `ConnectivityService` **μία φορά ανά διεργασία** (`??=`, `:95`) μέσα στη guarded ροή, ώστε σφάλμα εκεί να οδηγεί σε `ErrorApp` και το retry να μη διπλασιάζει listeners.
- Άδεια ειδοποιήσεων: `initialize({requestPermissions = false})` στην εκκίνηση + δημόσιο `requestPermissions()` που καλείται **μετά το πρώτο frame** από το `SplashScreen` (`unawaited`), ώστε η εκκίνηση να μην περιμένει διάλογο του λειτουργικού.
- Επαλήθευση: 5 νέα unit tests (`test/unit/core/startup/prepare_startup_test.dart`)· `flutter test` **260/260**· `flutter analyze` **No issues found**· device POCO X3: cold start online/offline χωρίς κενή οθόνη, logcat FATAL/Null check 0 (`device test/E58_E59_device_tests.md`).

**E59 — `Phoenix` χωρίς χρήση (FIXED 25/11/2026, `2.3.10+17`, commit `5cd74c3`)**
- Πριν: μετά το L18 το `Phoenix.rebirth` δεν καλούνταν πουθενά → wrapper `Phoenix` (`main.dart:172` πριν την αφαίρεση) + εξάρτηση `flutter_phoenix` (`pubspec.yaml:40`) ήταν νεκρός κώδικας.
- Διόρθωση: αφαιρέθηκαν και τα δύο — το `MyApp.build` επιστρέφει απευθείας το `MaterialApp`· `pubspec.lock` έχασε μόνο το `flutter_phoenix` (−8 γραμμές, το transitive `nested` προέρχεται από άλλο πακέτο).
- Επαλήθευση: `flutter analyze` 0/0/0, `flutter test` 260/260, release APK + device smoke (rotation χωρίς crash, `Phoenix` 0 στο logcat).

**E60 — `DebugConfig` σιωπηλό σε όλα τα builds (INFO 25/11/2026)**
- `_debug = false` σταθερό (`lib/core/utils/debug_config.dart:6`) → `DebugConfig.print`/`startup` **δεν τυπώνουν τίποτα**, άρα και τα logs του L18 hardening / E58 είναι σιωπηλά.
- Καμία επίπτωση σε λειτουργία· προτείνεται διακόπτης ανά build (`kDebugMode` ή `--dart-define`) όταν χρειαστεί διάγνωση σε device.

**E61 — Κεντρικό μήνυμα συγχρονισμού (🚫 WON'T FIX 26/11/2026)**
- Δεν είναι bug αλλά ιδέα: μετά την αφαίρεση του `MessageService` (E15) κανένα σημείο του κώδικα δεν παράγει μήνυμα συγχρονισμού (έλεγχος 26/11/2026: `waitForPendingWrites` / `onSyncComplete` / «Συγχρονισμός ολοκληρώθηκε» → **0** αναφορές· μόνο debug log `hasPendingWrites` στο `notifications_provider.dart:125`).
- **Απόφαση (Session 36, κεφ. 40): διαγραφή, όχι αναβίωση** — η ένδειξη offline καλύπτεται από το `OfflineAppBarChip` και τις φραγές `isConfirmedOffline`. Αν ποτέ ζητηθεί κεντρικό μήνυμα, απαιτείται **νέα 4-βηματική πρόταση** (θέση, χρόνος, όριο `waitForPendingWrites()`) και νέο ID.

**L23 — Μη ταυτοποιήσιμος peer (🚫 WON'T FIX 26/11/2026)**

- **Τι ήταν:** αν το peer σκέλος δεν ταυτοποιηθεί (αποτυχία ανάγνωσης group, leg χωρίς `transfer_group_id`, group με 0 ή >1 ενεργά legs, άκυρο σχήμα), η διαγραφή λογαριασμού κρύβει **μόνο** το ενεργό σκέλος, χωρίς marker → δεν επανέρχεται. Αμυντικό κενό, όχι ροϊκό bug (`account_delete_guard.dart:240–286`· η κανονική ροή καλύπτεται από E11).
- **Read-only έλεγχος 26/11/2026** (admin ανάγνωση Firestore, μόνο GET — καμία εγγραφή): **6 χρήστες / 2.312 κινήσεις / 146 transfer legs / 73 groups**. Έλεγχοι: leg χωρίς group id, group με ≠2 ενεργά legs, peer ανύπαρκτο/διαγραμμένο/άλλο group, άκυρο σχήμα, `account_id` που δεν υπάρχει, scheduled transfer χωρίς peer+group → **όλα 0**.
- **Ανά χρήστη:** `aristos62@yahoo.com` 67 groups (66 πλήρη, 1 πλήρως διαγραμμένο) · `demo@yahoo.com` 6 groups (2 πλήρη, 4 πλήρως διαγραμμένα) · οι υπόλοιποι 4 χρήστες 0 transfer legs. **0 προβληματικά groups παντού** — τα «πλήρως διαγραμμένα» ζεύγη είναι κανονικές διαγραφές, όχι μισά ζεύγη.
- **Απόφαση χρήστη (26/11/2026):** κλείσιμο ως **🚫 WON'T FIX** — το fail-closed guard κρίνεται **υπερβολή** (κανένα πραγματικό περιστατικό· η κανονική ροή καλύπτεται από E11). Καμία αλλαγή κώδικα, καμία επισκευή δεδομένων, κανένα version bump.

## Πώς προσθέτω εύρημα

1. Νέο `E#` στο τέλος του πίνακα **Ευρήματα** (ποτέ επαναχρησιμοποίηση ID).
2. Κατάσταση: `🔵 OPEN` · `⏸ DEFERRED` (με λόγο) · `✅ FIXED` (με commit) · `🚫 WON'T FIX` (με αιτιολόγηση) · `ℹ️ INFO`.
3. Αν είναι στην ουρά: γραμμή στον πίνακα **Σειρά εκκρεμοτήτων**.
4. Όταν διορθώνεται: αλλάζει μόνο η κατάσταση + ημερομηνία + commit· αν χρειάζεται, συμπληρώνεται σύντομη **Λεπτομέρεια**.
5. Οι τεχνικές λεπτομέρειες μένουν στο `DESIGN.md`· εδώ μόνο τι/πότε/κατάσταση.
