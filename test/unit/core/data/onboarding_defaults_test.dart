// ============================================================
// FILE: onboarding_defaults_test.dart
// Path: test/unit/core/data/onboarding_defaults_test.dart
// Ρόλος: Επαλήθευση σταθερών ids και default δεδομένων onboarding (E5).
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:family_economy/core/data/onboarding_defaults.dart';

void main() {
  // ============================================================
  // ΣΤΑΘΕΡΑ IDS
  // ============================================================
  group('OnboardingDefaults ids', () {
    test('default account id is stable and not a uuid', () {
      expect(OnboardingDefaults.defaultAccountId, 'default-account');
      expect(OnboardingDefaults.defaultAccountId.length, lessThan(36));
    });

    test('transfer category id is stable', () {
      expect(OnboardingDefaults.transferCategoryId, 'cat-transfer');
    });

    test('categoryId uses 1-based numbering', () {
      expect(OnboardingDefaults.categoryId('income', 0), 'cat-income-1');
      expect(OnboardingDefaults.categoryId('income', 5), 'cat-income-6');
      expect(OnboardingDefaults.categoryId('expense', 0), 'cat-expense-1');
      expect(OnboardingDefaults.categoryId('expense', 7), 'cat-expense-8');
    });

    test('subcategoryId uses 1-based numbering', () {
      expect(OnboardingDefaults.subcategoryId(0), 'sub-1');
      expect(OnboardingDefaults.subcategoryId(23), 'sub-24');
      expect(OnboardingDefaults.subcategoryId(70), 'sub-71');
    });
  });

  // ============================================================
  // ΠΛΗΘΗ
  // ============================================================
  group('OnboardingDefaults counts', () {
    test('6 income categories', () {
      expect(OnboardingDefaults.incomeCategories.length, 6);
    });

    test('8 expense categories', () {
      expect(OnboardingDefaults.expenseCategories.length, 8);
    });

    test('24 income subcategories', () {
      final total = OnboardingDefaults.incomeCategories
          .fold<int>(0, (sum, cat) => sum + cat.subcategories.length);
      expect(total, 24);
    });

    test('71 expense subcategories', () {
      final total = OnboardingDefaults.expenseCategories
          .fold<int>(0, (sum, cat) => sum + cat.subcategories.length);
      expect(total, 71);
    });

    test('95 subcategories in total', () {
      final income = OnboardingDefaults.incomeCategories
          .fold<int>(0, (sum, cat) => sum + cat.subcategories.length);
      final expense = OnboardingDefaults.expenseCategories
          .fold<int>(0, (sum, cat) => sum + cat.subcategories.length);
      expect(income + expense, 95);
    });
  });

  // ============================================================
  // ΜΟΝΑΔΙΚΟΤΗΤΑ IDS
  // ============================================================
  group('OnboardingDefaults id uniqueness', () {
    test('income category ids are unique', () {
      final ids = <String>{
        for (int i = 0; i < OnboardingDefaults.incomeCategories.length; i++)
          OnboardingDefaults.categoryId('income', i),
      };
      expect(ids.length, OnboardingDefaults.incomeCategories.length);
    });

    test('expense category ids are unique', () {
      final ids = <String>{
        for (int i = 0; i < OnboardingDefaults.expenseCategories.length; i++)
          OnboardingDefaults.categoryId('expense', i),
      };
      expect(ids.length, OnboardingDefaults.expenseCategories.length);
    });

    test('subcategory ids are unique inside each category', () {
      final all = [
        ...OnboardingDefaults.incomeCategories,
        ...OnboardingDefaults.expenseCategories,
      ];

      for (final category in all) {
        final ids = <String>{
          for (int i = 0; i < category.subcategories.length; i++)
            OnboardingDefaults.subcategoryId(i),
        };
        expect(
          ids.length,
          category.subcategories.length,
          reason: 'Διπλό id στις υποκατηγορίες της «${category.name}»',
        );
      }
    });

    test('category ids never collide with transfer category id', () {
      final ids = <String>[
        for (int i = 0; i < OnboardingDefaults.incomeCategories.length; i++)
          OnboardingDefaults.categoryId('income', i),
        for (int i = 0; i < OnboardingDefaults.expenseCategories.length; i++)
          OnboardingDefaults.categoryId('expense', i),
      ];
      expect(ids.contains(OnboardingDefaults.transferCategoryId), isFalse);
    });
  });

  // ============================================================
  // ΠΕΡΙΕΧΟΜΕΝΟ
  // ============================================================
  group('OnboardingDefaults content', () {
    test('all category names are non-empty', () {
      for (final category in [
        ...OnboardingDefaults.incomeCategories,
        ...OnboardingDefaults.expenseCategories,
      ]) {
        expect(category.name.trim(), isNotEmpty);
        expect(category.subcategories, isNotEmpty);
      }
    });

    test('all subcategory names are non-empty', () {
      for (final category in [
        ...OnboardingDefaults.incomeCategories,
        ...OnboardingDefaults.expenseCategories,
      ]) {
        for (final sub in category.subcategories) {
          expect(sub.name.trim(), isNotEmpty);
        }
      }
    });

    test('icon indices are never negative', () {
      for (final category in [
        ...OnboardingDefaults.incomeCategories,
        ...OnboardingDefaults.expenseCategories,
      ]) {
        expect(category.iconIndex, greaterThanOrEqualTo(0));
        for (final sub in category.subcategories) {
          expect(sub.iconIndex, greaterThanOrEqualTo(0));
        }
      }
    });

    test('income and expense category icon indices are sequential', () {
      for (int i = 0; i < OnboardingDefaults.incomeCategories.length; i++) {
        expect(OnboardingDefaults.incomeCategories[i].iconIndex, i);
      }
      for (int i = 0; i < OnboardingDefaults.expenseCategories.length; i++) {
        expect(OnboardingDefaults.expenseCategories[i].iconIndex, i);
      }
    });

    test('colors match the current onboarding values', () {
      expect(OnboardingDefaults.incomeColor, '#4CAF50');
      expect(OnboardingDefaults.incomeSubcategoryColor, '#81C784');
      expect(OnboardingDefaults.expenseColor, '#F44336');
      expect(OnboardingDefaults.expenseSubcategoryColor, '#E57373');
    });
  });
}
