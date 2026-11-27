// ============================================================
// FILE: l11_guard_test.dart
// Path: test/unit/core/messaging/l11_guard_test.dart
// Ρόλος: Guard του L11 (D10).
// - Κανένα άμεσο SnackBar έξω από το app_messenger.dart.
// - Κανένα raw σφάλμα σε Text/content/label/hintText.
// Στενός έλεγχος ανά γραμμή· logging και σχόλια εξαιρούνται.
// ============================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Σημεία όπου το κείμενο φτάνει στον χρήστη.
final RegExp _uiSink = RegExp(r'\bText\(|content:|label:|hintText:');

/// Raw interpolation σφάλματος: `$e`, `${e}`, `${e.toString()}`,
/// `$error`, `${error.toString()}`.
final RegExp _rawError = RegExp(
  r'\$(?:e|error)\b|\$\{(?:e|error)(?:\.toString\(\))?\}',
);

/// Γραμμές που δεν ελέγχονται: σχόλια και logging.
bool _isIgnored(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('//') ||
      trimmed.contains('DebugConfig.print') ||
      trimmed.contains('debugPrint(');
}

void main() {
  final dartFiles =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('κανένα άμεσο SnackBar έξω από το app_messenger.dart', () {
    final violations = <String>[];

    for (final file in dartFiles) {
      if (file.path.endsWith('app_messenger.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_isIgnored(line)) continue;
        if (line.contains('SnackBar(')) {
          violations.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('κανένα raw σφάλμα σε Text/content/label/hintText', () {
    final violations = <String>[];

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_isIgnored(line)) continue;
        if (!_uiSink.hasMatch(line)) continue;
        if (_rawError.hasMatch(line)) {
          violations.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
