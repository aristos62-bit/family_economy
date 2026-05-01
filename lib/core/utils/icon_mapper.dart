// ============================================
// 1. ICON MAPPING CLASS
// ============================================
// Βάλε αυτό σε ξεχωριστό αρχείο: lib/utils/icon_mapper.dart

class IconMapper {
  // Default εικόνες
  static const String defaultAccount = 'default_account.webp';
  static const String defaultCategory = 'default_categories.webp';
  static const String defaultSubcategory = 'default_subcategories.webp';

  // Επιστρέφει UI fallback icon path (αν χαθεί το asset)
  static String getFallbackUI(String type, {String? categoryType}) {
    switch (type) {
      case 'account':
        return 'assets/icons/accounts/$defaultAccount';

      case 'category':
        return categoryType == 'income'
            ? 'assets/icons/categories/income/$defaultCategory'
            : 'assets/icons/categories/expense/$defaultCategory';

      case 'subcategory':
        return categoryType == 'income'
            ? 'assets/icons/subcategories/income/$defaultSubcategory'
            : 'assets/icons/subcategories/expense/$defaultSubcategory';

      default:
        return 'assets/icons/default.webp';
    }
  }

  // Βοηθητική μέθοδος: ασφαλής ανάγνωση από Map<int, String>
  static String _getFromMap(Map<int, String> map, int? index, String fallback) {
    if (index == null) return fallback;
    return map[index] ?? fallback;
  }

  static int get accountIconsCount => accountIcons.length;
  // Mapping για Λογαριασμούς
  static const Map<int, String> accountIcons = {
    0: 'bank.webp',
    1: 'wallet.webp',
    2: 'cash.webp',
    3: 'credit_card.webp',
    4: 'savings.webp',
    71: 'account1.webp',
    72: 'account2.webp',
    73: 'account3.webp',
    74: 'account5.webp',
    75: 'account6.webp',
    76: 'default_account.webp',
    77: 'credit_cards.webp',
  };

  // Mapping για Κατηγορίες Εσόδων
  static const Map<int, String> incomeCategoryIcons = {
    0: 'salary.webp', // Μισθοί
    1: 'pension.webp', // Συντάξεις
    2: 'business.webp', // Επιχείρηση
    3: 'other_income.webp', // Άλλα Έσοδα
    4: 'cash_income.webp', // Μετρητά
    5: 'allowance.webp', // Επιδόματα
    78: 'default_categories.webp',
    79: 'no_subcategory.webp',
    80: 'refund.webp',
    81: 'hammer.webp',
    82: 'travel_allowance.webp',
    83: 'traveling.webp',
    84: 'traveling2.webp',
    85: 'traveling3.webp',
    86: 'truck.webp',
    87: 'work_2.webp',
  };

  // Mapping για Κατηγορίες Εξόδων
  static const Map<int, String> expenseCategoryIcons = {
    0: 'food.webp', // Διατροφή
    1: 'housing.webp', // Στέγαση
    2: 'transport.webp', // Μεταφορές
    3: 'health.webp', // Υγεία
    4: 'kids.webp', // Παιδιά
    5: 'entertainment.webp', // Διασκέδαση
    6: 'clothing.webp', // Ένδυση - Υπόδηση
    7: 'household.webp', // Οικιακά
    88: 'default_categories.webp',
    89: 'dry_cleaning2.webp',
    90:'good_health.webp',
    91: 'good_health2.webp',
    92: 'gym.webp',
    93: 'gym2.webp',
    94: 'hair.webp',
    95: 'home_care1.webp',
    96: 'cleaning0.webp',
    97: 'loan.webp',
    98: 'medical_supplies0.webp',
    99: 'no_subcategory.webp',
    100: 'phone_internet0.webp',
    101: 'super3.webp',
    102: 'travel2.webp',
    103: 'travel5.webp',
    104: 'traveling.webp',
    105: 'traveling2.webp',
    106: 'traveling3.webp',
    107 :'vehicle_fees1.webp',
    108: 'wine_shop8.webp',
    145: 'food.webp',
    146: 'farmer.webp',
  };

  // Mapping για Υποκατηγορίες Εσόδων
  static const Map<int, String> incomeSubcategoryIcons = {
    // Μισθοί (category_id: 1)
    0: 'work.webp', // Εργασία
    1: 'work_2.webp', // Εργασία 2
    2: 'overtime.webp', // Υπερωρίες
    3: 'bonus.webp', // Bonus
    4: 'travel_allowance.webp', // Εκτός Έδρας
    // Συντάξεις (category_id: 2)
    5: 'pension_main.webp', // Σύνταξη
    6: 'pension_supplementary.webp', // Επικουρική
    7: 'pension_disability.webp', // Αναπηρική
    8: 'pension_extra.webp', // Εκτακτα
    9: 'pension_benefits.webp', // Επιδόματα
    // Επιχείρηση (category_id: 3)
    10: 'business_income.webp', // Έσοδα Επιχείρησης
    11: 'tuition.webp', // Δίδακτρα
    12: 'daily_wages.webp', // Μεροκάματα
    13: 'advance.webp', // Προκαταβολές
    // Άλλα Έσοδα (category_id: 4)
    14: 'rent_income.webp', // Ενοίκια
    15: 'interest.webp', // Τόκοι
    16: 'benefits.webp', // Βηθήματα
    17: 'loan.webp', // Δάνεια
    18: 'stocks.webp', // Μετοχές
    19: 'crypto.webp', // Crypto
    20: 'refund.webp', // Επιστροφές
    // Μετρητά (category_id: 5)
    21: 'no_subcategory.webp', // Χωρις Υποκατηγορία
    // Επιδόματα (category_id: 6)
    22: 'public_benefits.webp', // Δημοσίου
    23: 'disability_benefits.webp', // Αναπηρικά
    109: 'business_income.webp',
    110: 'credit_cards.webp',
    111: 'credit_cards2.webp',
    112: 'crypto7.webp',
    113: 'crypto8.webp',
    116: 'default_subcategories.webp',
    117: 'delivery-truck.webp',
    118: 'hammer.webp',
    119: 'kids-r.webp',
    120: 'pension_benefits.webp',
    121: 'rent_income.webp',
    122: 'stocks.webp',
    123: 'truck.webp',


  };

  // Mapping για Υποκατηγορίες Εξόδων
  static const Map<int, String> expenseSubcategoryIcons = {
    // Διατροφή (category_id: 7)
    0: 'no_category.webp', // Χωρίς Κατηγορία
    1: 'supermarket.webp', // Σούπερ Μάρκετ
    2: 'department_store.webp', // Πολυκαταστήματα
    3: 'delivery.webp', // Delivery
    4: 'restaurant.webp', // Εστιατορια
    5: 'bakery.webp', // Αρτοποιεία
    6: 'pastry.webp', // Ζαχαροπλαστεία
    7: 'butcher.webp', // Κρεοπωλεία
    8: 'fish_market.webp', // Ιχθυοπωλεία
    9: 'wine_shop.webp', // Κάβες
    10: 'farmers_market.webp', // Παραγωγοί
    11: 'other_food.webp', // Άλλο
    // Στέγαση (category_id: 8)
    12: 'no_category_housing.webp', // Χωρίς Κατηγορία
    13: 'insurance.webp', // Ασφάλεια
    14: 'rent.webp', // Ενοίκιο
    15: 'heating.webp', // Θέρμανση
    16: 'cleaning.webp', // Καθαριότητα
    17: 'common_expenses.webp', // Κοινόχρηστα
    18: 'utilities.webp', // ΔΕΚΟ
    19: 'subscriptions.webp', // Συνδρομές
    20: 'maintenance.webp', // Συντήρηση
    21: 'phone_internet.webp', // Τηλεφωνία
    22: 'installments.webp', // Δόσεις
    23: 'other_housing.webp', // Άλλο
    // Μεταφορές (category_id: 9)
    24: 'no_category_transport.webp', // Χωρίς Κατηγορία
    25: 'fuel.webp', // Καύσιμα
    26: 'service.webp', // Service
    27: 'car_insurance.webp', // Ασφάλειες
    28: 'tickets.webp', // Εισητήρια
    29: 'car_rental.webp', // Ενοικίαση
    30: 'inspection.webp', // ΚΤΕΟ
    31: 'fines.webp', // Κλήσεις
    32: 'parking.webp', // Στάθμευση
    33: 'travel.webp', // Ταξιδιωτικά
    34: 'vehicle_fees.webp', // Τέλη
    35: 'other_transport.webp', // Άλλο
    // Υγεία (category_id: 10)
    36: 'no_category_health.webp', // Χωρίς Κατηγορία
    37: 'treatments.webp', // Θεραπείες
    38: 'doctors.webp', // Γιατροί
    39: 'labs.webp', // Εργαστήρια
    40: 'health_products.webp', // Προϊόντα Υγείας
    41: 'personal_hygiene.webp', // Ατομική Υγιεινή
    42: 'medical_supplies.webp', // Υγειονομικό Υλικό
    43: 'home_care.webp', // Οικιακές Υπηρεσίες
    44: 'pharmacy.webp', // Φάρμακα
    45: 'other_health.webp', // Άλλο
    // Παιδιά (category_id: 11)
    46: 'no_category_kids.webp', // Χωρίς Κατηγορία
    47: 'education.webp', // Εκπαίδευση
    48: 'activities.webp', // Δραστηριότητες
    49: 'private_education.webp', // Ιδιωτική εκπαίδευση
    50: 'childcare.webp', // Παιδική φροντίδα
    51: 'school_supplies.webp', // Σχολικά είδη
    52: 'allowance_kids.webp', // Χαρτζιλίκι
    53: 'other_kids.webp', // Άλλο
    // Διασκέδαση (category_id: 12)
    54: 'no_category_entertainment.webp', // Χωρίς Κατηγορία
    55: 'going_out.webp', // Έξοδοι
    56: 'press.webp', // Τύπος
    57: 'gifts.webp', // Δώρα
    58: 'shows.webp', // Θεάματα
    59: 'department_store_ent.webp', // Πολυκαταστήματα
    60: 'other_entertainment.webp', // Άλλο
    // Ένδυση - Υπόδηση (category_id: 13)
    61: 'no_category_clothing.webp', // Χωρίς Κατηγορία
    62: 'clothes.webp', // Ένδυση
    63: 'shoes.webp', // Υπόδηση
    64: 'dry_cleaning.webp', // Καθαριστήριο
    65: 'other_clothing.webp', // Άλλο
    // Οικιακά (category_id: 14)
    66: 'no_category_household.webp', // Χωρίς Κατηγορία
    67: 'cleaning_supplies.webp', // Είδη καθαρισμού
    68: 'furniture.webp', // Έπιπλα
    69: 'equipment.webp', // Εξοπλισμός
    70: 'other_household.webp', // Άλλο
    // rest icons
    124:'no_category_transpor6.webp',
    125: 'no_category_health4.webp',
    126: 'department_store_ent.webp',
    127: 'department_store3.webp',
    128: 'delivery4.webp',
    129: 'delivery2.webp',
    130: 'restaurant7.webp',
    131: 'restaurant3.webp',
    132: 'restaurant2.webp',
    1333: 'bakery2.webp',
    134: 'bakery1.webp',
    135: 'pastry8.webp',
    136: 'pastry1.webp',
    137: 'butcher9.webp',
    138: 'fish_market9.webp',
    139: 'fish_market3.webp',
    140: 'wine_shop8.webp',
    141: 'wine_shop7.webp',
    142: 'farmers_market8.webp',
    143: 'farmers_market7.webp',
    144: 'farmers_market4.webp',
    147: 'agricole.webp',
    148: 'agricole2.webp',
    149: 'agricole3.webp',
    150: 'agricole4.webp',
    151: 'good_health.webp',
    152: 'good_health2.webp',
    153: 'gym.webp',
    154: 'gym2.webp',
    155: 'hair.webp',
    156: 'health.webp',
       };

  // Μέθοδος για να παίρνεις το σωστό path
  static String getIconPath(
    String type,
    int? iconIndex, {
    String? categoryType,
  }) {
    switch (type) {
      case 'account':
        return 'assets/icons/accounts/'
            '${_getFromMap(accountIcons, iconIndex, defaultAccount)}';

      case 'category':
        final isIncome = categoryType == 'income';
        final map = isIncome ? incomeCategoryIcons : expenseCategoryIcons;
        final folder = isIncome ? 'income' : 'expense';

        return 'assets/icons/categories/$folder/'
            '${_getFromMap(map, iconIndex, defaultCategory)}';

      case 'subcategory':
        final isIncome = categoryType == 'income';
        final map = isIncome ? incomeSubcategoryIcons : expenseSubcategoryIcons;
        final folder = isIncome ? 'income' : 'expense';

        return 'assets/icons/subcategories/$folder/'
            '${_getFromMap(map, iconIndex, defaultSubcategory)}';

      default:
        return 'assets/icons/default.webp';
    }
  }
}
