// ============================================================
// FILE: account_password_dialog.dart
// Path: lib/core/widgets/account_password_dialog.dart
// Ρόλος: Διάλογος κωδικού για reauthentication πριν τη διαγραφή (E90).
// - Κενός κωδικός → inline σφάλμα, ο διάλογος μένει ανοιχτός.
// - Επιστρέφει το **raw** κείμενο (όχι trimmed).
// ============================================================

import 'package:material_ui/material_ui.dart';

import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/account_deletion_policy.dart';

class AccountPasswordDialog extends StatefulWidget {
  const AccountPasswordDialog({super.key});

  /// Επιστρέφει τον κωδικό όπως πληκτρολογήθηκε, ή `null` σε ακύρωση.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const AccountPasswordDialog(),
    );
  }

  @override
  State<AccountPasswordDialog> createState() => _AccountPasswordDialogState();
}

class _AccountPasswordDialogState extends State<AccountPasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text;
    if (raw.trim().isEmpty) {
      final error = AccountDeletionPolicy.passwordEmptyMessage;
      setState(() => _error = error);
      AccessibilityService.announceError(error);
      return;
    }
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AccountDeletionPolicy.passwordPromptTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AccountDeletionPolicy.passwordPromptMessage),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: AccountDeletionPolicy.passwordLabel,
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AccountDeletionPolicy.cancelAction),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            AccountDeletionPolicy.deleteAction,
            style: TextStyle(color: ColorsUI.getError(context.brightness)),
          ),
        ),
      ],
    );
  }
}
