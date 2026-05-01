import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

// ✅ Offline support imports
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/services/message_service.dart';

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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Firestore logging
    FirebaseFirestore.setLoggingEnabled(DebugConfig.isDebug);
    DebugConfig.print('↑ Firestore offline persistence ENABLED');
    DebugConfig.print('↑ Firestore offline writes ENABLED');
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
  } catch (e) {
    DebugConfig.print('Firebase initialization error: $e');
    runApp(ErrorApp(error: e.toString()));
  }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();

    return MaterialApp(
      // ✅ ΝΕΟΣ: Global navigator key
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,

      // ✅ Localization support for Greek
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
    );
  }
}

// ✅ Error screen για Firebase initialization failures
class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.redAccent.shade100.withValues(alpha: 0.15),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Σφάλμα Αρχικοποίησης',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Η εφαρμογή δεν μπόρεσε να συνδεθεί με τις υπηρεσίες Firebase.',
                    style: TextStyle(fontSize: 16, color: Colors.red.shade800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Text(
                      'Σφάλμα: $error',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        DebugConfig.print('User requested app restart'),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Επανεκκίνηση'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}