// ============================================================
// FILE: l11_guard_test.dart
// Path: test/unit/core/messaging/l11_guard_test.dart
// Ρόλος: Guard του L11 (D10).
// - Κανένα άμεσο SnackBar έξω από το app_messenger.dart.
// - Κανένα raw σφάλμα σε Text/content/label/hintText.
// - E82: raw σφάλμα και μέσω μεταβλητής (taint tracking), `.error` unwrapped.
// Στενός έλεγχος ανά sink/block· logging και σχόλια εξαιρούνται.
// ============================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Σημεία όπου το κείμενο φτάνει στον χρήστη.
final RegExp _uiSink = RegExp(r'\bText\(|content:|label:|hintText:');

/// Raw interpolation/μετατροπή σφάλματος:
/// `$e`, `$error`, `${e}`, `${e.toString()}`, `e.toString()`,
/// `${provider.error}`, `snapshot.error`, `snapshot.error.toString()`.
final RegExp _rawError = RegExp(
  r'\$(?:\{)?(?:e|error|exception)(?:\.toString\(\))?\}?'
  r'|(?<![A-Za-z0-9_])(?:e|error|exception)\.toString\(\)'
  r'|\$\{[^}]*\.error\b[^}]*\}'
  r'|\b\w*(?:Provider|provider|Snapshot|snapshot|State|state)\.error\b'
  r'|\.error\.toString\(\)',
);

/// Raw έκφραση στη δεξιά πλευρά ανάθεσης (για taint tracking).
final RegExp _rawExpression = RegExp(
  r'(?<![A-Za-z0-9_])(?:e|error|exception)\.toString\(\)'
  r'|\$(?:\{)?(?:e|error|exception)(?:\.toString\(\))?\}?'
  r'|\$\{[^}]*\.error\b[^}]*\}'
  r'|\b\w*(?:Provider|provider|Snapshot|snapshot|State|state)\.error\b'
  r'|\.error\.toString\(\)',
);

/// Ανάθεση σε μεταβλητή/πεδίο: `_error = e.toString();`
final RegExp _assignment = RegExp(
  r'^\s*(?:(?:final|var|late)\s+)?'
  r'(?:(?:String|Object|dynamic)\??\s+)?'
  r'([A-Za-z_]\w*)\s*=\s*(.+?);\s*$',
);

/// Γραμμές που δεν ελέγχονται: σχόλια και logging.
bool _isIgnored(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('//') ||
      trimmed.contains('DebugConfig.print') ||
      trimmed.contains('debugPrint(');
}

/// Επιστρέφει τις παραβιάσεις ενός αρχείου (source-level, χωρίς analyzer).
List<String> _scanSource(String path, String source) {
  final violations = <String>[];
  final lines = source.split('\n');
  final tainted = <String>{};

  // Πέρασμα 1: μεταβλητές που παίρνουν raw σφάλμα.
  for (final line in lines) {
    if (_isIgnored(line)) continue;
    final assignment = _assignment.firstMatch(line);
    if (assignment != null && _rawExpression.hasMatch(assignment.group(2)!)) {
      tainted.add(assignment.group(1)!);
    }
  }

  // Πέρασμα 2: sinks που δείχνουν raw ή tainted περιεχόμενο.
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_isIgnored(line)) continue;
    final sink = _uiSink.firstMatch(line);
    if (sink == null) continue;

    final argument = _stripSafeCalls(_readSinkArgument(lines, i, sink.start));
    if (_rawError.hasMatch(argument)) {
      violations.add('$path:${i + 1}: ${line.trim()}');
      continue;
    }

    for (final name in tainted) {
      final reference = RegExp(
        r'(?:\$\{?\s*)?\b' + RegExp.escape(name) + r'\b',
      );
      if (reference.hasMatch(argument)) {
        violations.add('$path:${i + 1}: πιθανό raw "$name": ${line.trim()}');
        break;
      }
    }
  }

  return violations;
}

/// Διαβάζει το όρισμα του sink, ακολουθώντας παρενθέσεις σε επόμενες γραμμές.
String _readSinkArgument(List<String> lines, int start, int offset) {
  final buffer = StringBuffer(lines[start].substring(offset));
  var balance = _parenBalance(buffer.toString());
  var i = start + 1;
  while (balance > 0 && i < lines.length && i <= start + 8) {
    buffer.write('\n');
    buffer.write(lines[i]);
    balance += _parenBalance(lines[i]);
    i++;
  }
  return buffer.toString();
}

int _parenBalance(String text) {
  var balance = 0;
  for (final unit in text.codeUnits) {
    if (unit == 0x28) balance++; // (
    if (unit == 0x29) balance--; // )
  }
  return balance;
}

/// Αφαιρεί τις εγκεκριμένες κλήσεις του `MessagePolicy` από το όρισμα.
/// Ό,τι περνά από εκεί είναι ασφαλές για τον χρήστη.
String _stripSafeCalls(String text) {
  const prefixes = <String>[
    'MessagePolicy.fromError(',
    'MessagePolicy.fromProvider(',
    'MessagePolicy.actionError(',
  ];
  var result = text;
  for (final prefix in prefixes) {
    var index = result.indexOf(prefix);
    while (index >= 0) {
      final end = _matchingParen(result, index + prefix.length - 1);
      if (end == -1) break;
      result = result.replaceRange(index, end + 1, '');
      index = result.indexOf(prefix);
    }
  }
  return result;
}

int _matchingParen(String text, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < text.length; i++) {
    if (text[i] == '(') depth++;
    if (text[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
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
      violations.addAll(_scanSource(file.path, file.readAsStringSync()));
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('E82: ο guard πιάνει raw σφάλμα μέσω μεταβλητής', () {
    const bad = '''
class Demo {
  String? _error;
  void load() {
    _error = e.toString();
  }
  Widget build() => Text(_error!);
}
''';
    expect(_scanSource('lib/demo_bad.dart', bad), isNotEmpty);

    const badSnapshot = r'''
Widget build() => Text('${snapshot.error}');
''';
    expect(_scanSource('lib/demo_snapshot.dart', badSnapshot), isNotEmpty);

    const badProvider = '''
Widget build() => Text(accountsProvider.error);
''';
    expect(_scanSource('lib/demo_provider.dart', badProvider), isNotEmpty);

    const good = '''
class Demo {
  String? _error;
  void load() {
    _error = MessagePolicy.fromError(e, action: 'φόρτωσης');
  }
  Widget build() => Text(_error!);
}
''';
    expect(_scanSource('lib/demo_good.dart', good), isEmpty);

    const allowed = r'''
Widget build() => Text(
  MessagePolicy.fromProvider(tagsProvider.error, action: 'φόρτωσης'),
);
''';
    expect(_scanSource('lib/demo_allowed.dart', allowed), isEmpty);

    const goodLiteral = '''
class Demo {
  String? _error = 'Αποτυχία φόρτωσης. Δοκιμάστε ξανά.';
  Widget build() => Text(_error!);
}
''';
    expect(_scanSource('lib/demo_literal.dart', goodLiteral), isEmpty);
  });

  test('E77: τα μηνύματα ασφαλείας πετιούνται ως UserMessageException', () {
    const files = <String>[
      'lib/presentation/auth/app_start.dart',
      'lib/presentation/screens/options/change_password_page.dart',
    ];
    final violations = <String>[];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      if (source.contains('throw Exception(')) {
        violations.add('$path: throw Exception(');
      }
      if (!source.contains('throw const UserMessageException(')) {
        violations.add('$path: λείπει throw const UserMessageException(');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('E81: inline validation στους διαλόγους', () {
    const expectations = <String, List<String>>{
      'lib/presentation/dialogs/edit_category_dialog.dart': [
        'errorText: _nameError',
      ],
      'lib/presentation/screens/options/oil/current_level_card.dart': [
        'errorText: heightError',
      ],
      'lib/presentation/screens/tags/tags_management_page.dart': [
        'errorText: nameError',
        'errorText: errorText',
      ],
      'lib/core/widgets/notification_edit_dialog.dart': [
        'errorText: _messageError',
        '_buildStopErrorText()',
      ],
    };
    final violations = <String>[];

    expectations.forEach((path, markers) {
      final source = File(path).readAsStringSync();
      for (final marker in markers) {
        if (!source.contains(marker)) {
          violations.add('$path: λείπει $marker');
        }
      }
    });

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
