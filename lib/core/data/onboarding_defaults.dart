// ============================================================
// FILE: onboarding_defaults.dart
// Path: lib/core/data/onboarding_defaults.dart
// Ρόλος: Default δεδομένα first-time onboarding με σταθερά doc ids (E5).
// Καθαρό Dart: καμία εξάρτηση από Firebase, ώστε να ελέγχεται
// με unit tests χωρίς mocks (ίδιο σκεπτικό με το schema.dart).
// ============================================================

/// Υποκατηγορία default κατηγορίας.
class OnboardingSubcategory {
  final String name;
  final int iconIndex;

  const OnboardingSubcategory(this.name, this.iconIndex);
}

/// Default κατηγορία με τις υποκατηγορίες της.
class OnboardingCategory {
  final String name;
  final int iconIndex;
  final List<OnboardingSubcategory> subcategories;

  const OnboardingCategory({
    required this.name,
    required this.iconIndex,
    required this.subcategories,
  });
}

/// Σταθερά ids + default δεδομένα του onboarding.
///
/// Τα ids είναι **σταθερά** (όχι τυχαία) ώστε δύο συσκευές που τρέχουν
/// onboarding με stale cache να γράψουν στο **ίδιο** document (E5).
/// Δεν συγκρούονται με υπάρχοντα ids: τα docs της εφαρμογής είναι
/// uuid v4 (36 χαρακτήρες) ή Firestore auto-ids (20 χαρακτήρες).
class OnboardingDefaults {
  OnboardingDefaults._();

  static const String defaultAccountId = 'default-account';
  static const String transferCategoryId = 'cat-transfer';

  static const String incomeColor = '#4CAF50';
  static const String incomeSubcategoryColor = '#81C784';
  static const String expenseColor = '#F44336';
  static const String expenseSubcategoryColor = '#E57373';

  /// `cat-income-1…6` / `cat-expense-1…8`.
  static String categoryId(String type, int index) => 'cat-$type-${index + 1}';

  /// `sub-1…n` — μοναδικό **μέσα** στη συλλογή υποκατηγοριών του γονέα.
  static String subcategoryId(int index) => 'sub-${index + 1}';

  // ============================================================
  // INCOME: 6 κατηγορίες / 24 υποκατηγορίες
  // ============================================================

  static const List<OnboardingCategory> incomeCategories = [
    OnboardingCategory(
      name: 'Μισθοί',
      iconIndex: 0,
      subcategories: [
        OnboardingSubcategory('Εργασία', 0),
        OnboardingSubcategory('Εργασία 2', 1),
        OnboardingSubcategory('Υπερωρίες', 2),
        OnboardingSubcategory('Bonus', 3),
        OnboardingSubcategory('Εκτός Έδρας', 4),
      ],
    ),
    OnboardingCategory(
      name: 'Συντάξεις',
      iconIndex: 1,
      subcategories: [
        OnboardingSubcategory('Σύνταξη', 5),
        OnboardingSubcategory('Επικουρική', 6),
        OnboardingSubcategory('Αναπηρική', 7),
        OnboardingSubcategory('Έκτακτα', 8),
        OnboardingSubcategory('Επιδόματα', 9),
      ],
    ),
    OnboardingCategory(
      name: 'Επιχείρηση',
      iconIndex: 2,
      subcategories: [
        OnboardingSubcategory('Έσοδα Επιχείρησης', 10),
        OnboardingSubcategory('Δίδακτρα', 11),
        OnboardingSubcategory('Μεροκάματα', 12),
        OnboardingSubcategory('Προκαταβολές', 13),
      ],
    ),
    OnboardingCategory(
      name: 'Άλλα Έσοδα',
      iconIndex: 3,
      subcategories: [
        OnboardingSubcategory('Ενοίκια', 14),
        OnboardingSubcategory('Τόκοι', 15),
        OnboardingSubcategory('Βοηθήματα', 16),
        OnboardingSubcategory('Δάνεια', 17),
        OnboardingSubcategory('Μετοχές', 18),
        OnboardingSubcategory('Crypto', 19),
        OnboardingSubcategory('Επιστροφές', 20),
      ],
    ),
    OnboardingCategory(
      name: 'Μετρητά',
      iconIndex: 4,
      subcategories: [
        OnboardingSubcategory('Χωρίς Υποκατηγορία', 21),
      ],
    ),
    OnboardingCategory(
      name: 'Επιδόματα',
      iconIndex: 5,
      subcategories: [
        OnboardingSubcategory('Δημοσίου', 22),
        OnboardingSubcategory('Αναπηρικά', 23),
      ],
    ),
  ];

  // ============================================================
  // EXPENSE: 8 κατηγορίες / 71 υποκατηγορίες
  // ============================================================

  static const List<OnboardingCategory> expenseCategories = [
    OnboardingCategory(
      name: 'Διατροφή',
      iconIndex: 0,
      subcategories: [
        OnboardingSubcategory('Χωρίς Κατηγορία', 0),
        OnboardingSubcategory('Σούπερ Μάρκετ', 1),
        OnboardingSubcategory('Πολυκαταστήματα', 2),
        OnboardingSubcategory('Delivery', 3),
        OnboardingSubcategory('Εστιατόρια', 4),
        OnboardingSubcategory('Αρτοποιεία', 5),
        OnboardingSubcategory('Ζαχαροπλαστεία', 6),
        OnboardingSubcategory('Κρεοπωλεία', 7),
        OnboardingSubcategory('Ιχθυοπωλεία', 8),
        OnboardingSubcategory('Κάβες', 9),
        OnboardingSubcategory('Παραγωγοί', 10),
        OnboardingSubcategory('Άλλο', 11),
      ],
    ),
    OnboardingCategory(
      name: 'Στέγαση',
      iconIndex: 1,
      subcategories: [
        OnboardingSubcategory('Χωρίς Κατηγορία', 12),
        OnboardingSubcategory('Ασφάλεια', 13),
        OnboardingSubcategory('Ενοίκιο', 14),
        OnboardingSubcategory('Θέρμανση', 15),
        OnboardingSubcategory('Καθαριότητα', 16),
        OnboardingSubcategory('Κοινόχρηστα', 17),
        OnboardingSubcategory('ΔΕΚΟ', 18),
        OnboardingSubcategory('Συνδρομές', 19),
        OnboardingSubcategory('Συντήρηση', 20),
        OnboardingSubcategory('Τηλεφωνία / Internet', 21),
        OnboardingSubcategory('Δόσεις', 22),
        OnboardingSubcategory('Άλλο', 23),
      ],
    ),
    OnboardingCategory(
      name: 'Μεταφορές',
      iconIndex: 2,
      subcategories: [
        OnboardingSubcategory('Χωρίς Κατηγορία', 24),
        OnboardingSubcategory('Καύσιμα', 25),
        OnboardingSubcategory('Service', 26),
        OnboardingSubcategory('Ασφάλειες', 27),
        OnboardingSubcategory('Εισιτήρια', 28),
        OnboardingSubcategory('Ενοικίαση', 29),
        OnboardingSubcategory('ΚΤΕΟ', 30),
        OnboardingSubcategory('Κλήσεις', 31),
        OnboardingSubcategory('Στάθμευση', 32),
        OnboardingSubcategory('Ταξιδιωτικά', 33),
        OnboardingSubcategory('Τέλη', 34),
        OnboardingSubcategory('Άλλο', 35),
      ],
    ),
    OnboardingCategory(
      name: 'Υγεία',
      iconIndex: 3,
      subcategories: [
        OnboardingSubcategory('Χωρίς Κατηγορία', 36),
        OnboardingSubcategory('Θεραπείες', 37),
        OnboardingSubcategory('Γιατροί', 38),
        OnboardingSubcategory('Εργαστήρια', 39),
        OnboardingSubcategory('Προϊόντα Υγείας', 40),
        OnboardingSubcategory('Ατομική Υγιεινή', 41),
        OnboardingSubcategory('Υγειονομικό Υλικό', 42),
        OnboardingSubcategory('Οικιακές Υπηρεσίες', 43),
        OnboardingSubcategory('Φάρμακα', 44),
        OnboardingSubcategory('Άλλο', 45),
      ],
    ),
    OnboardingCategory(
      name: 'Παιδιά',
      iconIndex: 4,
      subcategories: [
        OnboardingSubcategory('Χωρίς Κατηγορία', 46),
        OnboardingSubcategory('Εκπαίδευση', 47),
        OnboardingSubcategory('Δραστηριότητες', 48),
        OnboardingSubcategory('Ιδιωτική εκπαίδευση', 49),
        OnboardingSubcategory('Παιδική φροντίδα', 50),
        OnboardingSubcategory('Σχολικά είδη', 51),
        OnboardingSubcategory('Χαρτζιλίκι', 52),
        OnboardingSubcategory('Άλλο', 53),
      ],
    ),
    OnboardingCategory(
      name: 'Διασκέδαση',
      iconIndex: 5,
      subcategories: [
        OnboardingSubcategory('Χωρίς Κατηγορία', 54),
        OnboardingSubcategory('Έξοδοι', 55),
        OnboardingSubcategory('Τύπος', 56),
        OnboardingSubcategory('Δώρα', 57),
        OnboardingSubcategory('Θεάματα', 58),
        OnboardingSubcategory('Πολυκαταστήματα', 59),
        OnboardingSubcategory('Άλλο', 60),
      ],
    ),
    OnboardingCategory(
      name: 'Ένδυση',
      iconIndex: 6,
      subcategories: [
        OnboardingSubcategory('Χωρίς Κατηγορία', 61),
        OnboardingSubcategory('Ρούχα', 62),
        OnboardingSubcategory('Υπόδηση', 63),
        OnboardingSubcategory('Καθαριστήριο', 64),
        OnboardingSubcategory('Άλλο', 65),
      ],
    ),
    OnboardingCategory(
      name: 'Οικιακά',
      iconIndex: 7,
      subcategories: [
        OnboardingSubcategory('Χωρίς Κατηγορία', 66),
        OnboardingSubcategory('Είδη καθαρισμού', 67),
        OnboardingSubcategory('Έπιπλα', 68),
        OnboardingSubcategory('Εξοπλισμός', 69),
        OnboardingSubcategory('Άλλο', 70),
      ],
    ),
  ];
}
