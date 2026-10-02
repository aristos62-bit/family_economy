# Family Economy

Οικογενειακή διαχείριση οικονομικών — έσοδα, έξοδα, μεταφορές, προϋπολογισμοί,
προγραμματισμένες κινήσεις, γραφήματα και στατιστικά. Ελληνικό UI, Material 3,
ανοιχτό/σκοτεινό θέμα, offline-first με Firebase.

## Λειτουργίες

- Λογαριασμοί με υπόλοιπα (αποκλειστική ενημέρωση μέσω `TransactionsActionsService`)
- Κατηγορίες / υποκατηγορίες εσόδων-εξόδων, tags
- Προϋπολογισμοί (total / κατηγορίας / υποκατηγορίας) με in-memory υπολογισμό δαπανών
- Προγραμματισμένες (μελλοντικές) κινήσεις με αυτόματη εκτέλεση
- Γραφήματα: έσοδα/έξοδα, κατηγορίες, υποκατηγορίες, υπόλοιπα, πορεία ανά μήνα, προβολή κινήσεων
- Στατιστικά, ημερολόγιο, παρακολούθηση πετρελαίου, μετατροπέας μονάδων, εξαγωγές PDF/Excel
- Ειδοποιήσεις (τοπικές + επαναλαμβανόμενες), βιομετρικό ξεκλείδωμα

## Τεχνολογίες

Flutter 3.10 / Dart 3.10, Firebase (Auth, Cloud Firestore), Provider,
`flutter_local_notifications`, `fl_chart`, `pdf`/`excel`. Λεπτομέρειες στο
[DESIGN.md](DESIGN.md).

## Προαπαιτούμενα

- Flutter SDK ^3.10.4, JDK 21 (`flutter config --jdk-dir`)
- Firebase project με `firebase_options.dart`, κανόνες από `firestore.rules`
  και indexes από `firestore.indexes.json`

## Setup

```sh
flutter pub get
flutter analyze
flutter test
```

Εκτέλεση / build:

```sh
flutter run -d windows
flutter run -d chrome
flutter build windows
```

## Δομή

Η αρχιτεκτονική (layers, Firestore schema, flows) περιγράφεται στο
[DESIGN.md](DESIGN.md). Η πρόοδος ανά session στο [oldsessions.md](oldsessions.md).
