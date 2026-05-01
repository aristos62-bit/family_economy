// ============================================================
// FILE: onboarding_service.dart
// Path: lib/services/onboarding_service.dart
// Ρόλος: First-time initialization με default data
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:family_economy/core/utils/debug_config.dart';

typedef OnboardingProgressCallback = void Function(
    double progress,
    String message,
    );

class OnboardingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  Future<void> checkAndRunOnboarding(
      String userId, {
        OnboardingProgressCallback? onProgress,
      }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      var userData = userDoc.data();

      if (userData == null) {
        DebugConfig.print('⚠️ User document not found. Creating it now...');

        await _firestore.collection('users').doc(userId).set({
          'default_currency': 'EUR',
          'onboarding_completed': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, SetOptions(merge: true));

        final retryDoc = await _firestore.collection('users').doc(userId).get();
        userData = retryDoc.data();
      }

      final onboardingCompleted =
          (userData?['onboarding_completed'] as bool?) ?? false;


      if (onboardingCompleted) {
        DebugConfig.print('✅ Onboarding already completed - skipping');
        return;
      }

      DebugConfig.print('🚀 Starting first-time onboarding...');

      onProgress?.call(0.15, 'Δημιουργία κύριου λογαριασμού…');
      await _createDefaultAccount(userId);

      onProgress?.call(0.30, 'Δημιουργία κατηγοριών…');
      await _createDefaultCategories(userId, onProgress: onProgress);

      await _firestore.collection('users').doc(userId).update({
        'onboarding_completed': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      DebugConfig.print('✅ Onboarding completed successfully!');
      onProgress?.call(1.0, 'Η βάση σας είναι έτοιμη!');
    } catch (e) {
      DebugConfig.print('❌ Error in onboarding: $e');
      rethrow;
    }
  }

  Future<void> _createDefaultAccount(String userId) async {
    final now = DateTime.now();
    final accountUuid = _uuid.v4();

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .doc(accountUuid)
        .set({
      'user_id': userId,
      'name': 'Κύριος Λογαριασμός',
      'initial_balance': 0.0,
      'current_balance': 0.0,
      'currency': 'EUR',
      'account_type': 'bank',
      'icon_index': 0,
      'color': '#2196F3',
      'is_active': true,
      'display_order': 1,
      'created_at': Timestamp.fromDate(now),
      'updated_at': Timestamp.fromDate(now),
      'deleted': false,
    });

    DebugConfig.print('✅ Default account created');
  }

  Future<void> _createDefaultCategories(
      String userId, {
        OnboardingProgressCallback? onProgress,
      }) async {
    final now = DateTime.now();

    // ============================================================
    // INCOME: Categories + ALL Subcategories
    // ============================================================

    final incomeCategories = [
      {
        'name': 'Μισθοί',
        'icon_index': 0,
        'subcategories': [
          {'name': 'Εργασία', 'icon_index': 0},
          {'name': 'Εργασία 2', 'icon_index': 1},
          {'name': 'Υπερωρίες', 'icon_index': 2},
          {'name': 'Bonus', 'icon_index': 3},
          {'name': 'Εκτός Έδρας', 'icon_index': 4},
        ],
      },
      {
        'name': 'Συντάξεις',
        'icon_index': 1,
        'subcategories': [
          {'name': 'Σύνταξη', 'icon_index': 5},
          {'name': 'Επικουρική', 'icon_index': 6},
          {'name': 'Αναπηρική', 'icon_index': 7},
          {'name': 'Έκτακτα', 'icon_index': 8},
          {'name': 'Επιδόματα', 'icon_index': 9},
        ],
      },
      {
        'name': 'Επιχείρηση',
        'icon_index': 2,
        'subcategories': [
          {'name': 'Έσοδα Επιχείρησης', 'icon_index': 10},
          {'name': 'Δίδακτρα', 'icon_index': 11},
          {'name': 'Μεροκάματα', 'icon_index': 12},
          {'name': 'Προκαταβολές', 'icon_index': 13},
        ],
      },
      {
        'name': 'Άλλα Έσοδα',
        'icon_index': 3,
        'subcategories': [
          {'name': 'Ενοίκια', 'icon_index': 14},
          {'name': 'Τόκοι', 'icon_index': 15},
          {'name': 'Βοηθήματα', 'icon_index': 16},
          {'name': 'Δάνεια', 'icon_index': 17},
          {'name': 'Μετοχές', 'icon_index': 18},
          {'name': 'Crypto', 'icon_index': 19},
          {'name': 'Επιστροφές', 'icon_index': 20},
        ],
      },
      {
        'name': 'Μετρητά',
        'icon_index': 4,
        'subcategories': [
          {'name': 'Χωρίς Υποκατηγορία', 'icon_index': 21},
        ],
      },
      {
        'name': 'Επιδόματα',
        'icon_index': 5,
        'subcategories': [
          {'name': 'Δημοσίου', 'icon_index': 22},
          {'name': 'Αναπηρικά', 'icon_index': 23},
        ],
      },
    ];

    int displayOrder = 1;

    final incomeTotalCats = incomeCategories.length;
    for (int incomeIdx = 0; incomeIdx < incomeCategories.length; incomeIdx++) {
      final cat = incomeCategories[incomeIdx];
      onProgress?.call(0.30 + (incomeIdx / incomeTotalCats) * 0.30, "Κατηγορία εσόδων: ${cat['name']}");
      final categoryUuid = _uuid.v4();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(categoryUuid)
          .set({
        'user_id': userId,
        'name': cat['name'],
        'type': 'income',
        'icon_index': cat['icon_index'],
        'color': '#4CAF50',
        'is_system': false,
        'hidden': false,
        'display_order': displayOrder++,
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
        'deleted': false,
      });

      final subcats = (cat['subcategories'] as List);
      int subOrder = 1;

      for (final sc in subcats) {
        final subcategoryUuid = _uuid.v4();

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('categories')
            .doc(categoryUuid)
            .collection('subcategories')
            .doc(subcategoryUuid)
            .set({
          'user_id': userId,
          'category_id': categoryUuid,
          'name': sc['name'],
          'icon_index': sc['icon_index'],
          'color': '#81C784',
          'is_system': false,
          'hidden': false,
          'display_order': subOrder++,
          'created_at': Timestamp.fromDate(now),
          'updated_at': Timestamp.fromDate(now),
          'deleted': false,
        });

        DebugConfig.print('✅ Income category: ${cat['name']} → ${sc['name']}');
      }
    }

    // ============================================================
    // EXPENSE: Categories + ALL Subcategories
    // ============================================================

    final expenseCategories = [
      {
        'name': 'Διατροφή',
        'icon_index': 0,
        'subcategories': [
          {'name': 'Χωρίς Κατηγορία', 'icon_index': 0},
          {'name': 'Σούπερ Μάρκετ', 'icon_index': 1},
          {'name': 'Πολυκαταστήματα', 'icon_index': 2},
          {'name': 'Delivery', 'icon_index': 3},
          {'name': 'Εστιατόρια', 'icon_index': 4},
          {'name': 'Αρτοποιεία', 'icon_index': 5},
          {'name': 'Ζαχαροπλαστεία', 'icon_index': 6},
          {'name': 'Κρεοπωλεία', 'icon_index': 7},
          {'name': 'Ιχθυοπωλεία', 'icon_index': 8},
          {'name': 'Κάβες', 'icon_index': 9},
          {'name': 'Παραγωγοί', 'icon_index': 10},
          {'name': 'Άλλο', 'icon_index': 11},
        ],
      },
      {
        'name': 'Στέγαση',
        'icon_index': 1,
        'subcategories': [
          {'name': 'Χωρίς Κατηγορία', 'icon_index': 12},
          {'name': 'Ασφάλεια', 'icon_index': 13},
          {'name': 'Ενοίκιο', 'icon_index': 14},
          {'name': 'Θέρμανση', 'icon_index': 15},
          {'name': 'Καθαριότητα', 'icon_index': 16},
          {'name': 'Κοινόχρηστα', 'icon_index': 17},
          {'name': 'ΔΕΚΟ', 'icon_index': 18},
          {'name': 'Συνδρομές', 'icon_index': 19},
          {'name': 'Συντήρηση', 'icon_index': 20},
          {'name': 'Τηλεφωνία / Internet', 'icon_index': 21},
          {'name': 'Δόσεις', 'icon_index': 22},
          {'name': 'Άλλο', 'icon_index': 23},
        ],
      },
      {
        'name': 'Μεταφορές',
        'icon_index': 2,
        'subcategories': [
          {'name': 'Χωρίς Κατηγορία', 'icon_index': 24},
          {'name': 'Καύσιμα', 'icon_index': 25},
          {'name': 'Service', 'icon_index': 26},
          {'name': 'Ασφάλειες', 'icon_index': 27},
          {'name': 'Εισιτήρια', 'icon_index': 28},
          {'name': 'Ενοικίαση', 'icon_index': 29},
          {'name': 'ΚΤΕΟ', 'icon_index': 30},
          {'name': 'Κλήσεις', 'icon_index': 31},
          {'name': 'Στάθμευση', 'icon_index': 32},
          {'name': 'Ταξιδιωτικά', 'icon_index': 33},
          {'name': 'Τέλη', 'icon_index': 34},
          {'name': 'Άλλο', 'icon_index': 35},
        ],
      },
      {
        'name': 'Υγεία',
        'icon_index': 3,
        'subcategories': [
          {'name': 'Χωρίς Κατηγορία', 'icon_index': 36},
          {'name': 'Θεραπείες', 'icon_index': 37},
          {'name': 'Γιατροί', 'icon_index': 38},
          {'name': 'Εργαστήρια', 'icon_index': 39},
          {'name': 'Προϊόντα Υγείας', 'icon_index': 40},
          {'name': 'Ατομική Υγιεινή', 'icon_index': 41},
          {'name': 'Υγειονομικό Υλικό', 'icon_index': 42},
          {'name': 'Οικιακές Υπηρεσίες', 'icon_index': 43},
          {'name': 'Φάρμακα', 'icon_index': 44},
          {'name': 'Άλλο', 'icon_index': 45},
        ],
      },
      {
        'name': 'Παιδιά',
        'icon_index': 4,
        'subcategories': [
          {'name': 'Χωρίς Κατηγορία', 'icon_index': 46},
          {'name': 'Εκπαίδευση', 'icon_index': 47},
          {'name': 'Δραστηριότητες', 'icon_index': 48},
          {'name': 'Ιδιωτική εκπαίδευση', 'icon_index': 49},
          {'name': 'Παιδική φροντίδα', 'icon_index': 50},
          {'name': 'Σχολικά είδη', 'icon_index': 51},
          {'name': 'Χαρτζιλίκι', 'icon_index': 52},
          {'name': 'Άλλο', 'icon_index': 53},
        ],
      },
      {
        'name': 'Διασκέδαση',
        'icon_index': 5,
        'subcategories': [
          {'name': 'Χωρίς Κατηγορία', 'icon_index': 54},
          {'name': 'Έξοδοι', 'icon_index': 55},
          {'name': 'Τύπος', 'icon_index': 56},
          {'name': 'Δώρα', 'icon_index': 57},
          {'name': 'Θεάματα', 'icon_index': 58},
          {'name': 'Πολυκαταστήματα', 'icon_index': 59},
          {'name': 'Άλλο', 'icon_index': 60},
        ],
      },
      {
        'name': 'Ένδυση',
        'icon_index': 6,
        'subcategories': [
          {'name': 'Χωρίς Κατηγορία', 'icon_index': 61},
          {'name': 'Ρούχα', 'icon_index': 62},
          {'name': 'Υπόδηση', 'icon_index': 63},
          {'name': 'Καθαριστήριο', 'icon_index': 64},
          {'name': 'Άλλο', 'icon_index': 65},
        ],
      },
      {
        'name': 'Οικιακά',
        'icon_index': 7,
        'subcategories': [
          {'name': 'Χωρίς Κατηγορία', 'icon_index': 66},
          {'name': 'Είδη καθαρισμού', 'icon_index': 67},
          {'name': 'Έπιπλα', 'icon_index': 68},
          {'name': 'Εξοπλισμός', 'icon_index': 69},
          {'name': 'Άλλο', 'icon_index': 70},
        ],
      },
    ];

    displayOrder = 1;

    final expenseTotalCats = expenseCategories.length;
    for (int expIdx = 0; expIdx < expenseCategories.length; expIdx++) {
      final cat = expenseCategories[expIdx];
      onProgress?.call(0.60 + (expIdx / expenseTotalCats) * 0.37, "Κατηγορία εξόδων: ${cat['name']}");
      final categoryUuid = _uuid.v4();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(categoryUuid)
          .set({
        'user_id': userId,
        'name': cat['name'],
        'type': 'expense',
        'icon_index': cat['icon_index'],
        'color': '#F44336',
        'is_system': false,
        'hidden': false,
        'display_order': displayOrder++,
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
        'deleted': false,
      });

      final subcats = (cat['subcategories'] as List);
      int subOrder = 1;

      for (final sc in subcats) {
        final subcategoryUuid = _uuid.v4();

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('categories')
            .doc(categoryUuid)
            .collection('subcategories')
            .doc(subcategoryUuid)
            .set({
          'user_id': userId,
          'category_id': categoryUuid,
          'name': sc['name'],
          'icon_index': sc['icon_index'],
          'color': '#E57373',
          'is_system': false,
          'hidden': false,
          'display_order': subOrder++,
          'created_at': Timestamp.fromDate(now),
          'updated_at': Timestamp.fromDate(now),
          'deleted': false,
        });

        DebugConfig.print('✅ Expense category: ${cat['name']} → ${sc['name']}');
      }
    }
  }

}