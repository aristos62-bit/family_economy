import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/session/session_scope.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AccessibilityService.announceAfterFirstFrame(context, 'Αλλαγή κωδικού');
    });
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  double _getMaxWidth(double w) {
    if (w > 1200) return 720;
    if (w > 600) return 640;
    return w;
  }

  double _getHorizontalPadding(double w) {
    if (w > 1200) return 32.0;
    if (w > 600) return 24.0;
    return 16.0;
  }

  String? _validate() {
    final current = _currentCtrl.text.trim();
    final next = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (current.isEmpty) {
      return 'Γράψτε τον τρέχοντα κωδικό';
    }
    if (next.isEmpty) {
      return 'Γράψτε νέο κωδικό';
    }
    if (next.length < 6) {
      return 'Ο νέος κωδικός πρέπει να έχει τουλάχιστον 6 χαρακτήρες';
    }
    if (next != confirm) {
      return 'Ο νέος κωδικός και η επιβεβαίωση δεν ταιριάζουν';
    }
    if (current == next) {
      return 'Ο νέος κωδικός δεν μπορεί να είναι ίδιος με τον τρέχοντα';
    }
    return null;
  }

  Future<void> _changePassword() async {
    if (_saving) return;

    setState(() {
      _error = null;
    });

    final v = _validate();
    if (v != null) {
      AccessibilityService.announceError(v);
      setState(() => _error = v);
      return;
    }

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Δεν βρέθηκε ενεργός χρήστης');
      }

      final email = user.email;
      if (email == null || email.isEmpty) {
        throw Exception(
          'Ο λογαριασμός δεν έχει email. Δεν γίνεται αλλαγή κωδικού.',
        );
      }

      // ✅ Re-authentication (απαραίτητο από Firebase για updatePassword)
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _currentCtrl.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);

      await user.updatePassword(_newCtrl.text.trim());

      if (!mounted) return;

      AccessibilityService.announceSuccess('Ο κωδικός άλλαξε επιτυχώς');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ο κωδικός άλλαξε επιτυχώς'),
          backgroundColor: ColorsUI.getIncomeColor(context.brightness),
        ),
      );

      Navigator.of(context).maybePop();
    } on FirebaseAuthException catch (e) {
      final msg = _mapAuthError(e);
      if (mounted) {
        AccessibilityService.announceError(msg);
        setState(() => _error = msg);
      }
    } catch (e) {
      final msg = 'Σφάλμα: $e';
      if (mounted) {
        AccessibilityService.announceError(msg);
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Ο τρέχων κωδικός είναι λάθος';
      case 'weak-password':
        return 'Ο νέος κωδικός είναι πολύ αδύναμος';
      case 'requires-recent-login':
        return 'Για λόγους ασφαλείας, κάντε ξανά σύνδεση και δοκιμάστε';
      default:
        return 'Αποτυχία αλλαγής κωδικού (${e.code})';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Εδώ δείχνω ότι είμαστε κάτω από SessionScope (δεν το αλλάζω/χρησιμοποιώ αλλιώς)
    // ignore: unused_local_variable
    final userId = context.session.userId;

    return Scaffold(
      backgroundColor: ColorsUI.getBackground(context.brightness),
      appBar: AppBar(title: const Text('Αλλαγή Κωδικού')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = _getMaxWidth(constraints.maxWidth);
            final pad = _getHorizontalPadding(constraints.maxWidth);

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: pad, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Αλλαγή κωδικού',
                          style: TypographyUI.titleLarge(context.brightness),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Για ασφάλεια χρειάζεται να γράψετε τον τρέχοντα κωδικό.',
                        style: TypographyUI.bodyMedium(context.brightness)
                            .copyWith(
                              color: ColorsUI.getTextSecondary(
                                context.brightness,
                              ),
                            ),
                      ),
                      const SizedBox(height: 16),

                      if (_error != null) ...[
                        ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ColorsUI.getError(
                                context.brightness,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ColorsUI.getError(
                                  context.brightness,
                                ).withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: TypographyUI.bodyMedium(context.brightness)
                                  .copyWith(
                                    color: ColorsUI.getError(
                                      context.brightness,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      _passwordField(
                        label: 'Τρέχων κωδικός',
                        controller: _currentCtrl,
                        show: _showCurrent,
                        onToggle: () =>
                            setState(() => _showCurrent = !_showCurrent),
                        semanticsLabel: 'Πεδίο τρέχοντος κωδικού',
                      ),
                      const SizedBox(height: 12),

                      _passwordField(
                        label: 'Νέος κωδικός',
                        controller: _newCtrl,
                        show: _showNew,
                        onToggle: () => setState(() => _showNew = !_showNew),
                        semanticsLabel: 'Πεδίο νέου κωδικού',
                      ),
                      const SizedBox(height: 12),

                      _passwordField(
                        label: 'Επιβεβαίωση νέου κωδικού',
                        controller: _confirmCtrl,
                        show: _showConfirm,
                        onToggle: () =>
                            setState(() => _showConfirm = !_showConfirm),
                        semanticsLabel: 'Πεδίο επιβεβαίωσης νέου κωδικού',
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).maybePop(),
                              child: const Text('Άκυρο'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _changePassword,
                              child: _saving
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: ExcludeSemantics(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                ),
                              )
                                  : const Text('Αλλαγή κωδικού'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool show,
    required VoidCallback onToggle,
    required String semanticsLabel,
  }) {
    return Semantics(
      label: semanticsLabel,
      textField: true,
      child: TextField(
        controller: controller,
        obscureText: !show,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: ColorsUI.getInputFill(context.brightness),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: IconButton(
            tooltip: show ? 'Απόκρυψη' : 'Εμφάνιση',
            onPressed: onToggle,
            icon: Icon(show ? Icons.visibility_off : Icons.visibility),
          ),
        ),
      ),
    );
  }
}
