# Session 43 (2026-11-28) — E87–E89: προφόρτωση διάταξης γραφημάτων

> **Κεφάλαιο 50/50** · **Ημερομηνία:** 2026-11-28 · **Σχετικά:** E87, E88, E89 · `2.3.17+24`

### Πλαίσιο

Μετά το βιομετρικό gate η Αρχική εμφάνιζε για ένα καρέ μόνο το κουμπί
«Επεξεργασία Διάταξης Σελίδας» και αμέσως μετά τα γραφήματα: η
`GeneralViewPage` χτιζόταν με `chartOrder = []` και διάβαζε ασύγχρονα το
`SharedPreferences`. Η πρόταση Δ (προφόρτωση πριν το `HomePage`) εγκρίθηκε
με 1Α (ενιαίος reader), 2Α (όριο 500 ms) και 3Α (unit tests + συσκευή).

Κατά την ανάλυση βρέθηκαν δύο ακόμη σφάλματα:

- **E88:** το `graf_7` έμπαινε πριν από το `graf_6` στη σειρά, αλλά η
  ορατότητα συμπληρωνόταν στο τέλος → μετατοπισμένα κρυφά/ορατά γραφήματα,
  που γράφονταν μόνιμα.
- **E89:** ο editor μπορούσε να διαβάσει ορατότητα μικρότερη από τη σειρά
  (`RangeError`) και τοποθετούσε λείπον γράφημα πρώτο (`indexOf` = -1).

### Αλλαγές

| Αρχείο | Αλλαγή |
|---|---|
| `presentation/screens/charts/chart_layout_prefs.dart` | **Νέο.** `ChartLayout` (σειρά, ορατότητα, περίοδοι) + `ChartLayoutPrefs.load/loadWithin/fallback`. Ζευγάρωμα `(id, visible)` πριν από κάθε μετακίνηση, αφαίρεση άγνωστων/διπλών ids, migration `graf_7` πριν από `graf_6`, περίοδοι μέσω `PeriodPrefs`, όριο 500 ms (default) με `null` σε λήξη/σφάλμα. Καμία εγγραφή σειράς/ορατότητας. |
| `presentation/screens/charts/general_view_page.dart` | `initialLayout` + `_layoutReady`· εφαρμογή έτοιμης διάταξης στο `initState` χωρίς δεύτερη ανάγνωση· `_loadChartPreferences` μέσω `loadWithin` (2 s) με `fallback`· αφαίρεση των δύο εγγραφών σε κάθε εκκίνηση· κενό `Scaffold` μέχρι να είναι έτοιμη η διάταξη. |
| `presentation/screens/charts/view_option_page.dart` | Ανάγνωση σειράς/ορατότητας/περιόδων μέσω του loader (2 s)· `periodKeys`/`defaultPeriods` από μία πηγή· εγγραφές αμετάβλητες. |
| `presentation/screens/home/home_page.dart` | `initialChartLayout` → `GeneralViewPage(initialLayout)`. |
| `presentation/auth/app_start.dart` | `loadWithin(uid)` αμέσως μετά το `uid`, παράλληλα με user doc/βιομετρικό/schema/onboarding/scheduled· `await` πριν τη μετάβαση· πέρασμα στο `HomePage`. |
| `presentation/auth/login_page.dart` | Ίδια προφόρτωση πριν τη μετάβαση. |
| `test/unit/presentation/screens/charts/chart_layout_prefs_test.dart` | **Νέο.** 16 tests. |
| `pubspec.yaml` | `2.3.16+23` → `2.3.17+24`. |
| `DESIGN.md` | §1.1 version, §3.1 μετρήσεις, §4.3 βήματα/γραμμές + προφόρτωση, §5.8 ενιαίος reader, §9.1/§9.2 tests. |
| `error_list.md` | E87–E89 → ✅ FIXED 28/11/2026 + λεπτομέρειες. |

### Quality gates

| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | ✅ **No issues found!** (82,2 s) |
| `flutter test` (νέο αρχείο) | ✅ **16/16** |
| `flutter test` (πλήρες) | ✅ **374/374** |
| Device tests POCO X3 | ✅ **PASS** (28/11/2026) — E87 cold start & login χωρίς flash· E88 migration/pairing χωρίς μετατόπιση· E89a/E89b editor χωρίς `RangeError`· cleanup/επαναφορά ✅ |

### Device tests (POCO X3, 28/11/2026)

- **E87:** το πρώτο καρέ της Αρχικής είχε πλήρη διάταξη τόσο σε cold start
  (προεπιλεγμένη και αποθηκευμένη) όσο και μετά από logout/login· κανένα καρέ
  μόνο με το κουμπί «Επεξεργασία Διάταξης».
- **E88:** παλιά σειρά χωρίς `graf_7` → σωστό ζευγάρωμα· `graf_7` ορατό,
  `graf_6` κρυφό· τα prefs έμειναν αμετάβλητα (read-only loader).
- **E89a:** ορατότητα 5 τιμών για 7 γραφήματα → editor χωρίς `RangeError`,
  τα λείποντα ορατά.
- **E89b:** σειρά χωρίς `graf_1` → προστέθηκε στο τέλος· editor/save σωστά.
- **Καθαρισμός:** αρχικά prefs (μόνο περίοδοι), `fingerprint_enabled=true`,
  rotation/font/animations/airplane όπως αρχικά, temp files removed,
  app force-stopped, launcher foreground· demo λογαριασμός/δεδομένα άθικτα.
- Λεπτομέρειες/αποδείξεις: `device test/E87_E88_device_tests.md`,
  `device test/logs/e87_final_state.txt`.

### Τι δεν άλλαξε

Firestore schema/rules, providers, `PeriodPrefs` API, keys/format αποθήκευσης,
σειρά βιομετρικού/schema/onboarding/scheduled, `AppMessenger`, οι άλλες έξι
καρτέλες, η συμπεριφορά αποθήκευσης του editor.

### Ανοιχτά ρίσκα

- Χρήστες που πρόλαβαν τη μετατόπιση ορατότητας πριν την ενημέρωση δεν
  ανιχνεύονται με ασφάλεια· διορθώνεται χειροκίνητα από τον editor.
- Αν η τοπική ανάγνωση ξεπεράσει τα 500 ms στην εκκίνηση, το φαινόμενο
  παραμένει (σπάνιο· η σελίδα πέφτει στην παλιά συμπεριφορά).

### Backups

`backups/` (28/11/2026, suffix `20261128-chartlayout`):
`general_view_page.dart`, `view_option_page.dart`, `home_page.dart`,
`app_start.dart`, `login_page.dart`, `pubspec.yaml`, `DESIGN.md`,
`error_list.md`, `oldsessions.md`.
