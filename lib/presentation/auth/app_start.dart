import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/core/data/schema.dart';
import 'package:family_economy/core/data/schema_service.dart';
import 'package:family_economy/core/data/user_doc_policy.dart';
import 'package:family_economy/core/errors/user_message_exception.dart';
import 'package:family_economy/core/services/auth_service.dart';
import 'package:family_economy/core/services/biometric_auth_service.dart';
import 'package:family_economy/core/services/biometric_settings_service.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/utils/account_deletion_policy.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/utils/message_policy.dart';
import 'package:family_economy/core/widgets/startup_error_view.dart';

import 'package:family_economy/core/session/session.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';

import 'package:family_economy/services/notifications_service.dart';
import 'package:family_economy/services/onboarding_service.dart';

import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';
import 'package:family_economy/providers/notifications_provider.dart';
import 'package:family_economy/providers/budgets_provider.dart';
import 'package:family_economy/providers/tags_provider.dart';

import 'package:family_economy/presentation/auth/login_page.dart';
import 'package:family_economy/presentation/screens/charts/chart_layout_prefs.dart';
import 'package:family_economy/presentation/screens/home/home_page.dart';

// ✅ ΝΕΟΣ IMPORT
import 'package:family_economy/services/scheduled_transactions_service.dart';

class AppStart extends StatefulWidget {
  const AppStart({super.key});

  @override
  State<AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<AppStart> {
  bool _loading = true;
  String? _error;
  SchemaBlockedException? _blocked;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();

    // ✅ ΔΙΟΡΘΩΣΗ: Περιμένουμε το πρώτο frame πριν κάνουμε navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _run();
      }
    });
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
      _blocked = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
        );
        return;
      }

      final uid = user.uid;

      // Προφόρτωση της διάταξης γραφημάτων παράλληλα με τα υπόλοιπα βήματα.
      // Το await γίνεται πριν τη μετάβαση, με όριο χρόνου μέσα στο loadWithin.
      final chartLayoutFuture = ChartLayoutPrefs.loadWithin(uid);

      // 1) Load user data (for Session currency)
      // ✅ E64: μία κλήση — cache → server → create, χωρίς poll.
      final ensured = await _authService.ensureUserDocument(
        user,
        confirmedOffline: _isConfirmedOffline(),
      );
      if (!mounted) return;

      // SEC-005: ημιτελής διαγραφή → κλείδωμα πριν από βιομετρικό/schema.
      // Η συνέχιση γίνεται από τη σελίδα σύνδεσης (reauth + resume).
      if (ensured.outcome == UserDocOutcome.deletionPending) {
        throw const UserMessageException(
          AccountDeletionPolicy.pendingStartupMessage,
        );
      }

      final userData = ensured.data;
      final currency = (userData?['default_currency'] as String?) ?? 'EUR';
      DebugConfig.print(
        '🔑 Loaded user document for uid=$uid with default currency=$currency',
      );

      // 2) E65: βιομετρικές ρυθμίσεις από το doc που ήδη διαβάστηκε
      // (0 επιπλέον reads). Αν το doc δεν είναι διαθέσιμο, δεν μπορούμε να
      // επαληθεύσουμε το βιομετρικό gate → fail-closed με καθαρό μήνυμα.
      if (userData == null) {
        if (ensured.outcome == UserDocOutcome.skippedOffline) {
          throw const UserMessageException(
            'Χωρίς σύνδεση δεν είναι δυνατός ο έλεγχος ασφαλείας. '
            'Συνδεθείτε στο internet και πατήστε «Ξανά».',
          );
        }
        throw const UserMessageException(
          'Δεν ήταν δυνατή η ανάγνωση των ρυθμίσεων ασφαλείας. '
          'Δοκιμάστε ξανά.',
        );
      }

      final bio = BiometricSettings(
        enabled: (userData['fingerprint_enabled'] as bool?) ?? false,
        mode: (userData['biometric_mode'] as String?) ?? 'always',
        remember: (userData['biometric_remember'] as bool?) ?? false,
      );

      // 3) Gate: if enabled + always -> ask biometric now
      if (bio.enabled && bio.mode == 'always') {
        DebugConfig.print('🟢 Biometric authentication required for uid=$uid');
        final ok = await BiometricAuthService.instance.authenticate(
          reason: 'Είσοδος στην εφαρμογή',
        );

        if (!ok) {
          DebugConfig.print('🔴 Biometric authentication failed for uid=$uid');
          throw const UserMessageException('Αποτυχία βιομετρικής ταυτοποίησης');
        }
      }

      if (!mounted) return;

      // ✅ E4: Έλεγχος έκδοσης δεδομένων πριν από οποιαδήποτε εγγραφή.
      await _checkSchemaVersion(
        uid: uid,
        exists: ensured.exists,
        data: userData,
      );

      // ✅ ONBOARDING RECOVERY: αν το flag είναι ρητά `false`, το onboarding
      // είχε διακοπεί (kill/δίκτυο) → ξανατρέχει εδώ, ώστε χρήστης με
      // persisted session να μην μπει σε άδεια εφαρμογή.
      // Το flag διαβάζεται από το doc που ήδη φορτώθηκε (0 επιπλέον reads).
      await _runOnboardingIfNeeded(uid, userData);

      // ✅ ΚΡΙΣΙΜΗ ΔΙΟΡΘΩΣΗ: Check scheduled transactions BEFORE navigating
      await _checkScheduledTransactions(uid);

      if (!mounted) return;

      final chartLayout = await chartLayoutFuture;
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AccountsProvider(userId: uid),
              ),
              ChangeNotifierProvider(
                create: (_) => CategoriesProvider(userId: uid),
              ),
              ChangeNotifierProvider(
                create: (_) => TransactionsProvider(userId: uid),
              ),
              ChangeNotifierProvider(
                create: (_) => NotificationsProvider(userId: uid),
              ),
              ChangeNotifierProvider(
                create: (_) => BudgetsProvider(userId: uid),
              ),
              ChangeNotifierProvider(create: (_) => TagsProvider(userId: uid)),
            ],
            child: Builder(
              builder: (context) {
                DebugConfig.print(
                  '🔗 Binding NotificationsService.onTap to NotificationsProvider',
                );
                NotificationsService().onTap = (uuid) {
                  DebugConfig.print('📲 onTap called with payload=$uuid');
                  if (uuid == null || uuid.trim().isEmpty) return;
                  // ignore: unawaited_futures
                  context.read<NotificationsProvider>().markAsDelivered(
                    uuid.trim(),
                  );
                };
                return SessionScope(
                  session: Session(userId: uid, defaultCurrency: currency),
                  child: HomePage(initialChartLayout: chartLayout),
                );
              },
            ),
          ),
        ),
      );
    } on SchemaBlockedException catch (e) {
      DebugConfig.print(
        '⛔ Schema gate: code=${e.code ?? 'newer-data'} — ${e.message}',
      );
      if (!mounted) return;
      setState(() {
        _blocked = e;
        _error = e.message;
        _loading = false;
      });
      AccessibilityService.announceError(e.message);
    } catch (e) {
      DebugConfig.print('❌ AppStart error: $e');
      if (!mounted) return;
      final message = MessagePolicy.fromError(e, action: 'φόρτωσης στοιχείων');
      setState(() {
        _error = message;
        _loading = false;
      });
      AccessibilityService.announceError(message);
    }
  }

  /// ✅ E4: Έλεγχος έκδοσης δεδομένων με το doc που έχει ήδη διαβαστεί.
  /// Δεν κάνει δεύτερη ανάγνωση· γράφει μόνο αν χρειάζεται migration.
  Future<void> _checkSchemaVersion({
    required String uid,
    required bool exists,
    Map<String, dynamic>? data,
  }) async {
    final decision = await SchemaService().checkAndMigrate(
      uid: uid,
      exists: exists,
      data: data,
    );
    DebugConfig.print(
      '🗂️ schema: ${decision.status.name} '
      '(${decision.fromVersion} → ${decision.toVersion})',
    );
  }

  // ✅ Ανάκτηση διακοπέντος onboarding στην εκκίνηση με persisted session.
  // Χρησιμοποιεί το ήδη φορτωμένο doc (0 επιπλέον reads όταν δεν χρειάζεται).
  // Αν λείπει το πεδίο => θεωρείται ολοκληρωμένο (legacy users χωρίς διπλό
  // «Κύριο Λογαριασμό»). Σε αποτυχία ΔΕΝ μπλοκάρει την είσοδο στην εφαρμογή.
  Future<void> _runOnboardingIfNeeded(
    String uid,
    Map<String, dynamic>? userData,
  ) async {
    final completed = (userData?['onboarding_completed'] as bool?) ?? true;
    if (completed) return;

    // E5 gate (επίπεδο 1): offline → καμία εγγραφή, επανάληψη στην επόμενη
    // εκκίνηση. Αποφεύγει και την αναμονή του server timeout.
    if (_isConfirmedOffline()) {
      DebugConfig.print('📴 Onboarding resume skipped (offline)');
      return;
    }

    DebugConfig.print('🔁 Onboarding incomplete — resuming for uid=$uid');
    try {
      await OnboardingService().checkAndRunOnboarding(uid);
      DebugConfig.print('✅ Onboarding resumed and completed for uid=$uid');
    } on OnboardingOfflineException {
      // E5 gate (επίπεδο 2): ο server δεν επιβεβαίωσε — καμία εγγραφή.
      DebugConfig.print('📴 Onboarding resume skipped (offline)');
    } catch (e) {
      DebugConfig.print('⚠️ Onboarding resume failed (app continues): $e');
    }
  }

  /// E5: γρήγορος έλεγχος σύνδεσης πριν το server-truth gate του service.
  bool _isConfirmedOffline() {
    try {
      return context.read<ConnectivityService>().isConfirmedOffline;
    } catch (_) {
      return false;
    }
  }

  // ✅ ΝΕΟΣ ΜΕΘΟΔΟΣ: Έλεγχος προγραμματισμένων κινήσεων
  Future<void> _checkScheduledTransactions(String userId) async {
    try {
      DebugConfig.print('🔍 Checking scheduled transactions for user: $userId');

      final scheduledService = ScheduledTransactionsService();
      final executed = await scheduledService
          .checkAndExecutePendingTransactions(userId);

      if (executed.isNotEmpty) {
        DebugConfig.print(
          '✅ Executed ${executed.length} scheduled transactions on app start',
        );

        // ✅ ΠΡΟΣΘΗΚΗ ΓΡΑΜΜΗΣ 1: Set flag για HomePage να το δει
        ScheduledTransactionsService.lastExecutedCount = executed.length;
      } else {
        DebugConfig.print('ℹ️ No scheduled transactions to execute');

        // ✅ ΠΡΟΣΘΗΚΗ ΓΡΑΜΜΗΣ 2: Reset flag
        ScheduledTransactionsService.lastExecutedCount = 0;
      }
    } catch (e) {
      DebugConfig.print('❌ Error checking scheduled transactions: $e');

      // ✅ ΠΡΟΣΘΗΚΗ ΓΡΑΜΜΗΣ 3: Reset flag σε περίπτωση error
      ScheduledTransactionsService.lastExecutedCount = 0;

      // Δεν κάνουμε throw - δεν θέλουμε να σταματήσει η εφαρμογή
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      final blocked = _blocked;
      return Scaffold(
        body: StartupErrorView(
          title: blocked?.title ?? 'Απαιτείται ταυτοποίηση',
          message: blocked?.message ?? _error!,
          icon: blocked != null ? Icons.system_update_alt : Icons.lock_outline,
          primaryLabel: 'Ξανά',
          primaryIcon: Icons.refresh,
          onPrimary: _run,
          secondaryLabel: 'Αποσύνδεση',
          onSecondary: _logout,
        ),
      );
    }

    // fallback (σπάνιο)
    return const Scaffold(body: SizedBox.shrink());
  }
}
