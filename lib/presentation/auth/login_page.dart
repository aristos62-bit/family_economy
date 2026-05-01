import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/core/services/auth_service.dart';
import 'package:family_economy/services/onboarding_service.dart';
import 'package:family_economy/presentation/screens/home/home_page.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/session/session.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';
import 'package:family_economy/providers/notifications_provider.dart';
import 'package:family_economy/providers/budgets_provider.dart';
import 'package:family_economy/services/notifications_service.dart';
import 'package:family_economy/providers/tags_provider.dart';

class LoginRegisterPage extends StatefulWidget {
  const LoginRegisterPage({super.key});

  @override
  State<LoginRegisterPage> createState() => _LoginRegisterPageState();
}

class _LoginRegisterPageState extends State<LoginRegisterPage> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPassController;

  bool _isLogin = true;
  bool _showPassword = false;
  String? _errorMessage;
  bool _isLoading = false;

  // ✅ ΝΕΟ: Onboarding progress state
  bool _isOnboarding = false;
  double _onboardingProgress = 0.0;
  String _onboardingMessage = 'Παρακαλώ περιμένετε…';

  static final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPassController = TextEditingController();
  }

  void _togglePasswordVisibility() {
    setState(() => _showPassword = !_showPassword);
    // ✅ Ανακοινώνουμε τη νέα κατάσταση ώστε ο χρήστης με screen reader
    // να ξέρει αν ο κωδικός είναι ορατός ή όχι.
    AccessibilityService.announcePolite(
      _showPassword ? 'Ο κωδικός εμφανίζεται' : 'Ο κωδικός αποκρύφθηκε',
    );
  }

  // ✅ ΝΕΟ: Ενημερώνει το progress bar
  void _onOnboardingProgress(double progress, String message) {
    if (!mounted) return;
    setState(() {
      _onboardingProgress = progress;
      _onboardingMessage = message;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      AccessibilityService.announceError(
        'Παρακαλώ διορθώστε τα σφάλματα στη φόρμα',
      );
      setState(() => _isLoading = false);
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPassController.text.trim();

    try {
      User? user;

      if (_isLogin) {
        user = await _authService.signIn(email, password);
      } else {
        if (password != confirmPassword) {
          throw Exception('Οι κωδικοί δεν ταιριάζουν.');
        }
        user = await _authService.register(email, password);
      }
      final bool isNewUser = !_isLogin;

      final uid = user?.uid;
      if (uid == null) {
        setState(() {
          _errorMessage = 'Η σύνδεση απέτυχε. Δοκιμάστε ξανά.';
        });
        AccessibilityService.announceError(_errorMessage!);
        return;
      }

      final userDoc = await _authService.getUserDocument(uid);
      final userData = userDoc.data();
      final currency = userData?['default_currency'] as String? ?? 'EUR';

      // ✅ Recurring notifications sync (must run on login/register too)
      // ώστε να καλύπτει: πρώτη είσοδο, login μετά από logout, κλπ.
      try {
        //await RecurringNotificationsService().generateAhead(uid);
      } catch (e) {
        // Δεν θέλουμε να κόψει το login αν κάτι πάει στραβά.
        DebugConfig.print(
          '⚠️ RecurringNotificationsService startup sync failed: $e',
        );
      }

      // ✅ ONBOARDING: Τρέχει μόνο την πρώτη φορά
      if (isNewUser) {
        // ✅ ΝΕΟ: Εμφάνιση overlay progress
        setState(() {
          _isLoading = false;
          _isOnboarding = true;
          _onboardingProgress = 0.0;
          _onboardingMessage = 'Προετοιμασία…';
        });

        final onboardingService = OnboardingService();
        await onboardingService.checkAndRunOnboarding(
          uid,
          onProgress: _onOnboardingProgress,
        );

        // Μικρή παύση ώστε ο χρήστης να δει το 100%
        await Future.delayed(const Duration(milliseconds: 600));

        if (!mounted) return;
        setState(() => _isOnboarding = false);
      }

      AccessibilityService.announceSuccess('Επιτυχής σύνδεση');

      if (!mounted) return;

      // ✅ Ensure NotificationsService is initialized BEFORE entering HomePage
      // (permissions + timezone init happen in a predictable place)
      await NotificationsService().initialize();

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
                  child: const HomePage(),
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      DebugConfig.print('🔥 FULL ERROR: $e');
      DebugConfig.print('ERROR TYPE: ${e.runtimeType}');
      DebugConfig.print('ERROR MESSAGE: ${e.toString()}');

      String errorMessage = e.toString().replaceFirst('Exception: ', '').trim();

      if (errorMessage.isEmpty) {
        errorMessage = 'Προέκυψε άγνωστο σφάλμα. Δοκιμάστε ξανά.';
      }

      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }

      AccessibilityService.announceError(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      final message = 'Συμπληρώστε το email για επαναφορά κωδικού.';
      if (mounted) {
        setState(() => _errorMessage = message);
      }
      AccessibilityService.announceError(message);
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(email);
      final message = '✅ Ελέγξτε το email σας.';
      AccessibilityService.announcePolite('Εστάλη email επαναφοράς κωδικού');
      if (mounted) {
        setState(() => _errorMessage = message);
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '').trim();
      if (mounted) {
        setState(() => _errorMessage = errorMessage);
      }
      AccessibilityService.announceError(errorMessage);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // ✅ ΝΕΟ: Onboarding Progress Overlay
  Widget _buildOnboardingOverlay() {
    final progressPercent = (_onboardingProgress * 100).toInt();

    return Semantics(
      // ✅ Λέει στον screen reader ότι αυτό είναι dialog
      // οπότε το focus μεταφέρεται αυτόματα εδώ.
      scopesRoute: true,
      explicitChildNodes: true,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Το εικονίδιο είναι διακοσμητικό — το αποκλείουμε
                ExcludeSemantics(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.storage_rounded,
                      size: 36,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // ✅ Συγχωνεύουμε τίτλο + υπότιτλο σε ένα heading
                Semantics(
                  header: true,
                  label:
                      'Παρακαλώ περιμένετε. Γίνεται δημιουργία της Βάσης σας.',
                  excludeSemantics: true,
                  child: const Column(
                    children: [
                      Text(
                        'Παρακαλώ περιμένετε',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1B1F),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Γίνεται δημιουργία της Βάσης σας',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF49454F),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ✅ Το progress bar με liveRegion ώστε να ανακοινώνεται
                // κάθε αλλαγή προόδου αυτόματα.
                Semantics(
                  liveRegion: true,
                  label:
                      'Πρόοδος εγκατάστασης: $progressPercent τοις εκατό. $_onboardingMessage',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _onboardingProgress,
                          minHeight: 10,
                          backgroundColor: Colors.blue.shade50,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _onboardingMessage,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$progressPercent%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _isLogin ? 'Οθόνη σύνδεσης' : 'Οθόνη εγγραφής',
      namesRoute: true,
      explicitChildNodes: true,
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF42A5F5),
                    Color(0xFF1976D2),
                    Color(0xFF7B1FA2),
                  ],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxContentWidth = constraints.maxWidth > 600
                        ? 500.0
                        : constraints.maxWidth;

                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 36.0,
                          ),
                          child: Column(
                            children: [
                              Semantics(
                                label: 'Λογότυπο εφαρμογής',
                                image: true,
                                child: Image.asset(
                                  'assets/icons/finance1.webp',
                                  width: 140.0,
                                  height: 140.0,
                                ),
                              ),
                              const SizedBox(height: 24.0),

                              Semantics(
                                header: true,
                                liveRegion: true,
                                label: _isLogin ? 'Σύνδεση' : 'Εγγραφή',
                                excludeSemantics: true,
                                child: Text(
                                  _isLogin ? 'Σύνδεση' : 'Εγγραφή',
                                  style: const TextStyle(
                                    fontSize: 26.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.yellow,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12.0),

                              if (_errorMessage != null)
                                Semantics(
                                  label: 'Μήνυμα: $_errorMessage',
                                  liveRegion: true,
                                  child: Container(
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: BoxDecoration(
                                      color: _errorMessage!.startsWith('✅')
                                          ? Colors.green.withValues(alpha: 0.2)
                                          : Colors.red.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(
                                        color: _errorMessage!.startsWith('✅')
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 20.0),

                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                      decoration: const InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(),
                                        labelText: 'Email',
                                        labelStyle: TextStyle(
                                          color: Colors.black54,
                                        ),
                                        errorStyle: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Υποχρεωτικό πεδίο';
                                        }
                                        if (!value.contains('@')) {
                                          return 'Μη έγκυρο email';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16.0),

                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: !_showPassword,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: const OutlineInputBorder(),
                                        labelText: 'Κωδικός',
                                        labelStyle: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _showPassword
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                          ),
                                          onPressed: _togglePasswordVisibility,
                                          tooltip: _showPassword
                                              ? 'Απόκρυψη κωδικού'
                                              : 'Εμφάνιση κωδικού',
                                        ),
                                        errorStyle: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Υποχρεωτικός κωδικός';
                                        }
                                        if (value.length < 6) {
                                          return 'Τουλάχιστον 6 χαρακτήρες';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (!_isLogin) ...[
                                      const SizedBox(height: 16.0),
                                      TextFormField(
                                        controller: _confirmPassController,
                                        obscureText: !_showPassword,
                                        style: const TextStyle(
                                          color: Colors.black,
                                        ),
                                        decoration: const InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(),
                                          labelText: 'Επιβεβαίωση Κωδικού',
                                          labelStyle: TextStyle(
                                            color: Colors.black54,
                                          ),
                                          errorStyle: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Επιβεβαίωσε τον κωδικό';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                    const SizedBox(height: 24.0),

                                    ElevatedButton(
                                      onPressed: _isLoading ? null : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14.0,
                                        ),
                                        minimumSize: const Size(
                                          double.infinity,
                                          48.0,
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    Colors.white,
                                                  ),
                                            )
                                          : Text(
                                              _isLogin ? 'Σύνδεση' : 'Εγγραφή',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18.0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 12.0),

                                    TextButton(
                                      onPressed: _resetPassword,
                                      child: const Text(
                                        'Ξέχασες τον κωδικό;',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(height: 12.0),

                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _isLogin = !_isLogin;
                                          _errorMessage = null;
                                        });
                                      },
                                      child: Text(
                                        _isLogin
                                            ? 'Δεν έχεις λογαριασμό; Εγγραφή'
                                            : 'Έχεις ήδη λογαριασμό; Σύνδεση',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
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

            // ✅ ΝΕΟ: Onboarding overlay
            if (_isOnboarding) _buildOnboardingOverlay(),
          ],
        ),
      ),
    );
  }
}
