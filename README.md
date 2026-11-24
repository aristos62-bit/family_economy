# Family Economy

Οικογενειακή διαχείριση οικονομικών: έσοδα, έξοδα, μεταφορές, προϋπολογισμοί,
προγραμματισμένες κινήσεις, γραφήματα και στατιστικά. Ελληνικό UI, Material 3,
ανοιχτό/σκοτεινό θέμα, offline-first με Firebase.

Έκδοση εφαρμογής: **2.3.7+14** (`pubspec.yaml` — μοναδική πηγή της έκδοσης, επαληθεύτηκε 24/11/2026).

---

## Λειτουργίες

- **Λογαριασμοί** με υπόλοιπα, διπλότυπα-έλεγχο ονομάτων και επαναφορά διαγραμμένων
- **Κατηγορίες / υποκατηγορίες** εσόδων-εξόδων με 276 εικονίδια, **tags**
- **Συναλλαγές** με πρόσημο ποσού· **μεταφορές** ως ζεύγος εγγραφών (`transfer_group_id`)
- **Προϋπολογισμοί** (total / κατηγορίας / υποκατηγορίας) με όριο υπέρβασης και ειδοποίηση
- **Προγραμματισμένες κινήσεις** με αυτόματη εκτέλεση στην εκκίνηση και περιοδικό έλεγχο
- **7 γραφήματα** (έσοδα/έξοδα, κατηγορίες εσόδων, κατηγορίες εξόδων, υποκατηγορίες, υπόλοιπα λογαριασμών, μηνιαία πορεία, προβολή κινήσεων)
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
| Windows | ✅ Επιβεβαιωμένο **μόνο** με VS 2026 18.1.1 + SDK 10.0.26100· ❌ στο τρέχον μηχάνημα (VS 2022 17.10.1 + SDK 10.0.22621 → LNK2019) |
| Web | ✅ Επιβεβαιωμένο |
| iOS / macOS / Linux | ⚠️ Ο φάκελος υπάρχει, αλλά **χωρίς `Podfile`** → build μη επιβεβαιωμένο |

Λεπτομέρειες build ανά πλατφόρμα: [`DESIGN.md` §2](DESIGN.md).

---

## Τεχνολογίες

Flutter **3.50.1** / Dart **3.14.0** (μετρημένο 24/11/2026), Firebase (Auth,
Cloud Firestore), Provider / `ChangeNotifier`, `flutter_local_notifications`,
`fl_chart`, `local_auth`, `pdf` / `excel`.

Resolved εκδόσεις πακέτων, αρχιτεκτονική, Firestore schema και περιορισμοί:
[`DESIGN.md`](DESIGN.md) (μοναδική πηγή τεχνικής αλήθειας).

---

## Προαπαιτούμενα

- Flutter SDK (stable) — το `environment.sdk: ^3.10.4` του `pubspec.yaml`
  είναι **constraint της Dart**, όχι έκδοση Flutter
- Για Android build: Android SDK 36 · Java **17** (target) · **JDK 21 ή 22** στο CLI (και τα δύο επαληθευμένα) · Gradle **9.5.0** / AGP **9.3.1** / Kotlin **2.4.20**
- Για Windows build: Visual Studio **2026 18.1.1** + Windows SDK **10.0.26100** (βλ. `DESIGN.md` §2.5)
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
flutter analyze     # αναμενόμενο: 0 errors/warnings (72 info deprecations)
flutter test        # αναμενόμενο: 238/238
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
- Παράγει `InstallerOutput\FamilyBudgetSetup_v<ver>.exe` (Inno Setup, `fam_eco_new.iss`)
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
| [`oldsessions.md`](oldsessions.md) | Ιστορικό: ευρετήριο κεφαλαίων (+ φάκελος [`oldsessions/`](oldsessions/)) |
| [`error_list.md`](error_list.md) | Ευρήματα & εκκρεμότητες: κατάσταση και σειρά διόρθωσης |
| `docs/` | Legacy περιγραφές schema (import script) |
| `data/*.json` | Δεδομένα εισαγωγής |

Καθημερινές εντολές και quality gates: `AGENTS.md`.
