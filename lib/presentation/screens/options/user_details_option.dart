import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/session/session_scope.dart';

class UserDetailsPage extends StatefulWidget {
  const UserDetailsPage({super.key});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // User data
  Map<String, dynamic>? _userData;

  // Editable controllers
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  String _selectedLanguage = 'el';
  String _selectedCurrency = 'EUR';

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _usernameController = TextEditingController();
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Σελίδα Στοιχείων Χρήστη. Επεξεργασία προφίλ λογαριασμού.',
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userId = context.session.userId;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _displayNameController.text = _userData?['display_name'] ?? '';
          _usernameController.text = _userData?['username'] ?? '';
          _selectedLanguage = _userData?['preferred_language'] ?? 'el';
          _selectedCurrency = _userData?['default_currency'] ?? 'EUR';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Δεν βρέθηκαν στοιχεία χρήστη';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Σφάλμα φόρτωσης: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    final userId = context.session.userId;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'display_name': _displayNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'preferred_language': _selectedLanguage,
        'default_currency': _selectedCurrency,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Οι αλλαγές αποθηκεύτηκαν επιτυχώς'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Αποτυχία αποθήκευσης: ${e.toString()}';
        _isSaving = false;
      });

      AccessibilityService.announceError(_errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Στοιχεία Χρήστη'),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Semantics(
      liveRegion: true,
      label: 'Φόρτωση στοιχείων χρήστη. Παρακαλώ περιμένετε.',
      excludeSemantics: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: CircularProgressIndicator(color: context.cPrimary),
              ),
              const SizedBox(height: 16),
              ExcludeSemantics(
                child: Text('Φόρτωση στοιχείων...', style: context.bodyMd),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: context.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Κλείσιμο'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final userId = context.session.userId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Display Name
          _buildTextField(
            label: 'Ονοματεπώνυμο',
            controller: _displayNameController,
            icon: Icons.badge_rounded,
            hint: 'π.χ. Βαγγέλης Παπαδόπουλος',
          ),
          const SizedBox(height: 16),

          // Username
          _buildTextField(
            label: 'Όνομα Χρήστη',
            controller: _usernameController,
            icon: Icons.alternate_email_rounded,
            hint: 'π.χ. vaggelis',
          ),
          const SizedBox(height: 16),

          // Language
          _buildDropdown(
            label: 'Γλώσσα',
            value: _selectedLanguage,
            icon: Icons.language_rounded,
            items: const [
              DropdownMenuItem(value: 'el', child: Text('Ελληνικά')),
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedLanguage = value);
              }
            },
          ),
          const SizedBox(height: 16),

          // Currency
          _buildDropdown(
            label: 'Νόμισμα',
            value: _selectedCurrency,
            icon: Icons.euro_rounded,
            items: [
              const DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
              const DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
              const DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCurrency = value);
              }
            },
          ),
          const SizedBox(height: 24),

          // Info Card
          _buildInfoCard(userId),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).maybePop(),
                  child: const Text('Άκυρο'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  child: _isSaving
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
                      : const Text('Αποθήκευση'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TypographyUI.labelLarge(context.brightness),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: ExcludeSemantics(
              child: Icon(icon, size: 20),
            ),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TypographyUI.labelLarge(context.brightness),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: ExcludeSemantics(
              child: Icon(icon, size: 20),
            ),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String userId) {
    DateTime? asDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      return DateTime.tryParse(v.toString());
    }

    final createdAt = asDate(_userData?['created_at']);
    final lastSync = asDate(_userData?['last_sync_at']);


    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: context.cPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.cPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.info_outline, size: 16, color: context.cPrimary),
              ),
              const SizedBox(width: 8),
              Text(
                'Πληροφορίες Λογαριασμού',
                style: TypographyUI.labelMedium(context.brightness).copyWith(
                  color: context.cPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('User ID', '${userId.substring(0, 12)}...'),
          _buildInfoRow('Πάροχος', _userData?['auth_provider'] ?? 'N/A'),
          if (createdAt != null)
            _buildInfoRow(
              'Δημιουργία',
              '${createdAt.day}/${createdAt.month}/${createdAt.year}',
            ),
          if (lastSync != null)
            _buildInfoRow(
              'Τελευταίος συγχρονισμός',
              '${lastSync.day}/${lastSync.month}/${lastSync.year}',
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.bodySm),
          Text(
            value,
            style: context.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
