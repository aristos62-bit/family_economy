import 'package:local_auth/local_auth.dart';
import 'package:family_economy/core/utils/debug_config.dart';

class BiometricAuthService {
  BiometricAuthService._();
  static final BiometricAuthService instance = BiometricAuthService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Υπάρχει διαθέσιμο βιομετρικό στη συσκευή;
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Ζητάει δακτυλικό / Face ID
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
      );
    } catch (e, st) {
      DebugConfig.print('❌ Biometric authenticate exception: $e');
      DebugConfig.print('❌ type: ${e.runtimeType}');
      DebugConfig.print('$st');
      return false;
    }
  }
}
