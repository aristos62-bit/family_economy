// ============================================================
// FILE: connectivity_service.dart (UPDATED WITH DEBOUNCE)
// Path: lib/core/services/connectivity_service.dart
// Ρόλος: Παρακολούθηση σύνδεσης internet
// ============================================================

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:family_economy/core/utils/debug_config.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = false;

  // ✅ Initialization flag
  bool _isInitialized = false;

  // ✅ Debounce timer για σταθερότητα
  Timer? _debounceTimer;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  bool get isInitialized => _isInitialized;

  /// Offline **επιβεβαιωμένο** (μετά την αρχική ανάγνωση) — E24/E19.
  /// Μία πηγή αλήθειας για τις φραγές που απαιτούν σύνδεση.
  bool get isConfirmedOffline => _isInitialized && !_isOnline;

  ConnectivityService() {
    _initConnectivity();
    _subscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);

      // ✅ Mark as initialized
      _isInitialized = true;
      notifyListeners();
      DebugConfig.print('✅ ConnectivityService initialized: isOnline=$_isOnline');
    } catch (e) {
      DebugConfig.print('❌ Connectivity check error: $e');

      // ✅ Even on error, mark as initialized
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final newIsOnline = results.any(
          (result) =>
      result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet,
    );

    // ✅ Cancel any pending debounce timer
    _debounceTimer?.cancel();

    // ✅ Αν αλλάζει από offline → online, περίμενε 2 δευτερόλεπτα
    if (!_isOnline && newIsOnline) {
      DebugConfig.print('🔄 Connection detected - waiting 2s to confirm...');

      _debounceTimer = Timer(const Duration(seconds: 2), () {
        // ✅ Double-check ότι είμαστε ακόμα online
        _confirmOnlineStatus();
      });
      return;
    }

    // ✅ Αν αλλάζει σε offline, ενημέρωσε ΑΜΕΣΩΣ
    if (_isOnline && !newIsOnline) {
      _isOnline = false;
      notifyListeners();
      DebugConfig.print('📴 Internet connection lost - switching to offline mode');
      return;
    }
  }

  void _confirmOnlineStatus() async {
    try {
      // ✅ Re-check connectivity
      final result = await _connectivity.checkConnectivity();
      final isStillOnline = result.any(
            (r) =>
        r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );

      if (isStillOnline && !_isOnline) {
        _isOnline = true;
        notifyListeners();

        DebugConfig.print('✅ Internet connection restored (confirmed)');
      } else {
        DebugConfig.print('⚠️ Connection unstable - staying offline');
      }
    } catch (e) {
      DebugConfig.print('❌ Error confirming online status: $e');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}