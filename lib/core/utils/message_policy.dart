// ============================================================
// FILE: message_policy.dart
// Path: lib/core/utils/message_policy.dart
// Ρόλος: Μία πολιτική για όλα τα μηνύματα προς χρήστη (L11).
// Καθαρή λογική — χωρίς BuildContext / ScaffoldMessenger.
// ============================================================

import 'package:material_ui/material_ui.dart';

import '../errors/user_message_exception.dart';
import '../theme/ui_tokens.dart';

/// Οι τέσσερις τύποι μηνυμάτων της εφαρμογής.
enum MessageKind { success, info, warning, error }

/// Έτοιμο προς εμφάνιση μήνυμα: κείμενο, χρώματα, εικονίδιο, χρόνος.
class MessageSpec {
  const MessageSpec({
    required this.text,
    required this.kind,
    required this.duration,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.persist,
  });

  final String text;
  final MessageKind kind;
  final Duration duration;
  final Color background;
  final Color foreground;
  final IconData icon;
  final bool persist;
}

/// Κεντρικοί κανόνες για χρόνους, χρώματα, contrast και ασφαλή κείμενα.
class MessagePolicy {
  MessagePolicy._();

  static const Duration successDuration = Duration(seconds: 3);
  static const Duration infoDuration = Duration(seconds: 3);
  static const Duration warningDuration = Duration(seconds: 5);
  static const Duration errorDuration = Duration(seconds: 6);

  /// Πάνω από 600 logical pixels το SnackBar περιορίζεται σε 560.
  static const double wideBreakpoint = 600;
  static const double wideWidth = 560;

  static const String genericError = 'Κάτι πήγε στραβά. Δοκιμάστε ξανά.';

  static const String _tagsEmptyName =
      'Το όνομα του tag δεν μπορεί να είναι κενό';
  static final RegExp _tagsDuplicate = RegExp(r'^Το tag ".*" υπάρχει ήδη$');

  static MessageSpec build(
    MessageKind kind,
    String text,
    Brightness brightness, {
    bool hasAction = false,
    bool? persist,
    Duration? duration,
  }) {
    final background = backgroundFor(kind, brightness);
    return MessageSpec(
      text: text,
      kind: kind,
      duration: duration ?? durationFor(kind),
      background: background,
      foreground: foregroundFor(background),
      icon: iconFor(kind),
      persist: persist ?? hasAction,
    );
  }

  static Duration durationFor(MessageKind kind) {
    switch (kind) {
      case MessageKind.success:
        return successDuration;
      case MessageKind.info:
        return infoDuration;
      case MessageKind.warning:
        return warningDuration;
      case MessageKind.error:
        return errorDuration;
    }
  }

  static Color backgroundFor(MessageKind kind, Brightness brightness) {
    switch (kind) {
      case MessageKind.success:
        return ColorsUI.getSuccess(brightness);
      case MessageKind.info:
        return ColorsUI.getInfo(brightness);
      case MessageKind.warning:
        return ColorsUI.getWarning(brightness);
      case MessageKind.error:
        return ColorsUI.getError(brightness);
    }
  }

  /// Μαύρο ή λευκό — ό,τι δίνει μεγαλύτερη αντίθεση στο [background].
  static Color foregroundFor(Color background) {
    final luminance = background.computeLuminance();
    final whiteContrast = 1.05 / (luminance + 0.05);
    final blackContrast = (luminance + 0.05) / 0.05;
    return whiteContrast >= blackContrast ? Colors.white : Colors.black;
  }

  static IconData iconFor(MessageKind kind) {
    switch (kind) {
      case MessageKind.success:
        return Icons.check_circle_outline;
      case MessageKind.info:
        return Icons.info_outline;
      case MessageKind.warning:
        return Icons.warning_amber_rounded;
      case MessageKind.error:
        return Icons.error_outline;
    }
  }

  /// `null` = κινητό/στενή οθόνη· 560 = desktop/web.
  static double? widthFor(double screenWidth) =>
      screenWidth > wideBreakpoint ? wideWidth : null;

  static String actionError(String action) =>
      'Αποτυχία $action. Δοκιμάστε ξανά.';

  /// Μόνο ό,τι έχει δηλωθεί ρητά ως φιλικό προς χρήστη περνά.
  static String fromError(Object error, {required String action}) {
    if (error is UserMessageException) {
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
    }
    return actionError(action);
  }

  /// Allowlist για τα δύο γνωστά μηνύματα του `TagsProvider`.
  static String fromProvider(String? message, {required String action}) {
    if (message == null) return actionError(action);
    if (message == _tagsEmptyName) return message;
    if (_tagsDuplicate.hasMatch(message)) return message;
    return actionError(action);
  }
}
