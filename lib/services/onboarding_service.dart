// ============================================================
// FILE: onboarding_service.dart
// Path: lib/services/onboarding_service.dart
// Ρόλος: First-time initialization με default data
// ============================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:family_economy/core/data/onboarding_defaults.dart';
import 'package:family_economy/core/utils/debug_config.dart';

typedef OnboardingProgressCallback = void Function(
    double progress,
    String message,
    );

/// E5/2Α: Το onboarding δεν γράφει τίποτα χωρίς επιβεβαιωμένη σύνδεση.
/// Το μήνυμα είναι ορατό στον χρήστη και η είσοδος συνεχίζει κανονικά.
class OnboardingOfflineException implements Exception {
  static const String userMessage =
      'Χωρίς σύνδεση στο internet δεν μπορούν να δημιουργηθούν τα βασικά '
      'δεδομένα. Θα δημιουργηθούν αυτόματα στην επόμενη σύνδεση.';

  const OnboardingOfflineException();

  @override
  String toString() => userMessage;
}

/// E5: snapshot μιας κατηγορίας όπως διαβάστηκε από τον server.
class _CategorySnapshot {
  final String categoryId;
  final Set<String> subNames;
  final Set<String> subIds;

  const _CategorySnapshot({
    required this.categoryId,
    required this.subNames,
    required this.subIds,
  });
}

class OnboardingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Πόσο περιμένουμε τον server πριν θεωρήσουμε ότι είμαστε offline.
  static const Duration _serverTimeout = Duration(seconds: 8);

  Future<void> checkAndRunOnboarding(
      String userId, {
        OnboardingProgressCallback? onProgress,
      }) async {
    try {
      // E5 gate (επίπεδο 2): η αλήθεια είναι ΠΑΝΤΑ ο server. Αν δεν απαντήσει,
      // δεν γίνεται καμία εγγραφή (OnboardingOfflineException).
      var userData = await _readUserDataFromServer(userId);

      if (userData == null) {
        DebugConfig.print('⚠️ User document not found. Creating it now...');

        // F6: Timestamp (όχι ISO string) — ίδιος τύπος με `auth_service.dart`.
        final now = Timestamp.now();
        final initialData = <String, dynamic>{
          'default_currency': 'EUR',
          'onboarding_completed': false,
          'created_at': now,
          'updated_at': now,
        };
        await _firestore
            .collection('users')
            .doc(userId)
            .set(initialData, SetOptions(merge: true));
        userData = initialData;
      }

      final onboardingCompleted =
          (userData['onboarding_completed'] as bool?) ?? false;

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
        'updated_at': Timestamp.now(),
      });

      DebugConfig.print('✅ Onboarding completed successfully!');
      onProgress?.call(1.0, 'Η βάση σας είναι έτοιμη!');
    } on OnboardingOfflineException {
      DebugConfig.print('📴 Onboarding skipped: no server confirmation');
      rethrow;
    } catch (e) {
      DebugConfig.print('❌ Error in onboarding: $e');
      rethrow;
    }
  }

  /// E5 gate: διαβάζει το user document **από τον server** με timeout.
  /// Offline ή μη έγκυρη απάντηση → `OnboardingOfflineException` (καμία εγγραφή).
  Future<Map<String, dynamic>?> _readUserDataFromServer(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get(const GetOptions(source: Source.server))
          .timeout(_serverTimeout);
      return doc.data();
    } on TimeoutException {
      throw const OnboardingOfflineException();
    } on FirebaseException catch (e) {
      if (_isOfflineCode(e.code)) {
        throw const OnboardingOfflineException();
      }
      rethrow;
    }
  }

  /// E5: query πάντα με `Source.server` (όχι stale cache) + timeout.
  Future<QuerySnapshot<Map<String, dynamic>>> _serverQuery(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query
          .get(const GetOptions(source: Source.server))
          .timeout(_serverTimeout);
    } on TimeoutException {
      throw const OnboardingOfflineException();
    } on FirebaseException catch (e) {
      if (_isOfflineCode(e.code)) {
        throw const OnboardingOfflineException();
      }
      rethrow;
    }
  }

  static bool _isOfflineCode(String? code) {
    return code == 'unavailable' ||
        code == 'deadline-exceeded' ||
        code == 'network-request-failed';
  }

  Future<void> _createDefaultAccount(String userId) async {
    // ✅ Idempotency από τον server: αν υπάρχει ήδη έστω ένας λογαριασμός
    // (legacy random id ή διακοπέν onboarding), μη δημιουργήσεις δεύτερο.
    final existingAccounts = await _serverQuery(
      _firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .limit(1),
    );

    if (existingAccounts.docs.isNotEmpty) {
      DebugConfig.print('✅ Default account already exists — skipping');
      return;
    }

    final now = DateTime.now();

    // E5: σταθερό id → δύο συσκευές γράφουν το ίδιο document.
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .doc(OnboardingDefaults.defaultAccountId)
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
    }, SetOptions(merge: true));

    DebugConfig.print('✅ Default account created');
  }

  /// ✅ E5: idempotency από τον server — map `type|name` → snapshot με το
  /// υπάρχον category id και τα υπάρχοντα subcategory names/ids. Έτσι το
  /// onboarding που ξανατρέχει (ή δεύτερη συσκευή) δεν δημιουργεί διπλές
  /// κατηγορίες και δεν πατάει μετονομασμένα documents.
  Future<Map<String, _CategorySnapshot>> _existingCategoryState(
      String userId) async {
    final snap = await _serverQuery(
      _firestore
          .collection('users')
          .doc(userId)
          .collection('categories'),
    );

    final result = <String, _CategorySnapshot>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final subs =
          await _serverQuery(doc.reference.collection('subcategories'));
      result['${data['type']}|${data['name']}'] = _CategorySnapshot(
        categoryId: doc.id,
        subNames: {
          for (final s in subs.docs)
            if (s.data()['name'] is String) s.data()['name'] as String,
        },
        subIds: {for (final s in subs.docs) s.id},
      );
    }
    return result;
  }

  Future<void> _createDefaultCategories(
      String userId, {
        OnboardingProgressCallback? onProgress,
      }) async {
    final now = DateTime.now();
    final existingState = await _existingCategoryState(userId);
    final usedCategoryIds = {
      for (final snapshot in existingState.values) snapshot.categoryId,
    };

    // ============================================================
    // INCOME: Categories + ALL Subcategories
    // ============================================================

    final incomeCategories = [
      for (final category in OnboardingDefaults.incomeCategories)
        {
          'name': category.name,
          'icon_index': category.iconIndex,
          'subcategories': [
            for (final sub in category.subcategories)
              {'name': sub.name, 'icon_index': sub.iconIndex},
          ],
        },
    ];

    final incomeTotalCats = incomeCategories.length;
    for (int incomeIdx = 0; incomeIdx < incomeCategories.length; incomeIdx++) {
      final cat = incomeCategories[incomeIdx];
      onProgress?.call(0.30 + (incomeIdx / incomeTotalCats) * 0.30, "Κατηγορία εσόδων: ${cat['name']}");

      final state = existingState['income|${cat['name']}'];
      final existingSubNames = state?.subNames ?? const <String>{};
      // E5: σταθερό id. Αν το id χρησιμοποιείται ήδη από άλλη (πιθανώς
      // μετονομασμένη) κατηγορία, δεν την πατάμε — νέο uuid.
      final deterministicCategoryId =
          OnboardingDefaults.categoryId('income', incomeIdx);
      final categoryUuid = state?.categoryId ??
          (usedCategoryIds.contains(deterministicCategoryId)
              ? _uuid.v4()
              : deterministicCategoryId);

      if (state == null) {
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
          'display_order': incomeIdx + 1,
          'created_at': Timestamp.fromDate(now),
          'updated_at': Timestamp.fromDate(now),
          'deleted': false,
        });
      } else {
        DebugConfig.print(
            '✅ Income category exists: ${cat['name']} — έλεγχος subcategories');
      }

      final subcats = (cat['subcategories'] as List);

      for (int subIdx = 0; subIdx < subcats.length; subIdx++) {
        final sc = subcats[subIdx];
        final subName = sc['name'] as String;
        if (existingSubNames.contains(subName)) {
          continue;
        }
        // E5: σταθερό id. Αν το id ανήκει ήδη σε άλλο (πιθανώς
        // μετονομασμένο) document, δεν το πατάμε — νέο uuid.
        final deterministicSubId = OnboardingDefaults.subcategoryId(subIdx);
        final subcategoryUuid =
            (state?.subIds.contains(deterministicSubId) ?? false)
                ? _uuid.v4()
                : deterministicSubId;

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
          'display_order': subIdx + 1,
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
      for (final category in OnboardingDefaults.expenseCategories)
        {
          'name': category.name,
          'icon_index': category.iconIndex,
          'subcategories': [
            for (final sub in category.subcategories)
              {'name': sub.name, 'icon_index': sub.iconIndex},
          ],
        },
    ];

    final expenseTotalCats = expenseCategories.length;
    for (int expIdx = 0; expIdx < expenseCategories.length; expIdx++) {
      final cat = expenseCategories[expIdx];
      onProgress?.call(0.60 + (expIdx / expenseTotalCats) * 0.37, "Κατηγορία εξόδων: ${cat['name']}");

      final state = existingState['expense|${cat['name']}'];
      final existingSubNames = state?.subNames ?? const <String>{};
      // E5: ίδιος guard με τα έσοδα (κατηγορία που μετονομάστηκε).
      final deterministicCategoryId =
          OnboardingDefaults.categoryId('expense', expIdx);
      final categoryUuid = state?.categoryId ??
          (usedCategoryIds.contains(deterministicCategoryId)
              ? _uuid.v4()
              : deterministicCategoryId);

      if (state == null) {
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
          'display_order': expIdx + 1,
          'created_at': Timestamp.fromDate(now),
          'updated_at': Timestamp.fromDate(now),
          'deleted': false,
        });
      } else {
        DebugConfig.print(
            '✅ Expense category exists: ${cat['name']} — έλεγχος subcategories');
      }

      final subcats = (cat['subcategories'] as List);

      for (int subIdx = 0; subIdx < subcats.length; subIdx++) {
        final sc = subcats[subIdx];
        final subName = sc['name'] as String;
        if (existingSubNames.contains(subName)) {
          continue;
        }
        // E5: σταθερό id. Αν το id ανήκει ήδη σε άλλο (πιθανώς
        // μετονομασμένο) document, δεν το πατάμε — νέο uuid.
        final deterministicSubId = OnboardingDefaults.subcategoryId(subIdx);
        final subcategoryUuid =
            (state?.subIds.contains(deterministicSubId) ?? false)
                ? _uuid.v4()
                : deterministicSubId;

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
          'display_order': subIdx + 1,
          'created_at': Timestamp.fromDate(now),
          'updated_at': Timestamp.fromDate(now),
          'deleted': false,
        });

        DebugConfig.print('✅ Expense category: ${cat['name']} → ${sc['name']}');
      }
    }
  }

}