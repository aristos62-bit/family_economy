// ============================================================
// FILE: app_messenger.dart
// Path: lib/core/messaging/app_messenger.dart
// Ρόλος: Κεντρικός presenter μηνυμάτων (L11).
// Ουρά ανά ScaffoldMessengerState + αντικατάσταση μόνο μη-persist.
// ============================================================

import 'package:material_ui/material_ui.dart';

import '../utils/message_policy.dart';

/// Εμφανίζει όλα τα μηνύματα της εφαρμογής με ενιαίο τρόπο.
///
/// - Χρώματα, εικονίδιο και χρόνος από το [MessagePolicy].
/// - Πλάτος 560 σε οθόνες > 600 logical pixels, αλλιώς default περιθώρια.
/// - Μία ουρά ανά [ScaffoldMessengerState]: ένα μη-persist μήνυμα
///   αντικαθίσταται από το επόμενο· ένα persistent προστατεύεται.
class AppMessenger {
  AppMessenger._();

  static final Expando<List<_QueueEntry>> _queues = Expando<List<_QueueEntry>>(
    'AppMessenger',
  );

  static void success(
    BuildContext context,
    String text, {
    ScaffoldMessengerState? messenger,
    String? actionLabel,
    VoidCallback? onAction,
    bool? persist,
    Duration? duration,
  }) {
    show(
      context,
      MessageKind.success,
      text,
      messenger: messenger,
      actionLabel: actionLabel,
      onAction: onAction,
      persist: persist,
      duration: duration,
    );
  }

  static void info(
    BuildContext context,
    String text, {
    ScaffoldMessengerState? messenger,
    String? actionLabel,
    VoidCallback? onAction,
    bool? persist,
    Duration? duration,
  }) {
    show(
      context,
      MessageKind.info,
      text,
      messenger: messenger,
      actionLabel: actionLabel,
      onAction: onAction,
      persist: persist,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context,
    String text, {
    ScaffoldMessengerState? messenger,
    String? actionLabel,
    VoidCallback? onAction,
    bool? persist,
    Duration? duration,
  }) {
    show(
      context,
      MessageKind.warning,
      text,
      messenger: messenger,
      actionLabel: actionLabel,
      onAction: onAction,
      persist: persist,
      duration: duration,
    );
  }

  static void error(
    BuildContext context,
    String text, {
    ScaffoldMessengerState? messenger,
    String? actionLabel,
    VoidCallback? onAction,
    bool? persist,
    Duration? duration,
  }) {
    show(
      context,
      MessageKind.error,
      text,
      messenger: messenger,
      actionLabel: actionLabel,
      onAction: onAction,
      persist: persist,
      duration: duration,
    );
  }

  /// Κοινό σημείο εισόδου για κάθε μήνυμα.
  static void show(
    BuildContext context,
    MessageKind kind,
    String text, {
    ScaffoldMessengerState? messenger,
    String? actionLabel,
    VoidCallback? onAction,
    bool? persist,
    Duration? duration,
  }) {
    assert(
      (actionLabel == null) == (onAction == null),
      'actionLabel και onAction πάνε πάντα μαζί',
    );

    final state = messenger ?? ScaffoldMessenger.maybeOf(context);
    if (state == null) return;

    final hasAction = actionLabel != null && onAction != null;
    final spec = MessagePolicy.build(
      kind,
      text,
      Theme.of(context).brightness,
      hasAction: hasAction,
      persist: persist,
      duration: duration,
    );

    final queue = _queues[state] ??= <_QueueEntry>[];
    if (queue.isNotEmpty && !queue.first.persistent) {
      queue.removeAt(0);
      state.removeCurrentSnackBar();
    }

    final entry = _QueueEntry(spec.persist);
    queue.add(entry);

    final controller = state.showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            Icon(spec.icon, color: spec.foreground, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(spec.text, style: TextStyle(color: spec.foreground)),
            ),
          ],
        ),
        backgroundColor: spec.background,
        behavior: SnackBarBehavior.floating,
        width: MessagePolicy.widthFor(MediaQuery.sizeOf(context).width),
        duration: spec.duration,
        persist: spec.persist,
        action: hasAction
            ? SnackBarAction(
                label: actionLabel,
                textColor: spec.foreground,
                onPressed: onAction,
              )
            : null,
      ),
    );

    controller.closed.whenComplete(() {
      queue.remove(entry);
      if (queue.isEmpty) _queues[state] = null;
    });
  }
}

class _QueueEntry {
  const _QueueEntry(this.persistent);

  final bool persistent;
}
