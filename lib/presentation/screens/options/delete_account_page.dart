// ============================================================
// FILE: delete_account_page.dart
// Path: lib/presentation/screens/options/delete_account_page.dart
// Ρόλος: Σελίδα διαγραφής λογαριασμού (διπλή επιβεβαίωση + offline guard)
// ============================================================

import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/errors/user_message_exception.dart';
import 'package:family_economy/core/messaging/app_messenger.dart';
import 'package:family_economy/presentation/auth/login_page.dart';
import 'package:family_economy/core/services/account_deletion_service.dart';
import 'package:family_economy/core/services/auth_service.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/utils/account_deletion_policy.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/services/notifications_service.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final AuthService _authService = AuthService();

  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Σελίδα Διαγραφής Λογαριασμού. Απαιτείται διπλή επιβεβαίωση.',
    );
  }

  // Responsive helpers (ίδια λογική με OptionsPage)
  double _getMaxWidth(double screenWidth) {
    if (screenWidth > 1200) return 800; // Desktop
    if (screenWidth > 600) return 700; // Tablet
    return screenWidth; // Mobile
  }

  double _getHorizontalPadding(double screenWidth) {
    if (screenWidth > 1200) return 32.0; // Desktop
    if (screenWidth > 600) return 24.0; // Tablet
    return 16.0; // Mobile
  }

  Future<void> _startDeleteFlow() async {
    // ✅ Offline guard
    final isOnline = context.read<ConnectivityService>().isOnline;
    if (!isOnline) {
      AccessibilityService.announceError('Δεν υπάρχει σύνδεση στο internet');

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Χωρίς σύνδεση'),
          content: const Text(
            'Για λόγους ασφαλείας, η διαγραφή λογαριασμού απαιτεί ενεργή σύνδεση στο internet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // ✅ Confirmation #1
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Επιβεβαίωση'),
        content: const Text(
          'Είστε σίγουροι ότι θέλετε να διαγράψετε τον λογαριασμό σας '
          'και όλα τα δεδομένα σας;\n\n'
          'Η ενέργεια είναι μη αναστρέψιμη.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Άκυρο'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Συνέχεια',
              style: TextStyle(color: ColorsUI.getError(context.brightness)),
            ),
          ),
        ],
      ),
    );

    if (confirm1 != true || !mounted) return;

    // ✅ Confirmation #2 (τελική)
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Τελική Επιβεβαίωση',
          style: TextStyle(color: ColorsUI.getError(context.brightness)),
        ),
        content: const Text(
          'Τελευταία προειδοποίηση:\n'
          'Αν πατήσετε "Διαγραφή", ο λογαριασμός και όλα τα δεδομένα σας '
          'θα διαγραφούν οριστικά.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Άκυρο'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Διαγραφή',
              style: TextStyle(color: ColorsUI.getError(context.brightness)),
            ),
          ),
        ],
      ),
    );

    if (confirm2 != true || !mounted) return;

    // SEC-005: reauth-first — ο κωδικός ζητείται πριν από κάθε διαγραφή.
    final password = await _askPassword();
    if (password == null || !mounted) return;

    await _performDelete(password);
  }

  /// Ζητά τον κωδικό πρόσβασης για reauthentication.
  ///
  /// Επιστρέφει `null` όταν ο χρήστης ακυρώσει· κενός κωδικός → μήνυμα.
  Future<String?> _askPassword() async {
    var typedPassword = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AccountDeletionPolicy.passwordPromptTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AccountDeletionPolicy.passwordPromptMessage),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              autofocus: true,
              onChanged: (value) => typedPassword = value,
              decoration: const InputDecoration(
                labelText: AccountDeletionPolicy.passwordLabel,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) =>
                  Navigator.of(dialogContext).pop(value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(AccountDeletionPolicy.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(typedPassword),
            child: Text(
              AccountDeletionPolicy.deleteAction,
              style: TextStyle(color: ColorsUI.getError(context.brightness)),
            ),
          ),
        ],
      ),
    );

    final password = result?.trim();

    if (password == null) return null;
    if (password.isEmpty) {
      if (mounted) {
        AccessibilityService.announceError(
          AccountDeletionPolicy.passwordEmptyMessage,
        );
        await _showInfoDialog(
          title: AccountDeletionPolicy.failedTitle,
          message: AccountDeletionPolicy.passwordEmptyMessage,
        );
      }
      return null;
    }
    return password;
  }

  /// SEC-005: reauth → marker → cascade → root → notifications → Auth delete.
  Future<void> _performDelete(String password) async {
    if (_isDeleting) return;

    setState(() => _isDeleting = true);

    final userId = context.session.userId;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const UserMessageException(
          'Η συνεδρία έληξε. Συνδεθείτε ξανά.',
        );
      }

      // 1) Reauth-first: καμία εγγραφή πριν επιβεβαιωθεί η ταυτότητα.
      await _authService.reauthenticateWithPassword(password);
      if (!mounted) return;

      // 2) Τοπικές ειδοποιήσεις — best effort, πριν από το root delete ώστε
      // να μη μεγαλώνει το παράθυρο root → marker restore (SEC-005b).
      // Χωρίς αίτημα άδειας: η διαγραφή δεν πρέπει να ανοίγει διάλογο.
      try {
        final notifications = NotificationsService();
        await notifications.initialize(requestPermissions: false);
        await notifications.cancelAllNotifications();
      } catch (e) {
        DebugConfig.print('⚠️ cancelAllNotifications failed: $e');
      }

      // 3) Marker + cascade + root doc. Σε μερική αποτυχία το root μένει
      // και ο χρήστης μπορεί να συνεχίσει χωρίς νέο login.
      final service = AccountDeletionService(userId: userId);
      late AccountDeletionReport report;
      while (true) {
        report = await service.deleteAccountData();
        if (!mounted) return;

        if (report.isFailed) {
          await _showInfoDialog(
            title: AccountDeletionPolicy.failedTitle,
            message: AccountDeletionPolicy.failedMessage,
          );
          return;
        }

        if (report.isComplete) break;

        final retry = await _showPartialDialog(report);
        if (retry != true || !mounted) return;
      }

      // 4) Auth user — μία επανάληψη reauth αν ζητηθεί πρόσφατη σύνδεση.
      // SEC-005b: σε αποτυχία ο marker ξαναγράφεται και ο χρήστης επιλέγει.
      while (!await service.finalizeDeletion(report, () async {
        try {
          await _authService.deleteCurrentUser();
        } on AuthFlowException catch (e) {
          if (!e.requiresRecentLogin) rethrow;
          await _authService.reauthenticateWithPassword(password);
          await _authService.deleteCurrentUser();
        }
      })) {
        if (!mounted) return;
        final retry = await _showAuthPendingDialog();
        if (!mounted) return;
        if (retry != true) {
          await _closeWithPendingDeletion();
          return;
        }
      }

      if (!mounted) return;

      AccessibilityService.announceSuccess('Ο λογαριασμός διαγράφηκε');
      Navigator.of(context).pop(true);
    } on AuthFlowException catch (e) {
      if (!mounted) return;
      if (e.requiresRecentLogin) {
        AccessibilityService.announceError(
          AccountDeletionPolicy.recentLoginMessage,
        );
        await _showInfoDialog(
          title: 'Απαιτείται σύνδεση',
          message: AccountDeletionPolicy.recentLoginMessage,
        );
      } else {
        await _showInfoDialog(
          title: AccountDeletionPolicy.failedTitle,
          message: e.message,
        );
      }
    } on UserMessageException catch (e) {
      if (!mounted) return;
      await _showInfoDialog(
        title: AccountDeletionPolicy.failedTitle,
        message: e.message,
      );
    } catch (e) {
      DebugConfig.print('❌ delete account error: $e');
      if (!mounted) return;
      await _showInfoDialog(
        title: AccountDeletionPolicy.failedTitle,
        message: AccountDeletionPolicy.failedMessage,
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  /// SEC-005b: τα δεδομένα σβήστηκαν, εκκρεμεί ο Auth λογαριασμός.
  Future<bool?> _showAuthPendingDialog() {
    AccessibilityService.announceError(
      AccountDeletionPolicy.authPendingMessage,
    );
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text(AccountDeletionPolicy.authPendingTitle),
        content: const Text(AccountDeletionPolicy.authPendingMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AccountDeletionPolicy.closeAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AccountDeletionPolicy.retryAction),
          ),
        ],
      ),
    );
  }

  /// SEC-005b: ο χρήστης δεν συνεχίζει → αποσύνδεση και σελίδα σύνδεσης.
  Future<void> _closeWithPendingDeletion() async {
    await _authService.signOut();
    if (!mounted) return;
    AppMessenger.warning(
      context,
      AccountDeletionPolicy.authPendingClosedMessage,
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
      (route) => false,
    );
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
  }) async {
    AccessibilityService.announceError(message);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showPartialDialog(AccountDeletionReport report) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AccountDeletionPolicy.partialTitle),
        content: Text(
          '${AccountDeletionPolicy.partialMessage}\n\n'
          '${AccountDeletionPolicy.partialFailuresLabel}: '
          '${report.failures.length}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AccountDeletionPolicy.closeAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AccountDeletionPolicy.retryAction),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        AccessibilityService.announcePolite(
          AccountDeletionPolicy.runningMessage,
        );
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Διαγραφή Λογαριασμού')),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = _getMaxWidth(constraints.maxWidth);

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: _getHorizontalPadding(constraints.maxWidth),
                      vertical: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text('Προσοχή', style: context.h2),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Η διαγραφή λογαριασμού είναι μη αναστρέψιμη.\n'
                          'Θα διαγραφούν οριστικά ο λογαριασμός και όλα τα '
                          'δεδομένα σας (κινήσεις, λογαριασμοί, κατηγορίες, '
                          'ειδοποιήσεις).',
                          style: context.bodyMd.copyWith(color: context.cText2),
                        ),
                        const SizedBox(height: 20),

                        Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    ExcludeSemantics(
                                      child: Icon(
                                        Icons.warning_rounded,
                                        color: ColorsUI.getError(
                                          context.brightness,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Θα σας ζητηθεί διπλή επιβεβαίωση '
                                        'και ο κωδικός σας.',
                                        style: context.bodyMd.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                ElevatedButton(
                                  onPressed: _isDeleting
                                      ? null
                                      : _startDeleteFlow,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ColorsUI.getError(
                                      context.brightness,
                                    ),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: _isDeleting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: ExcludeSemantics(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation(
                                                Colors.white,
                                              ),
                                            ),
                                          ),
                                        )
                                      : const Text('Διαγραφή Λογαριασμού'),
                                ),
                                const SizedBox(height: 10),

                                OutlinedButton(
                                  onPressed: _isDeleting
                                      ? null
                                      : () => Navigator.of(context).maybePop(),
                                  child: const Text('Άκυρο'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
