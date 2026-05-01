// ============================================================
// FILE: message_service.dart
// Path: lib/core/services/message_service.dart
// Ρόλος: Κεντρική διαχείριση μηνυμάτων με accessibility & offline support
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';

enum MessageType {
  success,
  error,
  info,
  warning,
  sync,  // Για sync messages
}

class MessageService {
  // ✅ Singleton pattern
  MessageService._();

  static final MessageService instance = MessageService._();

  // Track pending operations for sync notification
  int _pendingOperations = 0;

  void incrementPending() => _pendingOperations++;

  void resetPending() => _pendingOperations = 0;

  int get pendingCount => _pendingOperations;

  /// Show message with automatic online/offline handling
  static void show(BuildContext context, {
    required String message,
    MessageType type = MessageType.info,
    Duration? duration,
    bool announceAccessibility = true,
  }) {
    final connectivity = context.read<ConnectivityService>();
    final isOffline = connectivity.isOffline;

    // ✅ DEBUG LOGGING
    DebugConfig.print('═══════════════════════════════════════════');
    DebugConfig.print('MessageService.show() called');
    DebugConfig.print('  Original message: $message');
    DebugConfig.print('  Type: $type');
    DebugConfig.print('  isOffline: $isOffline');
    DebugConfig.print('═══════════════════════════════════════════');

    // ✅ Determine actual message based on offline status
    String displayMessage = message;
    MessageType displayType = type;

    // Αν είναι offline και το message είναι success, αλλάζουμε σε warning
    if (isOffline && type == MessageType.success) {
      displayMessage = 'Θα συγχρονιστεί με επανασύνδεση';
      displayType = MessageType.warning;
      instance.incrementPending();

      DebugConfig.print('🟠 OFFLINE DETECTED - Message changed to: $displayMessage');
      DebugConfig.print('🟠 Pending count: ${instance.pendingCount}');
    } else {
      DebugConfig.print('✅ Showing normal message: $displayMessage');
    }

    // ✅ Show SnackBar
    _showSnackBar(
      context,
      message: displayMessage,
      type: displayType,
      duration: duration,
    );

    // ✅ Accessibility announcement
    if (announceAccessibility) {
      _announceMessage(displayMessage, displayType);
    }
  }

  /// Show success message (auto-handles offline)
  static void showSuccess(BuildContext context,
      String message, {
        bool announceAccessibility = true,
      }) {
    show(
      context,
      message: message,
      type: MessageType.success,
      duration: const Duration(seconds: 2),
      announceAccessibility: announceAccessibility,
    );
  }

  /// Show error message
  static void showError(BuildContext context,
      String message, {
        bool announceAccessibility = true,
      }) {
    show(
      context,
      message: message,
      type: MessageType.error,
      duration: const Duration(seconds: 3),
      announceAccessibility: announceAccessibility,
    );
  }

  /// Show info message
  static void showInfo(BuildContext context,
      String message, {
        bool announceAccessibility = true,
      }) {
    show(
      context,
      message: message,
      type: MessageType.info,
      duration: const Duration(seconds: 2),
      announceAccessibility: announceAccessibility,
    );
  }

  /// Show warning message
  static void showWarning(BuildContext context,
      String message, {
        bool announceAccessibility = true,
      }) {
    show(
      context,
      message: message,
      type: MessageType.warning,
      duration: const Duration(seconds: 3),
      announceAccessibility: announceAccessibility,
    );
  }

  /// Show sync completion message (only if there were pending operations)
  static void showSyncComplete(BuildContext context) {
    final count = instance.pendingCount;

    DebugConfig.print('═══════════════════════════════════════════');
    DebugConfig.print('MessageService.showSyncComplete() called');
    DebugConfig.print('  Pending count: $count');
    DebugConfig.print('═══════════════════════════════════════════');

    if (count == 0) {
      DebugConfig.print('⚠️ No pending operations - NOT showing sync message');
      return;
    }

    final message = count == 1
        ? 'Συγχρονισμός ολοκληρώθηκε'
        : 'Συγχρονισμός ολοκληρώθηκε ($count εγγραφές)';

    DebugConfig.print('✅ Showing sync message: $message');

    _showSnackBar(
      context,
      message: message,
      type: MessageType.sync,
      duration: const Duration(seconds: 3),
    );

    _announceMessage(message, MessageType.sync);

    instance.resetPending();
  }

  /// Internal: Show SnackBar with theming
  static void _showSnackBar(BuildContext context, {
    required String message,
    required MessageType type,
    Duration? duration,
  }) {
    final brightness = Theme
        .of(context)
        .brightness;
    final isDark = brightness == Brightness.dark;

    // ✅ Colors based on type and theme
    final colors = _getColors(type, isDark);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getIcon(type),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colors.background,
        duration: duration ?? const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 4,
      ),
    );
  }

  /// Internal: Accessibility announcement
  static void _announceMessage(String message, MessageType type) {
    switch (type) {
      case MessageType.success:
      case MessageType.sync:
        AccessibilityService.announceSuccess(message);
        break;
      case MessageType.error:
        AccessibilityService.announceError(message);
        break;
      case MessageType.warning:
      case MessageType.info:
        AccessibilityService.announcePolite(message);
        break;
    }
  }

  /// Internal: Get icon for message type
  static IconData _getIcon(MessageType type) {
    switch (type) {
      case MessageType.success:
        return Icons.check_circle;
      case MessageType.error:
        return Icons.error;
      case MessageType.warning:
        return Icons.schedule;
      case MessageType.info:
        return Icons.info;
      case MessageType.sync:
        return Icons.cloud_done;
    }
  }

  /// Internal: Get colors for message type
  static ({Color background, Color text}) _getColors(MessageType type,
      bool isDark,) {
    switch (type) {
      case MessageType.success:
        return (
        background: isDark ? const Color(0xFF2E7D32) : const Color(0xFF43A047),
        text: Colors.white,
        );

      case MessageType.error:
        return (
        background: isDark ? const Color(0xFFC62828) : const Color(0xFFE53935),
        text: Colors.white,
        );

      case MessageType.warning:
        return (
        background: isDark ? const Color(0xFFE65100) : const Color(0xFFF57C00),
        text: Colors.white,
        );

      case MessageType.info:
        return (
        background: isDark ? const Color(0xFF1565C0) : const Color(0xFF1976D2),
        text: Colors.white,
        );

      case MessageType.sync:
        return (
        background: isDark ? const Color(0xFF00695C) : const Color(0xFF00897B),
        text: Colors.white,
        );
    }
  }
}
