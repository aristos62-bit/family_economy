import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/presentation/auth/app_start.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _announced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ Το MediaQuery καλείται εδώ γιατί το initState()
    // δεν έχει ακόμα πρόσβαση στο InheritedWidget (MediaQuery).
    if (!_controller.isAnimating &&
        _controller.status == AnimationStatus.dismissed) {
      final bool reduceMotion = MediaQuery.of(context).disableAnimations;
      _controller.duration = reduceMotion
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 1500);
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1500,
      ), // default, θα αντικατασταθεί στο didChangeDependencies
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    // ✅ ΒΕΛΤΙΩΣΗ: Καλούμε την αρχικοποίηση ΜΕΤΑ το πρώτο frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  // ✅ ΒΕΛΤΙΩΜΕΝΗ ΜΕΘΟΔΟΣ: Χωρίς hardcoded delays
  Future<void> _initializeApp() async {
    try {
      await precacheImage(
        const AssetImage('assets/icons/finance1.webp'),
        context,
      );
      await _controller.forward();

      if (!mounted) return;

      // ✅ Ανακοίνωση ΜΕΤΑ το animation — και περιμένουμε
      // αρκετά ώστε το TalkBack να την τελειώσει πριν φύγουμε.
      if (!_announced) {
        _announced = true;
        AccessibilityService.announcePolite(
          'Εκκίνηση εφαρμογής Οικογενειακός Προϋπολογισμός. Παρακαλώ περιμένετε.',
        );
        await Future.delayed(const Duration(milliseconds: 2500));
      }

      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      _navigateToNextScreen(user);
    } catch (e) {
      DebugConfig.print('Error initializing app: $e');
      if (mounted) {
        _navigateToNextScreen(null);
      }
    }
  }

  // ✅ Καθαρή πλοήγηση με βάση τον χρήστη
  Future<void> _navigateToNextScreen(User? user) async {
    // ✅ ΠΑΝΤΑ πάμε AppStart (gate). Αυτό θα αποφασίσει Login ή Home.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppStart()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF42A5F5), Color(0xFF1976D2), Color(0xFF7B1FA2)],
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Image.asset(
                          'assets/icons/finance1.webp',
                          width: 250.0,
                          height: 250.0,
                          cacheWidth: 200,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 40.0),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 32.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                offset: Offset(0.5, 0.5),
                                blurRadius: 1.5,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                          children: const [
                            TextSpan(
                              text: 'Οικογενειακός ',
                              style: TextStyle(color: Colors.greenAccent),
                            ),
                            TextSpan(
                              text: 'Προϋπολογισμός',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        'Διαχείριση Οικονομικών',
                        style: TextStyle(fontSize: 20.0, color: Colors.white70),
                      ),
                      const SizedBox(height: 60.0),
                      const Text(
                        'Φόρτωση...',
                        style: TextStyle(fontSize: 16.0, color: Colors.white70),
                      ),
                      const SizedBox(height: 20.0),
                      const SizedBox(
                        width: 40.0,
                        height: 40.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
