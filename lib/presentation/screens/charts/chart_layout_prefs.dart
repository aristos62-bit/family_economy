// ============================================================
// FILE: chart_layout_prefs.dart
// PURPOSE: Ενιαία ανάγνωση της διάταξης γραφημάτων
//          (σειρά, ορατότητα, περίοδοι) από το SharedPreferences
// Location: lib/presentation/screens/charts/chart_layout_prefs.dart
// ============================================================

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/utils/period_prefs.dart';
import 'package:family_economy/presentation/screens/charts/chart_registry.dart';

/// Αμετάβλητη διάταξη γραφημάτων για έναν χρήστη.
///
/// Η [order] και η [visibility] είναι πάντα ευθυγραμμισμένες: η θέση `i` της
/// μίας αντιστοιχεί στο γράφημα `order[i]` της άλλης. Οι [periods] είναι
/// keyed ανά `chartId` (`graf_1`, `graf_2`, …).
class ChartLayout {
  ChartLayout({
    required List<String> order,
    required List<bool> visibility,
    required Map<String, String> periods,
  })  : assert(order.length == visibility.length),
        order = List<String>.unmodifiable(order),
        visibility = List<bool>.unmodifiable(visibility),
        periods = Map<String, String>.unmodifiable(periods);

  final List<String> order;
  final List<bool> visibility;
  final Map<String, String> periods;

  /// Η αποθηκευμένη περίοδος του [chartId] ή κενό όταν δεν χρησιμοποιεί.
  String periodFor(String chartId) => periods[chartId] ?? '';
}

/// Ανάγνωση και κανονικοποίηση της διάταξης γραφημάτων.
///
/// Μοναδικός writer παραμένει η σελίδα «Διάταξη Γραφημάτων»· εδώ γίνονται
/// μόνο οι διορθώσεις κωδικοποίησης περιόδου που ήδη κάνει το [PeriodPrefs].
class ChartLayoutPrefs {
  ChartLayoutPrefs._();

  /// Αντιστοίχιση `chartId` → πρόθεμα κλειδιού περιόδου στο SharedPreferences.
  static const Map<String, String> periodKeys = <String, String>{
    'graf_1': 'graf1',
    'graf_2': 'graf2',
    'graf_3': 'graf3',
    'graf_5': 'graf5',
    'graf_6': 'graf6',
  };

  /// Προεπιλεγμένες περίοδοι — δηλώνονται μία φορά για όλες τις οθόνες.
  static const Map<String, String> defaultPeriods = <String, String>{
    'graf_1': 'Εβδομάδα',
    'graf_2': 'Μήνας',
    'graf_3': 'Εβδομάδα',
    'graf_5': 'Μήνας',
    'graf_6': 'Μήνας',
  };

  static String orderKey(String userId) => 'chart_order_$userId';
  static String visibilityKey(String userId) => 'chart_visibility_$userId';

  /// Διάταξη ασφαλείας όταν η ανάγνωση αποτύχει ή λήξει το όριο χρόνου.
  static ChartLayout fallback() => ChartLayout(
        order: availableCharts.map((c) => c.id).toList(),
        visibility: List<bool>.filled(availableCharts.length, true),
        periods: Map<String, String>.of(defaultPeriods),
      );

  /// Διαβάζει τη διάταξη του [userId] χωρίς όριο χρόνου.
  ///
  /// Σειρά εργασιών:
  /// 1. Ζευγαρώνει κάθε αποθηκευμένο id με τη δική του ορατότητα **πριν**
  ///    από οποιαδήποτε μετακίνηση.
  /// 2. Αφαιρεί άγνωστα ids και διπλότυπα (κρατά την πρώτη θέση).
  /// 3. Αν λείπει το `graf_7` και υπάρχει το `graf_6`, το εισάγει πριν από
  ///    αυτό (ίδια μετανάστευση με την παλιά σελίδα).
  /// 4. Προσθέτει τα υπόλοιπα λείποντα στο τέλος, ορατά.
  /// 5. Διαβάζει τις περιόδους μέσω [PeriodPrefs.load].
  static Future<ChartLayout> load(
    SharedPreferences prefs,
    String userId,
  ) async {
    final stopwatch = Stopwatch()..start();

    final defaultOrder = availableCharts.map((c) => c.id).toList();
    final savedOrder = prefs.getStringList(orderKey(userId));
    final savedVisibility = prefs.getStringList(visibilityKey(userId));

    final entries = <_LayoutEntry>[];
    final seen = <String>{};

    if (savedOrder != null) {
      for (var i = 0; i < savedOrder.length; i++) {
        final id = savedOrder[i];
        if (!defaultOrder.contains(id)) continue;
        if (!seen.add(id)) continue;

        // Ορατό είναι ό,τι δεν είναι ρητά `false`· μια χαλασμένη τιμή δεν
        // κρύβει γράφημα.
        final visible = savedVisibility != null && i < savedVisibility.length
            ? savedVisibility[i] != 'false'
            : true;
        entries.add(_LayoutEntry(id, visible));
      }
    }

    // Migration: το graf_7 μπαίνει πριν από το graf_6.
    if (!seen.contains('graf_7') && seen.contains('graf_6')) {
      final index = entries.indexWhere((entry) => entry.id == 'graf_6');
      entries.insert(index, const _LayoutEntry('graf_7', true));
      seen.add('graf_7');
    }

    // Νέα/λείποντα γραφήματα στο τέλος, ορατά.
    for (final id in defaultOrder) {
      if (seen.add(id)) {
        entries.add(_LayoutEntry(id, true));
      }
    }

    final periods = <String, String>{};
    for (final entry in periodKeys.entries) {
      periods[entry.key] = await PeriodPrefs.load(
        prefs,
        '${entry.value}_period_$userId',
        defaultPeriods[entry.key]!,
      );
    }

    DebugConfig.startup(
      'CHART_LAYOUT: loaded ${entries.length} charts '
      'in ${stopwatch.elapsedMilliseconds}ms',
    );

    return ChartLayout(
      order: entries.map((entry) => entry.id).toList(),
      visibility: entries.map((entry) => entry.visible).toList(),
      periods: periods,
    );
  }

  /// Όπως το [load], αλλά με συνολικό όριο χρόνου.
  ///
  /// Επιστρέφει `null` σε λήξη ή σφάλμα, ώστε ο caller να πέσει στην
  /// υπάρχουσα συμπεριφορά χωρίς να κολλήσει η εκκίνηση.
  static Future<ChartLayout?> loadWithin(
    String userId, {
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        _remaining(timeout, stopwatch),
      );
      final layout = await load(prefs, userId).timeout(
        _remaining(timeout, stopwatch),
      );
      return layout;
    } on TimeoutException {
      DebugConfig.print(
        'CHART_LAYOUT: timeout after ${stopwatch.elapsedMilliseconds}ms',
      );
      return null;
    } catch (e) {
      DebugConfig.print('CHART_LAYOUT: load failed: $e');
      return null;
    }
  }

  static Duration _remaining(Duration deadline, Stopwatch stopwatch) {
    final remaining = deadline - stopwatch.elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class _LayoutEntry {
  const _LayoutEntry(this.id, this.visible);

  final String id;
  final bool visible;
}
