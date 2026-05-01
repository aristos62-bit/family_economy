import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:family_economy/core/services/biometric_auth_service.dart';
import 'package:family_economy/core/services/biometric_settings_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';

class BiometricGate extends StatefulWidget {
  final Widget child;

  const BiometricGate({super.key, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _unlocked = false;
  String? _error;

  // για να μην ξανατρέχει authenticate σε κάθε rebuild
  bool _authInProgress = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // safe start
    WidgetsBinding.instance.addPostFrameCallback((_) => _runGate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Αν ο χρήστης έχει ενεργό "always", όταν γυρνάει από background ξανακλειδώνει
    if (state == AppLifecycleState.resumed) {
      // ξαναπέρνα το gate (θα αποφασίσει μόνο του αν χρειάζεται)
      _runGate();
    }
  }

  Future<void> _runGate() async {
    if (!mounted) return;

    final uid = _uid;
    if (uid == null) {
      // δεν είναι logged-in -> δεν κάνουμε gate
      setState(() {
        _loading = false;
        _unlocked = true;
        _error = null;
      });
      return;
    }

    if (_authInProgress) return;
    _authInProgress = true;

    setState(() {
      _loading = true;
      _error = null;
    });
    AccessibilityService.announcePolite('Έλεγχος βιομετρικών. Παρακαλώ περιμένετε.');

    try {
      final settings = await BiometricSettingsService.instance.load(uid);

      // Αν δεν είναι ενεργό -> άνοιξε κατευθείαν
      if (!settings.enabled) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _unlocked = true;
        });
        return;
      }

      // Αν mode == on_demand -> επίσης μην μπλοκάρεις (αφού το θέλει “όταν το ζητήσω”)
      if (settings.mode == 'on_demand') {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _unlocked = true;
        });
        return;
      }

      // mode == always -> ζήτα βιομετρικό
      final available = await BiometricAuthService.instance.isAvailable();
      if (!available) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _unlocked =
              true; // fallback: αφήνουμε να μπει (ή μπορείς να κάνεις signOut)
          _error = 'Η συσκευή δεν υποστηρίζει βιομετρικά.';
        });
        return;
      }

      final ok = await BiometricAuthService.instance.authenticate(
        reason: 'Σύνδεση με βιομετρική ταυτοποίηση',
      );

      if (!mounted) return;

      if (ok) {
        setState(() {
          _loading = false;
          _unlocked = true;
        });
      } else {
        // απέτυχε/ακύρωσε -> μένουμε κλειδωμένοι και δείχνουμε κουμπί "Δοκίμασε ξανά"
        setState(() {
          _loading = false;
          _unlocked = false;
          _error = 'Αποτυχία βιομετρικής ταυτοποίησης.';
        });
      }
    } catch (e, st) {
      DebugConfig.print('❌ BiometricGate error: $e');
      DebugConfig.print('$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _unlocked =
            true; // fallback: μην μπλοκάρεις όλη την εφαρμογή λόγω Firestore
        _error = 'Σφάλμα φόρτωσης ρυθμίσεων βιομετρικών.';
      });
    } finally {
      _authInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    // Κλειδωμένο / Loading screen
    return Semantics(
      label: 'Οθόνη βιομετρικής ταυτοποίησης',
      namesRoute: true,
      explicitChildNodes: true,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_loading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text('Έλεγχος βιομετρικών...'),
                  ] else ...[
                    ExcludeSemantics(
                      child: const Icon(Icons.fingerprint, size: 48),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      label: _error ?? 'Απαιτείται βιομετρική ταυτοποίηση',
                      excludeSemantics: true,
                      child: Text(_error ?? 'Απαιτείται βιομετρική ταυτοποίηση'),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      hint: 'Ενεργοποιεί ξανά τη βιομετρική ταυτοποίηση',
                      child: ElevatedButton(
                        onPressed: _runGate,
                        child: const Text('Δοκίμασε ξανά'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
