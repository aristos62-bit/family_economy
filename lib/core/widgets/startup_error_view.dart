// ============================================================
// FILE: startup_error_view.dart
// Path: lib/core/widgets/startup_error_view.dart
// Ρόλος: Κοινή διάταξη οθόνης σφάλματος εκκίνησης.
// Χρησιμοποιείται από το ErrorApp (main.dart) και το AppStart.
// - Scroll: χωρίς overflow σε μεγάλο textScale / μικρές οθόνες.
// - Μία κύρια ενέργεια + προαιρετική δευτερεύουσα.
// ============================================================

import 'package:material_ui/material_ui.dart';

class StartupErrorView extends StatelessWidget {
  const StartupErrorView({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.details,
    this.icon = Icons.error_outline,
    this.primaryIcon,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;

  final String primaryLabel;
  final VoidCallback onPrimary;

  /// Προαιρετικό τεχνικό κείμενο (εμφανίζεται σε monospace πλαίσιο).
  final String? details;

  final IconData icon;

  /// Αν δοθεί, η κύρια ενέργεια γίνεται `ElevatedButton.icon`.
  final IconData? primaryIcon;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final showDetails = details != null && details!.trim().isNotEmpty;
    final hasSecondary = secondaryLabel != null && onSecondary != null;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 80, color: Colors.red.shade700),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(fontSize: 16, color: Colors.red.shade800),
                textAlign: TextAlign.center,
              ),
              if (showDetails) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    details!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (hasSecondary)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSecondary,
                        child: Text(secondaryLabel!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _primaryButton()),
                  ],
                )
              else
                _primaryButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton() {
    final style = ElevatedButton.styleFrom(
      backgroundColor: Colors.red.shade700,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    );

    final icon = primaryIcon;
    if (icon == null) {
      return ElevatedButton(
        onPressed: onPrimary,
        style: style,
        child: Text(primaryLabel),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPrimary,
      icon: Icon(icon),
      label: Text(primaryLabel),
      style: style,
    );
  }
}