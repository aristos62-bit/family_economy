// ============================================================
// FILE: scheduled_transactions_page.dart
// Path: lib/presentation/screens/scheduled/scheduled_transactions_page.dart
// Ρόλος: Προβολή και διαχείριση προγραμματισμένων κινήσεων
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/services/scheduled_transactions_service.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';

class ScheduledTransactionsPage extends StatefulWidget {
  const ScheduledTransactionsPage({super.key});

  @override
  State<ScheduledTransactionsPage> createState() =>
      _ScheduledTransactionsPageState();
}

class _ScheduledTransactionsPageState extends State<ScheduledTransactionsPage> {
  @override
  void initState() {
    super.initState();
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Προγραμματισμένες Κινήσεις. '
      'Λίστα κινήσεων με μελλοντική ημερομηνία.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.session.userId;
    final scheduledService = ScheduledTransactionsService();
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: ColorsUI.getBackground(brightness),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: scheduledService.getScheduledTransactions(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Semantics(
              liveRegion: true,
              label: 'Φόρτωση προγραμματισμένων κινήσεων. Παρακαλώ περιμένετε.',
              child: const Center(
                child: ExcludeSemantics(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
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
                    Text(
                      'Σφάλμα φόρτωσης',
                      style: TypographyUI.titleMedium(brightness),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TypographyUI.bodySmall(brightness),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final scheduledTransactions = snapshot.data ?? [];

          if (scheduledTransactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.event_available,
                        size: 80,
                        color: ColorsUI.getTextSecondary(brightness),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Δεν υπάρχουν προγραμματισμένες κινήσεις',
                      style: TypographyUI.titleMedium(brightness),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Οι κινήσεις με μελλοντική ημερομηνία θα εμφανίζονται εδώ',
                      style: TypographyUI.bodyMedium(brightness),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: scheduledTransactions.length,
            itemBuilder: (context, index) {
              final transaction = scheduledTransactions[index];
              return _ScheduledTransactionCard(
                transaction: transaction,
                userId: userId,
              );
            },
          );
        },
      ),
    );
  }
}

class _ScheduledTransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String userId;

  const _ScheduledTransactionCard({
    required this.transaction,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheduledDate = (transaction['scheduled_for_date'] as Timestamp)
        .toDate();
    final amount = (transaction['amount'] as num).toDouble();
    final type = transaction['transaction_type'] as String;
    final notes = transaction['notes'] as String?;

    Color typeColor;
    IconData typeIcon;
    String typeLabel;

    switch (type) {
      case 'income':
        typeColor = ColorsUI.getIncomeColor(brightness);
        typeIcon = Icons.add_circle;
        typeLabel = 'Έσοδο';
        break;
      case 'expense':
        typeColor = ColorsUI.getExpenseColor(brightness);
        typeIcon = Icons.remove_circle;
        typeLabel = 'Έξοδο';
        break;
      case 'transfer':
        typeColor = ColorsUI.getTransferColor(brightness);
        typeIcon = Icons.swap_horiz;
        typeLabel = 'Μεταφορά';
        break;
      default:
        typeColor = ColorsUI.getPrimary(brightness);
        typeIcon = Icons.receipt;
        typeLabel = 'Κίνηση';
    }

    return AccessibilityService.accessibleButton(
      label:
          '$typeLabel €${amount.abs().toStringAsFixed(2)} '
          'προγραμματισμένο για ${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}',
      hint: 'Πατήστε για περισσότερες επιλογές',
      onPressed: () => _showTransactionDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ColorsUI.getCard(brightness),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: typeColor.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: ColorsUI.shadowLight.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showTransactionDetails(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ExcludeSemantics(
                          child: Icon(typeIcon, color: typeColor, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeLabel,
                              style: TypographyUI.labelLarge(
                                brightness,
                              ).copyWith(color: typeColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(amount.abs()),
                              style: TypographyUI.titleMedium(brightness)
                                  .copyWith(
                                    color: typeColor,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Ακύρωση προγραμματισμένης κίνησης',
                        child: IconButton(
                          onPressed: () => _showCancelDialog(context),
                          icon: ExcludeSemantics(
                            child: Icon(
                              Icons.cancel,
                              color: ColorsUI.getError(brightness),
                            ),
                          ),
                          tooltip: 'Ακύρωση',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ExcludeSemantics(
                    child: Divider(
                      color: typeColor.withValues(alpha: 0.2),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: ColorsUI.getTextSecondary(brightness),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}',
                        style: TypographyUI.bodyMedium(brightness),
                      ),
                      const Spacer(),
                      _getDaysUntilBadge(context, scheduledDate),
                    ],
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ColorsUI.getTextSecondary(
                          brightness,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              Icons.note,
                              size: 14,
                              color: ColorsUI.getTextSecondary(brightness),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              notes,
                              style: TypographyUI.bodySmall(brightness),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getDaysUntilBadge(BuildContext context, DateTime scheduledDate) {
    final brightness = Theme.of(context).brightness;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );
    final daysUntil = scheduled.difference(today).inDays;

    String label;
    Color badgeColor;

    if (daysUntil == 0) {
      label = 'Σήμερα';
      badgeColor = ColorsUI.getWarning(brightness);
    } else if (daysUntil == 1) {
      label = 'Αύριο';
      badgeColor = ColorsUI.getInfo(brightness);
    } else if (daysUntil < 0) {
      label = 'Εκπρόθεσμη';
      badgeColor = ColorsUI.getError(brightness);
    } else {
      label = 'σε $daysUntil ημ.';
      badgeColor = ColorsUI.getPrimary(brightness);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: ExcludeSemantics(
        child: Text(
          label,
          style: TypographyUI.labelSmall(
            brightness,
          ).copyWith(color: badgeColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorsUI.getSurface(brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                ExcludeSemantics(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: ColorsUI.getDivider(brightness),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Λεπτομέρειες Προγραμματισμένης Κίνησης',
                        style: TypographyUI.titleMedium(brightness),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Κλείσιμο',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: ExcludeSemantics(
                        child: Icon(
                          Icons.close,
                          color: ColorsUI.getTextSecondary(brightness),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Details
                // Details
                FutureBuilder<Map<String, String>>(
                  future: _loadTransactionDetails(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Semantics(
                        liveRegion: true,
                        label: 'Φόρτωση λεπτομερειών κίνησης.',
                        child: const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: ExcludeSemantics(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    }

                    final details = snapshot.data ?? {};

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(
                          brightness: brightness,
                          label: 'Τύπος',
                          value: _getTypeLabel(
                            transaction['transaction_type'] as String,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          brightness: brightness,
                          label: 'Ποσό',
                          value:
                              '€${(transaction['amount'] as num).abs().toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          brightness: brightness,
                          label: 'Ημερομηνία',
                          value: _formatDate(
                            (transaction['scheduled_for_date'] as Timestamp)
                                .toDate(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          brightness: brightness,
                          label: 'Λογαριασμός',
                          value: details['account'] ?? 'Φόρτωση...',
                        ),
                        if (details['category'] != null) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            brightness: brightness,
                            label: 'Κατηγορία',
                            value: details['category']!,
                          ),
                        ],
                        // ✅ ΝΕΟΣ: Υποκατηγορία
                        if (details['subcategory'] != null) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            brightness: brightness,
                            label: 'Υποκατηγορία',
                            value: details['subcategory']!,
                          ),
                        ],
                        if (transaction['notes'] != null &&
                            (transaction['notes'] as String).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            brightness: brightness,
                            label: 'Σημειώσεις',
                            value: transaction['notes'] as String,
                          ),
                        ],
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showCancelDialog(context);
                        },
                        icon: const ExcludeSemantics(
                          child: Icon(Icons.cancel, size: 20),
                        ),
                        label: const Text('Ακύρωση Κίνησης'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColorsUI.getError(brightness),
                          side: BorderSide(
                            color: ColorsUI.getError(brightness),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, String>> _loadTransactionDetails() async {
    final scheduledService = ScheduledTransactionsService();
    final details = <String, String>{};

    try {
      final accountId = transaction['account_id'] as String;
      details['account'] = await scheduledService.getAccountName(
        userId,
        accountId,
      );

      final categoryId = transaction['category_id'] as String?;
      if (categoryId != null && categoryId.isNotEmpty) {
        details['category'] = await scheduledService.getCategoryName(
          userId,
          categoryId,
        );
      }

      // ✅ ΝΕΟΣ: Φόρτωση υποκατηγορίας
      final subcategoryId = transaction['subcategory_id'] as String?;
      if (subcategoryId != null && subcategoryId.isNotEmpty) {
        details['subcategory'] = await scheduledService.getSubcategoryName(
          userId,
          subcategoryId,
        );
      }
    } catch (e) {
      DebugConfig.print('❌ Error loading transaction details: $e');
    }

    return details;
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'income':
        return 'Έσοδο';
      case 'expense':
        return 'Έξοδο';
      case 'transfer':
        return 'Μεταφορά';
      default:
        return 'Κίνηση';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showCancelDialog(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.warning, color: ColorsUI.getWarning(brightness), size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Ακύρωση Κίνησης')),
          ],
        ),
        content: const Text(
          'Είστε σίγουροι ότι θέλετε να ακυρώσετε αυτήν την προγραμματισμένη κίνηση;\n\nΗ κίνηση θα διαγραφεί οριστικά.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Όχι'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                final scheduledService = ScheduledTransactionsService();
                await scheduledService.cancelScheduledTransaction(
                  userId,
                  transaction['uuid'] as String,
                );

                if (context.mounted) {
                  final successColor = brightness == Brightness.light
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF81C784);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const ExcludeSemantics(
                            child: Icon(Icons.check_circle, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Η κίνηση ακυρώθηκε επιτυχώς',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: successColor,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.all(16),
                      elevation: 4,
                    ),
                  );

                  AccessibilityService.announceSuccess('Η κίνηση ακυρώθηκε');
                }
              } catch (e) {
                DebugConfig.print('❌ Error cancelling transaction: $e');

                if (context.mounted) {
                  final errorColor = brightness == Brightness.light
                      ? const Color(0xFFC62828)
                      : const Color(0xFFE57373);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const ExcludeSemantics(
                            child: Icon(Icons.error, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Σφάλμα κατά την ακύρωση',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: errorColor,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.all(16),
                      elevation: 4,
                    ),
                  );

                  AccessibilityService.announceError('Σφάλμα κατά την ακύρωση');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsUI.getError(brightness),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ναι, Ακύρωση'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final Brightness brightness;
  final String label;
  final String value;

  const _DetailRow({
    required this.brightness,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ColorsUI.getCard(brightness),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ColorsUI.getBorder(brightness)),
        ),
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: TypographyUI.labelMedium(
                    brightness,
                  ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(value, style: TypographyUI.bodyMedium(brightness)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
