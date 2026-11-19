# Family Economy

Οικογενειακή διαχείριση οικονομικών: έσοδα, έξοδα, μεταφορές, προϋπολογισμοί,
προγραμματισμένες κινήσεις, γραφήματα και στατιστικά. Ελληνικό UI, Material 3,
ανοιχτό/σκοτεινό θέμα, offline-first με Firebase.

Έκδοση εφαρμογής: **2.0.1+2** (`pubspec.yaml` — μοναδική πηγή της έκδοσης).

---

## Λειτουργίες

- **Λογαριασμοί** με υπόλοιπα, διπλότυπα-έλεγχο ονομάτων και επαναφορά διαγραμμένων
- **Κατηγορίες / υποκατηγορίες** εσόδων-εξόδων με 277 εικονίδια, **tags**
- **Συναλλαγές** με πρόσημο ποσού· **μεταφορές** ως ζεύγος εγγραφών (`transfer_group_id`)
- **Προϋπολογισμοί** (total / κατηγορίας / υποκατηγορίας) με όριο υπέρβασης και ειδοποίηση
- **Προγραμματισμένες κινήσεις** με αυτόματη εκτέλεση στην εκκίνηση και περιοδικό έλεγχο
- **7 γραφήματα** (έσοδα/έξοδα, κατηγορίες, υποκατηγορίες, υπόλοιπα, μηνιαία πορεία, προβολή κινήσεων)
- **Στατιστικά** (μέσοι όροι, σύγκριση budget, στατιστικά tags), **ημερολόγιο**
- **Παρακολούθηση πετρελαίου** (δεξαμενή, κατανάλωση, ιστορικό αγορών)
- **Μετατροπέας μονάδων**, **εξαγωγή PDF/Excel**
- **Ειδοποιήσεις**: τοπικές + επαναλαμβανόμενες (`daily` / `weekly` / `monthly`)
- **Βιομετρικό ξεκλείδωμα** (`always` / `on_demand`), **accessibility** (semantics + ανακοινώσεις)
- **Offline-first**: τοπική cache Firestore, συγχρονισμός με ενημέρωση κατά την επανασύνδεση

---

## Πλατφόρμες

| Πλατφόρμα | Κατάσταση |
|---|---|
| Android | ✅ Επιβεβαιωμένο |
| Windows | ✅ Επιβεβαιωμένο (installer με Inno Setup) |
| Web | ✅ Επιβεβαιωμένο |
| iOS / macOS / Linux | ⚠️ Ο φάκελος υπάρχει, αλλά **χωρίς `Podfile`** → build μη επιβεβαιωμένο |

Λεπτομέρειες build ανά πλατφόρμα: [`DESIGN.md` §2](DESIGN.md).

---

## Τεχνολογίες

Flutter **3.47.8** / Dart **3.13.7** (μετρημένο 19/11/2026), Firebase (Auth,
Cloud Firestore), Provider / `ChangeNotifier`, `flutter_local_notifications`,
`fl_chart`, `local_auth`, `pdf` / `excel`.

Resolved εκδόσεις πακέτων, αρχιτεκτονική, Firestore schema και περιορισμοί:
[`DESIGN.md`](DESIGN.md) (μοναδική πηγή τεχνικής αλήθειας).

---

## Προαπαιτούμενα

- Flutter SDK (stable) — το `environment.sdk: ^3.10.4` του `pubspec.yaml`
  είναι **constraint της Dart**, όχι έκδοση Flutter
- Για Android build: Android SDK 36 · Java **17** (target) · JDK 21 στο CLI
- Για Windows build: Visual Studio με C++ desktop workload
- Firebase project με:
  - `lib/firebase_options.dart`
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
  - `firestore.rules` + `firestore.indexes.json` (deploy μέσω Firebase CLI)

> Τα `google-services.json` / `GoogleService-Info.plist` είναι **client config** και
> βρίσκονται στο repo. Κλειδιά service account (admin SDK) **δεν** ανήκουν ποτέ εδώ.

---

## Setup & έλεγχοι

```sh
flutter pub get
flutter analyze     # αναμενόμενο: No issues found
flutter test        # αναμενόμενο: 50/50
```

Εκτέλεση:

```sh
flutter run -d windows
flutter run -d chrome
flutter run -d <android-device>
```

---

## Build & διανομή

```sh
flutter build windows
flutter build apk
```

Πλήρες build + installer:

```bat
build_and_setup_final.bat
```

- Διαβάζει την έκδοση **αυτόματα** από το `pubspec.yaml`
- Παράγει `InstallerOutput\FamilyBudgetSetup.exe` (Inno Setup, `fam_eco_new.iss`)
- Προεπιλεγμένος φάκελος εγκατάστασης: `%LOCALAPPDATA%\f_budget`
- ⚠️ Η release έκδοση Android υπογράφεται με **debug key** (βλ. `DESIGN.md` §2.1)

---

## Versioning

SemVer `MAJOR.MINOR.PATCH+BUILD` — η έκδοση αλλάζει **μόνο** στο `pubspec.yaml`.
Κανόνας απόφασης (πότε MAJOR / MINOR / PATCH) και εκκρεμότητες: `DESIGN.md` §1.5.

---

## Δομή & τεκμηρίωση

| Αρχείο | Ρόλος |
|---|---|
| [`DESIGN.md`](DESIGN.md) | Τεχνική αλήθεια: stack, δομή, αρχιτεκτονική, Firestore, build, tests |
| [`AGENTS.md`](AGENTS.md) | Κανόνες λειτουργίας για agents |
| [`oldsessions.md`](oldsessions.md) | Ιστορικό ανά session |
| `docs/` | Legacy περιγραφές schema (import script) |
| `data/*.json` | Δεδομένα εισαγωγής |

Καθημερινές εντολές και quality gates: `AGENTS.md`.
