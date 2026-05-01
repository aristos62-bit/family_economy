// ============================================================
// FILE: database_cleanup_page.dart
// Path: lib/presentation/screens/options/database_cleanup_page.dart
// Ρόλος: UI για καθαρισμό βάσης δεδομένων
// ✅ Preview mode
// ✅ Confirmation dialogs
// ✅ Progress indicators
// ✅ Detailed reporting
// ✅ Accessibility support
// ============================================================

import 'package:flutter/material.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/services/database_cleanup_service.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';

class DatabaseCleanupPage extends StatefulWidget {
  const DatabaseCleanupPage({super.key});

  @override
  State<DatabaseCleanupPage> createState() => _DatabaseCleanupPageState();
}

class _DatabaseCleanupPageState extends State<DatabaseCleanupPage> {
  // ── State ──────────────────────────────────
  bool _cleanNotifications = true;
  bool _cleanBudgets = true;
  bool _cleanTransactions = true;
  bool _cleanCategories = false; // Επικίνδυνο - disabled by default
  bool _cleanSubcategories = false;
  bool _cleanOilTank = false;

  int _notificationsDays = 90;
  int _budgetsDays = 365;
  int _transactionsDays = 30;
  int _categoriesDays = 180;

  bool _isLoading = false;
  CleanupPreview? _preview;

  // ── Init ──────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityService.announceAfterFirstFrame(
        context,
        'Συντήρηση Βάσης Δεδομένων',
      );
    });
  }

  // ── Build ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bg = context.cPrimary;
    final fg = context.cOnPrimary;
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        iconTheme: IconThemeData(color: fg),
        actionsIconTheme: IconThemeData(color: fg),
        title: Text('Συντήρηση Βάσης', style: context.titleLg.withColor(fg)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWarningCard(),
              const SizedBox(height: 24),
              _buildOptionsCard(),
              const SizedBox(height: 24),
              if (!_isLoading) ...[
                _buildPreviewButton(),
                const SizedBox(height: 12),
                _buildCleanupButton(),
              ] else
                _buildLoadingIndicator(),
              const SizedBox(height: 24),
              if (_preview != null) _buildPreviewResults(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: Colors.orange.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Προσοχή',
                    style: TextStyle(
                      color: context.cText,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Η διαγραφή δεδομένων είναι μόνιμη και δεν μπορεί να αναιρεθεί. Χρησιμοποιήστε την προεπισκόπηση πριν συνεχίσετε.',
                    style: TextStyle(color: context.cText2, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      color: context.cSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Επιλογές Καθαρισμού',
              style: TextStyle(
                color: context.cText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Notifications
            _buildCheckboxTile(
              title: 'Υπενθυμίσεις',
              subtitle: 'Παλιές, διαβασμένες, ή ληγμένες',
              value: _cleanNotifications,
              onChanged: (v) => setState(() => _cleanNotifications = v!),
              days: _notificationsDays,
              onDaysChanged: (v) =>
                  setState(() => _notificationsDays = v.toInt()),
            ),

            const Divider(height: 32),

            // Budgets
            _buildCheckboxTile(
              title: 'Προϋπολογισμοί',
              subtitle: 'Ληγμένοι προϋπολογισμοί',
              value: _cleanBudgets,
              onChanged: (v) => setState(() => _cleanBudgets = v!),
              days: _budgetsDays,
              onDaysChanged: (v) => setState(() => _budgetsDays = v.toInt()),
            ),

            const Divider(height: 32),

            // Transactions
            _buildCheckboxTile(
              title: 'Συναλλαγές',
              subtitle: 'Διαγραμμένες συναλλαγές',
              value: _cleanTransactions,
              onChanged: (v) => setState(() => _cleanTransactions = v!),
              days: _transactionsDays,
              onDaysChanged: (v) =>
                  setState(() => _transactionsDays = v.toInt()),
            ),

            const Divider(height: 32),

            // Categories (dangerous)
            _buildCheckboxTile(
              title: 'Κατηγορίες',
              subtitle: 'Διαγραμμένες κατηγορίες (επικίνδυνο)',
              value: _cleanCategories,
              onChanged: (v) => setState(() => _cleanCategories = v!),
              days: _categoriesDays,
              onDaysChanged: (v) => setState(() => _categoriesDays = v.toInt()),
              dangerous: true,
            ),

            const Divider(height: 32),

            // Subcategories (dangerous)
            _buildCheckboxTile(
              title: 'Υποκατηγορίες',
              subtitle: 'Διαγραμμένες υποκατηγορίες (επικίνδυνο)',
              value: _cleanSubcategories,
              onChanged: (v) => setState(() => _cleanSubcategories = v!),
              days: _categoriesDays,
              onDaysChanged: (v) => setState(() => _categoriesDays = v.toInt()),
              dangerous: true,
            ),

            const Divider(height: 32),

            // Oil Tank (full reset)
            _buildCheckboxTile(
              title: 'Δεξαμενή Πετρελαίου',
              subtitle: 'Διαγραφή όλων των αγορών και επαναφορά ρυθμίσεων',
              value: _cleanOilTank,
              onChanged: (v) => setState(() => _cleanOilTank = v!),
              dangerous: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
    int? days,
    ValueChanged<double>? onDaysChanged,
    bool dangerous = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$title: ${value ? "ενεργό" : "ανενεργό"}',
          child: CheckboxListTile(
            title: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: dangerous ? Colors.red : context.cText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (dangerous) ...[
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: Icon(Icons.warning, color: Colors.red, size: 16),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(color: context.cText2, fontSize: 12),
            ),
            value: value,
            onChanged: onChanged,
            activeColor: dangerous ? Colors.red : context.cPrimary,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (value && days != null && onDaysChanged != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Παλαιότητα: $days ημέρες',
                  style: TextStyle(
                    color: context.cText2,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Slider(
                  value: days.toDouble(),
                  min: 7,
                  max: 365,
                  divisions: 51,
                  label: '$days ημέρες',
                  onChanged: onDaysChanged,
                  activeColor: dangerous ? Colors.red : context.cPrimary,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewButton() {
    return Semantics(
      button: true,
      label: 'Προεπισκόπηση καθαρισμού',
      excludeSemantics: true,
      child: ElevatedButton.icon(
        onPressed: _handlePreview,
        icon: const ExcludeSemantics(child: Icon(Icons.visibility)),
        label: const Text('Προεπισκόπηση'),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.cPrimary,
          foregroundColor: context.cOnPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanupButton() {
    final hasSelection =
        _cleanNotifications ||
            _cleanBudgets ||
            _cleanTransactions ||
            _cleanCategories ||
            _cleanSubcategories ||
            _cleanOilTank;

    return Semantics(
      button: true,
      label: 'Εκκίνηση καθαρισμού',
      enabled: hasSelection,
      excludeSemantics: true,
      child: ElevatedButton.icon(
        onPressed: hasSelection ? _handleCleanup : null,
        icon: const ExcludeSemantics(child: Icon(Icons.delete_sweep)),
        label: const Text('Καθαρισμός'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Semantics(
      liveRegion: true,
      label: 'Εκτέλεση καθαρισμού. Παρακαλώ περιμένετε.',
      excludeSemantics: true,
      child: Center(
        child: Column(
          children: [
            ExcludeSemantics(
              child: CircularProgressIndicator(color: context.cPrimary),
            ),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Text(
                'Εκτέλεση...',
                style: TextStyle(color: context.cText2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewResults() {
    if (_preview == null) return const SizedBox.shrink();

    return Card(
      color: context.cPrimary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.cPrimary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.info_outline, color: context.cPrimary),
                ),
                const SizedBox(width: 8),
                Text(
                  'Προεπισκόπηση',
                  style: TextStyle(
                    color: context.cText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_preview!.notificationsCount > 0)
              _buildPreviewItem(
                'Υπενθυμίσεις',
                _preview!.notificationsCount,
                Icons.notifications,
              ),
            if (_preview!.budgetsCount > 0)
              _buildPreviewItem(
                'Προϋπολογισμοί',
                _preview!.budgetsCount,
                Icons.account_balance_wallet,
              ),
            if (_preview!.transactionsCount > 0)
              _buildPreviewItem(
                'Συναλλαγές',
                _preview!.transactionsCount,
                Icons.receipt_long,
              ),
            if (_preview!.categoriesCount > 0)
              _buildPreviewItem(
                'Κατηγορίες',
                _preview!.categoriesCount,
                Icons.category,
                dangerous: true,
              ),
            if (_preview!.subcategoriesCount > 0)
              _buildPreviewItem(
                'Υποκατηγορίες',
                _preview!.subcategoriesCount,
                Icons.subdirectory_arrow_right,
                dangerous: true,
              ),
            if (_preview!.oilTankCount > 0)
              _buildPreviewItem(
                'Δεξαμενή Πετρελαίου',
                _preview!.oilTankCount,
                Icons.local_gas_station,
                dangerous: true,
              ),

            const Divider(height: 24),

            Text(
              'Σύνολο: ${_preview!.totalCount} εγγραφές',
              style: TextStyle(
                color: context.cText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewItem(
      String label,
      int count,
      IconData icon, {
        bool dangerous = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              icon,
              color: dangerous ? Colors.red : context.cText2,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: dangerous ? Colors.red : context.cText,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: dangerous
                  ? Colors.red.withValues(alpha: 0.15)
                  : context.cPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: dangerous ? Colors.red : context.cPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // HANDLERS
  // ══════════════════════════════════════════════

  Future<void> _handlePreview() async {
    setState(() {
      _isLoading = true;
      _preview = null;
    });

    try {
      final userId = context.session.userId;
      final service = DatabaseCleanupService(userId: userId);

      final options = CleanupOptions(
        cleanNotifications: _cleanNotifications,
        cleanBudgets: _cleanBudgets,
        cleanTransactions: _cleanTransactions,
        cleanCategories: _cleanCategories,
        cleanSubcategories: _cleanSubcategories,
        cleanOilTank: _cleanOilTank,
        notificationsDaysOld: _notificationsDays,
        budgetsDaysOld: _budgetsDays,
        transactionsDaysOld: _transactionsDays,
        categoriesDaysOld: _categoriesDays,
      );

      final preview = await service.previewCleanup(options);

      if (!mounted) return;

      setState(() {
        _preview = preview;
        _isLoading = false;
      });

      AccessibilityService.announcePolite(
        'Θα διαγραφούν ${preview.totalCount} εγγραφές',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Σφάλμα προεπισκόπησης: $e');
    }
  }

  Future<void> _handleCleanup() async {
    // Confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);
    if (!mounted) return;
    try {
      final userId = context.session.userId;
      final service = DatabaseCleanupService(userId: userId);

      final options = CleanupOptions(
        cleanNotifications: _cleanNotifications,
        cleanBudgets: _cleanBudgets,
        cleanTransactions: _cleanTransactions,
        cleanCategories: _cleanCategories,
        cleanSubcategories: _cleanSubcategories,
        cleanOilTank: _cleanOilTank,
        notificationsDaysOld: _notificationsDays,
        budgetsDaysOld: _budgetsDays,
        transactionsDaysOld: _transactionsDays,
        categoriesDaysOld: _categoriesDays,
      );

      final report = await service.performCleanup(options);

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (report.success) {
        _showSuccessDialog(report);
      } else {
        _showError('Σφάλμα: ${report.error}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Σφάλμα καθαρισμού: $e');
    }
  }

  // ══════════════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════════════

  Future<bool> _showConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Επιβεβαίωση Καθαρισμού'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Είστε σίγουροι ότι θέλετε να διαγράψετε τα επιλεγμένα δεδομένα;',
            ),
            const SizedBox(height: 16),
            if (_preview != null) ...[
              const Text(
                'Θα διαγραφούν:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('• Υπενθυμίσεις: ${_preview!.notificationsCount}'),
              Text('• Προϋπολογισμοί: ${_preview!.budgetsCount}'),
              Text('• Συναλλαγές: ${_preview!.transactionsCount}'),
              if (_preview!.categoriesCount > 0)
                Text('• Κατηγορίες: ${_preview!.categoriesCount}'),
              if (_preview!.subcategoriesCount > 0)
                Text('• Υποκατηγορίες: ${_preview!.subcategoriesCount}'),
              if (_preview!.oilTankCount > 0)
                Text('• Δεξαμενή Πετρελαίου: ${_preview!.oilTankCount}'),
              const SizedBox(height: 8),
              Text(
                'Σύνολο: ${_preview!.totalCount} εγγραφές',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Αυτή η ενέργεια δεν μπορεί να αναιρεθεί!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Άκυρο'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Διαγραφή'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showSuccessDialog(CleanupReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.check_circle, color: Colors.green, size: 32),
            ),
            const SizedBox(width: 12),
            const Text('Επιτυχής Καθαρισμός'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Διαγράφηκαν ${report.totalDeleted} εγγραφές σε ${report.duration.inSeconds} δευτερόλεπτα.',
            ),
            const SizedBox(height: 16),
            if (report.notificationsDeleted > 0)
              Text('• Υπενθυμίσεις: ${report.notificationsDeleted}'),
            if (report.budgetsDeleted > 0)
              Text('• Προϋπολογισμοί: ${report.budgetsDeleted}'),
            if (report.transactionsDeleted > 0)
              Text('• Συναλλαγές: ${report.transactionsDeleted}'),
            if (report.categoriesDeleted > 0)
              Text('• Κατηγορίες: ${report.categoriesDeleted}'),
            if (report.subcategoriesDeleted > 0)
              Text('• Υποκατηγορίες: ${report.subcategoriesDeleted}'),
            if (report.oilTankDeleted > 0)
              Text('• Δεξαμενή Πετρελαίου: ${report.oilTankDeleted}'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Εντάξει'),
          ),
        ],
      ),
    );

    AccessibilityService.announcePolite(
      'Καθαρισμός ολοκληρώθηκε. Διαγράφηκαν ${report.totalDeleted} εγγραφές.',
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.error, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}