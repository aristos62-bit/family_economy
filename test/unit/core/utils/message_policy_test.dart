// ============================================================
// FILE: message_policy_test.dart
// Path: test/unit/core/utils/message_policy_test.dart
// Ρόλος: Έλεγχος της κεντρικής πολιτικής μηνυμάτων (L11).
// Καθαρό Dart — χωρίς Firebase / widgets.
// ============================================================

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:family_economy/core/errors/user_message_exception.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/message_policy.dart';

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('MessagePolicy — χρόνοι', () {
    test('success/info 3s, warning 5s, error 6s', () {
      expect(
        MessagePolicy.durationFor(MessageKind.success),
        const Duration(seconds: 3),
      );
      expect(
        MessagePolicy.durationFor(MessageKind.info),
        const Duration(seconds: 3),
      );
      expect(
        MessagePolicy.durationFor(MessageKind.warning),
        const Duration(seconds: 5),
      );
      expect(
        MessagePolicy.durationFor(MessageKind.error),
        const Duration(seconds: 6),
      );
    });

    test('το duration override κερδίζει τον default', () {
      final spec = MessagePolicy.build(
        MessageKind.error,
        'x',
        Brightness.light,
        duration: const Duration(seconds: 7),
      );
      expect(spec.duration, const Duration(seconds: 7));
    });
  });

  group('MessagePolicy — χρώματα', () {
    test('semantic background (light)', () {
      expect(
        MessagePolicy.backgroundFor(MessageKind.success, Brightness.light),
        ColorsUI.getSuccess(Brightness.light),
      );
      expect(
        MessagePolicy.backgroundFor(MessageKind.info, Brightness.light),
        ColorsUI.getInfo(Brightness.light),
      );
      expect(
        MessagePolicy.backgroundFor(MessageKind.warning, Brightness.light),
        ColorsUI.getWarning(Brightness.light),
      );
      expect(
        MessagePolicy.backgroundFor(MessageKind.error, Brightness.light),
        ColorsUI.getError(Brightness.light),
      );
    });

    test('semantic background (dark)', () {
      expect(
        MessagePolicy.backgroundFor(MessageKind.success, Brightness.dark),
        ColorsUI.getSuccess(Brightness.dark),
      );
      expect(
        MessagePolicy.backgroundFor(MessageKind.info, Brightness.dark),
        ColorsUI.getInfo(Brightness.dark),
      );
      expect(
        MessagePolicy.backgroundFor(MessageKind.warning, Brightness.dark),
        ColorsUI.getWarning(Brightness.dark),
      );
      expect(
        MessagePolicy.backgroundFor(MessageKind.error, Brightness.dark),
        ColorsUI.getError(Brightness.dark),
      );
    });

    test('foreground >= 4.5:1 για κάθε τύπο και brightness', () {
      for (final kind in MessageKind.values) {
        for (final brightness in Brightness.values) {
          final background = MessagePolicy.backgroundFor(kind, brightness);
          final foreground = MessagePolicy.foregroundFor(background);
          expect(
            _contrast(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: '$kind / $brightness',
          );
          expect(foreground, anyOf(Colors.black, Colors.white));
        }
      }
    });
  });

  group('MessagePolicy — εικονίδια', () {
    test('κάθε τύπος έχει το δικό του εικονίδιο', () {
      expect(
        MessagePolicy.iconFor(MessageKind.success),
        Icons.check_circle_outline,
      );
      expect(MessagePolicy.iconFor(MessageKind.info), Icons.info_outline);
      expect(
        MessagePolicy.iconFor(MessageKind.warning),
        Icons.warning_amber_rounded,
      );
      expect(MessagePolicy.iconFor(MessageKind.error), Icons.error_outline);
    });
  });

  group('MessagePolicy — persist', () {
    test('χωρίς action → false', () {
      final spec = MessagePolicy.build(
        MessageKind.info,
        'x',
        Brightness.light,
      );
      expect(spec.persist, isFalse);
    });

    test('με action → true (default)', () {
      final spec = MessagePolicy.build(
        MessageKind.info,
        'x',
        Brightness.light,
        hasAction: true,
      );
      expect(spec.persist, isTrue);
    });

    test('persist:false κερδίζει το action', () {
      final spec = MessagePolicy.build(
        MessageKind.info,
        'x',
        Brightness.light,
        hasAction: true,
        persist: false,
      );
      expect(spec.persist, isFalse);
    });

    test('persist:true χωρίς action', () {
      final spec = MessagePolicy.build(
        MessageKind.info,
        'x',
        Brightness.light,
        persist: true,
      );
      expect(spec.persist, isTrue);
    });
  });

  group('MessagePolicy — πλάτος', () {
    test('360 και 600 → null, 601 → 560', () {
      expect(MessagePolicy.widthFor(360), isNull);
      expect(MessagePolicy.widthFor(600), isNull);
      expect(MessagePolicy.widthFor(601), 560);
    });
  });

  group('MessagePolicy — κείμενα σφαλμάτων', () {
    test('actionError', () {
      expect(
        MessagePolicy.actionError('αποθήκευσης'),
        'Αποτυχία αποθήκευσης. Δοκιμάστε ξανά.',
      );
    });

    test('build συνθέτει σωστά το spec', () {
      final spec = MessagePolicy.build(
        MessageKind.warning,
        'Προσοχή',
        Brightness.light,
        hasAction: true,
      );
      expect(spec.text, 'Προσοχή');
      expect(spec.kind, MessageKind.warning);
      expect(spec.background, ColorsUI.getWarning(Brightness.light));
      expect(spec.foreground, MessagePolicy.foregroundFor(spec.background));
      expect(spec.icon, Icons.warning_amber_rounded);
      expect(spec.duration, const Duration(seconds: 5));
      expect(spec.persist, isTrue);
    });

    test('fromError: UserMessageException περνά αυτούσιο', () {
      expect(
        MessagePolicy.fromError(
          const UserMessageException('Λάθος email ή κωδικός.'),
          action: 'σύνδεσης',
        ),
        'Λάθος email ή κωδικός.',
      );
    });

    test('fromError: τεχνικό σφάλμα → generic', () {
      expect(
        MessagePolicy.fromError(StateError('boom'), action: 'σύνδεσης'),
        'Αποτυχία σύνδεσης. Δοκιμάστε ξανά.',
      );
      expect(
        MessagePolicy.fromError(TypeError(), action: 'φόρτωσης'),
        'Αποτυχία φόρτωσης. Δοκιμάστε ξανά.',
      );
    });

    test('fromError: κενό UserMessageException → generic', () {
      expect(
        MessagePolicy.fromError(
          const UserMessageException('   '),
          action: 'αποθήκευσης',
        ),
        'Αποτυχία αποθήκευσης. Δοκιμάστε ξανά.',
      );
    });

    test('fromProvider: κενό όνομα περνά', () {
      expect(
        MessagePolicy.fromProvider(
          'Το όνομα του tag δεν μπορεί να είναι κενό',
          action: 'δημιουργίας',
        ),
        'Το όνομα του tag δεν μπορεί να είναι κενό',
      );
    });

    test('fromProvider: duplicate περνά', () {
      expect(
        MessagePolicy.fromProvider(
          'Το tag "Ενοίκιο" υπάρχει ήδη',
          action: 'δημιουργίας',
        ),
        'Το tag "Ενοίκιο" υπάρχει ήδη',
      );
    });

    test('fromProvider: null → generic', () {
      expect(
        MessagePolicy.fromProvider(null, action: 'φόρτωσης'),
        'Αποτυχία φόρτωσης. Δοκιμάστε ξανά.',
      );
    });

    test('fromProvider: τεχνικό → generic', () {
      expect(
        MessagePolicy.fromProvider('Missing userId', action: 'φόρτωσης'),
        'Αποτυχία φόρτωσης. Δοκιμάστε ξανά.',
      );
      expect(
        MessagePolicy.fromProvider(
          'Exception: FirebaseException(permission-denied)',
          action: 'ενημέρωσης',
        ),
        'Αποτυχία ενημέρωσης. Δοκιμάστε ξανά.',
      );
    });
  });
}