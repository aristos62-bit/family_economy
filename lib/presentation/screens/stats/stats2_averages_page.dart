// ============================================================
// FILE: stats2_averages_page.dart
// PURPOSE: Μέσοι Όροι Κατανάλωσης (Firebase + Providers, offline-safe)
// Location: lib/presentation/screens/stats/stats2_averages_page.dart
//
// ✅ Uses:
//   - TransactionsProvider (loadPeriod + cache + realtime listener, offline-safe)
//   - CategoriesProvider (getCategoryByUuid / getSubcategoryByUuid / getCategoriesByType)
//   - UI_TOKENS (ui_tokens.dart) for dark mode colors
//   - AccessibilityService
//
// NOTE:
// - Υπολογίζει Μ.Ο. κατανάλωσης ΜΟΝΟ για έξοδα (χωρίς μεταφορές)
// - Ο χρήστης επιλέγει το χρονικό διάστημα (από-έως)
// - Συνολικοί μήνες: σταθμισμένοι μήνες μεταξύ ημ/νίας από και έως
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';

import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';

class Stats2AveragesPage extends StatefulWidget {
  const Stats2AveragesPage({super.key});

  @override
  State<Stats2AveragesPage> createState() => _Stats2AveragesPageState();
}

class _Stats2AveragesPageState extends State<Stats2AveragesPage> {
  static const String _periodKey = 'STATS2_AVERAGES';

  // ✅ ΝΕΟ: State για επιλογή ημερομηνιών
  DateTime? _fromDate;
  DateTime? _toDate;

  bool _loadScheduled = false;
  DateTime? _listeningStart;
  DateTime? _listeningEnd;

  // ✅ ΝΕΟ: για να αποφεύγουμε πολλαπλές αναφορές κατά την αλλαγή ημερομηνιών
  bool _isRefreshing = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default: τρέχων μήνας (1η ημέρα έως τέλος μήνα)
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month + 1, 0);
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Μέσοι Όροι Κατανάλωσης. '
          'Επιλέξτε χρονικό διάστημα για να δείτε τους μέσους όρους.',
    );
  }

  // ------------------ HELPERS: DATE PICKER ------------------

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isFrom ? 'Ημ/νία από' : 'Ημ/νία έως',
      locale: const Locale('el', 'GR'),
    );
    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
          _toDate = _fromDate;
        }
      } else {
        _toDate = picked;
        if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
          _fromDate = _toDate;
        }
      }
      // Καθαρισμός cache για να φορτωθεί το νέο διάστημα
      _listeningStart = null;
      _listeningEnd = null;
    });
    AccessibilityService.announcePolite(
      isFrom
          ? 'Ημερομηνία από: ${_dateFormat.format(picked)}'
          : 'Ημερομηνία έως: ${_dateFormat.format(picked)}',
    );
  }

  // ------------------ OFFLINE-SAFE listener ------------------

  void _ensureTransactionsListener({
    required TransactionsProvider transactionsP,
    required DateTime from,
    required DateTime to,
  }) {
    final rangeChanged = _listeningStart == null ||
        _listeningEnd == null ||
        _listeningStart != from ||
        _listeningEnd != to;

    if (!rangeChanged || _loadScheduled) return;

    _listeningStart = from;
    _listeningEnd = to;
    _loadScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!mounted) return;

      transactionsP.loadPeriod(_periodKey, from, to);
    });
  }

  Future<void> _refresh(TransactionsProvider tp) async {
    if (_fromDate == null || _toDate == null) return;
    AccessibilityService.announcePolite('Ανανέωση δεδομένων...');
    setState(() => _isRefreshing = true);
    await tp.loadPeriod(_periodKey, _fromDate!, _toDate!);
    if (mounted) setState(() => _isRefreshing = false);
  }

  // ------------------ CALC helpers ------------------

  /// Υπολογίζει τους μήνες με βάρος για το διάστημα [start, end].
  /// Ο πρώτος μήνας και ο τελευταίος μήνας λαμβάνουν κλάσμα ανάλογα με την ημέρα έναρξης/λήξης.
  double _monthsWeightedForRange(DateTime start, DateTime end) {
    // Κανονικοποίηση στην 1η ημέρα του μήνα για τον πρώτο μήνα
    final firstMonthStart = DateTime(start.year, start.month, 1);
    final lastMonthStart = DateTime(end.year, end.month, 1);

    // Πλήρεις μήνες μεταξύ firstMonthStart και lastMonthStart
    final fullMonths = (lastMonthStart.year - firstMonthStart.year) * 12 +
        (lastMonthStart.month - firstMonthStart.month);

    // Βάρος πρώτου μήνα: ημέρες από start έως τέλος μήνα / σύνολο ημερών μήνα
    final daysInFirstMonth = DateTime(start.year, start.month + 1, 0).day;
    final daysFromStartToEndOfMonth = daysInFirstMonth - start.day + 1;
    final firstMonthWeight = daysFromStartToEndOfMonth / daysInFirstMonth;

    // Βάρος τελευταίου μήνα: ημέρες από 1η έως end.day / σύνολο ημερών μήνα
    final daysInLastMonth = DateTime(end.year, end.month + 1, 0).day;
    final lastMonthWeight = end.day / daysInLastMonth;

    // Αν start και end είναι στον ίδιο μήνα
    if (start.year == end.year && start.month == end.month) {
      final totalDaysInMonth = daysInFirstMonth;
      final daysInRange = end.day - start.day + 1;
      return daysInRange / totalDaysInMonth;
    }

    return fullMonths + firstMonthWeight + lastMonthWeight;
  }

  String _formatPeriod(DateTime from, DateTime to) {
    final df = DateFormat('dd/MM/yyyy', 'el_GR');
    return '${df.format(from)} → ${df.format(to)}';
  }

  // ------------------ BUILD ------------------

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Consumer2<CategoriesProvider, TransactionsProvider>(
      builder: (context, categoriesP, transactionsP, _) {
        // Αν δεν έχουν επιλεγεί ημερομηνίες, εμφανίζουμε ένα μήνυμα
        if (_fromDate == null || _toDate == null) {
          return Scaffold(
            backgroundColor: context.cBg,
            appBar: _buildAppBar(brightness),
            body: Center(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.calendar_month,
                        size: 64,
                        color: context.cText2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Επιλέξτε χρονικό διάστημα',
                      style: context.titleMd.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Χρησιμοποιήστε τα πεδία παραπάνω για να ορίσετε την περίοδο ανάλυσης',
                      style: context.bodySm,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ✅ Φόρτωση συναλλαγών για το επιλεγμένο διάστημα
        _ensureTransactionsListener(
          transactionsP: transactionsP,
          from: _fromDate!,
          to: _toDate!,
        );

        final allTxs = transactionsP.getTransactionsForPeriod(_periodKey);

        // Build fast lookup for expense category ids
        final expenseCategories = categoriesP.getCategoriesByType('expense');
        final expenseCatIds = expenseCategories.map((c) => c.uuid).toSet();

        // Filter: expense only, no transfers, no deleted
        final expenseTxs = allTxs.where((t) {
          if (t.isTransfer) return false;
          if (t.categoryId == null) return false;
          if (!expenseCatIds.contains(t.categoryId)) return false;
          // expense amounts are negative
          return t.amount < 0;
        }).toList();

        final isLoading = transactionsP.isLoadingPeriod(_periodKey);
        final hasError = transactionsP.getErrorForPeriod(_periodKey) != null;

        // Υπολογισμός συνολικών μηνών με βάση το επιλεγμένο διάστημα (όχι τα transactions)
        final totalMonths = _monthsWeightedForRange(_fromDate!, _toDate!);

        // Αν δεν υπάρχουν έξοδα στην περίοδο
        if (!isLoading && expenseTxs.isEmpty) {
          return Scaffold(
            backgroundColor: context.cBg,
            appBar: _buildAppBar(brightness),
            body: RefreshIndicator(
              onRefresh: () => _refresh(transactionsP),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDateRangeCard(),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Card(
                      color: context.cSurface,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                Icons.info_outline,
                                size: 48,
                                color: context.cText2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Δεν υπάρχουν έξοδα στην επιλεγμένη περίοδο',
                              style: context.titleMd.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Δοκιμάστε διαφορετικό χρονικό διάστημα',
                              style: context.bodySm,
                              textAlign: TextAlign.center,
                            ),
                            if (hasError) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Σφάλμα φόρτωσης: ${transactionsP.getErrorForPeriod(_periodKey)}',
                                style: context.bodySm.copyWith(color: ColorsUI.getError(brightness)),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Aggregate by category/subcategory
        final Map<String, _CategoryAvg> categories = {};

        for (final t in expenseTxs) {
          final catId = t.categoryId!;
          final cat = categoriesP.getCategoryByUuid(catId);
          final catName = cat?.name ?? 'Άγνωστη Κατηγορία';

          final subId = t.subcategoryId;
          String subName = 'Χωρίς υποκατηγορία';
          if (subId != null) {
            final sub = categoriesP.getSubcategoryByUuid(catId, subId);
            subName = sub?.name ?? 'Άγνωστη Υποκατηγορία';
          }

          final catEntry = categories.putIfAbsent(
            catId,
                () => _CategoryAvg(id: catId, name: catName),
          );

          catEntry.totalAmountAbs += t.amount.abs();

          final subKey = subId ?? '_none';
          final subEntry = catEntry.subs.putIfAbsent(
            subKey,
                () => _SubAvg(id: subKey, name: subName),
          );

          subEntry.totalAmountAbs += t.amount.abs();
          subEntry.count += 1;
        }

        // Ταξινόμηση κατηγοριών κατά Μ.Ο. φθίνουσα
        final sortedCats = categories.values.toList()
          ..sort((a, b) {
            final avgA = totalMonths > 0 ? a.totalAmountAbs / totalMonths : 0.0;
            final avgB = totalMonths > 0 ? b.totalAmountAbs / totalMonths : 0.0;
            return avgB.compareTo(avgA);
          });
        for (final c in sortedCats) {
          final subsList = c.subs.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          c._sortedSubs = subsList;
        }

        final horizontalPadding = MediaQuery.of(context).size.width >= 700 ? 18.0 : 12.0;

        return Scaffold(
          backgroundColor: context.cBg,
          appBar: _buildAppBar(brightness),
          body: isLoading || _isRefreshing
              ? Semantics(
            liveRegion: true,
            label: 'Υπολογισμός μέσων όρων. Παρακαλώ περιμένετε.',
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ExcludeSemantics(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  ExcludeSemantics(
                    child: Text(
                      'Υπολογισμός μέσων όρων...',
                      style: context.bodySm,
                    ),
                  ),
                ],
              ),
            ),
          )
              : RefreshIndicator(
            onRefresh: () => _refresh(transactionsP),
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
              children: [
                _buildDateRangeCard(),
                const SizedBox(height: 10),

                // Header card with period info
                Semantics(
                  container: true,
                  child: Card(
                    color: context.cSurface,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: ColorsUI.getBorder(brightness)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.info_outline,
                                  color: ColorsUI.getInfo(brightness),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    'Περίοδος Ανάλυσης',
                                    style: context.titleMd.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Semantics(
                            label: 'Περίοδος: ${_formatPeriod(_fromDate!, _toDate!)}',
                            child: ExcludeSemantics(
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month, size: 18, color: context.cText2),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatPeriod(_fromDate!, _toDate!),
                                      style: context.bodySm.copyWith(color: context.cText2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Semantics(
                            label: 'Σταθμισμένοι μήνες: ${totalMonths.toStringAsFixed(2)}',
                            child: ExcludeSemantics(
                              child: Row(
                                children: [
                                  Icon(Icons.timelapse, size: 18, color: context.cText2),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Σταθμισμένοι Μήνες: ${totalMonths.toStringAsFixed(2)}',
                                    style: context.bodySm.copyWith(color: context.cText2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Οι μέσοι όροι υπολογίζονται με βάση τα έξοδα σας (χωρίς μεταφορές) '
                                'για την παραπάνω περίοδο.',
                            style: context.bodySm.copyWith(
                              fontStyle: FontStyle.italic,
                              color: context.cText2,
                            ),
                          ),
                          if (hasError) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Σφάλμα φόρτωσης: ${transactionsP.getErrorForPeriod(_periodKey)}',
                              style: context.bodySm.copyWith(color: ColorsUI.getError(brightness)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Categories list
                ...sortedCats.map((cat) {
                  final monthlyAvg = totalMonths > 0 ? cat.totalAmountAbs / totalMonths : 0.0;

                  return Semantics(
                    container: true,
                    label: 'Κατηγορία ${cat.name}, μέσος όρος ${CurrencyFormatter.format(monthlyAvg)} ανά μήνα',
                    child: Card(
                      color: context.cSurface,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: ColorsUI.getBorder(brightness)),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        leading: ExcludeSemantics(
                          child: CircleAvatar(
                            backgroundColor: ColorsUI.getExpenseColor(brightness).withValues(alpha: 0.15),
                            child: Icon(
                              Icons.category,
                              color: ColorsUI.getExpenseColor(brightness),
                            ),
                          ),
                        ),
                        title: Text(
                          cat.name,
                          style: context.bodyMd.copyWith(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Μ.Ο. μηνιαίας κατανάλωσης: ${CurrencyFormatter.format(monthlyAvg)}',
                          style: context.bodySm.copyWith(
                            color: ColorsUI.getExpenseColor(brightness),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onExpansionChanged: (expanded) {
                          AccessibilityService.announcePolite(
                            expanded
                                ? 'Ανάπτυξη κατηγορίας ${cat.name}'
                                : 'Σύμπτυξη κατηγορίας ${cat.name}',
                          );
                        },
                        children: [
                          ExcludeSemantics(
                            child: Divider(height: 1, color: ColorsUI.getDivider(brightness)),
                          ),
                          ...cat.sortedSubs.map((sub) {
                            final subMonthly = totalMonths > 0 ? sub.totalAmountAbs / totalMonths : 0.0;

                            return Semantics(
                              container: true,
                              label: 'Υποκατηγορία ${sub.name}, μέσος όρος '
                                  '${CurrencyFormatter.format(subMonthly)} ανά μήνα, '
                                  '${sub.count} συναλλαγές',
                              child: ExcludeSemantics(
                                child: ListTile(
                                  leading: Icon(
                                    Icons.subdirectory_arrow_right,
                                    color: context.cText2,
                                  ),
                                  title: Text(sub.name, style: context.bodyMd),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 2),
                                      Text(
                                        'Μ.Ο./μήνα: ${CurrencyFormatter.format(subMonthly)}',
                                        style: context.bodySm.copyWith(
                                          color: ColorsUI.getWarning(brightness),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${sub.count} συναλλαγές',
                                        style: context.bodySm.copyWith(color: context.cText2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------ UI COMPONENTS ------------------

  PreferredSizeWidget _buildAppBar(Brightness brightness) {
    return AppBar(
      backgroundColor: ColorsUI.getPrimary(brightness),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Semantics(
        button: true,
        label: 'Πίσω',
        child: IconButton(
          icon: const ExcludeSemantics(child: Icon(Icons.arrow_back)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Semantics(
        header: true,
        child: Text(
          'Μέσοι Όροι Κατανάλωσης',
          style: context.titleMd.copyWith(
            color: ColorsUI.getOnPrimary(brightness),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeCard() {
    return Card(
      elevation: 2,
      color: context.cSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ExcludeSemantics(
                child: Icon(Icons.calendar_month, color: context.cPrimary, size: 22),
              ),
              const SizedBox(width: 8),
              Semantics(
                header: true,
                child: Text(
                  'Χρονικό Διάστημα',
                  style: TextStyle(fontWeight: FontWeight.bold, color: context.cText),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Ημερομηνία από. ${_fromDate == null ? 'Μη επιλεγμένη' : _dateFormat.format(_fromDate!)}',
                  child: InkWell(
                    onTap: () => _pickDate(isFrom: true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Από',
                        border: const OutlineInputBorder(),
                        prefixIcon: const ExcludeSemantics(child: Icon(Icons.calendar_today)),
                        isDense: true,
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          _fromDate == null ? 'Επιλογή ημερομηνίας' : _dateFormat.format(_fromDate!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Ημερομηνία έως. ${_toDate == null ? 'Μη επιλεγμένη' : _dateFormat.format(_toDate!)}',
                  child: InkWell(
                    onTap: () => _pickDate(isFrom: false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Έως',
                        border: const OutlineInputBorder(),
                        prefixIcon: const ExcludeSemantics(child: Icon(Icons.calendar_today)),
                        isDense: true,
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          _toDate == null ? 'Επιλογή ημερομηνίας' : _dateFormat.format(_toDate!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ------------------ INTERNAL DATA ------------------

class _CategoryAvg {
  final String id;
  final String name;
  double totalAmountAbs = 0.0;

  final Map<String, _SubAvg> subs = {};
  List<_SubAvg> _sortedSubs = const [];

  _CategoryAvg({required this.id, required this.name});

  List<_SubAvg> get sortedSubs => _sortedSubs;
}

class _SubAvg {
  final String id; // subUuid or '_none'
  final String name;
  double totalAmountAbs = 0.0;
  int count = 0;

  _SubAvg({required this.id, required this.name});
}