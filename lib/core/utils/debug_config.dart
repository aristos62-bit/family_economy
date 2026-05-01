import 'package:flutter/foundation.dart';

class DebugConfig {

  /// 🔧 Κεντρικός διακόπτης logs
  static const bool _debug = true;   // true = logs ON, false = logs OFF

  static bool get isDebug => _debug;

  static final Stopwatch _startupWatch = Stopwatch()..start();

  /// Κανονικά debug logs
  static void print(Object? object) {
    if (_debug) {
      debugPrint(object.toString());
    }
  }

  /// Startup performance logs
  static void startup(String label) {
    if (_debug) {
      final ms = _startupWatch.elapsedMilliseconds;
      debugPrint('🚀 STARTUP +${ms}ms  $label');
    }
  }
}