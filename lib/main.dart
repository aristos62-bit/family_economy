import 'package:material_ui/material_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'package:family_economy/providers/theme_provider.dart';
import 'package:family_economy/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

// ✅ Offline support imports
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/services/message_service.dart';
import 'package:family_economy/core/widgets/startup_error_view.dart';

// ✅ ΝΕΟΣ: Scheduled transactions

// ✅ ΝΕΕΣ ΓΡΑΜΜΕΣ: Notifications
import 'package:family_economy/services/notifications_service.dart';

// ✅ Global navigator key για messages
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DebugConfig.startup("APP START");

  // Φόρτωση theme
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();
  DebugConfig.startup("ThemeProvider initialized");

  // ✅ ΝΕΕΣ ΓΡΑΜΜΕΣ: Initialize NotificationsService
  await NotificationsService().initialize();
  DebugConfig.startup("NotificationsService initialized");

  // ✅ ΝΕΟΣ: Create ConnectivityService instance
  final connectivityService = ConnectivityService();
  DebugConfig.startup("ConnectivityService created");
  try {
    await _bootstrap(
      themeProvider: themeProvider,
      connectivityService: connectivityService,
    );
  } catch (e) {
    DebugConfig.print('Firebase initialization error: $e');
    runApp(
      ErrorApp(
        error: e.toString(),
        onRetry: () => _bootstrap(
          themeProvider: themeProvider,
          connectivityService: connectivityService,
          isRetry: true,
        ),
      ),
    );
  }
}

/// Αρχικοποίηση Firebase/Firestore και εκκίνηση της εφαρμογής.
/// Καλείται ξανά από την [ErrorApp] («Δοκιμή ξανά») — L18.
Future<void> _bootstrap({
  required ThemeProvider themeProvider,
  required ConnectivityService connectivityService,
  bool isRetry = false,
}) async {
  DebugConfig.startup(isRetry ? "Bootstrap retry" : "Firebase init");

  // Σε επανάληψη, αν το Firebase app υπάρχει ήδη από την προηγούμενη
  // προσπάθεια, δεν ξανακαλούμε initializeApp (μη εγγυημένη idempotency).
  if (isRetry && Firebase.apps.isNotEmpty) {
    DebugConfig.print('↑ Firebase app already initialized — skip initializeApp');
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  DebugConfig.startup("Firebase initialized");

  // ✅ Αναμονή για φόρτωση auth state (για Windows/Desktop)
  // Στα Windows, το Firebase Auth χρειάζεται λίγο χρόνο να φορτώσει
  // το persisted user state από το local storage
  try {
    await FirebaseAuth.instance.authStateChanges().first.timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
    DebugConfig.print('↑ Firebase Auth state initialized');
    DebugConfig.startup("Firebase Auth state ready");
  } catch (e) {
    DebugConfig.print('⚠️ Auth state initialization: $e');
  }

  // ✅ Ενεργοποίηση Firestore offline persistence
  // best-effort: σε επανάληψη το instance μπορεί να έχει ήδη ξεκινήσει και
  // η αλλαγή settings δεν επιτρέπεται — δεν μπλοκάρει την εκκίνηση (L18).
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    DebugConfig.print('↑ Firestore offline persistence ENABLED');
    DebugConfig.print('↑ Firestore offline writes ENABLED');
  } catch (e) {
    DebugConfig.print('⚠️ Firestore settings: $e');
  }

  // Firestore logging
  FirebaseFirestore.setLoggingEnabled(DebugConfig.isDebug);
  DebugConfig.startup("Firestore configured");
  DebugConfig.startup("runApp starting");
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
        ),
        // ✅ ΑΛΛΑΓΗ: Χρήση .value αντί για create
        ChangeNotifierProvider<ConnectivityService>.value(
          value: connectivityService,
        ),
      ],
      // ✅ ΑΛΛΑΓΗ: Περνάμε το connectivityService στο MyApp
      child: MyApp(connectivityService: connectivityService),
    ),
  );
}

// ✅ ΑΛΛΑΓΗ: MyApp είναι τώρα StatefulWidget
class MyApp extends StatefulWidget {
  final ConnectivityService connectivityService;

  const MyApp({
    super.key,
    required this.connectivityService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();

    // ✅ Setup sync complete callback
    widget.connectivityService.onSyncComplete = () {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        MessageService.showSyncComplete(context);
      }
    };

  }

  @override
  void dispose() {
    widget.connectivityService.onSyncComplete = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();

    return Phoenix(
      child: MaterialApp(
        // ✅ ΝΕΟΣ: Global navigator key
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,

        // ✅ Localization support for Greek
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [
          Locale('el', 'GR'), // Greek
          Locale('en', 'US'), // English (fallback)
        ],

        // ✅ Χρησιμοποιούμε τα themes σου
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: tp.themeMode,

        // ✅ Προστασία text scaling + Offline Banner
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final textScaler = TextScaler.linear(
            mediaQuery.textScaler.scale(1.0).clamp(0.85, 1.45),
          );

          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: textScaler),
            child: AnnouncementOverlay(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },

        home: const SplashScreen(),
      ),
    );
  }
}

/// ✅ Error screen για Firebase initialization failures (L18)
class ErrorApp extends StatefulWidget {
  final String error;

  /// Επανάληψη αρχικοποίησης. Σε επιτυχία καλεί `runApp` και το δέντρο
  /// αντικαθίσταται· σε αποτυχία πετά, ώστε η οθόνη να δείξει το νέο σφάλμα.
  final Future<void> Function() onRetry;

  const ErrorApp({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  State<ErrorApp> createState() => _ErrorAppState();
}

class _ErrorAppState extends State<ErrorApp> {
  late String _error = widget.error;
  bool _retrying = false;
  int _attempts = 0;

  Future<void> _handleRetry() async {
    if (_retrying) return;

    setState(() => _retrying = true);

    try {
      await widget.onRetry();
      // Σε επιτυχία το runApp έχει ήδη αντικαταστήσει το δέντρο.
      if (!mounted) return;
      setState(() => _retrying = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _attempts++;
        _retrying = false;
      });
      AccessibilityService.announceError(
        'Αποτυχία επανάληψης αρχικοποίησης: $_error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _attempts > 0
        ? 'Σφάλμα: $_error\nΠροσπάθειες: $_attempts'
        : 'Σφάλμα: $_error';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.redAccent.shade100.withValues(alpha: 0.15),
        body: StartupErrorView(
          title: 'Σφάλμα Αρχικοποίησης',
          message:
          'Η εφαρμογή δεν μπόρεσε να ολοκληρώσει την αρχικοποίηση.',
          details: details,
          primaryLabel: _retrying ? 'Νέα προσπάθεια…' : 'Δοκιμή ξανά',
          primaryIcon: Icons.refresh,
          onPrimary: _handleRetry,
        ),
      ),
    );
  }
}