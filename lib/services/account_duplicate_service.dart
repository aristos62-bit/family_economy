// ============================================================
// FILE: account_duplicate_service.dart
// Path: lib/services/account_duplicate_service.dart
// Ρόλος: Διαχείριση διπλότυπων ονομάτων + διάλογος επαναφοράς
//        διαγραμμένου λογαριασμού (E19/E14/E29/E30/E31/E33).
// Το I/O της επαναφοράς ζει στο core/services/account_restore_service.dart.
// ============================================================

import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/services/account_restore_service.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/utils/account_restore_policy.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/session/session_scope.dart';

/// Αποτέλεσμα του ελέγχου ονόματος για δημιουργία λογαριασμού (E33).
enum CreateAccountOutcome {
  /// Δεν υπάρχει σύγκρουση → συνεχίζει η δημιουργία.
  proceed,

  /// Έγινε ενέργεια (διπλότυπο/επιτυχής επαναφορά) → κλείνει ο διάλογος.
  closeDialog,

  /// Ο χρήστης ακύρωσε/απέτυχε η επαναφορά → μένει ανοιχτός ο διάλογος.
  keepDialog,
}

class AccountDuplicateService {
  // ✅ Singleton pattern
  AccountDuplicateService._();
  static final AccountDuplicateService instance = AccountDuplicateService._();

  void _showSuccessSnack(BuildContext context, String message) {
    final b = Theme.of(context).brightness;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: ColorsUI.getOnPrimary(b)),
        ),
        backgroundColor: ColorsUI.getSuccess(b),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnack(BuildContext context, String message) {
    final b = Theme.of(context).brightness;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: ColorsUI.getOnError(b))),
        backgroundColor: ColorsUI.getError(b),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Έλεγχος αν υπάρχει ενεργός λογαριασμός με το ίδιο όνομα
  bool activeAccountNameExists(
    BuildContext context,
    String name, {
    String? excludeUuid,
  }) {
    final accountsProvider = context.read<AccountsProvider>();
    final allAccounts = accountsProvider.accounts;

    return allAccounts.any((account) {
      if (excludeUuid != null && account.uuid == excludeUuid) {
        return false;
      }
      return account.name.trim().toLowerCase() == name.trim().toLowerCase();
    });
  }

  /// Εύρεση διεγραμμένου λογαριασμού με το ίδιο όνομα (ανεκτική ανάγνωση — E31).
  Future<DeletedAccountInfo?> findDeletedAccountByName(
    String userId,
    String name,
  ) async {
    final wanted = name.trim().toLowerCase();
    if (wanted.isEmpty) return null;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .where('deleted', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final accountName = (data['name'] as String?)?.trim() ?? '';
        if (accountName.toLowerCase() != wanted) continue;

        final currency = (data['currency'] as String?)?.trim() ?? '';
        final archivedAt = data['archived_at'];

        return DeletedAccountInfo(
          uuid: doc.id,
          name: accountName,
          currency: currency.isEmpty
              ? CurrencyFormatter.defaultCurrency
              : currency,
          initialBalance: _amountOf(data['initial_balance']),
          currentBalance: _amountOf(data['current_balance']),
          archivedAt: archivedAt is Timestamp ? archivedAt.toDate() : null,
        );
      }

      return null;
    } catch (e) {
      DebugConfig.print('❌ Error finding deleted account: $e');
      return null;
    }
  }

  /// Διάλογος επαναφοράς διαγραμμένου λογαριασμού.
  /// Επιστρέφει `true` μόνο όταν ο λογαριασμός επανήλθε.
  Future<bool> showRestoreAccountDialog(
    BuildContext context,
    String userId,
    DeletedAccountInfo deletedAccount,
  ) async {
    final result = await showDialog<_RestoreDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RestoreAccountDialog(
        userId: userId,
        account: deletedAccount,
      ),
    );

    if (result == null || !result.restored) return false;
    if (!context.mounted) return true;

    _showSuccessSnack(context, result.message);
    AccessibilityService.announceAfterFirstFrame(context, result.message);
    return true;
  }

  /// Helper: Πλήρης έλεγχος για δημιουργία λογαριασμού.
  Future<CreateAccountOutcome> checkForCreateAccount(
    BuildContext context,
    String userId,
    String accountName,
  ) async {
    // 1. Έλεγχος ενεργών λογαριασμών
    if (activeAccountNameExists(context, accountName)) {
      _showErrorSnack(context, 'Υπάρχει ενεργός Λογαριασμός με αυτό το Όνομα');
      return CreateAccountOutcome.closeDialog;
    }

    // 2. Έλεγχος διεγραμμένων λογαριασμών
    final deletedAccount = await findDeletedAccountByName(userId, accountName);
    if (!context.mounted) return CreateAccountOutcome.keepDialog;
    if (deletedAccount == null) return CreateAccountOutcome.proceed;

    final restored = await showRestoreAccountDialog(
      context,
      userId,
      deletedAccount,
    );
    if (!context.mounted) return CreateAccountOutcome.keepDialog;
    return restored
        ? CreateAccountOutcome.closeDialog
        : CreateAccountOutcome.keepDialog;
  }

  /// Helper: Έλεγχος για επεξεργασία λογαριασμού
  /// Returns: true αν μπορεί να συνεχίσει, false αν πρέπει να σταματήσει
  Future<bool> checkForEditAccount(
    BuildContext context,
    String accountName,
    String currentAccountUuid,
  ) async {
    // Έλεγχος μόνο ενεργών (όχι διεγραμμένων)
    if (activeAccountNameExists(
      context,
      accountName,
      excludeUuid: currentAccountUuid,
    )) {
      _showErrorSnack(
        context,
        'Υπάρχει ήδη ενεργός λογαριασμός με αυτό το όνομα',
      );
      return false;
    }
    // ✅ Έλεγχος διεγραμμένου λογαριασμού με ίδιο όνομα
    final userId = context.session.userId;

    final deletedAccount = await findDeletedAccountByName(userId, accountName);

    if (!context.mounted) return false;

    if (deletedAccount != null && deletedAccount.uuid != currentAccountUuid) {
      _showErrorSnack(context, 'Δεν μπορεί να χρησιμοποιηθεί αυτό το Όνομα');
      return false;
    }
    return true;
  }

  static double _amountOf(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return CurrencyFormatter.parseInput(value) ?? 0.0;
    return 0.0;
  }
}

// ============================================================
// ΔΙΑΛΟΓΟΣ ΕΠΑΝΑΦΟΡΑΣ (preview → εκτέλεση, χωρίς providers σελίδας)
// ============================================================

class _RestoreDialogResult {
  const _RestoreDialogResult({required this.restored, this.message = ''});

  final bool restored;
  final String message;
}

enum _RestorePhase { loading, offline, preview, working, error, confirmWipe }

class _RestoreAccountDialog extends StatefulWidget {
  const _RestoreAccountDialog({
    required this.userId,
    required this.account,
  });

  final String userId;
  final DeletedAccountInfo account;

  @override
  State<_RestoreAccountDialog> createState() => _RestoreAccountDialogState();
}

class _RestoreAccountDialogState extends State<_RestoreAccountDialog> {
  final AccountRestoreService _service = AccountRestoreService();

  _RestorePhase _phase = _RestorePhase.loading;
  AccountRestorePlan? _plan;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  bool _isConfirmedOffline() {
    try {
      return context.read<ConnectivityService>().isConfirmedOffline;
    } catch (_) {
      return false;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;

    if (_isConfirmedOffline()) {
      setState(() {
        _phase = _RestorePhase.offline;
        _error = 'Η επαναφορά απαιτεί σύνδεση στο internet.';
      });
      return;
    }

    setState(() {
      _phase = _RestorePhase.loading;
      _error = '';
    });

    final preview = await _service.preview(
      userId: widget.userId,
      accountUuid: widget.account.uuid,
    );
    if (!mounted) return;

    if (preview.isSuccess) {
      setState(() {
        _plan = preview.plan;
        _phase = _RestorePhase.preview;
      });
      return;
    }

    setState(() {
      _phase = _RestorePhase.error;
      _error = _previewError(preview.failure);
    });
  }

  String _previewError(AccountRestoreFailure failure) {
    switch (failure) {
      case AccountRestoreFailure.missing:
        return 'Ο λογαριασμός δεν υπάρχει πλέον.';
      case AccountRestoreFailure.alreadyActive:
        return 'Ο λογαριασμός είναι ήδη ενεργός.';
      case AccountRestoreFailure.readFailed:
        return 'Σφάλμα ανάγνωσης ιστορικού. Δεν άλλαξε τίποτα.';
      case AccountRestoreFailure.none:
      case AccountRestoreFailure.changed:
      case AccountRestoreFailure.writeFailed:
        return 'Η επαναφορά δεν είναι διαθέσιμη τώρα.';
    }
  }

  Future<void> _restore({required bool withHistory}) async {
    final plan = _plan;
    if (withHistory && plan == null) return;

    setState(() => _phase = _RestorePhase.working);

    final result = withHistory
        ? await _service.restoreWithHistory(
            userId: widget.userId,
            plan: plan!,
          )
        : await _service.restoreWithoutBalance(
            userId: widget.userId,
            accountUuid: widget.account.uuid,
          );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop(
        _RestoreDialogResult(restored: true, message: result.message()),
      );
      return;
    }

    setState(() {
      _phase = _RestorePhase.error;
      _error = result.message();
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final busy = _phase == _RestorePhase.working;

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        backgroundColor: ColorsUI.getSurface(brightness),
        title: Text(
          'Επαναφορά Λογαριασμού',
          style: TypographyUI.titleLarge(brightness),
        ),
        content: SingleChildScrollView(child: _buildContent(brightness)),
        actions: _buildActions(brightness),
      ),
    );
  }

  Widget _buildContent(Brightness brightness) {
    switch (_phase) {
      case _RestorePhase.loading:
        return Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Φόρτωση ιστορικού…',
                style: TypographyUI.bodyMedium(brightness),
              ),
            ),
          ],
        );

      case _RestorePhase.offline:
      case _RestorePhase.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error,
              style: TypographyUI.bodyMedium(brightness),
            ),
            const SizedBox(height: 12),
            Text(
              'Ο λογαριασμός παραμένει όπως είναι.',
              style: TypographyUI.bodySmall(brightness),
            ),
          ],
        );

      case _RestorePhase.working:
        return Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Γίνεται επαναφορά…',
                style: TypographyUI.bodyMedium(brightness),
              ),
            ),
          ],
        );

      case _RestorePhase.confirmWipe:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Επαναφορά χωρίς υπόλοιπο',
              style: TypographyUI.titleSmall(brightness),
            ),
            const SizedBox(height: 8),
            Text(
              'Το αρχικό και το τρέχον υπόλοιπο θα μηδενιστούν και το '
              'ιστορικό θα παραμείνει κρυφό. Η ενέργεια δεν αναιρείται.',
              style: TypographyUI.bodyMedium(brightness),
            ),
          ],
        );

      case _RestorePhase.preview:
        return _buildPreview(brightness);
    }
  }

  Widget _buildPreview(Brightness brightness) {
    final plan = _plan;
    if (plan == null) {
      return Text(
        'Δεν υπάρχουν στοιχεία.',
        style: TypographyUI.bodyMedium(brightness),
      );
    }

    final muted = TypographyUI.bodySmall(brightness).copyWith(
      color: ColorsUI.getTextSecondary(brightness),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _accountCard(brightness),
        const SizedBox(height: 16),
        Text(plan.historySummary, style: TypographyUI.bodyMedium(brightness)),
        const SizedBox(height: 4),
        Text(plan.hiddenSummary, style: TypographyUI.bodyMedium(brightness)),
        if (plan.peersSummary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(plan.peersSummary, style: TypographyUI.bodyMedium(brightness)),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ColorsUI.getPrimary(brightness).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ColorsUI.getPrimary(brightness).withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            plan.balanceSummary,
            style: TypographyUI.titleSmall(brightness),
          ),
        ),
        if (!plan.hasHistory) ...[
          const SizedBox(height: 10),
          Text(
            'Αν ο λογαριασμός είχε κινήσεις που έχουν καθαριστεί, το '
            'υπόλοιπο θα είναι μόνο το αρχικό ποσό.',
            style: muted,
          ),
        ],
        for (final note in plan.skipNotes) ...[
          const SizedBox(height: 8),
          Text('• $note', style: muted),
        ],
        const SizedBox(height: 10),
        Text(
          'Ο λογαριασμός θα μετράει ξανά στο συνολικό υπόλοιπο.',
          style: muted,
        ),
      ],
    );
  }

  Widget _accountCard(Brightness brightness) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorsUI.getCard(brightness),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorsUI.getBorder(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restore,
                size: 20,
                color: ColorsUI.getPrimary(brightness),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.account.name,
                  style: TypographyUI.titleSmall(brightness),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Αρχικό υπόλοιπο: ${_money(widget.account.initialBalance)}',
            style: TypographyUI.bodySmall(brightness),
          ),
          Text(
            'Τρέχον υπόλοιπο: ${_money(widget.account.currentBalance)}',
            style: TypographyUI.bodySmall(brightness),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(Brightness brightness) {
    switch (_phase) {
      case _RestorePhase.loading:
      case _RestorePhase.working:
        return <Widget>[];

      case _RestorePhase.offline:
      case _RestorePhase.error:
        return <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Κλείσιμο',
              style: TypographyUI.buttonBase().copyWith(
                color: ColorsUI.getTextSecondary(brightness),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _load,
            child: const Text('Δοκιμή ξανά'),
          ),
        ];

      case _RestorePhase.confirmWipe:
        return <Widget>[
          TextButton(
            onPressed: () => setState(() => _phase = _RestorePhase.preview),
            child: Text(
              'Πίσω',
              style: TypographyUI.buttonBase().copyWith(
                color: ColorsUI.getTextSecondary(brightness),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _restore(withHistory: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsUI.getError(brightness),
              foregroundColor: ColorsUI.getOnError(brightness),
            ),
            child: const Text('Ναι, μηδενισμός'),
          ),
        ];

      case _RestorePhase.preview:
        return <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Ακύρωση',
              style: TypographyUI.buttonBase().copyWith(
                color: ColorsUI.getTextSecondary(brightness),
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _phase = _RestorePhase.confirmWipe),
            child: const Text('Χωρίς υπόλοιπο'),
          ),
          ElevatedButton(
            onPressed: () => _restore(withHistory: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsUI.getPrimary(brightness),
              foregroundColor: ColorsUI.getOnPrimary(brightness),
            ),
            child: const Text('Επαναφορά με ιστορικό'),
          ),
        ];
    }
  }

  String _money(double value) =>
      CurrencyFormatter.format(value, currency: widget.account.currency);
}
