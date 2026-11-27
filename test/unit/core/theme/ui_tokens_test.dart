// ============================================================
// FILE: ui_tokens_test.dart
// Path: test/unit/core/theme/ui_tokens_test.dart
// Ρόλος: Έλεγχος του δημόσιου contrastRatio (E67 / L11).
// Καθαρό Dart — χωρίς widgets.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:family_economy/core/theme/ui_tokens.dart';

void main() {
  group('ColorsUI.contrastRatio — E67', () {
    test('λευκό/μαύρο = 21', () {
      expect(
        ColorsUI.contrastRatio(Colors.white, Colors.black),
        closeTo(21.0, 0.01),
      );
    });

    test('ίδιο χρώμα = 1', () {
      expect(
        ColorsUI.contrastRatio(ColorsUI.primaryLight, ColorsUI.primaryLight),
        closeTo(1.0, 0.001),
      );
    });

    test('είναι συμμετρικό', () {
      final a = ColorsUI.getWarning(Brightness.light);
      final b = ColorsUI.textPrimaryDark;
      expect(
        ColorsUI.contrastRatio(a, b),
        closeTo(ColorsUI.contrastRatio(b, a), 0.0001),
      );
    });

    test('το warning light δεν περνά 4.5:1 με λευκό (τεκμηρίωση E67)', () {
      final warning = ColorsUI.getWarning(Brightness.light);
      expect(ColorsUI.contrastRatio(Colors.white, warning), lessThan(4.5));
    });
  });
}
