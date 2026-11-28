// ============================================================
// FILE: password_change_policy_test.dart
// Path: test/unit/core/utils/password_change_policy_test.dart
// Ρόλος: E93 — ο κωδικός χρησιμοποιείται πάντα ως έχει (χωρίς trim).
// ============================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:family_economy/core/utils/password_change_policy.dart';

void main() {
  group('PasswordChangePolicy.validateChange — E93', () {
    test('κενά στις άκρες διατηρούνται σε όλα τα πεδία', () {
      expect(
        PasswordChangePolicy.validateChange(
          current: ' oldpass ',
          next: ' newpass1 ',
          confirm: ' newpass1 ',
        ),
        isNull,
      );
    });

    test('η επιβεβαίωση συγκρίνεται ως έχει (όχι trimmed)', () {
      expect(
        PasswordChangePolicy.validateChange(
          current: 'oldpass',
          next: 'newpass1 ',
          confirm: 'newpass1',
        ),
        PasswordChangePolicy.confirmMismatchMessage,
      );
    });

    test('το μήκος μετριέται στο raw κείμενο', () {
      // 6 χαρακτήρες raw (5 κενά + «a»)· με trim θα ήταν 1 και θα αποτύγχανε.
      expect(
        PasswordChangePolicy.validateChange(
          current: 'oldpass',
          next: '     a',
          confirm: '     a',
        ),
        isNull,
      );
    });

    test('πεδίο με μόνο κενά θεωρείται κενό', () {
      expect(
        PasswordChangePolicy.validateChange(
          current: '   ',
          next: 'newpass1',
          confirm: 'newpass1',
        ),
        PasswordChangePolicy.currentEmptyMessage,
      );
      expect(
        PasswordChangePolicy.validateChange(
          current: 'oldpass',
          next: '      ',
          confirm: '      ',
        ),
        PasswordChangePolicy.newEmptyMessage,
      );
    });

    test('ο ίδιος κωδικός με τον τρέχοντα συγκρίνεται raw', () {
      expect(
        PasswordChangePolicy.validateChange(
          current: 'pass 1',
          next: 'pass 1',
          confirm: 'pass 1',
        ),
        PasswordChangePolicy.sameAsCurrentMessage,
      );
    });

    test('σύντομος νέος κωδικός απορρίπτεται', () {
      expect(
        PasswordChangePolicy.validateChange(
          current: 'oldpass',
          next: '12345',
          confirm: '12345',
        ),
        PasswordChangePolicy.newTooShortMessage,
      );
    });
  });

  group('PasswordChangePolicy — login validators', () {
    test('κενό ή μόνο κενά → «Υποχρεωτικός κωδικός»', () {
      expect(
        PasswordChangePolicy.validateLoginPassword(null),
        PasswordChangePolicy.loginPasswordEmptyMessage,
      );
      expect(
        PasswordChangePolicy.validateLoginPassword('   '),
        PasswordChangePolicy.loginPasswordEmptyMessage,
      );
    });

    test('το μήκος μετριέται στο raw κείμενο', () {
      expect(PasswordChangePolicy.validateLoginPassword('     a'), isNull);
      expect(
        PasswordChangePolicy.validateLoginPassword('12345'),
        PasswordChangePolicy.loginPasswordTooShortMessage,
      );
    });

    test('η επιβεβαίωση εγγραφής δέχεται κενά ως μέρος κωδικού', () {
      expect(PasswordChangePolicy.validateConfirmPassword(' pass '), isNull);
      expect(
        PasswordChangePolicy.validateConfirmPassword('   '),
        PasswordChangePolicy.confirmPasswordEmptyMessage,
      );
    });
  });

  group('E93 source guard — κανένα trim σε password', () {
    const files = <String>[
      'lib/presentation/auth/login_page.dart',
      'lib/presentation/screens/options/change_password_page.dart',
    ];

    const forbidden = <String>[
      '_passwordController.text.trim()',
      '_confirmPassController.text.trim()',
      '_currentCtrl.text.trim()',
      '_newCtrl.text.trim()',
      '_confirmCtrl.text.trim()',
    ];

    test('δεν υπάρχει .text.trim() σε password controllers', () {
      for (final path in files) {
        final source = File(path).readAsStringSync();
        for (final pattern in forbidden) {
          expect(
            source.contains(pattern),
            isFalse,
            reason: '$path περιέχει $pattern',
          );
        }
      }
    });

    test('το login περνά raw κωδικό στην υπηρεσία', () {
      final source = File(
        'lib/presentation/auth/login_page.dart',
      ).readAsStringSync();
      expect(
        source.contains('final password = _passwordController.text;'),
        isTrue,
      );
      expect(
        source.contains('final confirmPassword = _confirmPassController.text;'),
        isTrue,
      );
    });

    test('η αλλαγή κωδικού χρησιμοποιεί την policy', () {
      final source = File(
        'lib/presentation/screens/options/change_password_page.dart',
      ).readAsStringSync();
      expect(source.contains('PasswordChangePolicy.validateChange('), isTrue);
    });
  });
}
