# Session 28 (2026-11-24) — Flutter 3.50.1: οδηγός αποκατάστασης + αλλαγές συσκευής

> **Κεφάλαιο 31/31** · **Ημερομηνία:** 2026-11-24 · **Σχετικά:** toolchain, Android Gradle 9/AGP 9, Firebase C++ SDK, Firebase CLI
> **Σκοπός:** αναπαραγώγιμος οδηγός για τον **ίδιο έλεγχο και διόρθωση σε άλλον υπολογιστή** με τις ίδιες εκδόσεις Flutter/Android Studio. Δεν άλλαξαν Firestore, rules, indexes, schema, `lib/` ή `test/`.

### Πλαίσιο

Ο χρήστης αναβάθμισε το Flutter από **3.47.8 / Dart 3.13.7** σε **3.50.1 / Dart 3.14.0**. Ο έλεγχος έδειξε ότι ο κώδικας είναι υγιής, αλλά το **Android build μπλοκαρίστηκε από τρία διαδοχικά εμπόδια toolchain**. Στην ίδια συσκευή έγιναν επίσης αλλαγές στον Firebase CLI λογαριασμό και στο Flutter JDK config. Το Windows build απέτυχε με ξεχωριστή αιτία (MSVC) και **δεν επηρεάζει** τη ροή εργασίας από Android Studio.

### Κατάσταση toolchain όπως μετρήθηκε

| Στοιχείο | Πριν (`DESIGN.md` §1.1) | Μετά (24/11/2026) |
|---|---|---|
| Flutter / Dart | 3.47.8 / 3.13.7 | **3.50.1 / 3.14.0** |
| JDK (Flutter CLI) | 21.0.2 (ρυθμισμένο) | **22.0.1** (`flutter config --jdk-dir`) |
| Android SDK | 36.0.0 | 36.0.0 (εγκαταστάθηκαν Build-Tools 36) |
| Gradle wrapper | 8.14.0 | **9.5.0** |
| AGP / Kotlin plugin | 8.11.1 / 2.2.20 | **9.3.1 / 2.4.20** |
| Visual Studio | Community 2026 18.1.1 · SDK 10.0.26100 | **Community 2022 17.10.1 · SDK 10.0.22621** (μη εναρμονισμένο) |
| Firebase C++ SDK (Windows) | 13.13.1 | 13.13.1 (αμετάβλητο) |

### Οδηγός διόρθωσης για τον άλλον υπολογιστή (βήμα-βήμα)

1. **Επαλήθευση εκδόσεων**
   ```powershell
   cd C:\Users\Vaggelis\aris_flutter\family_economy
   flutter --version      # πρέπει 3.50.1 / Dart 3.14.0
   flutter doctor -v
   git status --short
   ```
2. **Dependencies.** Το `flutter pub get --enforce-lockfile` περνά, αλλά το `flutter analyze` τρέχει κανονικό `pub get` και **αλλάζει το `pubspec.lock`** (Dart 3.14). Κρατήσαμε τη νέα λύση: `clock 1.1.2→1.1.3`, `stack_trace 1.12.1→1.12.2`, `test_api 0.7.12→0.7.14`, νέο `listen 1.0.1`, constraint `dart >=3.13.0-0`.
3. **JDK.** Ο Gradle 8.14 υποστηρίζει Java **έως 24**· ο JBR του Android Studio ήταν **25.0.4** → `Java/Gradle incompatibility`. Ρύθμιση εκτός repo:
   ```powershell
   flutter config --jdk-dir="C:\Program Files\Java\jdk-22"
   flutter doctor -v      # "Java binary at: ...jdk-22"
   ```
   Στο Android Studio: **Ctrl+Alt+S → αναζήτηση `Gradle JDK` (ή `Daemon JVM criteria`) → Build, Execution, Deployment → Build Tools → Gradle**, και επιλογή του ίδιου JDK 22 (ή `Add JDK...`). Η ρύθμιση του IDE αφορά το κουμπί *Run*· το `flutter build apk` χρησιμοποιεί το `flutter config`.
4. **Άδειες SDK:** `flutter doctor --android-licenses` και **`y` + Enter σε κάθε ερώτηση** μέχρι «All Android licenses accepted». Το πρώτο build εγκατέστησε και Build-Tools 36.
5. **Εμπόδιο 2 — ελάχιστος Gradle.** Το Flutter 3.50.1 απορρίπτει Gradle < **9.3.1** (`--android-skip-build-dependency-validation` **δεν** χρησιμοποιήθηκε). Οι τιμές του ίδιου του template (`flutter_tools/lib/src/android/gradle_utils.dart`): Gradle **9.5.0**, AGP **9.3.1**, Kotlin **2.4.20**.
   - `android/gradle/wrapper/gradle-wrapper.properties`: `gradle-8.14-all.zip` → **`gradle-9.5.0-all.zip`**
   - `android/settings.gradle.kts`: `com.android.application` `8.11.1` → **`9.3.1`** · `org.jetbrains.kotlin.android` `2.2.20` → **`2.4.20`**
6. **Εμπόδιο 3 — DSL του AGP 9.** Μετά το βήμα 5 το build απέτυχε στο `android/app/build.gradle.kts` (3 errors: `android {}` / `kotlinOptions`). Migration στο στυλ του Flutter 3.50.1:
   - Αφαίρεση `id("kotlin-android")` από το `plugins {}` (AGP 9 = Built-in Kotlin).
   - Αφαίρεση του `kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }`.
   - Προσθήκη **εκτός** του `android {}`:
     ```kotlin
     kotlin {
         compilerOptions {
             jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
         }
     }
     ```
   - Διατηρήθηκαν: `coreLibraryDesugaring`, `google-services`, `signingConfig(debug)`, `isMinifyEnabled=false`, `isShrinkResources=false`.
7. **Windows (μόνο αν χρειάζεται desktop build).** Το `flutter build windows --debug` αποτυγχάνει με LNK2019/LNK1120 (7 unresolved: `__std_find_end_1`, `__std_search_1`, `__std_remove_8`, `_Cnd_timedwait_for_unchecked`, `_Avx2WmemEnabled` κ.λπ.) από τα προ-built `firebase_app/firebase_firestore/firebase_auth.lib` του C++ SDK 13.13.1. Αιτία: VS **17.10.1** + SDK **10.0.22621** ενώ το docs απαιτούν VS **2026 18.1.1** + SDK **10.0.26100**. Γνωστό upstream: flutterfire **#17270**· λύση = αναβάθμιση Visual Studio/Windows SDK. **Δεν έγινε** εδώ (ο χρήστης δουλεύει Android). Μην κάνεις downgrade Firebase — αναιρεί το patch eMudhra.
8. **Quality gates μετά τη διόρθωση**
   ```powershell
   flutter analyze     # 72 info (μόνο deprecation), 0 error/warning
   flutter test        # 238/238
   flutter build apk --debug
   flutter build web --release
   ```
   Στο PowerShell τα `flutter build` μπορεί να δείξουν `Exit code: 1` λόγω **stderr warnings**· το απόλυτο σημάδι επιτυχίας είναι `√ Built ...`.

### Όλες οι αλλαγές που έγιναν σε αυτή τη συσκευή

| Ενέργεια | Αποτέλεσμα |
|---|---|
| Clone/μεταφορά session | Νέο clone στο `C:\Users\Vaggelis\aris_flutter\family_economy` (`main`, `eb4a1cc`)· το παλιό clone στο `C:\Users\Vaggelis\Documents\Default Project` **παρέμεινε** |
| GitHub CLI | Εγκατάσταση `gh` v2.105.0, login ως `aristos62-bit`, `gh auth setup-git`· κανένα token στο repo |
| Firebase CLI | Ο λογαριασμός του άλλου χρήστη (`gavrielatosvaggelis@gmail.com`, ληγμένο token/401) **αντικαταστάθηκε** στο CLI από τον `aristos62@gmail.com` του χρήστη· `firebase use family-economy-d1b4d`· read-only `projects:list` + `firestore:indexes` (7 indexes). **Κανένα deploy** |
| Flutter upgrade (από τον χρήστη) | 3.50.1 / Dart 3.14.0 |
| `pubspec.lock` + generated registrants | 8 files τροποποιήθηκαν από το `pub get` (linux/macos/windows) |
| `flutter config --jdk-dir` (από τον χρήστη) | `C:\Program Files\Java\jdk-22` — **εκτός repo**, παγκόσμια ρύθμιση Flutter |
| Android Studio Gradle JDK (από τον χρήστη) | Ρυθμίστηκε στο ίδιο JDK 22 (GUI builds) |
| Άδειες Android SDK (από τον χρήστη) | Ολοκληρώθηκαν· `flutter doctor` → «All Android licenses accepted» |
| 3 Android files (με έγκριση + backup) | Gradle wrapper, `settings.gradle.kts`, `app/build.gradle.kts` όπως στο βήμα 5–6 |
| Build artifacts | `android/build/` εμφανίστηκε ως **untracked** (δεν καλύπτεται από το `/build/` του `.gitignore`) |
| Docs (24/11/2026) | `DESIGN.md` (§1.1, §2.1, §2.5, §2.7, §9.1, §11 L33–L35), `README.md`, `AGENTS.md` ενημερώθηκαν με το νέο toolchain και τα πραγματικά build αποτελέσματα |
| Backups | 6 αρχεία στο `backups/` (βλ. τέλος) |

### Quality gates — αποτελέσματα

- `flutter test` → **238/238** (πριν και μετά τις αλλαγές).
- `flutter build apk --debug` → ✅ **`build\app\outputs\flutter-apk\app-debug.apk`**.
- `flutter build web --release` → ✅ `build\web` (Wasm dry-run warnings από `image-4.3.0`).
- `flutter analyze` → 72 **info** (`package:flutter/material.dart` deprecated μετά το 3.47), **0 errors / 0 warnings**.
- `flutter build windows --debug` → ❌ LNK2019/LNK1120 (βήμα 7) — δεν διορθώθηκε.

### Εκκρεμότητες / γνωστά warnings

- **KGP:** η Flutter προειδοποιεί ότι `file_picker`, `firebase_auth`, `firebase_core`, `package_info_plus`, `shared_preferences_android` εφαρμόζουν ακόμα Kotlin Gradle Plugin. Σήμερα χτίζουν· **μελλοντική έκδοση θα αποτύχει**.
- **72 deprecation infos** — δεν μπλοκάρουν build.
- **README drift:** διορθώθηκε 24/11/2026 — `README.md` πλέον δείχνει `2.3.7+14`, `238/238` και Flutter 3.50.1.
- **`DESIGN.md` / `AGENTS.md`:** ενημερώθηκαν 24/11/2026 με το νέο toolchain και τα πραγματικά build αποτελέσματα.
- **`error_list.md`** — τα νέα ευρήματα **δεν καταγράφηκαν** ακόμα.
- Εκκρεμεί απόφαση: κράτημα/revert των 8 files του `pub get`, διαχείριση `android/build/`, ενημέρωση `error_list.md`.

### Backups

- `backups/gradle-wrapper_20261124_115240.bak`
- `backups/settings-gradle-kts_20261124_115240.bak`
- `backups/app-build-gradle-kts_20261124_115951.bak`
- `backups/AGENTS_20261124_124159.bak`
- `backups/DESIGN_20261124_124159.bak`
- `backups/README_20261124_124159.bak`

> Κανένα αρχείο με credentials/κλειδιά δεν αντιγράφηκε στον φάκελο `backups/`.
