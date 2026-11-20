# Session 14 (2026-11-19) — E4: Versioning δεδομένων ✅

> **Κεφάλαιο 15/16** · **Ημερομηνία:** 2026-11-19 · **Πηγή:** `oldsessions.md` γρ. 463–534 (αρχείο πριν το refactor της 2026-11-20)

---

### Απόφαση & πλαίσιο
- Το E4 **εγκρίθηκε** και υλοποιήθηκε σε 11 μικρά βήματα: ένα αρχείο τη φορά, **backup πρώτα**, `flutter analyze` + `flutter test` μετά από κάθε αλλαγή.
- **Απόκλιση από την αρχική διατύπωση:** `schema_version` **μόνο** στο Firestore root doc (`users/{uid}`) — **όχι** SharedPreferences. Λόγος: με `persistenceEnabled + CACHE_SIZE_UNLIMITED` (`main.dart:64–67`) το doc είναι διαθέσιμο offline· δεύτερο σημείο αλήθειας θα ξέφευγε (αλλαγή λογαριασμού, καθαρισμός cache).
- **Καμία αλλαγή στους `firestore.rules`:** το root doc είναι owner read/write χωρίς field validation.

### Νέα αρχεία
| Αρχείο | Γραμμές | Ρόλος |
|---|---|---|
| `lib/core/data/schema.dart` | 249 | Σταθερές (`current = baseline = 1`), ανεκτικός parser, `decide()`, `failureFor()`, `resolveWrite()`, `SchemaBlockedException` |
| `lib/core/data/schema_service.dart` | 187 | Gate + migrations (κενό registry) + εγγραφή έκδοσης με `timeout(3s)` + επαλήθευση `Source.cache` |
| `lib/core/widgets/startup_error_view.dart` | 140 | Κοινή διάταξη σφάλματος (scroll, κόκκινο, κύριο + δευτερεύον κουμπί) |
| `test/unit/core/data/schema_test.dart` | 334 | **34 tests** |
| `test/unit/core/widgets/startup_error_view_test.dart` | 154 | **5 tests** |

### Αλλαγές σε υπάρχοντα αρχεία
| Αρχείο | Αλλαγή |
|---|---|
| `main.dart` | `ErrorApp` → `StartupErrorView` (ίδια κείμενα· `Phoenix.rebirth` **άθικτο**) |
| `app_start.dart` | Gate πριν τις scheduled transactions (103) · typed catch (148) · error UI (239) |
| `login_page.dart` | Gate μετά την ανάγνωση του doc (119) — **μηδέν νέο UI** |
| `options_page.dart` | `_buildInfoCard` → «Δεδομένα · Έκδοση N» (1434) |
| `auth_service.dart` | Σφράγισμα νέου χρήστη: `schema_version`, `schema_updated_at` |

### Αποφάσεις-κλειδιά
1. **Timeout ≠ αποτυχία.** Offline το `set()` **δεν** ολοκληρώνεται (η εγγραφή μένει στην ουρά). Γι' αυτό: timeout → **1 ανάγνωση cache** (`Source.cache` πρώτα, μετά fallback) → `appliedLocally` ή φραγή.
2. **Φραγή** μόνο σε πραγματικό σφάλμα, σε `newerThanApp`, ή σε μη επιβεβαιωμένη τοπική εφαρμογή.
3. **Καμία migration framework.** Κενό registry· όσο `current == baseline` η ροή `pending` είναι **μαθηματικά αδύνατη** ⇒ 0 writes για υπάρχοντες χρήστες.
4. **`ErrorApp` restart δεν διορθώθηκε** (γνωστό bug: `Phoenix.rebirth` χωρίς ancestor, δεν επανατρέχει το `main()`) → `DESIGN.md` §11 L18.
5. **Login χωρίς νέο UI:** το υπάρχον spinner του κουμπιού + το υπάρχον `catch` αρκούν (το `SchemaBlockedException.toString()` επιστρέφει μόνο το μήνυμα).

### Quality gates
| Έλεγχος | Αποτέλεσμα |
|---|---|
| `flutter analyze` | ✅ No issues found (~5s) |
| `flutter test` | ✅ **89/89** (84 + 5) |

### Εκκρεμότητες
| # | Θέμα | Κατάσταση |
|---|---|---|
| 1 | `_debug = true` προσωρινά για QA → **πρέπει** `false` πριν το commit | ✅ `false` |
| 2 | `backups/` εκτός `.gitignore` (11 `.bak` untracked) | ✅ προστέθηκε στο `.gitignore` |
| 3 | Χειροκίνητο QA (offline migration, kill-restart) — μόνο όταν `Schema.current` γίνει 2 | ⏳ |
| 4 | Τα νέα αρχεία θέλουν `git add` | ✅ commit `211fb86` |

### Release
- Commit κώδικα: `211fb86` (`feat(data): add schema versioning gate at startup (E4)`) · pushed.
- Version bump: `2.0.1+2` → **`2.1.0+3`** (MINOR: προαιρετικό νέο πεδίο με default, βλ. `DESIGN.md` §1.5.3).
- Tag: **`v2.1.0`** σε commit `release: v2.1.0`.

### Backups αυτού του session
`DESIGN_20261119_173403.bak`, `app_start_20261119_173403.bak`, `app_start_20261119_175708.bak`, `auth_service_20261119_173403.bak`, `login_page_20261119_173403.bak`, `login_page_20261119_181125.bak`, `main_20261119_173403.bak`, `oldsessions_20261119_173403.bak`, `options_page_20261119_173403.bak`, `options_page_20261119_182021.bak`, `schema_service_20261119_182916.bak`, `widget_test_20261119_173403.bak`, `DESIGN_20261119_184222.bak`, `oldsessions_20261119_184222.bak`, `DESIGN_20261119_184727.bak`, `gitignore_20261119_184727.bak`, `oldsessions_20261119_184727.bak`, `DESIGN_20261119_185231.bak`, `oldsessions_20261119_185231.bak`, `pubspec_20261119_185231.bak`

### Έλεγχος συνέπειας `.md` ↔ κώδικας (19/11/2026)
Πλήρης έλεγχος **όλων** των `.md` με μετρήσεις πάνω στον κώδικα. Διορθώθηκαν:

| Αρχείο | Λάθος πριν | Πραγματικότητα |
|---|---|---|
| `AGENTS.md` | `flutter test` → 50/50 · κανόνας 7 «backups tracked» | **89/89** · `backups/` ignored |
| `README.md` | έκδοση `2.0.1+2`, 50/50, 277 εικονίδια, `FamilyBudgetSetup.exe` | **`2.1.0+3`**, **89/89**, **276**, `FamilyBudgetSetup_v<ver>.exe` |
| `DESIGN.md` | 75 outdated · 277 icons · 50/50 · 98 Dart · 12 oil · 6 tests/50 · παλιά line refs σε `main.dart` · 82 κλήσεις/29 αρχεία · services+core 17 · 180 SnackBar · 58 accessibility · 141 users refs · uuid 367 · deleted 200 · updated_at 114 · notifyListeners 66 · `backups/` 41 tracked | **77 · 276 · 89 · 102 · 13 · 8/89 · 30–93 · 83/30 · 18 · 186 · 61 · 142 · 423 · 247 · 116 · 67 · 0 (ignored)** |
| `docs/rules/firestore.rules.md` | ανέφερε ανύπαρκτο `isOwner(data)`, ελλιπείς διαδρομές | ξαναγράφτηκε από το πραγματικό `firestore.rules` (μόνο `isSignedIn`, 15 paths, `settings`, `oil_purchases`, `exchange_rates`) |
| `docs/tables/users.md` | έλειπαν `schema_version` / `schema_updated_at`, `created_at` ως ISO string | Timestamp πεδία + E4 πεδία + σημείωση |
| `docs/tables/account_snapshots.md` | σπασμένο markdown (χωρίς heading/κλείσιμο code fence) | πλήρες αρχείο στο ίδιο στυλ |

**Backups εκτός git:** `git rm -r --cached backups/` + `lib/*.backup` + `oldsessions.md.backup` → **65 αρχεία έφυγαν από το index** (παρέμειναν στον δίσκο), `*.backup` προστέθηκε στο `.gitignore`. Tracked: **635 → 570**.

Νεότερα backups (`*_20261119_190148.bak`): `AGENTS.md`, `README.md`, `DESIGN.md`, `oldsessions.md`, `.gitignore`, `docs_rules_firestore.rules.md`, `docs_tables_users.md`, `docs_tables_account_snapshots.md`.

---
