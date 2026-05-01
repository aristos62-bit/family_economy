import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/core/services/auth_service.dart';
import 'package:family_economy/core/services/biometric_auth_service.dart';
import 'package:family_economy/core/services/biometric_settings_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';

import 'package:family_economy/core/session/session.dart';
import 'package:family_economy/core/session/session_scope.dart';

import 'package:family_economy/services/notifications_service.dart';

import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';
import 'package:family_economy/providers/notifications_provider.dart';
import 'package:family_economy/providers/budgets_provider.dart';
import 'package:family_economy/providers/tags_provider.dart';

import 'package:family_economy/presentation/auth/login_page.dart';
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

      // 1) Load user data (for Session currency)
      final userDoc = await _authService.getUserDocument(uid);
      final userData = userDoc.data();
      final currency = (userData?['default_currency'] as String?) ?? 'EUR';
      DebugConfig.print('🔑 Loaded user document for uid=$uid with default currency=$currency');
      // 2) Load biometric settings
      final bio = await BiometricSettingsService.instance.load(uid);

      // 3) Gate: if enabled + always -> ask biometric now
      if (bio.enabled && bio.mode == 'always') {
        DebugConfig.print('🟢 Biometric authentication required for uid=$uid');
        final ok = await BiometricAuthService.instance.authenticate(
          reason: 'Είσοδος στην εφαρμογή',

        );

        if (!ok) {
          DebugConfig.print('🔴 Biometric authentication failed for uid=$uid');
          throw Exception('Αποτυχία βιομετρικής ταυτοποίησης');
        }
      }

      if (!mounted) return;

      // ✅ ΚΡΙΣΙΜΗ ΔΙΟΡΘΩΣΗ: Check scheduled transactions BEFORE navigating
      await _checkScheduledTransactions(uid);

      // ✅ Recurring notifications: generate occurrences ahead (killed-app safe)
      // await RecurringNotificationsService().generateAhead(uid, horizonDays: 45);

      if (!mounted) return;

      Navigator.pushReplacement(
      context,
        MaterialPageRoute(
          builder: (_) => MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AccountsProvider(userId: uid)),
              ChangeNotifierProvider(create: (_) => CategoriesProvider(userId: uid)),
              ChangeNotifierProvider(create: (_) => TransactionsProvider(userId: uid)),
              ChangeNotifierProvider(create: (_) => NotificationsProvider(userId: uid)),
              ChangeNotifierProvider(create: (_) => BudgetsProvider(userId: uid)),
              ChangeNotifierProvider(create: (_) => TagsProvider(userId: uid)),
            ],
            child: Builder(
              builder: (context) {
                DebugConfig.print('🔗 Binding NotificationsService.onTap to NotificationsProvider');
                NotificationsService().onTap = (uuid) {
                  DebugConfig.print('📲 onTap called with payload=$uuid');
                  if (uuid == null || uuid.trim().isEmpty) return;
                  // ignore: unawaited_futures
                  context.read<NotificationsProvider>().markAsDelivered(uuid.trim());
                };
                return SessionScope(
                  session: Session(userId: uid, defaultCurrency: currency),
                  child: const HomePage(),
                );
              },
            ),
          ),

        ),
      );
    } catch (e) {
      DebugConfig.print('❌ AppStart error: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ✅ ΝΕΟΣ ΜΕΘΟΔΟΣ: Έλεγχος προγραμματισμένων κινήσεων
  Future<void> _checkScheduledTransactions(String userId) async {
    try {
      DebugConfig.print('🔍 Checking scheduled transactions for user: $userId');

      final scheduledService = ScheduledTransactionsService();
      final executed = await scheduledService.checkAndExecutePendingTransactions(userId);

      if (executed.isNotEmpty) {
        DebugConfig.print('✅ Executed ${executed.length} scheduled transactions on app start');

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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Απαιτείται ταυτοποίηση',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _logout,
                        child: const Text('Αποσύνδεση'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _run,
                        child: const Text('Ξανά'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // fallback (σπάνιο)
    return const Scaffold(body: SizedBox.shrink());
  }
}