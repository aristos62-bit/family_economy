// ============================================================
// TRANSACTIONS SHOW PAGE – FIREBASE VERSION (PART 1/3)
// Path: lib/presentation/screens/transactions/transactions_show_page.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/core/utils/debug_config.dart';
// Core imports
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/core/services/transactions_actions_service.dart';
import 'package:family_economy/presentation/screens/transactions/widgets/transaction_edit_sheet.dart';

class TransactionsShowPage extends StatefulWidget {
  final String accountUuid;
  final String accountName;

  const TransactionsShowPage({
    super.key,
    required this.accountUuid,
    required this.accountName,
  });

  @override
  State<TransactionsShowPage> createState() => _TransactionsShowPageState();
}

final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class _TransactionsShowPageState extends State<TransactionsShowPage> {
  // ============================================================
  // STATE VARIABLES
  // ============================================================

  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _error;
  DateTimeRange? _selectedDateRange;
  bool _showScheduled = false; // ✅ Εμφάνιση προγραμματισμένων κινήσεων

  // ============================
  //  messages helpers
  //============================

  void _showSuccessSnack(String message) {
    final b = Theme.of(context).brightness;

    final messenger = _scaffoldMessengerKey.currentState;
    DebugConfig.print('TXEDIT: showSuccessSnack messengerIsNull=${messenger == null}');

    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: ColorsUI.getOnPrimary(b)),
        ),
        backgroundColor: ColorsUI.getSuccess(b),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  void _showErrorSnack(String message) {
    final b = Theme.of(context).brightness;

    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: ColorsUI.getOnError(b)),
        ),
        backgroundColor: ColorsUI.getError(b),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // LIFECYCLE METHODS
  // ============================================================

  @override
  void initState() {
    super.initState();

    // ✅ Καθυστέρηση μέχρι να είναι έτοιμο το widget tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadTransactions(); // ✅ Τώρα το context είναι έτοιμο

        AccessibilityService.announcePolite(
          'Άνοιξε η σελίδα κινήσεων για τον λογαριασμό ${widget.accountName}',
        );
      }
    });
  }

  // ============================================================
  // DATA LOADING
  // ============================================================

  Future<void> _loadTransactions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = context.session.userId;

      // Query transactions for this account
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('account_id', isEqualTo: widget.accountUuid)
          .where('deleted', isEqualTo: false);

      // ✅ Apply date range filter in Firestore query (NOT client-side)
      if (_selectedDateRange != null) {
        final start = DateTime(
          _selectedDateRange!.start.year,
          _selectedDateRange!.start.month,
          _selectedDateRange!.start.day,
        );

        final endExclusive = DateTime(
          _selectedDateRange!.end.year,
          _selectedDateRange!.end.month,
          _selectedDateRange!.end.day,
        ).add(const Duration(days: 1));

        query = query
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThan: Timestamp.fromDate(endExclusive));
      }

      query = query.orderBy('date', descending: true).limit(100);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(); // online if possible
      } catch (_) {
        // ✅ Offline fallback: read from local cache
        snapshot = await query.get(const GetOptions(source: Source.cache));
      }

      // ✅ Map docs
      List<Map<String, dynamic>> transactions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'uuid': doc.id, ...data};
      }).toList();

      // ✅ Αν ΔΕΝ θέλουμε scheduled, κρύβουμε τις pending scheduled κινήσεις
      if (!_showScheduled) {
        transactions = transactions.where((t) {
          final isScheduled = t['is_scheduled'] as bool? ?? false;
          final isExecuted = t['is_executed'] as bool? ?? false;

          // Κρύβουμε μόνο τις pending scheduled (scheduled=true && executed=false)
          if (isScheduled && !isExecuted) return false;
          return true;
        }).toList();
      }

      if (!mounted) return;

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      DebugConfig.print('Error loading transactions: $e');
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // DATE RANGE PICKER
  // ============================================================

  void _pickDateRange() async {
    final initialDateRange =
        _selectedDateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;

        final colorScheme = brightness == Brightness.dark
            ? ColorScheme.dark(
                primary: ColorsUI.primaryDark,
                onPrimary: ColorsUI.textPrimaryDark,
                secondary: ColorsUI.primaryDark.withValues(alpha: 0.6),
                onSecondary: ColorsUI.textPrimaryLight,
                surface: ColorsUI.surfaceDark,
                onSurface: ColorsUI.textPrimaryDark,
                error: ColorsUI.errorDark,
                onError: ColorsUI.textPrimaryDark,
              )
            : ColorScheme.light(
                primary: ColorsUI.primaryLight,
                onPrimary: ColorsUI.textPrimaryLight,
                secondary: ColorsUI.primaryLight.withValues(alpha: 0.4),
                onSecondary: ColorsUI.textPrimaryLight,
                surface: ColorsUI.surfaceLight,
                onSurface: ColorsUI.textPrimaryLight,
                error: ColorsUI.errorLight,
                onError: ColorsUI.textPrimaryLight,
              );

        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: colorScheme,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
            ),
            dialogTheme: DialogThemeData(backgroundColor: colorScheme.surface),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });

      _loadTransactions();

      AccessibilityService.announcePolite(
        'Φίλτρο κινήσεων από ${picked.start.day}/${picked.start.month}/${picked.start.year} '
        'έως ${picked.end.day}/${picked.end.month}/${picked.end.year}',
      );
    }
  }

  // ============================================================
  // TRANSACTION TYPE HELPERS
  // ============================================================

  Color _getTransactionColor(
      Brightness brightness,
      double amount,
      ) {
    // Το χρώμα εξαρτάται ΠΑΝΤΑ από το πρόσημο
    if (amount >= 0) {
      return ColorsUI.getIncomeColor(brightness); // πράσινο
    } else {
      return ColorsUI.getExpenseColor(brightness); // κόκκινο
    }
  }


  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'income':
        return Icons.arrow_downward;
      case 'expense':
        return Icons.arrow_upward;
      case 'transfer':
        return Icons.swap_horiz;
      default:
        return Icons.monetization_on;
    }
  }

  // ============================================================
  // DELETE TRANSACTION
  // ============================================================

  Future<void> _deleteTransaction(Map<String, dynamic> tx) async {
    final isTransfer = tx['transaction_type'] == 'transfer';
    final brightness = Theme.of(context).brightness;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ColorsUI.getSurface(brightness),
        title: Text(
          'Διαγραφή Κίνησης',
          style: TypographyUI.titleLarge(brightness),
        ),
        content: Text(
          isTransfer
              ? 'Αυτή η κίνηση είναι μεταφορά.\n\n'
              'Θέλετε να συνεχίσετε με τη διαγραφή;'
              : 'Είστε σίγουροι ότι θέλετε να διαγράψετε αυτή την κίνηση;',
          style: TypographyUI.bodyMedium(brightness),
        ),

        actions: [
          Semantics(
            button: true,
            label: 'Ακύρωση διαγραφής',
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Ακύρωση',
                style: TypographyUI.buttonBase().copyWith(
                  color: ColorsUI.getTextSecondary(brightness),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Επιβεβαίωση διαγραφής κίνησης',
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorsUI.getError(brightness),
                foregroundColor: Colors.white,
              ),
              child: const Text('Διαγραφή'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      // ✅ Accessibility για cancel
      AccessibilityService.announcePolite('Ακυρώθηκε η διαγραφή');
      return;
    }

    // ✅ Background operation
    final scaffoldContext = context;
    if (!context.mounted) return;
    final userId = scaffoldContext.session.userId;

    // ✅ OPTIMISTIC UI: αν είναι transfer, βγάλε ΑΜΕΣΩΣ και τα 2 legs από τη λίστα
    final txUuid = tx['uuid'] as String?;
    final transferGroupId = tx['transfer_group_id'] as String?;

    final backup = List<Map<String, dynamic>>.from(_transactions);

    setState(() {
      _transactions = _transactions.where((t) {
        final id = t['uuid'] as String?;
        if (id == null) return true;

        // πάντα βγάζουμε το leg που πάτησε ο χρήστης
        if (txUuid != null && id == txUuid) return false;

        // αν είναι transfer και έχουμε group id, βγάζουμε και το άλλο leg που έχει ίδιο group
        if (isTransfer && transferGroupId != null) {
          final g = t['transfer_group_id'] as String?;
          if (g != null && g == transferGroupId) return false;
        }

        return true;
      }).toList();
    });


    // ✅ δείξε μήνυμα άμεσα (και offline)
    _showSuccessSnack('Η κίνηση διαγράφηκε');

    // ✅ background delete
    try {
      final isScheduled = tx['is_scheduled'] as bool? ?? false;
      final isExecuted = tx['is_executed'] as bool? ?? false;
      final isPendingScheduled = isScheduled && !isExecuted;

      await TransactionsActionsService().delete(
        userId: userId,
        tx: tx,
        skipBalanceUpdate: isPendingScheduled,
      );

      if (!mounted) return;
      _loadTransactions(); // τελική “συμφωνία” με cache/server
    } catch (error) {
      if (!mounted) return;

      // ❌ rollback UI αν αποτύχει
      setState(() {
        _transactions = backup;
      });
      if (!context.mounted) return;
      _showErrorSnack('Σφάλμα Διαγραφής');
      DebugConfig.print('Delete transaction error: $error');
    }
  }

  // ============================================================
  // EDIT TRANSACTION DIALOG
  // ============================================================

  // ============================================================
  // SAVE TRANSACTION EDIT
  // ============================================================

  //helper method για category names

  // ============================================================
  // BUILD METHOD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 600 && screenWidth <= 1200;
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: ColorsUI.getBackground(brightness),
        appBar: AppBar(
          backgroundColor: ColorsUI.getSurface(brightness),
          elevation: 0,
          leading: Semantics(
            button: true,
            label: 'Επιστροφή',
            child: IconButton(
              icon: ExcludeSemantics(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: ColorsUI.getTextPrimary(brightness),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Επιστροφή',
            ),
          ),
          actions: [
            Semantics(
              button: true,
              label: 'Επιλογή χρονικού διαστήματος',
              child: IconButton(
                icon: ExcludeSemantics(
                  child: Icon(
                    Icons.date_range,
                    color: ColorsUI.getPrimary(brightness),
                  ),
                ),
                onPressed: _pickDateRange,
                tooltip: 'Επιλογή ημερολογίου',
              ),
            ),
          ],
          title: Text('Κινήσεις', style: TypographyUI.titleLarge(brightness)),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildAccountHeader(brightness, horizontalPadding),
              if (_selectedDateRange != null)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 8,
                  ),
                  child: Text(
                    'Εμφάνιση από: ${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} '
                    'έως ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
                    style: TypographyUI.bodyMedium(
                      brightness,
                    ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState(brightness)
                    : _error != null
                    ? _buildErrorState(brightness, _error!)
                    : _transactions.isEmpty
                    ? _buildEmptyState(brightness)
                    : _buildTransactionsList(brightness, horizontalPadding),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI COMPONENTS
  // ============================================================

  Widget _buildAccountHeader(Brightness brightness, double padding) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: ColorsUI.getSurface(brightness),
        border: Border(
          bottom: BorderSide(color: ColorsUI.getDivider(brightness), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.accountName,
              style: TypographyUI.titleMedium(brightness),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: 'Εμφάνιση προγραμματισμένων κινήσεων',
            checked: _showScheduled,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Text(
                    'Προγραμματισμένες Κινήσεις',
                    style: TypographyUI.bodySmall(brightness).copyWith(
                      color: ColorsUI.getTextSecondary(brightness),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: Checkbox(
                    value: _showScheduled,
                    onChanged: (v) {
                      final newValue = v ?? false;
                      setState(() => _showScheduled = newValue);
                      _loadTransactions();
                      AccessibilityService.announcePolite(
                        newValue
                            ? 'Εμφάνιση προγραμματισμένων κινήσεων ενεργή'
                            : 'Εμφάνιση προγραμματισμένων κινήσεων ανενεργή',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLoadingState(Brightness brightness) {
    return Semantics(
      liveRegion: true,
      label: 'Φόρτωση κινήσεων. Παρακαλώ περιμένετε.',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: CircularProgressIndicator(
                color: ColorsUI.getPrimary(brightness),
              ),
            ),
            const SizedBox(height: 16),
            ExcludeSemantics(
              child: Text(
                'Φόρτωση κινήσεων...',
                style: TypographyUI.bodyMedium(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Brightness brightness, String error) {
    return Semantics(
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: ColorsUI.getError(brightness),
                ),
              ),
              const SizedBox(height: 16),
              Text('Σφάλμα φόρτωσης', style: TypographyUI.titleLarge(brightness)),
              const SizedBox(height: 8),
              Text(
                error,
                style: TypographyUI.bodyMedium(brightness),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Brightness brightness) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: ColorsUI.getTextSecondary(brightness),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Δεν υπάρχουν κινήσεις',
            style: TypographyUI.titleMedium(brightness),
          ),
          if (_selectedDateRange != null) ...[
            const SizedBox(height: 8),
            Text(
              'Για το επιλεγμένο χρονικό διάστημα',
              style: TypographyUI.bodyMedium(
                brightness,
              ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionsList(Brightness brightness, double padding) {
    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final tx in _transactions) {
      final dateTimestamp = tx['date'] as Timestamp?;
      if (dateTimestamp == null) continue;

      final date = dateTimestamp.toDate();
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(tx);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final transactions = grouped[dateKey]!;
        final date = DateTime.parse(dateKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(
                header: true,
                child: Text(
                  _formatDateHeader(date),
                  style: TypographyUI.titleSmall(brightness).copyWith(
                    color: ColorsUI.getTextSecondary(brightness),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Transactions for this date
            ...transactions.map((tx) => _buildTransactionCard(brightness, tx)),
          ],
        );
      },
    );
  }

  String _formatDateHeader(DateTime date) {
    const months = [
      'Ιανουαρίου',
      'Φεβρουαρίου',
      'Μαρτίου',
      'Απριλίου',
      'Μαΐου',
      'Ιουνίου',
      'Ιουλίου',
      'Αυγούστου',
      'Σεπτεμβρίου',
      'Οκτωβρίου',
      'Νοεμβρίου',
      'Δεκεμβρίου',
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Σήμερα';
    } else if (dateOnly == yesterday) {
      return 'Χθες';
    } else {
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  Widget _buildTransactionCard(Brightness brightness, Map<String, dynamic> tx) {
    final type = tx['transaction_type'] as String? ?? 'expense';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final isScheduled = tx['is_scheduled'] as bool? ?? false;
    final isExecuted = tx['is_executed'] as bool? ?? false;
    final isPendingScheduled = isScheduled && !isExecuted;
    final currency = tx['currency'] as String? ?? 'EUR';
    final notes = tx['notes'] as String? ?? '';
    final categoryId = tx['category_id'] as String?;
    final subcategoryId = tx['subcategory_id'] as String?;
    final isTransfer = type == 'transfer';
    final color = _getTransactionColor(brightness, amount);

    final icon = _getTransactionIcon(type);

    return Selector<CategoriesProvider, String>(
      selector: (_, p) {
        if (type == 'transfer') return 'Μεταφορά'; // ✅ ΠΡΟΣΘΗΚΗ

        if (categoryId == null || categoryId.isEmpty) return '';

        final cat = p.getCategoryByUuid(categoryId);
        if (cat == null) return '';

        if (subcategoryId != null && subcategoryId.isNotEmpty) {
          final sub = p.getSubcategoryByUuid(categoryId, subcategoryId);
          if (sub != null) return '${cat.name} / ${sub.name}';
        }

        return cat.name;
      },
      builder: (context, categoryTitle, _) {
        final displayTitle = categoryTitle.isEmpty
            ? 'Χωρίς κατηγορία'
            : categoryTitle;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          color: ColorsUI.getCard(brightness),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isTransfer
                  ? color.withValues(alpha: 0.9)
                  : ColorsUI.getBorder(brightness),
              width: isTransfer ? 2 : 1,
            ),
          ),
          child: Semantics(
            label: '$displayTitle: ${CurrencyFormatter.format(amount.abs(), currency: currency)}'
                '${isPendingScheduled ? ". Προγραμματισμένη κίνηση" : ""}'
                '${notes.isNotEmpty ? ". $notes" : ""}',
            child: InkWell(
              onTap: () {
                AccessibilityService.announcePolite(
                  '$displayTitle: ${CurrencyFormatter.format(amount.abs(), currency: currency)}',
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Row(
                  children: [
                    // Icon
                    ExcludeSemantics(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            style: TypographyUI.bodyLarge(
                              brightness,
                            ).copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isPendingScheduled) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Προγραμματισμένη κίνηση',
                              style: TypographyUI.bodySmall(brightness).copyWith(
                                color: ColorsUI.getTextSecondary(brightness),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (notes.isNotEmpty)
                            Text(
                              notes,
                              style: TypographyUI.bodySmall(brightness).copyWith(
                                color: ColorsUI.getTextSecondary(brightness),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ICONS ΠΑΝΩ – ΠΟΣΟ ΚΑΤΩ
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              button: true,
                              label: 'Επεξεργασία κίνησης $displayTitle',
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                icon: ExcludeSemantics(
                                  child: Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: ColorsUI.getTextSecondary(brightness),
                                  ),
                                ),
                                onPressed: isPendingScheduled ? null : () async {
                                  DebugConfig.print('TXEDIT: pressed');

                                  if (isTransfer) {
                                    await showDialog<void>(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        backgroundColor: ColorsUI.getSurface(brightness),
                                        title: Text('Επεξεργασία Μεταφοράς', style: TypographyUI.titleLarge(brightness)),
                                        content: Text(
                                          'Η κίνηση είναι Μεταφορά.\n\n'
                                              'Οι αλλαγές που θα κάνετε θα εφαρμοστούν ΚΑΙ '
                                              'στην αντίστοιχη κίνηση του άλλου λογαριασμού.',
                                          style: TypographyUI.bodyMedium(brightness),
                                        ),
                                        actions: [
                                          Semantics(
                                            button: true,
                                            label: 'Κλείσιμο ενημέρωσης μεταφοράς',
                                            child: TextButton(
                                              onPressed: () => Navigator.pop(dCtx),
                                              child: Text('OK', style: TypographyUI.buttonBase().copyWith(color: ColorsUI.getPrimary(brightness))),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  if (!context.mounted) return;

                                  DebugConfig.print('TXEDIT: opening sheet...');
                                  final result = await TransactionEditSheet.show(context, tx: tx);
                                  DebugConfig.print('TXEDIT: sheet closed. resultIsNull=${result == null}');

                                  if (result == null) return;

                                  DebugConfig.print('TXEDIT: result date=${result.date} amountAbs=${result.amountAbs}');

                                  if (!context.mounted) return;
                                  final userId = context.session.userId;

                                  final backup = List<Map<String, dynamic>>.from(_transactions);
                                  final txUuid = tx['uuid'] as String?;

                                  if (txUuid != null) {
                                    setState(() {
                                      _transactions = _transactions.map((t) {
                                        if (t['uuid'] != txUuid) return t;

                                        final oldAmount = (t['amount'] as num?)?.toDouble() ?? 0.0;
                                        final signedNewAmount =
                                        oldAmount >= 0 ? result.amountAbs : -result.amountAbs;

                                        return {
                                          ...t,
                                          'amount': signedNewAmount,
                                          'date': Timestamp.fromDate(result.date),
                                          'category_id': result.categoryId,
                                          'subcategory_id': result.subcategoryId,
                                          'account_id': result.accountId,
                                          'notes': (result.notes == null || result.notes!.trim().isEmpty)
                                              ? ''
                                              : result.notes!.trim(),
                                        };
                                      }).toList();
                                    });
                                  }

                                  _showSuccessSnack('Η μεταβολή αποθηκεύτηκε');

                                  try {
                                    await TransactionsActionsService().edit(
                                      userId: userId,
                                      tx: tx,
                                      newAmountAbs: result.amountAbs,
                                      newDate: result.date,
                                      newCategoryId: result.categoryId,
                                      newSubcategoryId: result.subcategoryId,
                                      newAccountId: result.accountId,
                                      newNotes: result.notes,
                                    );

                                    if (!context.mounted) return;
                                    _loadTransactions();
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    setState(() {
                                      _transactions = backup;
                                    });
                                    _showErrorSnack('Η αποθήκευση απέτυχε');
                                    DebugConfig.print('Save transaction edit error: $e');
                                  }
                                },
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: 'Διαγραφή κίνησης $displayTitle',
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                icon: ExcludeSemantics(
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: ColorsUI.getError(brightness),
                                  ),
                                ),
                                onPressed: () => _deleteTransaction(tx),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ExcludeSemantics(
                          child: Text(
                            CurrencyFormatter.format(
                              amount.abs(),
                              currency: currency,
                            ),
                            style: TypographyUI.bodyLarge(
                              brightness,
                            ).copyWith(fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
