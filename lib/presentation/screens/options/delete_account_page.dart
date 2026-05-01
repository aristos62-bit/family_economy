// ============================================================
// FILE: delete_account_page.dart
// Path: lib/presentation/screens/options/delete_account_page.dart
// Ρόλος: Σελίδα διαγραφής λογαριασμού (διπλή επιβεβαίωση + offline guard)
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/services/connectivity_service.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Σελίδα Διαγραφής Λογαριασμού. Απαιτείται διπλή επιβεβαίωση.',
    );
  }

  // Responsive helpers (ίδια λογική με OptionsPage)
  double _getMaxWidth(double screenWidth) {
    if (screenWidth > 1200) return 800; // Desktop
    if (screenWidth > 600) return 700; // Tablet
    return screenWidth; // Mobile
  }

  double _getHorizontalPadding(double screenWidth) {
    if (screenWidth > 1200) return 32.0; // Desktop
    if (screenWidth > 600) return 24.0; // Tablet
    return 16.0; // Mobile
  }

  Future<void> _startDeleteFlow() async {
    // ✅ Offline guard
    final isOnline = context.read<ConnectivityService>().isOnline;
    if (!isOnline) {
      AccessibilityService.announceError('Δεν υπάρχει σύνδεση στο internet');

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Χωρίς σύνδεση'),
          content: const Text(
            'Για λόγους ασφαλείας, η διαγραφή λογαριασμού απαιτεί ενεργή σύνδεση στο internet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // ✅ Confirmation #1
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Επιβεβαίωση'),
        content: const Text(
          'Είστε σίγουροι ότι θέλετε να διαγράψετε τον λογαριασμό σας;\n\n'
              'Η ενέργεια είναι μη αναστρέψιμη.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Άκυρο'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Συνέχεια',
              style: TextStyle(color: ColorsUI.getError(context.brightness)),
            ),
          ),
        ],
      ),
    );

    if (confirm1 != true || !mounted) return;

    // ✅ Confirmation #2 (τελική)
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Τελική Επιβεβαίωση',
          style: TextStyle(color: ColorsUI.getError(context.brightness)),
        ),
        content: const Text(
          'Τελευταία προειδοποίηση:\n'
              'Αν πατήσετε "Διαγραφή", ο λογαριασμός θα διαγραφεί οριστικά.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Άκυρο'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Διαγραφή',
              style: TextStyle(color: ColorsUI.getError(context.brightness)),
            ),
          ),
        ],
      ),
    );

    if (confirm2 != true || !mounted) return;

    await _performDelete();
  }

  Future<void> _performDelete() async {
    if (_isDeleting) return;

    setState(() => _isDeleting = true);

    final userId = context.session.userId;
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    try {
      // ✅ (1) Σημείωσε τον χρήστη ως deleted στη Firestore (ασφαλές και γρήγορο)
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {
          'deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        },
        SetOptions(merge: true),
      );

      // ✅ (2) Προσπάθησε να διαγράψεις τον Auth user
      if (user != null) {
        await user.delete();
      }

      if (!mounted) return;

      AccessibilityService.announceSuccess('Ο λογαριασμός διαγράφηκε');

      // ✅ (3) Κλείνουμε τη σελίδα πίσω (η ροή logout/navigation θα μπει στο επόμενο βήμα)
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // Πολύ συχνό: requires-recent-login
      if (e.code == 'requires-recent-login') {
        AccessibilityService.announceError(
          'Για λόγους ασφαλείας απαιτείται πρόσφατη σύνδεση',
        );

        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Απαιτείται σύνδεση'),
            content: const Text(
              'Για λόγους ασφαλείας, πρέπει να συνδεθείτε ξανά και μετά να δοκιμάσετε διαγραφή λογαριασμού.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        AccessibilityService.announceError('Σφάλμα διαγραφής: ${e.code}');

        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Σφάλμα'),
            content: Text('Αποτυχία διαγραφής λογαριασμού: ${e.code}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      AccessibilityService.announceError('Σφάλμα διαγραφής: $e');

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Σφάλμα'),
          content: Text('Αποτυχία διαγραφής λογαριασμού: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Διαγραφή Λογαριασμού'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = _getMaxWidth(constraints.maxWidth);

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: _getHorizontalPadding(constraints.maxWidth),
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Προσοχή',
                          style: context.h2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Η διαγραφή λογαριασμού είναι μη αναστρέψιμη.\n'
                            'Θα χαθούν τα δεδομένα πρόσβασης και ο λογαριασμός δεν θα μπορεί να επανέλθει.',
                        style: context.bodyMd.copyWith(color: context.cText2),
                      ),
                      const SizedBox(height: 20),

                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  ExcludeSemantics(
                                    child: Icon(Icons.warning_rounded,
                                        color: ColorsUI.getError(context.brightness)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Θα σας ζητηθεί διπλή επιβεβαίωση.',
                                      style: context.bodyMd.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              ElevatedButton(
                                onPressed: _isDeleting ? null : _startDeleteFlow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ColorsUI.getError(context.brightness),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _isDeleting
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
                                    : const Text('Διαγραφή Λογαριασμού'),
                              ),
                              const SizedBox(height: 10),

                              OutlinedButton(
                                onPressed: _isDeleting ? null : () => Navigator.of(context).maybePop(),
                                child: const Text('Άκυρο'),
                              ),
                            ],
                          ),
                        ),
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
}
