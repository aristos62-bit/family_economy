// ============================================================
// FILE: period_prefs.dart
// PURPOSE: Ανάγνωση & επιδιόρθωση της αποθηκευμένης περιόδου γραφημάτων
// Location: lib/core/utils/period_prefs.dart
// ============================================================

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Διαχείριση της «περιόδου» που αποθηκεύεται ανά γράφημα στο SharedPreferences.
///
/// Σε παλιές εγκαταστάσεις υπάρχουν τιμές γραμμένες με λάθος κωδικοποίηση
/// (τα UTF-8 bytes διαβάστηκαν ως CP437 ή CP1252), π.χ. `╬£╬«╬╜╬▒╧é` αντί
/// `Μήνας`. Η [normalize] επιδιορθώνει τέτοιες τιμές και η [load] τις
/// ξαναγράφει σωστές, ώστε το πρόβλημα να μην επανέλθει.
class PeriodPrefs {
  PeriodPrefs._();

  /// Πρόθεμα για προσαρμοσμένο εύρος: `Custom_YYYY-MM-DD_YYYY-MM-DD`.
  static const String customPrefix = 'Custom_';

  /// Οι έγκυρες επιλογές περιόδου.
  static const List<String> options = <String>[
    'Σήμερα',
    'Εβδομάδα',
    'Μήνας',
    'Έτος',
  ];

  static final RegExp _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Είναι η [value] έγκυρη περίοδος (γνωστή επιλογή ή έγκυρο προσαρμοσμένο εύρος);
  static bool isValid(String value) {
    if (options.contains(value)) return true;
    if (!value.startsWith(customPrefix)) return false;
    final parts = value.split('_');
    return parts.length == 3 &&
        _isoDate.hasMatch(parts[1]) &&
        _isoDate.hasMatch(parts[2]);
  }

  /// Επιστρέφει έγκυρη περίοδο: την ίδια, την επιδιορθωμένη ή το [fallback].
  static String normalize(String? raw, String fallback) {
    if (raw == null || raw.isEmpty) return fallback;
    if (isValid(raw)) return raw;
    final repaired = repairEncoding(raw);
    if (repaired != null && isValid(repaired)) return repaired;
    return fallback;
  }

  /// Διαβάζει την περίοδο από τα [prefs]· αν η τιμή ήταν χαλασμένη, τη
  /// διορθώνει και την ξαναγράφει (self-healing).
  static Future<String> load(
    SharedPreferences prefs,
    String key,
    String fallback,
  ) async {
    final raw = prefs.getString(key);
    final value = normalize(raw, fallback);
    if (raw != value) {
      await prefs.setString(key, value);
    }
    return value;
  }

  /// Προσπαθεί να ανακτήσει το αρχικό κείμενο από λάθος κωδικοποίηση.
  ///
  /// Επιστρέφει `null` όταν δεν προκύπτει έγκυρη περίοδος — έτσι δεν
  /// «διορθώνεται» ποτέ κατά λάθος μια σωστή τιμή.
  static String? repairEncoding(String value) {
    if (value.isEmpty) return null;

    for (final bytes in <List<int>?>[
      _bytesCp437First(value),
      _bytesLatin1First(value),
    ]) {
      if (bytes == null) continue;
      final decoded = _tryDecodeUtf8(bytes);
      if (decoded != null && decoded != value && isValid(decoded)) {
        return decoded;
      }
    }
    return null;
  }

  static String? _tryDecodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return null;
    }
  }

  /// UTF-8 bytes που διαβάστηκαν ως CP437: κάθε χαρακτήρας → byte μέσω CP437.
  static List<int>? _bytesCp437First(String value) {
    final bytes = <int>[];
    for (final unit in value.codeUnits) {
      final byte = _cp437Reverse[String.fromCharCode(unit)] ??
          (unit <= 0xFF ? unit : _cp1252Reverse[String.fromCharCode(unit)]);
      if (byte == null) return null;
      bytes.add(byte);
    }
    return bytes;
  }

  /// UTF-8 bytes που διαβάστηκαν ως Latin-1/CP1252.
  static List<int>? _bytesLatin1First(String value) {
    final bytes = <int>[];
    for (final unit in value.codeUnits) {
      final byte =
          unit <= 0xFF ? unit : _cp1252Reverse[String.fromCharCode(unit)];
      if (byte == null) return null;
      bytes.add(byte);
    }
    return bytes;
  }

  static final Map<String, int> _cp437Reverse = _buildCp437Reverse();

  static Map<String, int> _buildCp437Reverse() {
    assert(_cp437High.length == 128);
    final map = <String, int>{};
    for (var i = 0; i < _cp437High.length; i++) {
      map[_cp437High[i]] = 0x80 + i;
    }
    return map;
  }

  /// CP437, bytes 0x80–0xFF — η σειρά είναι σημαντική.
  static const String _cp437High =
      'ÇüéâäàåçêëèïîìÄÅ'
      'ÉæÆôöòûùÿÖÜ¢£¥₧ƒ'
      'áíóúñÑªº¿⌐¬½¼¡«»'
      '░▒▓│┤╡╢╖╕╣║╗╝╜╛┐'
      '└┴┬├─┼╞╟╚╔╩╦╠═╬╧'
      '╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀'
      'αßΓπΣσµτΦΘΩδ∞φε∩'
      '≡±≥≤⌠⌡÷≈°∙·√ⁿ²■\u00A0';

  /// Χαρακτήρες του CP1252 στο 0x80–0x9F (όπου διαφέρει από το Latin-1).
  static const Map<String, int> _cp1252Reverse = <String, int>{
    '€': 0x80,
    '‚': 0x82,
    'ƒ': 0x83,
    '„': 0x84,
    '…': 0x85,
    '†': 0x86,
    '‡': 0x87,
    'ˆ': 0x88,
    '‰': 0x89,
    'Š': 0x8A,
    '‹': 0x8B,
    'Œ': 0x8C,
    'Ž': 0x8E,
    '‘': 0x91,
    '’': 0x92,
    '“': 0x93,
    '”': 0x94,
    '•': 0x95,
    '–': 0x96,
    '—': 0x97,
    '˜': 0x98,
    '™': 0x99,
    'š': 0x9A,
    '›': 0x9B,
    'œ': 0x9C,
    'ž': 0x9E,
    'Ÿ': 0x9F,
  };
}
