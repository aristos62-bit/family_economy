import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_economy/presentation/screens/charts/chart_layout_prefs.dart';
import 'package:family_economy/presentation/screens/charts/chart_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'test-uid';
  final defaultOrder = availableCharts.map((c) => c.id).toList();

  Future<ChartLayout> loadWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return ChartLayoutPrefs.load(prefs, uid);
  }

  group('ChartLayoutPrefs.load — σειρά & ορατότητα', () {
    test('άδειες προτιμήσεις → προεπιλεγμένη σειρά, όλα ορατά', () async {
      final layout = await loadWith({});

      expect(layout.order, defaultOrder);
      expect(layout.visibility, List<bool>.filled(defaultOrder.length, true));
      expect(layout.visibility.length, layout.order.length);
    });

    test('προσαρμοσμένη σειρά διατηρείται', () async {
      final custom = [
        'graf_6',
        'graf_1',
        'graf_4',
        'graf_2',
        'graf_5',
        'graf_7',
        'graf_3',
      ];
      final layout = await loadWith({'chart_order_$uid': custom});

      expect(layout.order, custom);
    });

    test('άγνωστο id αφαιρείται', () async {
      final layout = await loadWith({
        'chart_order_$uid': ['graf_1', 'graf_unknown', 'graf_2'],
      });

      expect(layout.order, isNot(contains('graf_unknown')));
      expect(layout.order, defaultOrder);
    });

    test('διπλό id κρατά την πρώτη θέση', () async {
      final layout = await loadWith({
        'chart_order_$uid': [
          'graf_1',
          'graf_2',
          'graf_1',
          'graf_3',
          'graf_4',
          'graf_5',
          'graf_7',
          'graf_6',
        ],
      });

      expect(layout.order.where((id) => id == 'graf_1').length, 1);
      expect(layout.order.first, 'graf_1');
    });

    test('λείπον graf_7 με graf_6 → μπαίνει πριν από το graf_6', () async {
      final layout = await loadWith({
        'chart_order_$uid': [
          'graf_1',
          'graf_2',
          'graf_3',
          'graf_4',
          'graf_5',
          'graf_6',
        ],
      });

      final index7 = layout.order.indexOf('graf_7');
      final index6 = layout.order.indexOf('graf_6');
      expect(index7, greaterThanOrEqualTo(0));
      expect(index7, lessThan(index6));
      expect(layout.visibility[index7], isTrue);
    });

    test('λείπον γράφημα προστίθεται στο τέλος, ορατό', () async {
      final layout = await loadWith({
        'chart_order_$uid': ['graf_1', 'graf_2', 'graf_3', 'graf_4', 'graf_5'],
      });

      expect(layout.order.last, 'graf_6');
      expect(layout.order[layout.order.length - 2], 'graf_7');
      expect(layout.visibility.last, isTrue);
    });

    test('κοντύτερη ορατότητα → τα υπόλοιπα ορατά', () async {
      final layout = await loadWith({
        'chart_order_$uid': defaultOrder,
        'chart_visibility_$uid': ['true', 'false'],
      });

      expect(layout.visibility.length, layout.order.length);
      expect(layout.visibility[1], isFalse);
      expect(layout.visibility.skip(2), everyElement(isTrue));
    });

    test('κρυφό γράφημα διατηρεί τη θέση του', () async {
      final index = defaultOrder.indexOf('graf_5');
      final visibility = List<String>.filled(defaultOrder.length, 'true');
      visibility[index] = 'false';

      final layout = await loadWith({
        'chart_order_$uid': defaultOrder,
        'chart_visibility_$uid': visibility,
      });

      expect(layout.order, defaultOrder);
      expect(layout.visibility[index], isFalse);
    });

    test('χαλασμένη τιμή ορατότητας δεν κρύβει γράφημα', () async {
      final visibility = List<String>.filled(defaultOrder.length, 'true');
      visibility[0] = 'yes';

      final layout = await loadWith({
        'chart_order_$uid': defaultOrder,
        'chart_visibility_$uid': visibility,
      });

      expect(layout.visibility[0], isTrue);
    });
  });

  group('ChartLayoutPrefs.load — περίοδοι', () {
    test('έγκυρη περίοδος διατηρείται', () async {
      final layout = await loadWith({'graf1_period_$uid': 'Έτος'});

      expect(layout.periodFor('graf_1'), 'Έτος');
      expect(layout.periodFor('graf_2'), 'Μήνας');
    });

    test('χαλασμένη κωδικοποίηση διορθώνεται και ξαναγράφεται', () async {
      SharedPreferences.setMockInitialValues({
        'graf1_period_$uid': '╬£╬«╬╜╬▒╧é',
      });
      final prefs = await SharedPreferences.getInstance();

      final layout = await ChartLayoutPrefs.load(prefs, uid);

      expect(layout.periodFor('graf_1'), 'Μήνας');
      expect(prefs.getString('graf1_period_$uid'), 'Μήνας');
    });

    test('άκυρη περίοδος → προεπιλογή', () async {
      final layout = await loadWith({'graf3_period_$uid': '???'});

      expect(layout.periodFor('graf_3'), 'Εβδομάδα');
    });

    test('γράφημα χωρίς περίοδο → κενό', () async {
      final layout = await loadWith({});

      expect(layout.periodFor('graf_4'), isEmpty);
      expect(layout.periodFor('graf_7'), isEmpty);
    });
  });

  group('ChartLayoutPrefs.load — εγγραφές', () {
    test('καμία εγγραφή όταν τα δεδομένα είναι ήδη έγκυρα', () async {
      final order = List<String>.of(defaultOrder);
      final visibility = List<String>.filled(defaultOrder.length, 'true');

      SharedPreferences.setMockInitialValues({
        'chart_order_$uid': order,
        'chart_visibility_$uid': visibility,
        'graf1_period_$uid': 'Εβδομάδα',
        'graf2_period_$uid': 'Μήνας',
        'graf3_period_$uid': 'Εβδομάδα',
        'graf5_period_$uid': 'Μήνας',
        'graf6_period_$uid': 'Μήνας',
      });
      final prefs = await SharedPreferences.getInstance();

      await ChartLayoutPrefs.load(prefs, uid);

      expect(prefs.getStringList('chart_order_$uid'), order);
      expect(prefs.getStringList('chart_visibility_$uid'), visibility);
      expect(prefs.getString('graf1_period_$uid'), 'Εβδομάδα');
    });
  });

  group('ChartLayoutPrefs.fallback', () {
    test('επιστρέφει όλα τα γραφήματα ορατά με τις προεπιλογές', () {
      final layout = ChartLayoutPrefs.fallback();

      expect(layout.order, defaultOrder);
      expect(layout.visibility, everyElement(isTrue));
      expect(layout.periodFor('graf_1'), 'Εβδομάδα');
      expect(layout.periodFor('graf_6'), 'Μήνας');
    });
  });

  group('ChartLayoutPrefs.loadWithin', () {
    test('επιστρέφει τη διάταξη όταν η ανάγνωση προλάβει', () async {
      SharedPreferences.setMockInitialValues({});
      final layout = await ChartLayoutPrefs.loadWithin(uid);

      expect(layout, isNotNull);
      expect(layout!.order, defaultOrder);
    });
  });
}
