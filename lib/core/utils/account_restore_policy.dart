// ============================================================
// FILE: account_restore_policy.dart
// Path: lib/core/utils/account_restore_policy.dart
// Ρόλος: ΕΝΑΣ κανόνας για την επαναφορά διαγραμμένου λογαριασμού (E19/E14).
// - Επιστρέφει ΜΟΝΟ ζεύγη μεταφορών που ακύρωσε η διαγραφή (marker).
// - Ποτέ κίνηση που διέγραψε ο χρήστης, ποτέ εκκρεμές ζεύγος.
// - Το υπόλοιπο του λογαριασμού = αρχικό + ό,τι μετράει (E20).
// - Deltas μόνο στους peers, chunks ≤499, μηνύματα για τον χρήστη.
// Χωρίς Firebase: ελέγξιμο με unit tests (όπως το account_delete_guard).
// ============================================================

import 'package:family_economy/core/utils/account_balance.dart';
import 'package:family_economy/core/utils/account_delete_guard.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';

/// Ένα chunk επαναφοράς: ζεύγη + τα deltas **μόνο αυτών** των ζευγών.
class AccountRestoreChunk {
  const AccountRestoreChunk({
    required this.units,
    required this.deltasByAccount,
  });

  final List<TransferRestoreUnit> units;
  final Map<String, double> deltasByAccount;

  /// 2 legs ανά ζεύγος + 1 write ανά λογαριασμό με delta.
  int get writeCount => units.length * 2 + deltasByAccount.length;
}

/// Πλήρες πλάνο επαναφοράς (καθαρό, ελέγξιμο).
class AccountRestorePlan {
  const AccountRestorePlan({
    required this.accountUuid,
    required this.accountName,
    required this.currency,
    required this.initialBalance,
    required this.storedBalance,
    required this.targetBalance,
    required this.restorablePairs,
    required this.restoredLegs,
    required this.hiddenLegs,
    required this.userDeletedHidden,
    required this.pendingPairs,
    required this.incompletePairs,
    required this.invalidPairs,
    required this.missingPeerPairs,
    required this.peerDeltas,
    required this.peerNames,
    required this.chunks,
    required this.fingerprint,
  });

  final String accountUuid;
  final String accountName;
  final String currency;
  final double initialBalance;
  final double storedBalance;
  final double targetBalance;
  final int restorablePairs;
  final int restoredLegs;
  final int hiddenLegs;
  final int userDeletedHidden;
  final int pendingPairs;
  final int incompletePairs;
  final int invalidPairs;
  final int missingPeerPairs;
  final Map<String, double> peerDeltas;
  final List<String> peerNames;
  final List<AccountRestoreChunk> chunks;
  final String fingerprint;

  bool get hasHistory => restorablePairs > 0;

  bool get balanceChanges =>
      (storedBalance - targetBalance).abs() >= AccountDeleteGuard.epsilon;

  int get skippedPairs =>
      pendingPairs + incompletePairs + invalidPairs + missingPeerPairs;

  int get totalWrites =>
      chunks.fold<int>(0, (sum, chunk) => sum + chunk.writeCount);

  String get historySummary {
    if (!hasHistory) {
      return 'Δεν βρέθηκε ιστορικό προς επαναφορά.';
    }
    final legs = restoredLegs == 1 ? '1 κίνηση' : '$restoredLegs κινήσεις';
    return 'Επιστρέφουν: ${_pairLabel(restorablePairs)} ($legs)';
  }

  String get hiddenSummary {
    if (hiddenLegs == 0) return 'Όλες οι κινήσεις επιστρέφουν.';
    return 'Μένουν κρυφές: ${_legLabel(hiddenLegs)}';
  }

  String get balanceSummary =>
      'Υπόλοιπο: ${_money(storedBalance)} → ${_money(targetBalance)}';

  String get peersSummary {
    if (peerNames.isEmpty) return '';
    return 'Επιστρέφουν ποσά σε: ${peerNames.join(', ')}';
  }

  /// Αιτίες που κάποιες μεταφορές δεν επιστρέφουν (καθαρό, ελέγξιμο κείμενο).
  List<String> get skipNotes {
    final notes = <String>[];

    if (pendingPairs > 0) {
      notes.add(
        pendingPairs == 1
            ? '1 εκκρεμής προγραμματισμένη μεταφορά έμεινε ακυρωμένη '
                  '(δεν επανέρχεται για να μην εκτελεστεί αυτόματα).'
            : '$pendingPairs εκκρεμείς προγραμματισμένες μεταφορές έμειναν '
                  'ακυρωμένες (δεν επανέρχονται για να μην εκτελεστούν '
                  'αυτόματα).',
      );
    }

    if (incompletePairs > 0) {
      notes.add(
        incompletePairs == 1
            ? '1 μεταφορά δεν επανήλθε: λείπει το άλλο σκέλος.'
            : '$incompletePairs μεταφορές δεν επανήλθαν: λείπει το άλλο '
                  'σκέλος.',
      );
    }

    if (invalidPairs > 0) {
      notes.add(
        invalidPairs == 1
            ? '1 μεταφορά δεν επανήλθε: τα δύο σκέλη δεν συμφωνούν.'
            : '$invalidPairs μεταφορές δεν επανήλθαν: τα δύο σκέλη δεν '
                  'συμφωνούν.',
      );
    }

    if (missingPeerPairs > 0) {
      notes.add(
        missingPeerPairs == 1
            ? '1 μεταφορά δεν επανήλθε: ο άλλος λογαριασμός δεν υπάρχει πλέον.'
            : '$missingPeerPairs μεταφορές δεν επανήλθαν: ο άλλος λογαριασμός '
                  'δεν υπάρχει πλέον.',
      );
    }

    return notes;
  }

  /// Μήνυμα επιτυχίας (σωστός ενικός/πληθυντικός — μάθημα E26).
  String successMessage() {
    final buffer = StringBuffer();
    final who = accountName.trim().isEmpty
        ? 'Ο λογαριασμός'
        : 'Ο λογαριασμός «${accountName.trim()}»';

    if (!hasHistory) {
      buffer.write(
        '$who επανήλθε με υπόλοιπο ${_money(targetBalance)}. '
        'Δεν βρέθηκε ιστορικό προς επαναφορά.',
      );
    } else {
      buffer.write('$who επανήλθε με ${_pairLabel(restorablePairs)}. ');
      buffer.write(
        'Υπόλοιπο: ${_money(storedBalance)} → ${_money(targetBalance)}.',
      );
      if (hiddenLegs > 0) {
        buffer.write(
          hiddenLegs == 1
              ? ' 1 κίνηση έμεινε κρυφή.'
              : ' ${_legLabel(hiddenLegs)} έμειναν κρυφές.',
        );
      }
    }

    final notes = skipNotes;
    if (notes.isNotEmpty) {
      buffer.write(' ${notes.join(' ')}');
    }

    return buffer.toString();
  }

  String _money(double value) =>
      CurrencyFormatter.format(value, currency: currency);

  static String _pairLabel(int count) =>
      count == 1 ? '1 μεταφορά' : '$count μεταφορές';

  static String _legLabel(int count) =>
      count == 1 ? '1 κίνηση' : '$count κινήσεις';
}

class AccountRestorePolicy {
  AccountRestorePolicy._();

  /// Χτίζει το πλάνο επαναφοράς από δεδομένα που διαβάστηκαν (0 I/O).
  ///
  /// [existingAccountIds] : **όλοι** οι λογαριασμοί που υπάρχουν (όχι μόνο
  ///   οι ενεργοί) — ένα ζεύγος με διαγραμμένο αλλά υπαρκτό peer επανέρχεται.
  /// [accountsById] : raw docs για ονόματα/nomisma των peers.
  static AccountRestorePlan build({
    required String accountUuid,
    required Map<String, dynamic> accountData,
    required List<Map<String, dynamic>> ownTransactions,
    required List<Map<String, dynamic>> markedLegs,
    required Set<String> existingAccountIds,
    required Map<String, Map<String, dynamic>> accountsById,
  }) {
    final accountName = _text(accountData['name']);
    final currency = _text(
      accountData['currency'],
      fallback: CurrencyFormatter.defaultCurrency,
    );
    final initialBalance = _amount(accountData['initial_balance']);
    final storedBalance = _amount(accountData['current_balance']);

    final units = AccountDeleteGuard.buildRestoreUnits(
      accountUuid: accountUuid,
      markedLegs: markedLegs,
      activeAccountIds: existingAccountIds,
    );

    final accepted = <TransferRestoreUnit>[];
    var pendingPairs = 0;
    var incompletePairs = 0;
    var invalidPairs = 0;
    var missingPeerPairs = 0;

    for (final unit in units) {
      if (unit.canRestore && unit.appliesBalance) {
        accepted.add(unit);
        continue;
      }
      if (unit.canRestore && !unit.appliesBalance) {
        pendingPairs++;
        continue;
      }
      switch (unit.skipReason) {
        case 'incomplete_pair':
          incompletePairs++;
          break;
        case 'invalid_shape':
          invalidPairs++;
          break;
        case 'peer_inactive':
          missingPeerPairs++;
          break;
        default:
          incompletePairs++;
      }
    }

    final acceptedLegIds = <String>{
      for (final unit in accepted) ...unit.legUuids,
    };

    var hiddenLegs = 0;
    var userDeletedHidden = 0;
    for (final tx in ownTransactions) {
      final uuid = _uuidOf(tx);
      if (uuid.isEmpty || tx['deleted'] != true) continue;
      if (acceptedLegIds.contains(uuid)) continue;

      hiddenLegs++;
      final marker = _text(tx['annulled_by_account_deleted']);
      if (marker.isEmpty) userDeletedHidden++;
    }

    final effective = <Map<String, dynamic>>[];
    for (final tx in ownTransactions) {
      final uuid = _uuidOf(tx);
      if (tx['deleted'] == true && acceptedLegIds.contains(uuid)) {
        effective.add(<String, dynamic>{...tx, 'deleted': false});
      } else {
        effective.add(tx);
      }
    }

    final balance = AccountBalanceRules.compute(
      initialBalance: initialBalance,
      transactions: effective,
    );

    final chunks = _buildChunks(units: accepted, accountUuid: accountUuid);
    final peerDeltas = <String, double>{};
    for (final chunk in chunks) {
      chunk.deltasByAccount.forEach((accountId, delta) {
        _addDelta(peerDeltas, accountId, delta);
      });
    }

    final peerNames = <String>[];
    for (final accountId in peerDeltas.keys) {
      final name = _text(accountsById[accountId]?['name']);
      peerNames.add(name.isEmpty ? 'άγνωστος λογαριασμός' : name);
    }
    peerNames.sort();

    return AccountRestorePlan(
      accountUuid: accountUuid,
      accountName: accountName,
      currency: currency,
      initialBalance: initialBalance,
      storedBalance: storedBalance,
      targetBalance: balance.newBalance,
      restorablePairs: accepted.length,
      restoredLegs: acceptedLegIds.length,
      hiddenLegs: hiddenLegs,
      userDeletedHidden: userDeletedHidden,
      pendingPairs: pendingPairs,
      incompletePairs: incompletePairs,
      invalidPairs: invalidPairs,
      missingPeerPairs: missingPeerPairs,
      peerDeltas: Map<String, double>.unmodifiable(peerDeltas),
      peerNames: List<String>.unmodifiable(peerNames),
      chunks: List<AccountRestoreChunk>.unmodifiable(chunks),
      fingerprint: _fingerprint(
        legs: acceptedLegIds,
        targetCents: AccountBalanceRules.centsOf(balance.newBalance),
        peerDeltas: peerDeltas,
      ),
    );
  }

  /// Chunks ≤ [AccountDeleteGuard.maxWritesPerBatch] χωρίς **ποτέ** να σπάει
  /// ζεύγος· τα deltas υπολογίζονται **ανά chunk** ώστε το retry να είναι σωστό.
  static List<AccountRestoreChunk> _buildChunks({
    required List<TransferRestoreUnit> units,
    required String accountUuid,
  }) {
    final chunks = <AccountRestoreChunk>[];
    var currentUnits = <TransferRestoreUnit>[];
    var currentDeltas = <String, double>{};

    AccountRestoreChunk buildChunk() => AccountRestoreChunk(
      units: List<TransferRestoreUnit>.unmodifiable(currentUnits),
      deltasByAccount: Map<String, double>.unmodifiable(currentDeltas),
    );

    for (final unit in units) {
      final projectedUnits = <TransferRestoreUnit>[...currentUnits, unit];
      final projectedDeltas = <String, double>{...currentDeltas};
      unit.deltasByAccount.forEach((accountId, delta) {
        if (accountId == accountUuid) return;
        _addDelta(projectedDeltas, accountId, delta);
      });

      final projectedWrites =
          projectedUnits.length * 2 + projectedDeltas.length;

      if (currentUnits.isNotEmpty &&
          projectedWrites > AccountDeleteGuard.maxWritesPerBatch) {
        chunks.add(buildChunk());
        currentUnits = <TransferRestoreUnit>[unit];
        currentDeltas = <String, double>{};
        unit.deltasByAccount.forEach((accountId, delta) {
          if (accountId == accountUuid) return;
          _addDelta(currentDeltas, accountId, delta);
        });
      } else {
        currentUnits = projectedUnits;
        currentDeltas = projectedDeltas;
      }
    }

    if (currentUnits.isNotEmpty) chunks.add(buildChunk());
    return chunks;
  }

  /// Αποτύπωμα του πλάνου: αν αλλάξει ανάμεσα σε προεπισκόπηση και εκτέλεση,
  /// η επαναφορά ματαιώνεται (ποτέ σιωπηλά «παλιό» υπόλοιπο).
  static String _fingerprint({
    required Set<String> legs,
    required int targetCents,
    required Map<String, double> peerDeltas,
  }) {
    final sortedLegs = legs.toList()..sort();
    final peerIds = peerDeltas.keys.toList()..sort();
    final peers = peerIds
        .map((id) => '$id:${AccountBalanceRules.centsOf(peerDeltas[id])}')
        .join(',');
    return '$targetCents|${sortedLegs.join(',')}|$peers';
  }

  static void _addDelta(Map<String, double> map, String key, double value) {
    if (key.trim().isEmpty) return;
    final next = (map[key] ?? 0.0) + value;
    if (next.abs() < AccountDeleteGuard.epsilon) {
      map.remove(key);
    } else {
      map[key] = next;
    }
  }

  static String _uuidOf(Map<String, dynamic> tx) =>
      _text(tx['uuid']).isEmpty ? _text(tx['id']) : _text(tx['uuid']);

  static String _text(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    return fallback;
  }

  static double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return CurrencyFormatter.parseInput(value) ?? 0.0;
    }
    return 0.0;
  }
}
