# new_material_fix.md — Material εκτός SDK: επαναχρησιμοποιήσιμη διόρθωση

> **Σκοπός:** οδηγίες βήμα-βήμα για να εφαρμοστεί η **ίδια, επαληθευμένη** διόρθωση
> (`package:flutter/material.dart` → `package:material_ui/material_ui.dart`) σε **κάθε**
> Flutter project, χωρίς να ξαναγίνεται η έρευνα από την αρχή.
>
> **Επαληθεύτηκε** στο `family_economy` (Flutter 3.50.1 / Dart 3.14.0, 25/11/2026):
> 72 info → **0**, 251/251 tests, `apk`/`web`/`windows` builds ✅.
> Ιστορικό: `oldsessions/35-session-32-material-ui-migration.md` · εύρημα E56 στο `error_list.md`.

---

## 1. Πότε χρειάζεται

Από τη **Flutter 3.47** το Material αποσπάστηκε από το SDK σε ξεχωριστό πακέτο.
Το `package:flutter/material.dart` είναι πλέον `@Deprecated` με μήνυμα:

```
'Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre.'
```

Ενδείξεις ότι ένα project το χρειάζεται:

- `flutter analyze` βγάζει **1 `info` (`deprecated_member_use`) ανά αρχείο** που κάνει import `package:flutter/material.dart`
- `+2 info` στο `main.dart` για `GlobalMaterialLocalizations.delegate` / `GlobalCupertinoLocalizations.delegate`
  (μήνυμα: *«Use GlobalMaterialLocalizations from package:material_ui/material_ui.dart instead»*)
- Το analyze επιστρέφει **exit code 1** και «βρόμικο» output, παρόλο που δεν υπάρχουν λάθη

> Δεν είναι bugs. Είναι migration σε νέο πακέτο — **καμία αλλαγή σε λογική/UI**.

---

## 2. Προαπαιτούμενα (έλεγχος πρώτα)

```powershell
flutter --version
```

| Απαίτηση | Ελάχιστο |
|---|---|
| Flutter | **≥ 3.47.0** |
| Dart | **≥ 3.13.0** |
| `material_ui` | `^1.11.1` (φέρνει transitive `cupertino_ui`) |

- Αν το project είναι σε **παλιότερη** Flutter: **μην** κάνεις αυτή τη migration — εκεί το `flutter/material.dart` δεν είναι deprecated. Πρώτα upgrade Flutter (βλ. δικό μας οδηγό: `oldsessions/31-session-28-flutter-350-upgrade-repair.md`).
- Αν το project έχει `environment: sdk: ...` που αποκλείει το 3.13+, ενημέρωσε το constraint **μόνο** αν το επιτρέπει η Flutter του project.
- Πάρε baseline: `flutter analyze` και κράτα πόσα info/ποια αρχεία (για σύγκριση στο τέλος).

---

## 3. Δοκιμή σε worktree (συνιστάται)

Ώστε να μη λερωθεί το working tree αν κάτι πάει στραβά:

```powershell
git worktree add ..\material_ui_trial -b material_ui_trial
cd ..\material_ui_trial
flutter pub get
# ... βήματα 4–8 εδώ ...
```

Αν βγει καθαρό → εφαρμογή στο κύριο project (ίδια βήματα) ή merge.
Καθαρισμός:

```powershell
cd ..
git worktree remove ..\material_ui_trial --force
git branch -D material_ui_trial
```

---

## 4. Backup (πριν από κάθε edit)

```powershell
$dst = "backups\$(Get-Date -Format yyyy-MM-dd)-material-ui"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item pubspec.yaml, pubspec.lock, lib\main.dart $dst
```

> Κανόνας: ποτέ credentials/keys μέσα στο repo ή στο `backups/` — πάνε σε φάκελο εκτός repo.

---

## 5. Προσθήκη εξάρτησης

```powershell
flutter pub add material_ui
```

Ισοδύναμο χειροκίνητο (αν θέλεις συγκεκριμένη έκδοση) — στο `pubspec.yaml`, κάτω από `dependencies:`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  material_ui: ^1.11.1
```

και μετά `flutter pub get`.

Έλεγχος ότι μπήκε:

```powershell
Select-String -Path pubspec.yaml -Pattern "material_ui"
Select-String -Path pubspec.lock -Pattern "material_ui|cupertino_ui" -Context 0,2
```

---

## 6. Αυτόματη αλλαγή των imports

```powershell
dart fix --dry-run --code=migrate_design_widgets
dart fix --apply --code=migrate_design_widgets
```

- Αλλάζει **μόνο** το import: `package:flutter/material.dart` → `package:material_ui/material_ui.dart`
  (σε `lib/` **και** `test/`), χωρίς να αγγίξει κώδικα.
- Το `--dry-run` δείχνει πόσα αρχεία θα αλλάξουν — αν δείχνει 0, έλεγξε ότι έγινε πρώτα `flutter pub get`
  και ότι το SDK είναι ≥ 3.47 (`dart fix --help` για διαθέσιμα codes).

Έλεγχος ότι δεν έμεινε τίποτα:

```powershell
# Πρέπει να επιστρέψει 0 γραμμές
Get-ChildItem lib,test -Recurse -Filter *.dart | Select-String "package:flutter/material.dart"
# Πόσα αρχεία μετανάστευσαν
(Get-ChildItem lib,test -Recurse -Filter *.dart | Select-String "package:material_ui/material_ui.dart" | Measure-Object).Count
```

Αν μείνει κάποιο αρχείο εκτός `lib/`/`test/` (π.χ. `example/`, `tool/`, generated), άλλαξέ το χειροκίνητα στο ίδιο pattern.

---

## 7. Localization delegates στο `main.dart`

**Πριν**

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
...
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
```

**Μετά** (το `material_ui` τα παρέχει όλα μαζί: Material + Cupertino + Widgets)

```dart
import 'package:material_ui/material_ui.dart';
...
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
```

- Αφαίρεσε το `import 'package:flutter_localizations/flutter_localizations.dart';` **αν** το αρχείο δεν το χρειάζεται πια αλλού.
- Έλεγξε όλο το project: `Get-ChildItem lib,test -Recurse -Filter *.dart | Select-String "flutter_localizations"`.
  Αν κάποιο αρχείο το importάρει μόνο για τους delegates, κάνε την ίδια αλλαγή και εκεί.
- Το `flutter_localizations` μπορεί να μείνει στο `pubspec.yaml` (το χρησιμοποιεί και το `material_ui` εσωτερικά) — δεν βλάπτει.
- `supportedLocales`, `locale`, `intl`/`DateFormat` **δεν** αλλάζουν.

---

## 8. Τι **δεν** χρειάζεται

| Πράγμα | Γιατί όχι |
|---|---|
| `MaterialUiCompatibilityBridge` | Είναι **deprecated**· θα ξανάφερνε info. Χρήση **μόνο** αν εμφανιστούν σφάλματα διπλών τύπων (βλ. §9). |
| Αλλαγές σε `ThemeData`, `Colors`, widgets, layouts | Τα ονόματα/API είναι ίδια. |
| Αλλαγή tests | Τα types έχουν ίδια ονόματα· μόνο το import αλλάζει (το κάνει το `dart fix`). |
| Version bump | Αν δεν προστίθεται λειτουργία, η έκδοση μένει ίδια. |
| Αλλαγές σε Firestore/rules/indexes/signing | Καμία σχέση με UI πακέτο. |

**Πακέτα που ακόμα κάνουν import `flutter/material`** (π.χ. `fl_chart`, `responsive_framework`, `flutter_phoenix`, `nested`):
δεν πειράζουν, **εφόσον** δεν εκθέτουν Material τύπο σε API που περνά η εφαρμογή. Έλεγχος:
`Select-String -Path .dart_tool\package_config.json -Pattern "material_ui"` + γρήγορο audit των πακέτων που χρησιμοποιείς.
Στο `family_economy` **κανένα** conflict — χωρίς bridge.

> Το `package:flutter/cupertino.dart` **δεν** είναι deprecated (δεν έχει `@Deprecated`) — αν το project το χρησιμοποιεί,
> δεν χρειάζεται καμία αλλαγή και δεν απαιτείται `cupertino_ui`.

---

## 9. Παγίδες & troubleshooting

| Σύμπτωμα | Αιτία | Λύση |
|---|---|---|
| `Target of URI doesn't exist: 'package:material_ui/material_ui.dart'` | Δεν έγινε `pub get` | `flutter pub get` |
| `The argument type 'ThemeData' can't be assigned to the parameter type 'ThemeData'` | Δύο Material: κάποιο αρχείο κρατά `package:flutter/material.dart` ή πακέτο εκθέτει Material τύπο | Έλεγξε imports (§6). Αν επιμένει από dependency → `MaterialUiCompatibilityBridge` (τελευταία λύση) ή ενημέρωση πακέτου |
| `dart fix` δεν αλλάζει τίποτα | Παλιό SDK ή λάθος code | `flutter --version` ≥ 3.47· `dart fix --dry-run` χωρίς `--code` για διαθέσιμα codes |
| Σφάλμα σε test με `MaterialApp`/`Scaffold` | Το test importάρει ακόμα `flutter/material` | Το `dart fix` το καλύπτει· αλλιώς χειροκίνητα |
| `Exit code: 1` στο PowerShell ενώ όλα πέτυχαν | `flutter`/`git` γράφουν warnings σε **stderr** | Κριτήριο επιτυχίας: `No issues found!` / `All tests passed!` / `√ Built` |
| Ελληνικά σχόλια έγιναν **mojibake** | `Get-Content -Raw` + `Set-Content` με λάθος encoding | Χρήση editor ή .NET UTF-8 χωρίς BOM (`[System.IO.File]::WriteAllText($p,$t,(New-Object System.Text.UTF8Encoding($false)))`) |
| `flutter pub get` δείχνει πολλά «newer versions available» | Ενημερώσεις πακέτων | Αγνόησέ το — δεν είναι σφάλμα |

---

## 10. Επαλήθευση (ίδια σειρά, ίδια κριτήρια)

```powershell
flutter analyze                      # ✅ No issues found! (0 errors / 0 warnings / 0 info)
flutter test                         # ✅ All tests passed!
flutter build apk --debug            # ✅ √ Built ...app-debug.apk
flutter build web --release          # ✅ √ Built build\web
flutter build windows --release      # ✅ √ Built ...\Release\<app>.exe   (αν υποστηρίζεται Windows)
```

**Smoke test σε συσκευή** (5 λεπτά) — τα σημεία που αγγίζει η αλλαγή delegates:

1. Εκκίνηση + εναλλαγή **dark/light**
2. **Date/Time picker** στα ελληνικά (π.χ. φίλτρο περιόδου, ημερομηνία κίνησης)
3. Ένα **dialog** (AlertDialog) και ένα **dropdown**
4. **Tooltips** σε γράφημα/κουμπί
5. `adb logcat` για `E/flutter`, `FATAL EXCEPTION`, `No MaterialLocalizations`

---

## 11. Rollback

```powershell
git restore pubspec.yaml pubspec.lock lib test
flutter pub get
```

ή επαναφορά από το `backups/<ημερομηνία>-material-ui/`.
Αν έγινε commit: `git revert <sha>` (όχι `reset` σε pushed history).

---

## 12. Checklist ανά project (copy-paste)

```
[ ] flutter --version  → Flutter ≥ 3.47 / Dart ≥ 3.13
[ ] flutter analyze    → baseline (πόσα info)
[ ] backup: pubspec.yaml, pubspec.lock, lib/main.dart
[ ] (προαιρετικά) worktree trial
[ ] flutter pub add material_ui
[ ] dart fix --dry-run --code=migrate_design_widgets
[ ] dart fix --apply  --code=migrate_design_widgets
[ ] 0 imports: package:flutter/material.dart  (lib + test)
[ ] main.dart: GlobalMaterialLocalizations.delegates (+ αφαίρεση flutter_localizations import)
[ ] flutter analyze → No issues found
[ ] flutter test    → All tests passed
[ ] build apk/web/windows
[ ] smoke test συσκευής (dark/light, pickers, dialogs, tooltips, logcat)
[ ] docs του project (DESIGN/README/AGENTS/error_list/oldsessions) + commit
```

---

## 13. Στοιχεία αναφοράς (family_economy, 25/11/2026)

| Στοιχείο | Τιμή |
|---|---|
| Toolchain | Flutter **3.50.1** / Dart **3.14.0** |
| Πακέτο | `material_ui` **1.11.1** (+ `cupertino_ui` 1.1.7) |
| Αλλαγές | **70 αρχεία** (69 `lib/` + 1 `test/`) μέσω `dart fix` + `main.dart` (import + delegates) |
| Αποτέλεσμα | 72 info → **0/0/0** |
| Tests | **251/251** (καμία αλλαγή σε test logic) |
| Builds | `apk --debug` ✅ · `web --release` ✅ · `windows --release` ✅ |
| Version | **χωρίς bump** (`2.3.7+14`) |
| Commits | `d7f1597` (code) · `685e16d` (docs) |
| Backups | `backups/2026-11-25-material-ui/` |

**Χρόνος εφαρμογής σε νέο project:** ~10 λεπτά (το `dart fix` κάνει όλη τη δουλειά) + ~15 λεπτά επαλήθευση.
