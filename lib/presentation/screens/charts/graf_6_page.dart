// ============================================================
// FILE: graf_6_page.dart
// PURPOSE: Detailed Transactions List View with Filtering (Realtime + Offline-safe)
// Location: lib/presentation/screens/charts/graf_6_page.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/core/utils/chart_helpers.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/session/session_scope.dart';

class Graf6Page extends StatefulWidget {
  final String selectedPeriod;

  const Graf6Page({super.key, required this.selectedPeriod});

  @override
  State<Graf6Page> createState() => _Graf6PageState();
}

class _Graf6PageState extends State<Graf6Page> {
  String _filterType = 'all'; // all, income, expense, transfer

  // Για να μη “φωνάζει” ο screen reader σε κάθε rebuild/stream tick
  int? _lastAnnouncedCount;
  bool _lastAnnouncedError = false;

  // ----------------------------
  // QUERY (Realtime, Offline-safe)
  // ----------------------------
  Query<Map<String, dynamic>> _buildTransactionsQuery(String userId) {
    final dateRange = ChartHelpers.getDateRange(widget.selectedPeriod);
    final startDate = DateTime.parse(dateRange['start']!);
    final endDate = DateTime.parse(
      dateRange['end']!,
    ).add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThan: Timestamp.fromDate(endDate))
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .limit(100);
  }

  // ----------------------------
  // SNAPSHOT -> UI MODEL
  // ----------------------------
  List<Map<String, dynamic>> _mapSnapshotToTransactions({
    required QuerySnapshot<Map<String, dynamic>> snapshot,
    required AccountsProvider accountsProvider,
    required CategoriesProvider categoriesProvider,
  }) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> transactionsList = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      // Skip future transactions
      final dateValue = data['date'];
      if (dateValue == null) continue;
      final transDate = (dateValue as Timestamp).toDate();
      if (transDate.isAfter(now)) continue;

      // Determine transaction type
      String type;
      final transferGroupId = data['transfer_group_id'];
      if (transferGroupId != null) {
        type = 'transfer';
      } else {
        final categoryId = data['category_id'] as String?;
        if (categoryId != null) {
          final category = categoriesProvider.getCategoryByUuid(categoryId);
          type = category?.type ?? 'unknown';
        } else {
          type = 'unknown';
        }
      }

      // Apply filter
      if (_filterType != 'all' && type != _filterType) continue;

      // Account
      final accountId = data['account_id'] as String?;
      final account = accountId != null
          ? accountsProvider.getAccountByUuid(accountId)
          : null;

      // Category
      final categoryId = data['category_id'] as String?;
      final category = categoryId != null
          ? categoriesProvider.getCategoryByUuid(categoryId)
          : null;

      // Subcategory
      final subcategoryId = data['subcategory_id'] as String?;
      final subcategory = (categoryId != null && subcategoryId != null)
          ? categoriesProvider.getSubcategoryByUuid(categoryId, subcategoryId)
          : null;

      // Amount
      final amountValue = data['amount'];
      if (amountValue == null) continue;
      final amount = (amountValue as num).toDouble();

      final notes = data['notes'] as String?;

      transactionsList.add({
        'id': doc.id,
        'type': type,
        'amount': amount,
        'date': transDate,
        'account_name': account?.name ?? 'Άγνωστος',
        'category_name': type == 'transfer'
            ? 'Μεταφορά'
            : (category?.name ?? 'Χωρίς κατηγορία'),
        'subcategory_name': type == 'transfer' ? null : subcategory?.name,
        'notes': notes,
      });
    }

    return transactionsList;
  }

  // ----------------------------
  // ACCESSIBILITY ANNOUNCEMENTS (safe)
  // ----------------------------
  void _announceCountIfChanged(int count) {
    if (!mounted) return;
    if (_lastAnnouncedCount == count && !_lastAnnouncedError) return;

    _lastAnnouncedError = false;
    _lastAnnouncedCount = count;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (count == 0) {
        AccessibilityService.announcePolite('Δεν βρέθηκαν κινήσεις');
      } else {
        AccessibilityService.announcePolite('Βρέθηκαν $count κινήσεις');
      }
    });
  }

  void _announceErrorOnce() {
    if (!mounted) return;
    if (_lastAnnouncedError) return;

    _lastAnnouncedError = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AccessibilityService.announceError('Σφάλμα φόρτωσης κινήσεων');
    });
  }

  // ----------------------------
  // FILTER
  // ----------------------------
  void _onFilterChanged(String newFilter) {
    setState(() => _filterType = newFilter);

    String filterLabel;
    switch (newFilter) {
      case 'all':
        filterLabel = 'όλες';
        break;
      case 'income':
        filterLabel = 'έσοδα';
        break;
      case 'expense':
        filterLabel = 'έξοδα';
        break;
      case 'transfer':
        filterLabel = 'μεταφορές';
        break;
      default:
        filterLabel = newFilter;
    }

    AccessibilityService.announcePolite('Φίλτρο άλλαξε σε $filterLabel');

    // Reset announce state ώστε να ανακοινώσει σωστά το νέο αποτέλεσμα φίλτρου
    _lastAnnouncedCount = null;
    _lastAnnouncedError = false;
  }

  // ----------------------------
  // SEMANTIC SUMMARY
  // ----------------------------
  String _buildSemanticSummaryFrom(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) {
      return 'Δεν υπάρχουν κινήσεις για την περίοδο ${ChartHelpers.formatPeriodLabel(widget.selectedPeriod)}.';
    }

    int incomeCount = 0;
    int expenseCount = 0;
    int transferCount = 0;
    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (var t in transactions) {
      final type = t['type'] as String;
      final amount = (t['amount'] as num).toDouble();

      if (type == 'income') {
        incomeCount++;
        totalIncome += amount;
      } else if (type == 'expense') {
        expenseCount++;
        totalExpense += amount.abs();
      } else if (type == 'transfer') {
        transferCount++;
      }
    }

    return 'Αναλυτική προβολή κινήσεων. '
        'Σύνολο: ${transactions.length} κινήσεις. '
        'Έσοδα: $incomeCount (${ChartHelpers.formatMoney(totalIncome)}). '
        'Έξοδα: $expenseCount (${ChartHelpers.formatMoney(totalExpense)}). '
        'Μεταφορές: $transferCount.';
  }

  // ----------------------------
  // UI
  // ----------------------------
  Widget _buildSkeleton(Brightness brightness) {
    final color = brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade300;

    return ExcludeSemantics(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(Brightness brightness) {
    return Semantics(
      label: 'Φίλτρα κινήσεων',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _buildFilterChip('all', 'Όλες', Icons.list, brightness),
            const SizedBox(width: 8),
            _buildFilterChip(
              'income',
              'Έσοδα',
              Icons.arrow_downward,
              brightness,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              'expense',
              'Έξοδα',
              Icons.arrow_upward,
              brightness,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              'transfer',
              'Μεταφορές',
              Icons.swap_horiz,
              brightness,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String value,
    String label,
    IconData icon,
    Brightness brightness,
  ) {
    final isSelected = _filterType == value;

    return Semantics(
      button: true,
      label: 'Φίλτρο $label',
      hint: 'Πατήστε για να φιλτράρετε τις κινήσεις ως $label',
      selected: isSelected,
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: 16,
                color: isSelected
                    ? ColorsUI.getPrimary(brightness)
                    : ColorsUI.getTextSecondary(brightness),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TypographyUI.labelSmall(brightness).copyWith(
                color: isSelected
                    ? ColorsUI.getPrimary(brightness)
                    : ColorsUI.getTextSecondary(brightness),
              ),
            ),
          ],
        ),
        onSelected: (_) => _onFilterChanged(value),
        backgroundColor: ColorsUI.getSurface(brightness),
        selectedColor: ColorsUI.getPrimary(brightness).withValues(alpha: 0.15),
        checkmarkColor: ColorsUI.getPrimary(brightness),
        side: BorderSide(
          color: isSelected
              ? ColorsUI.getPrimary(brightness)
              : ColorsUI.getDivider(brightness),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState(Brightness brightness) {
    return Semantics(
      label: 'Δεν υπάρχουν κινήσεις',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 200),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: ColorsUI.getTextSecondary(brightness),
                  ),
                ),
                const SizedBox(height: 16),
                ExcludeSemantics(
                  child: Text(
                    'Δεν βρέθηκαν κινήσεις',
                    style: TypographyUI.titleMedium(brightness),
                  ),
                ),
                const SizedBox(height: 8),
                ExcludeSemantics(
                  child: Text(
                    'Δεν υπάρχουν κινήσεις για την επιλεγμένη περίοδο',
                    style: TypographyUI.bodyMedium(
                      brightness,
                    ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList(
    List<Map<String, dynamic>> transactions,
    Brightness brightness,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transactions.length,
        itemBuilder: (context, index) =>
            _buildTransactionCard(transactions[index], brightness),
      ),
    );
  }

  Widget _buildTransactionCard(
    Map<String, dynamic> transaction,
    Brightness brightness,
  ) {
    final type = transaction['type'] as String;
    final amount = (transaction['amount'] as num).toDouble();
    final date = transaction['date'] as DateTime;
    final accountName = transaction['account_name'] as String;

    final isTransfer = type == 'transfer';
    final isOutgoingTransfer = isTransfer && amount < 0;

    final accountLabel = isTransfer
        ? (isOutgoingTransfer ? 'Από → $accountName' : 'Προς → $accountName')
        : accountName;

    final categoryName = transaction['category_name'] as String;
    final subcategoryName = transaction['subcategory_name'] as String?;
    final notes = transaction['notes'] as String?;

    IconData icon;
    Color color;
    String typeLabel;

    if (type == 'income') {
      icon = Icons.arrow_downward;
      color = ColorsUI.getIncomeColor(brightness);
      typeLabel = 'Έσοδο';
    } else if (type == 'expense') {
      icon = Icons.arrow_upward;
      color = ColorsUI.getExpenseColor(brightness);
      typeLabel = 'Έξοδο';
    } else {
      icon = Icons.swap_horiz;
      color = ColorsUI.getTransferColor(brightness);
      typeLabel = 'Μεταφορά';
    }

    final semanticLabel =
        '$typeLabel στις ${_formatDate(date)}. '
        'Ποσό: ${ChartHelpers.formatMoney(amount.abs())}. '
        'Λογαριασμός: $accountName. '
        'Κατηγορία: $categoryName'
        '${subcategoryName != null ? ', $subcategoryName' : ''}'
        '${notes != null && notes.isNotEmpty ? '. Σημειώσεις: $notes' : ''}.';

    return Semantics(
      label: semanticLabel,
      button: false,
      child: ExcludeSemantics(
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: ColorsUI.getSurface(brightness),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: ColorsUI.getDivider(brightness), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subcategoryName != null
                            ? '$categoryName - $subcategoryName'
                            : categoryName,
                        style: TypographyUI.titleSmall(brightness),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 12,
                            color: ColorsUI.getTextSecondary(brightness),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              accountLabel,
                              style: TypographyUI.bodySmall(brightness)
                                  .copyWith(
                                    color: ColorsUI.getTextSecondary(
                                      brightness,
                                    ),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: ColorsUI.getTextSecondary(brightness),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(date),
                            style: TypographyUI.bodySmall(brightness).copyWith(
                              color: ColorsUI.getTextSecondary(brightness),
                            ),
                          ),
                        ],
                      ),

                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notes,
                          style: TypographyUI.bodySmall(brightness).copyWith(
                            color: ColorsUI.getTextSecondary(brightness),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                Text(
                  ChartHelpers.formatMoney(amount.abs()),
                  style: TypographyUI.bodySmall(
                    brightness,
                  ).copyWith(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transDate = DateTime(date.year, date.month, date.day);

    if (transDate == today) {
      return 'Σήμερα';
    } else if (transDate == yesterday) {
      return 'Χθες';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // ----------------------------
  // BUILD
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // ✅ Rebuild μόνο όταν αλλάζει το isLoading (όχι σε κάθε notifyListeners)
    final accountsLoading = context.select<AccountsProvider, bool>(
      (p) => p.isLoading,
    );
    final categoriesLoading = context.select<CategoriesProvider, bool>(
      (p) => p.isLoading,
    );
    final providersReady = !accountsLoading && !categoriesLoading;

    return Semantics(
      container: true,
      label:
          'Αναλυτική προβολή κινήσεων για την περίοδο ${ChartHelpers.formatPeriodLabel(widget.selectedPeriod)}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterChips(brightness),
          const SizedBox(height: 12),

          if (!providersReady)
            Semantics(
              label: 'Φόρτωση κινήσεων',
              liveRegion: true,
              excludeSemantics: true,
              child: _buildSkeleton(brightness),
            )
          else
            Builder(
              builder: (context) {
                final userId = context.session.userId;

                // ⚠️ read (όχι watch) για να μην ξαναχτίζεται όλη η λίστα με κάθε provider update
                final accountsProvider = context.read<AccountsProvider>();
                final categoriesProvider = context.read<CategoriesProvider>();

                final query = _buildTransactionsQuery(userId);

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: query.snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return Semantics(
                        label: 'Φόρτωση κινήσεων',
                        child: _buildSkeleton(brightness),
                      );
                    }

                    if (snap.hasError) {
                      _announceErrorOnce();
                      return _buildEmptyState(brightness);
                    }

                    final data = snap.data;
                    if (data == null) {
                      _announceCountIfChanged(0);
                      return _buildEmptyState(brightness);
                    }

                    final transactions = _mapSnapshotToTransactions(
                      snapshot: data,
                      accountsProvider: accountsProvider,
                      categoriesProvider: categoriesProvider,
                    );

                    _announceCountIfChanged(transactions.length);

                    // 🔎 Semantic summary βασισμένο στα realtime δεδομένα
                    return Semantics(
                      container: true,
                      label: _buildSemanticSummaryFrom(transactions),
                      child: transactions.isEmpty
                          ? _buildEmptyState(brightness)
                          : _buildTransactionsList(transactions, brightness),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
