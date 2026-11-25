// ============================================================
// FILE: database_cleanup_page.dart
// Path: lib/presentation/screens/options/database_cleanup_page.dart
// Ρόλος: UI για καθαρισμό βάσης δεδομένων.
// ✅ Πάντα φρέσκια προεπισκόπηση πριν την επιβεβαίωση (E42)
// ✅ Offline φραγή (E43) + PopScope/κλείδωμα κατά την εκτέλεση (E45)
// ✅ 3-κατάστατο αποτέλεσμα: πλήρες / μερικό / ακυρωμένο
// ✅ Scrollable διάλογοι (resize / text scale 0.85–1.45)
// ============================================================

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/services/database_cleanup_service.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/database_cleanup_policy.dart';
import 'package:family_economy/core/widgets/offline_banner.dart';

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
  bool _cleanOilTank = false;

  int _notificationsDays = 90;
  int _budgetsDays = 365;
  int _transactionsDays = 30;
  int _categoriesDays = 180;

  bool _isRunning = false;
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

    return PopScope(
      canPop: !_isRunning,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showInfo(CleanupPolicy.runningMessage);
      },
      child: Scaffold(
        backgroundColor: context.cBg,
        appBar: AppBar(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          iconTheme: IconThemeData(color: fg),
          actionsIconTheme: IconThemeData(color: fg),
          title: Text('Συντήρηση Βάσης', style: context.titleLg.withColor(fg)),
          actions: const [OfflineAppBarChip()],
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
                if (!_isRunning) ...[
                  _buildPreviewButton(),
                  const SizedBox(height: 12),
                  _buildCleanupButton(),
                ] else
                  _buildLoadingIndicator(),
                const SizedBox(height: 24),
                if (_preview != null && !_isRunning) _buildPreviewResults(),
              ],
            ),
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
                    'Η διαγραφή δεδομένων είναι μόνιμη και δεν μπορεί να '
                    'αναιρεθεί. Χρησιμοποιήστε την προεπισκόπηση πριν '
                    'συνεχίσετε.',
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
              subtitle: 'Παλιές, διαβασμένες, ληγμένες ή διαγραμμένες',
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
              subtitle: 'Ληγμένοι ή διαγραμμένοι προϋπολογισμοί',
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

            // Categories + subcategories (μία εργασία)
            _buildCheckboxTile(
              title: 'Κατηγορίες & Υποκατηγορίες',
              subtitle:
                  'Διαγραμμένες κατηγορίες μαζί με τις υποκατηγορίες τους '
                  '(επικίνδυνο)',
              value: _cleanCategories,
              onChanged: (v) => setState(() => _cleanCategories = v!),
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
    final enabled = !_isRunning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$title: ${value ? "ενεργό" : "ανενεργό"}',
          enabled: enabled,
          child: CheckboxListTile(
            title: Text(
              title,
              style: TextStyle(
                color: dangerous ? Colors.red : context.cText,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(color: context.cText2, fontSize: 12),
            ),
            secondary: dangerous
                ? const ExcludeSemantics(
                    child: Icon(Icons.warning, color: Colors.red, size: 16),
                  )
                : null,
            value: value,
            onChanged: enabled ? onChanged : null,
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
                  min: CleanupPolicy.minDays.toDouble(),
                  max: CleanupPolicy.maxDays.toDouble(),
                  divisions:
                      (CleanupPolicy.maxDays - CleanupPolicy.minDays) ~/
                      CleanupPolicy.dayStep,
                  label: '$days ημέρες',
                  onChanged: enabled ? onDaysChanged : null,
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
    final hasSelection = _options().hasSelection;

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
    final preview = _preview;
    if (preview == null) return const SizedBox.shrink();

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
                Expanded(
                  child: Text(
                    'Προεπισκόπηση',
                    style: TextStyle(
                      color: context.cText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (preview.notificationsCount > 0)
              _buildPreviewItem(
                'Υπενθυμίσεις',
                preview.notificationsCount,
                Icons.notifications,
              ),
            if (preview.budgetsCount > 0)
              _buildPreviewItem(
                'Προϋπολογισμοί',
                preview.budgetsCount,
                Icons.account_balance_wallet,
              ),
            if (preview.transactionsCount > 0)
              _buildPreviewItem(
                'Συναλλαγές',
                preview.transactionsCount,
                Icons.receipt_long,
              ),
            if (preview.categoriesCount > 0)
              _buildPreviewItem(
                'Κατηγορίες',
                preview.categoriesCount,
                Icons.category,
                dangerous: true,
              ),
            if (preview.subcategoriesCount > 0)
              _buildPreviewItem(
                'Υποκατηγορίες',
                preview.subcategoriesCount,
                Icons.subdirectory_arrow_right,
                dangerous: true,
              ),
            if (preview.oilTankCount > 0)
              _buildPreviewItem(
                'Δεξαμενή Πετρελαίου',
                preview.oilTankCount,
                Icons.local_gas_station,
                dangerous: true,
              ),

            const Divider(height: 24),

            Text(
              'Σύνολο: ${preview.totalCount} εγγραφές',
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

  CleanupOptions _options() => CleanupOptions(
    cleanNotifications: _cleanNotifications,
    cleanBudgets: _cleanBudgets,
    cleanTransactions: _cleanTransactions,
    cleanCategories: _cleanCategories,
    cleanOilTank: _cleanOilTank,
    notificationsDaysOld: _notificationsDays,
    budgetsDaysOld: _budgetsDays,
    transactionsDaysOld: _transactionsDays,
    categoriesDaysOld: _categoriesDays,
  );

  DatabaseCleanupService _service() =>
      DatabaseCleanupService(userId: context.session.userId);

  bool _ensureOnline() {
    final connectivity = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );
    if (connectivity.isConfirmedOffline) {
      _showError(CleanupPolicy.offlineMessage);
      return false;
    }
    return true;
  }

  Future<void> _handlePreview() async {
    if (_isRunning) return;
    if (!_ensureOnline()) return;

    setState(() {
      _isRunning = true;
      _preview = null;
    });

    try {
      final preview = await _service().previewCleanup(_options());
      if (!mounted) return;

      setState(() {
        _preview = preview;
        _isRunning = false;
      });

      AccessibilityService.announcePolite(
        preview.isEmpty
            ? CleanupPolicy.nothingToDeleteMessage
            : 'Θα διαγραφούν ${preview.totalCount} εγγραφές',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRunning = false);
      _showError('Σφάλμα προεπισκόπησης: $e');
    }
  }

  Future<void> _handleCleanup() async {
    if (_isRunning) return;
    if (!_ensureOnline()) return;

    // Πάντα φρέσκια προεπισκόπηση — ποτέ παλιά νούμερα στον διάλογο.
    setState(() {
      _isRunning = true;
      _preview = null;
    });

    final CleanupPreview fresh;
    try {
      fresh = await _service().previewCleanup(_options());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRunning = false);
      _showError('Σφάλμα προεπισκόπησης: $e');
      return;
    }

    if (!mounted) return;
    setState(() {
      _preview = fresh;
      _isRunning = false;
    });

    if (fresh.isEmpty) {
      _showInfo(CleanupPolicy.nothingToDeleteMessage);
      return;
    }

    final confirmed = await _showConfirmationDialog(fresh);
    if (!confirmed || !mounted) return;

    setState(() => _isRunning = true);

    try {
      final report = await _service().performCleanup(_options());
      if (!mounted) return;

      setState(() {
        _isRunning = false;
        _preview = null;
      });

      _showResultDialog(report);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRunning = false);
      _showError('Σφάλμα καθαρισμού: $e');
    }
  }

  // ══════════════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════════════

  Future<bool> _showConfirmationDialog(CleanupPreview preview) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Επιβεβαίωση Καθαρισμού'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Είστε σίγουροι ότι θέλετε να διαγράψετε τα επιλεγμένα '
              'δεδομένα;',
            ),
            const SizedBox(height: 16),
            const Text(
              'Θα διαγραφούν:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (preview.notificationsCount > 0)
              Text(
                CleanupPolicy.countLine(
                  'Υπενθυμίσεις',
                  preview.notificationsCount,
                ),
              ),
            if (preview.budgetsCount > 0)
              Text(
                CleanupPolicy.countLine(
                  'Προϋπολογισμοί',
                  preview.budgetsCount,
                ),
              ),
            if (preview.transactionsCount > 0)
              Text(
                CleanupPolicy.countLine(
                  'Συναλλαγές',
                  preview.transactionsCount,
                ),
              ),
            if (preview.categoriesCount > 0)
              Text(
                CleanupPolicy.countLine('Κατηγορίες', preview.categoriesCount),
              ),
            if (preview.subcategoriesCount > 0)
              Text(
                CleanupPolicy.countLine(
                  'Υποκατηγορίες',
                  preview.subcategoriesCount,
                ),
              ),
            if (preview.oilTankCount > 0)
              Text(
                CleanupPolicy.countLine(
                  'Δεξαμενή Πετρελαίου',
                  preview.oilTankCount,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Σύνολο: ${preview.totalCount} εγγραφές',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Αυτή η ενέργεια δεν μπορεί να αναιρεθεί!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Άκυρο'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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

  void _showResultDialog(CleanupReport report) {
    final isPartial = report.isPartial;
    final color = isPartial ? Colors.orange : Colors.green;
    final icon = isPartial ? Icons.warning_amber_rounded : Icons.check_circle;

    final lines = <Widget>[
      if (report.notificationsDeleted > 0)
        Text(
          CleanupPolicy.countLine(
            'Υπενθυμίσεις',
            report.notificationsDeleted,
          ),
        ),
      if (report.budgetsDeleted > 0)
        Text(
          CleanupPolicy.countLine(
            'Προϋπολογισμοί',
            report.budgetsDeleted,
          ),
        ),
      if (report.transactionsDeleted > 0)
        Text(
          CleanupPolicy.countLine(
            'Συναλλαγές',
            report.transactionsDeleted,
          ),
        ),
      if (report.categoriesDeleted > 0)
        Text(
          CleanupPolicy.countLine(
            'Κατηγορίες',
            report.categoriesDeleted,
          ),
        ),
      if (report.subcategoriesDeleted > 0)
        Text(
          CleanupPolicy.countLine(
            'Υποκατηγορίες',
            report.subcategoriesDeleted,
          ),
        ),
      if (report.oilTankDeleted > 0)
        Text(
          CleanupPolicy.countLine(
            'Δεξαμενή Πετρελαίου',
            report.oilTankDeleted,
          ),
        ),
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Row(
          children: [
            ExcludeSemantics(child: Icon(icon, color: color, size: 32)),
            const SizedBox(width: 12),
            Expanded(child: Text(CleanupPolicy.titleOf(report.outcome))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.outcome == CleanupOutcome.cancelled
                  ? CleanupPolicy.nothingToDeleteMessage
                  : report.hasDeleted
                  ? 'Διαγράφηκαν ${report.totalDeleted} εγγραφές σε '
                        '${_durationText(report.duration)}.'
                  : CleanupPolicy.partialNothingDeleted,
            ),
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...lines,
            ],
            if (isPartial) ...[
              const SizedBox(height: 16),
              const Text(
                CleanupPolicy.partialIntro,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...report.failures.map((label) => Text('• $label')),
              const SizedBox(height: 8),
              const Text(CleanupPolicy.partialNote),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Εντάξει'),
          ),
        ],
      ),
    );

    AccessibilityService.announcePolite(
      report.hasDeleted
          ? 'Καθαρισμός ολοκληρώθηκε. Διαγράφηκαν '
                '${report.totalDeleted} εγγραφές.'
          : CleanupPolicy.partialNothingDeleted,
    );
  }

  String _durationText(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 1) return 'λιγότερο από 1 δευτερόλεπτο';
    return seconds == 1 ? '1 δευτερόλεπτο' : '$seconds δευτερόλεπτα';
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

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.info_outline, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: context.cPrimary,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
