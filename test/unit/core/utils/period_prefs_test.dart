import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_economy/core/utils/period_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PeriodPrefs.isValid', () {
    test('δέχεται τις γνωστές επιλογές', () {
      for (final option in PeriodPrefs.options) {
        expect(PeriodPrefs.isValid(option), isTrue, reason: option);
      }
    });

    test('δέχεται έγκυρο προσαρμοσμένο εύρος', () {
      expect(PeriodPrefs.isValid('Custom_2026-01-01_2026-12-31'), isTrue);
    });

    test('απορρίπτει άκυρο ή ημιτελές προσαρμοσμένο εύρος', () {
      expect(PeriodPrefs.isValid('Custom_'), isFalse);
      expect(PeriodPrefs.isValid('Custom_2026-01-01'), isFalse);
      expect(PeriodPrefs.isValid('Custom_2026-1-1_2026-12-31'), isFalse);
    });

    test('απορρίπτει άγνωστο κείμενο', () {
      expect(PeriodPrefs.isValid('Μήνας!'), isFalse);
      expect(PeriodPrefs.isValid(''), isFalse);
    });
  });

  group('PeriodPrefs.normalize', () {
    test('αφήνει ανέπαφη μια έγκυρη τιμή', () {
      expect(PeriodPrefs.normalize('Έτος', 'Μήνας'), 'Έτος');
    });

    test('null / κενό → fallback', () {
      expect(PeriodPrefs.normalize(null, 'Εβδομάδα'), 'Εβδομάδα');
      expect(PeriodPrefs.normalize('', 'Εβδομάδα'), 'Εβδομάδα');
    });

    test('άγνωστο κείμενο → fallback', () {
      expect(PeriodPrefs.normalize('???', 'Μήνας'), 'Μήνας');
    });

    test('διορθώνει UTF-8 bytes που διαβάστηκαν ως CP437', () {
      // «Μήνας» ως UTF-8: CE 9C CE AE CE BD CE B1 CF 82
      const corrupted = '╬£╬«╬╜╬▒╧é';
      expect(corrupted.length, 10);
      expect(PeriodPrefs.normalize(corrupted, 'Εβδομάδα'), 'Μήνας');
    });

    test('διορθώνει UTF-8 bytes που διαβάστηκαν ως CP1252', () {
      const corrupted = 'ÎœÎ®Î½Î±Ï‚';
      expect(PeriodPrefs.normalize(corrupted, 'Εβδομάδα'), 'Μήνας');
    });

    test('δεν «διορθώνει» έγκυρο προσαρμοσμένο εύρος', () {
      const custom = 'Custom_2026-01-01_2026-12-31';
      expect(PeriodPrefs.normalize(custom, 'Μήνας'), custom);
    });
  });

  group('PeriodPrefs.load', () {
    test('διαβάζει, διορθώνει και ξαναγράφει χαλασμένη τιμή', () async {
      const key = 'graf1_period_test-uid';
      SharedPreferences.setMockInitialValues({key: '╬£╬«╬╜╬▒╧é'});
      final prefs = await SharedPreferences.getInstance();

      final value = await PeriodPrefs.load(prefs, key, 'Εβδομάδα');

      expect(value, 'Μήνας');
      expect(prefs.getString(key), 'Μήνας');
    });

    test('γράφει το fallback όταν λείπει η τιμή', () async {
      const key = 'graf2_period_test-uid';
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final value = await PeriodPrefs.load(prefs, key, 'Μήνας');

      expect(value, 'Μήνας');
      expect(prefs.getString(key), 'Μήνας');
    });

    test('δεν αγγίζει ήδη έγκυρη τιμή', () async {
      const key = 'graf3_period_test-uid';
      SharedPreferences.setMockInitialValues({key: 'Σήμερα'});
      final prefs = await SharedPreferences.getInstance();

      final value = await PeriodPrefs.load(prefs, key, 'Εβδομάδα');

      expect(value, 'Σήμερα');
      expect(prefs.getString(key), 'Σήμερα');
    });
  });
}
