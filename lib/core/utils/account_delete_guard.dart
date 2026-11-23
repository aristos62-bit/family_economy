// ============================================================
// FILE: account_delete_guard.dart
// Path: lib/core/utils/account_delete_guard.dart
// Ρόλος: Καθαρή απόφαση για διαγραφή λογαριασμού (χωρίς Firebase).
// - Επιτρέπει τη διαγραφή μόνο όταν μένει ≥1 ενεργός λογαριασμός.
// - Τα μηνύματα ζουν εδώ, όπως στο Schema.failureFor (καθαρά, ελέγξιμα).
// - E20: ο κανόνας «εκκρεμής προγραμματισμένη» μοιράζεται με το
//   account_balance.dart (ένα σημείο αλήθειας, όχι διπλότυπα).
// ============================================================

import 'package:family_economy/core/utils/account_balance.dart';

/// Αιτία φραγής της διαγραφής λογαριασμού.
enum AccountDeleteBlock {
  /// Επιτρέπεται η διαγραφή.
  none,

  /// Δεν υπάρχει κανένας ενεργός λογαριασμός.
  noActiveAccount,

  /// Είναι ο τελευταίος ενεργός λογαριασμός.
  lastActiveAccount,
}

/// Αποτέλεσμα της απόφασης: επιτρέπεται ή όχι + αιτιολόγηση για τον χρήστη.
class AccountDeleteDecision {
  const AccountDeleteDecision({
    required this.block,
    required this.message,
  });

  final AccountDeleteBlock block;
  final String message;

  bool get canDelete => block == AccountDeleteBlock.none;
}

/// Ενέργεια που επιτρέπεται για έναν λογαριασμό (E26).
enum AccountAction {
  /// Καθαρός λογαριασμός (χωρίς κινήσεις/budgets) → πραγματική διαγραφή.
  delete,

  /// Έχει ιστορικό → αρχειοθέτηση (καμία κίνηση δεν αγγίζεται).
  archive,

  /// Εκκρεμούν προγραμματισμένες κινήσεις.
  blockPending,

  /// Είναι ο τελευταίος ενεργός λογαριασμός.
  blockLast,

  /// Δεν υπάρχει ενεργός λογαριασμός.
  blockNone,
}

/// Απόφαση E26: τι επιτρέπεται (διαγραφή / αρχειοθέτηση / φραγή) + μήνυμα.
class AccountActionDecision {
  const AccountActionDecision({
    required this.action,
    required this.message,
  });

  final AccountAction action;
  final String message;

  bool get canDelete => action == AccountAction.delete;
  bool get canArchive => action == AccountAction.archive;
  bool get isBlocked =>
      action == AccountAction.blockPending ||
      action == AccountAction.blockLast ||
      action == AccountAction.blockNone;
}

class AccountDeleteGuard {
  AccountDeleteGuard._();

  /// Αποφασίζει με βάση το πλήθος των **ενεργών** λογαριασμών
  /// (`AccountsProvider.accounts.length` — μηδέν επιπλέον reads).
  static AccountDeleteDecision evaluate(int activeAccountCount) {
    if (activeAccountCount <= 0) {
      return const AccountDeleteDecision(
        block: AccountDeleteBlock.noActiveAccount,
        message: 'Δεν υπάρχει ενεργός λογαριασμός για διαγραφή.',
      );
    }

    if (activeAccountCount == 1) {
      return const AccountDeleteDecision(
        block: AccountDeleteBlock.lastActiveAccount,
        message:
            'Δεν μπορεί να διαγραφεί ο τελευταίος ενεργός λογαριασμός. '
            'Δημιουργήστε πρώτα έναν νέο λογαριασμό.',
      );
    }

    return const AccountDeleteDecision(
      block: AccountDeleteBlock.none,
      message: '',
    );
  }

  // ============================================================
  // E26 — ΠΟΙΑ ΕΝΕΡΓΕΙΑ ΕΠΙΤΡΕΠΕΤΑΙ (καθαρό Dart, 0 reads)
  // ============================================================

  /// Αποφασίζει αν ο λογαριασμός **διαγράφεται** (καθαρός) ή
  /// **αρχειοθετείται** (έχει ιστορικό) ή αν υπάρχει φραγή.
  ///
  /// [activeAccountCount] : `AccountsProvider.accounts.length` (ενεργοί).
  /// [hasAnyTransaction] : υπάρχει έστω μία μη διαγραμμένη κίνηση.
  /// [budgetsCount] : ενεργά budgets που δείχνουν στον λογαριασμό.
  /// [pendingCount] : εκκρεμείς προγραμματισμένες κινήσεις του λογαριασμού.
  /// [targetIsVisible] : ο υπό διαγραφή λογαριασμός μετριέται ήδη στους
  ///   ενεργούς (E32). Για αρχειοθετημένο στόχο προσθέτουμε 1, ώστε η φραγή
  ///   «τελευταίος ενεργός» να αφορά τους λογαριασμούς που **μένουν**.
  static AccountActionDecision decide({
    required int activeAccountCount,
    required bool hasAnyTransaction,
    required int budgetsCount,
    int pendingCount = 0,
    bool targetIsVisible = true,
  }) {
    if (activeAccountCount <= 0) {
      return const AccountActionDecision(
        action: AccountAction.blockNone,
        message: 'Δεν υπάρχει ενεργός λογαριασμός.',
      );
    }

    final effectiveCount =
        activeAccountCount + (targetIsVisible ? 0 : 1);

    if (effectiveCount == 1) {
      return const AccountActionDecision(
        action: AccountAction.blockLast,
        message:
            'Ο λογαριασμός είναι ο τελευταίος ενεργός. '
            'Δημιουργήστε πρώτα έναν νέο λογαριασμό.',
      );
    }

    if (pendingCount > 0) {
      final pendingText = pendingCount == 1
          ? 'Υπάρχει 1 εκκρεμής προγραμματισμένη κίνηση. '
          : 'Υπάρχουν $pendingCount εκκρεμείς προγραμματισμένες κινήσεις. ';
      return AccountActionDecision(
        action: AccountAction.blockPending,
        message:
            '$pendingText'
            'Ακυρώστε ${pendingCount == 1 ? 'την' : 'τις'} πρώτα από την '
            'καρτέλα «Προγραμματισμένες».',
      );
    }

    if (hasAnyTransaction || budgetsCount > 0) {
      return const AccountActionDecision(
        action: AccountAction.archive,
        message: '',
      );
    }

    return const AccountActionDecision(
      action: AccountAction.delete,
      message: '',
    );
  }

  // ============================================================
  // E11 — ΠΛΑΝΟ ΑΚΥΡΩΣΗΣ ΜΕΤΑΦΟΡΩΝ (καθαρό Dart, χωρίς Firebase)
  // ============================================================

  /// Ανοχή για σύγκριση ποσών (float dust από `FieldValue.increment`).
  static const double epsilon = 0.005;

  /// Μέγιστο πλήθος writes ανά batch (Firestore όριο 500, κρατάμε 499).
  static const int maxWritesPerBatch = 499;

  static bool _isPresent(String? value) => (value ?? '').trim().isNotEmpty;

  static void _addDelta(Map<String, double> map, String key, double value) {
    if (key.trim().isEmpty) return;
    final next = (map[key] ?? 0.0) + value;
    if (next.abs() < epsilon) {
      map.remove(key);
    } else {
      map[key] = next;
    }
  }

  static TransferPairState _pairStateOf(Map<String, dynamic> leg) {
    return AccountBalanceRules.isPendingScheduled(leg)
        ? TransferPairState.pending
        : TransferPairState.complete;
  }

  /// Χτίζει το πλάνο ακύρωσης για τις **ενεργές** κινήσεις του λογαριασμού.
  ///
  /// [activeLegs] : maps με `uuid` (doc id) + πεδία του transaction.
  /// [peerLegsByGroup] : για σκέλη **χωρίς** peer πεδία (scheduled/legacy),
  ///   η ομάδα όπως διαβάστηκε από το `transfer_group_id`.
  static AccountDeletePlan buildPlan({
    required String accountUuid,
    required List<Map<String, dynamic>> activeLegs,
    Map<String, List<Map<String, dynamic>>> peerLegsByGroup =
        const <String, List<Map<String, dynamic>>>{},
  }) {
    final pairs = <TransferAnnulmentPair>[];
    final plain = <String>[];
    final deltas = <String, double>{};
    final pendingLegUuids = <String>[];
    var activeLegCount = 0;
    var partial = 0;
    var unknown = 0;

    for (final leg in activeLegs) {
      final uuid = (leg['uuid'] as String?)?.trim() ?? '';
      if (uuid.isEmpty) continue;

      activeLegCount++;
      if (AccountBalanceRules.isPendingScheduled(leg)) {
        pendingLegUuids.add(uuid);
      }

      final type = leg['transaction_type'] as String?;
      final amount = (leg['amount'] as num?)?.toDouble() ?? 0.0;

      if (type != 'transfer') {
        plain.add(uuid);
        continue;
      }

      final legAccountId =
          _isPresent(leg['account_id'] as String?)
              ? (leg['account_id'] as String).trim()
              : accountUuid;
      final groupId = (leg['transfer_group_id'] as String?)?.trim() ?? '';

      var peerUuid = (leg['transfer_peer_uuid'] as String?)?.trim() ?? '';
      var peerAccountId =
          (leg['transfer_peer_account_id'] as String?)?.trim() ?? '';
      var peerAmount = -amount;
      final state = _pairStateOf(leg);

      if (!_isPresent(peerUuid) || !_isPresent(peerAccountId)) {
        // Scheduled / legacy: το άλλο σκέλος βρίσκεται μόνο από την ομάδα.
        final groupLegs = peerLegsByGroup[groupId];
        if (groupId.isEmpty || groupLegs == null || groupLegs.isEmpty) {
          unknown++;
          plain.add(uuid);
          continue;
        }

        Map<String, dynamic>? other;
        var otherActive = 0;
        for (final candidate in groupLegs) {
          final candidateUuid = (candidate['uuid'] as String?)?.trim() ?? '';
          if (candidateUuid.isEmpty || candidateUuid == uuid) continue;
          if (candidate['deleted'] == true) continue;
          otherActive++;
          other ??= candidate;
        }

        if (otherActive != 1 || other == null) {
          // 0 → λείπει το άλλο σκέλος· >1 → ασυνεπές → μόνο κρύψιμο.
          partial++;
          plain.add(uuid);
          continue;
        }

        peerUuid = (other['uuid'] as String?)?.trim() ?? '';
        peerAccountId = (other['account_id'] as String?)?.trim() ?? '';
        peerAmount = (other['amount'] as num?)?.toDouble() ?? 0.0;

        if (!_isPresent(peerUuid) ||
            !_isPresent(peerAccountId) ||
            peerAmount.abs() < epsilon ||
            ((peerAmount > 0) == (amount > 0))) {
          partial++;
          plain.add(uuid);
          continue;
        }
      }

      pairs.add(
        TransferAnnulmentPair(
          groupId: groupId,
          legUuid: uuid,
          legAccountId: legAccountId,
          legAmount: amount,
          peerUuid: peerUuid,
          peerAccountId: peerAccountId,
          peerAmount: peerAmount,
          state: state,
        ),
      );
    }

    // Ολοκληρωμένα ζεύγη: αντιστροφή και των δύο υπολοίπων.
    for (final pair in pairs) {
      if (!pair.isComplete) continue;
      _addDelta(deltas, pair.legAccountId, -pair.legAmount);
      _addDelta(deltas, pair.peerAccountId, -pair.peerAmount);
    }

    return AccountDeletePlan(
      accountUuid: accountUuid,
      annulledPairs: List<TransferAnnulmentPair>.unmodifiable(pairs),
      plainLegUuids: List<String>.unmodifiable(plain),
      deltasByAccount: Map<String, double>.unmodifiable(deltas),
      partialPairs: partial,
      unknownPairs: unknown,
      activeLegCount: activeLegCount,
      pendingLegUuids: List<String>.unmodifiable(pendingLegUuids),
    );
  }

  /// Χτίζει τα ζεύγη προς επαναφορά από τα legs που φέρουν marker.
  ///
  /// Κάθε ζεύγος επανέρχεται **μόνο** αν είναι πλήρες και συνεπές· αλλιώς
  /// μένει κρυφό (καμία ανάσταση μισού ζεύγους).
  static List<TransferRestoreUnit> buildRestoreUnits({
    required String accountUuid,
    required List<Map<String, dynamic>> markedLegs,
    Set<String> activeAccountIds = const <String>{},
  }) {
    final byGroup = <String, List<Map<String, dynamic>>>{};

    for (final leg in markedLegs) {
      final groupId = (leg['transfer_group_id'] as String?)?.trim() ?? '';
      if (groupId.isEmpty) continue;
      byGroup.putIfAbsent(groupId, () => <Map<String, dynamic>>[]).add(leg);
    }

    final units = <TransferRestoreUnit>[];

    byGroup.forEach((groupId, legs) {
      final valid = legs.where((leg) {
        final uuid = (leg['uuid'] as String?)?.trim() ?? '';
        final marker = (leg['annulled_by_account_deleted'] as String?)?.trim();
        return uuid.isNotEmpty &&
            marker == accountUuid &&
            leg['deleted'] == true;
      }).toList();

      if (valid.length != 2) {
        units.add(
          TransferRestoreUnit.skipped(groupId, 'incomplete_pair'),
        );
        return;
      }

      final a = valid[0];
      final b = valid[1];
      final aUuid = (a['uuid'] as String).trim();
      final bUuid = (b['uuid'] as String).trim();
      final aAmount = (a['amount'] as num?)?.toDouble();
      final bAmount = (b['amount'] as num?)?.toDouble();
      final aAccount = (a['account_id'] as String?)?.trim() ?? '';
      final bAccount = (b['account_id'] as String?)?.trim() ?? '';

      final validShape = aUuid != bUuid &&
          aAmount != null &&
          bAmount != null &&
          aAmount.abs() >= epsilon &&
          bAmount.abs() >= epsilon &&
          aAccount.isNotEmpty &&
          bAccount.isNotEmpty &&
          aAccount != bAccount &&
          (a['transaction_type'] as String?) == 'transfer' &&
          (b['transaction_type'] as String?) == 'transfer' &&
          ((aAmount > 0) != (bAmount > 0)) &&
          (aAmount.abs() - bAmount.abs()).abs() < epsilon;

      if (!validShape) {
        units.add(
          TransferRestoreUnit.skipped(groupId, 'invalid_shape'),
        );
        return;
      }

      // Και οι δύο λογαριασμοί πρέπει να είναι ενεργοί (όχι διαγραμμένοι),
      // αλλιώς θα «αναστηθεί» ζεύγος που δείχνει σε ανύπαρκτο λογαριασμό.
      if (activeAccountIds.isNotEmpty &&
          (!activeAccountIds.contains(aAccount) ||
              !activeAccountIds.contains(bAccount))) {
        units.add(
          TransferRestoreUnit.skipped(groupId, 'peer_inactive'),
        );
        return;
      }

      final isPending = _pairStateOf(a) == TransferPairState.pending;
      final deltas = <String, double>{};
      if (!isPending) {
        _addDelta(deltas, aAccount, aAmount);
        _addDelta(deltas, bAccount, bAmount);
      }

      units.add(
        TransferRestoreUnit(
          groupId: groupId,
          legUuids: List<String>.unmodifiable(<String>[aUuid, bUuid]),
          deltasByAccount: Map<String, double>.unmodifiable(deltas),
          appliesBalance: !isPending,
          skipReason: null,
        ),
      );
    });

    return units;
  }
}

/// Κατάσταση ζεύγους μεταφοράς ως προς τη διαγραφή λογαριασμού.
enum TransferPairState {
  /// Εκτελεσμένο (ή όχι προγραμματισμένο) ζεύγος: κρύψιμο 2 legs + 2 deltas.
  complete,

  /// Εκκρεμές (`is_scheduled && !is_executed`): κρύψιμο 2 legs, 0 deltas.
  pending,
}

/// Ένα ζεύγος μεταφοράς που ακυρώνεται μαζί με τον λογαριασμό.
class TransferAnnulmentPair {
  const TransferAnnulmentPair({
    required this.groupId,
    required this.legUuid,
    required this.legAccountId,
    required this.legAmount,
    required this.peerUuid,
    required this.peerAccountId,
    required this.peerAmount,
    required this.state,
  });

  final String groupId;
  final String legUuid;
  final String legAccountId;
  final double legAmount;
  final String peerUuid;
  final String peerAccountId;
  final double peerAmount;
  final TransferPairState state;

  bool get isComplete => state == TransferPairState.complete;
  bool get isPending => state == TransferPairState.pending;
}

/// Ένα chunk από ζεύγη + τα deltas **μόνο αυτών** των ζευγών.
class AccountDeletePairChunk {
  const AccountDeletePairChunk({
    required this.pairs,
    required this.deltasByAccount,
  });

  final List<TransferAnnulmentPair> pairs;
  final Map<String, double> deltasByAccount;

  /// 2 legs ανά ζεύγος + 1 write ανά λογαριασμό με delta.
  int get writeCount => pairs.length * 2 + deltasByAccount.length;
}

/// Πλήρες πλάνο διαγραφής λογαριασμού (καθαρό, ελέγξιμο).
class AccountDeletePlan {
  const AccountDeletePlan({
    required this.accountUuid,
    required this.annulledPairs,
    required this.plainLegUuids,
    required this.deltasByAccount,
    required this.partialPairs,
    required this.unknownPairs,
    required this.activeLegCount,
    required this.pendingLegUuids,
  });

  final String accountUuid;
  final List<TransferAnnulmentPair> annulledPairs;
  final List<String> plainLegUuids;
  final Map<String, double> deltasByAccount;
  final int partialPairs;
  final int unknownPairs;

  /// Πλήθος μη διαγραμμένων κινήσεων του λογαριασμού (E26 gate).
  final int activeLegCount;

  /// Legs με `is_scheduled && !is_executed` (εκκρεμείς).
  final List<String> pendingLegUuids;

  /// Υπάρχει έστω μία κίνηση → δεν επιτρέπεται πραγματική διαγραφή.
  bool get hasAnyTransaction => activeLegCount > 0;

  bool get hasPendingScheduled => pendingLegUuids.isNotEmpty;

  int get completedPairs =>
      annulledPairs.where((pair) => pair.isComplete).length;

  int get pendingPairs =>
      annulledPairs.where((pair) => pair.isPending).length;

  int get transferCount => annulledPairs.length;

  bool get hasTransfers =>
      annulledPairs.isNotEmpty || partialPairs > 0 || unknownPairs > 0;

  /// Deltas μόνο για τους **άλλους** λογαριασμούς (για τον διάλογο).
  Map<String, double> get peerDeltas => <String, double>{
        for (final entry in deltasByAccount.entries)
          if (entry.key != accountUuid) entry.key: entry.value,
      };

  /// Legs + deltas + 1 write για τον λογαριασμό.
  int get totalWrites =>
      plainLegUuids.length +
      annulledPairs.length * 2 +
      deltasByAccount.length +
      1;

  bool get fitsSingleBatch =>
      totalWrites <= AccountDeleteGuard.maxWritesPerBatch;

  List<List<String>> buildPlainChunks({
    int maxWrites = AccountDeleteGuard.maxWritesPerBatch,
  }) {
    final chunks = <List<String>>[];
    for (var i = 0; i < plainLegUuids.length; i += maxWrites) {
      final end = (i + maxWrites < plainLegUuids.length)
          ? i + maxWrites
          : plainLegUuids.length;
      chunks.add(plainLegUuids.sublist(i, end));
    }
    return chunks;
  }

  /// Chunks ≤ [maxWrites] **χωρίς ποτέ** να σπάει ζεύγος.
  /// Τα deltas υπολογίζονται **ανά chunk** ώστε το retry να είναι σωστό.
  List<AccountDeletePairChunk> buildPairChunks({
    int maxWrites = AccountDeleteGuard.maxWritesPerBatch,
  }) {
    final chunks = <AccountDeletePairChunk>[];
    var pairs = <TransferAnnulmentPair>[];
    var deltas = <String, double>{};

    void flush() {
      if (pairs.isEmpty) return;
      chunks.add(
        AccountDeletePairChunk(
          pairs: List<TransferAnnulmentPair>.unmodifiable(pairs),
          deltasByAccount: Map<String, double>.unmodifiable(deltas),
        ),
      );
      pairs = <TransferAnnulmentPair>[];
      deltas = <String, double>{};
    }

    for (final pair in annulledPairs) {
      final pairDeltas = <String, double>{};
      if (pair.isComplete) {
        AccountDeleteGuard._addDelta(
          pairDeltas,
          pair.legAccountId,
          -pair.legAmount,
        );
        AccountDeleteGuard._addDelta(
          pairDeltas,
          pair.peerAccountId,
          -pair.peerAmount,
        );
      }

      final newAccounts = pairDeltas.keys
          .where((accountId) => !deltas.containsKey(accountId))
          .length;
      final projected =
          (pairs.length + 1) * 2 + deltas.length + newAccounts;

      if (projected > maxWrites && pairs.isNotEmpty) flush();

      pairs.add(pair);
      pairDeltas.forEach((accountId, delta) {
        AccountDeleteGuard._addDelta(deltas, accountId, delta);
      });
    }

    flush();
    return chunks;
  }
}

/// Ζεύγος προς επαναφορά (ή προς παράλειψη, με αιτία).
class TransferRestoreUnit {
  const TransferRestoreUnit({
    required this.groupId,
    required this.legUuids,
    required this.deltasByAccount,
    required this.appliesBalance,
    required this.skipReason,
  });

  factory TransferRestoreUnit.skipped(String groupId, String reason) {
    return TransferRestoreUnit(
      groupId: groupId,
      legUuids: const <String>[],
      deltasByAccount: const <String, double>{},
      appliesBalance: false,
      skipReason: reason,
    );
  }

  final String groupId;
  final List<String> legUuids;
  final Map<String, double> deltasByAccount;
  final bool appliesBalance;
  final String? skipReason;

  bool get canRestore => skipReason == null && legUuids.length == 2;

  int get writeCount => legUuids.length + deltasByAccount.length;
}
