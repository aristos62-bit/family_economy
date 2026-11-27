// ============================================================
// FILE: ui_tokens_test.dart
// Path: test/unit/core/theme/ui_tokens_test.dart
// Ρόλος: Έλεγχος του δημόσιου contrastRatio + getAccessibleTextColor (E67 / L11).
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

  group('ColorsUI.getAccessibleTextColor — E67', () {
    test('λευκό φόντο → σκούρο token του theme, ≥ 4.5:1', () {
      final fg = ColorsUI.getAccessibleTextColor(Colors.white);
      expect(fg, ColorsUI.textPrimaryLight);
      expect(
        ColorsUI.contrastRatio(fg, Colors.white),
        greaterThanOrEqualTo(ColorsUI.minContrastRatio),
      );
    });

    test('μαύρο φόντο → ανοιχτό token του theme, ≥ 4.5:1', () {
      final fg = ColorsUI.getAccessibleTextColor(Colors.black);
      expect(fg, ColorsUI.textPrimaryDark);
      expect(
        ColorsUI.contrastRatio(fg, Colors.black),
        greaterThanOrEqualTo(ColorsUI.minContrastRatio),
      );
    });

    test('warning light: το παλιό threshold έδινε < 4.5:1 — τώρα περνά', () {
      final warning = ColorsUI.getWarning(Brightness.light);
      final fg = ColorsUI.getAccessibleTextColor(warning);
      expect(
        ColorsUI.contrastRatio(fg, warning),
        greaterThanOrEqualTo(ColorsUI.minContrastRatio),
      );
    });

    test('μεσαίο γκρι: κανένα token δεν αρκεί → fallback black/white', () {
      const mid = Color(0xFF777777);
      expect(
        ColorsUI.contrastRatio(ColorsUI.textPrimaryLight, mid),
        lessThan(ColorsUI.minContrastRatio),
      );
      expect(
        ColorsUI.contrastRatio(ColorsUI.textPrimaryDark, mid),
        lessThan(ColorsUI.minContrastRatio),
      );

      final fg = ColorsUI.getAccessibleTextColor(mid);
      expect(fg == Colors.black || fg == Colors.white, isTrue);
      expect(
        ColorsUI.contrastRatio(fg, mid),
        greaterThanOrEqualTo(ColorsUI.minContrastRatio),
      );
    });

    test('sweep 256 αποχρώσεων γκρι: πάντα ≥ 4.5:1', () {
      for (var v = 0; v <= 255; v++) {
        final bg = Color.fromARGB(255, v, v, v);
        final fg = ColorsUI.getAccessibleTextColor(bg);
        expect(
          ColorsUI.contrastRatio(fg, bg),
          greaterThanOrEqualTo(ColorsUI.minContrastRatio),
          reason: 'gray $v',
        );
      }
    });
  });
}
