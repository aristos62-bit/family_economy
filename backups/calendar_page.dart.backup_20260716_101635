// ============================================================
// FILE: calendar_page.dart
// Path: lib/presentation/screens/calendar/calendar_page.dart
// Ρόλος: Ημερολόγιο με real-time ενημέρωση εσόδων/εξόδων
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/core/utils/debug_config.dart';

import 'package:family_economy/providers/transactions_provider.dart';
import 'package:family_economy/providers/categories_provider.dart';

// ✅ Notifications
import 'package:family_economy/models/notification_model.dart';
import 'package:family_economy/providers/notifications_provider.dart';
import 'package:family_economy/core/widgets/notifications_list_widget.dart';
import 'package:family_economy/core/widgets/notification_edit_dialog.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _selectedMonth;
  DateTime? _selectedDay;

  int _monthLoadSeq = 0;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _selectedDay = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      AccessibilityService.announceAfterFirstFrame(
        context,
        'Ημερολόγιο ${_getMonthYearText(_selectedMonth)}',
      );

      _loadMonthData();
    });
  }

  Future<void> _loadMonthData() async {
    if (!mounted) return;

    final int seq = ++_monthLoadSeq;
    final month = _selectedMonth;

    await context.read<CategoriesProvider>().firstLoad;

    if (!mounted || seq != _monthLoadSeq) return;

    final transactionsProvider = context.read<TransactionsProvider>();

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 1);

    final periodKey = _getPeriodKey(month);

    await transactionsProvider.loadPeriod(periodKey, startDate, endDate);
  }

  String _getPeriodKey(DateTime month) {
    return '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }

  String _getMonthYearText(DateTime month) {
    const monthNames = [
      'Ιανουάριος',
      'Φεβρουάριος',
      'Μάρτιος',
      'Απρίλιος',
      'Μάιος',
      'Ιούνιος',
      'Ιούλιος',
      'Αύγουστος',
      'Σεπτέμβριος',
      'Οκτώβριος',
      'Νοέμβριος',
      'Δεκέμβριος',
    ];
    return '${monthNames[month.month - 1]} ${month.year}';
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _selectedDay = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadMonthData();
    });

    AccessibilityService.announcePolite(_getMonthYearText(_selectedMonth));
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _selectedDay = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadMonthData();
    });

    AccessibilityService.announcePolite(_getMonthYearText(_selectedMonth));
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      _selectedDay = day;
    });

    final dateLabel = AccessibilityService.dateLabel(day);
    AccessibilityService.announcePolite('Επιλέχθηκε: $dateLabel');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsUI.getBackground(context.brightness),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;
          final isDesktop = constraints.maxWidth >= 1200;

          return SafeArea(
            child: Column(
              children: [
                _buildMonthHeader(context),
                _buildWeekdayHeaders(context),

                Expanded(
                  child: Consumer2<TransactionsProvider, CategoriesProvider>(
                    builder:
                        (context, transactionsProvider, categoriesProvider, _) {
                          if (categoriesProvider.isLoading &&
                              !categoriesProvider.hasSubcategoriesLoaded) {
                            return Semantics(
                              liveRegion: true,
                              label:
                                  'Φόρτωση ημερολογίου. Παρακαλώ περιμένετε.',
                              excludeSemantics: true,
                              child: const Center(
                                child: ExcludeSemantics(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            );
                          }

                          final periodKey = _getPeriodKey(_selectedMonth);
                          final transactions = transactionsProvider
                              .getTransactionsForPeriod(periodKey);

                          final categoryTypes = <String, String>{};
                          for (final category
                              in categoriesProvider.allCategories) {
                            categoryTypes[category.uuid] = category.type;
                          }

                          final dayTotalsMap = _buildDayTotalsMap(
                            transactions,
                            categoryTypes,
                          );

                          return Column(
                            children: [
                              Expanded(
                                child: _buildCalendarGridWithTotals(
                                  context,
                                  isTablet,
                                  isDesktop,
                                  dayTotalsMap,
                                ),
                              ),
                            ],
                          );
                        },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorsUI.getPrimary(context.brightness),
            ColorsUI.getSecondary(context.brightness).withValues(alpha: 0.88),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AccessibilityService.accessibleButton(
            label: 'Προηγούμενος μήνας',
            hint: 'Μεταβείτε στον προηγούμενο μήνα',
            onPressed: _previousMonth,
            child: Icon(
              Icons.chevron_left_rounded,
              size: 32,
              color: ColorsUI.getOnPrimary(context.brightness),
            ),
          ),

          Semantics(
            label: 'Τρέχων μήνας: ${_getMonthYearText(_selectedMonth)}',
            header: true,
            child: Text(
              _getMonthYearText(_selectedMonth),
              style: TypographyUI.headlineMedium(Theme.of(context).brightness)
                  .copyWith(
                    color: ColorsUI.getOnPrimary(Theme.of(context).brightness),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),

          AccessibilityService.accessibleButton(
            label: 'Επόμενος μήνας',
            hint: 'Μεταβείτε στον επόμενο μήνα',
            onPressed: _nextMonth,
            child: Icon(
              Icons.chevron_right_rounded,
              size: 32,
              color: ColorsUI.getOnPrimary(context.brightness),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders(BuildContext context) {
    const weekdays = ['Δε', 'Τρ', 'Τε', 'Πε', 'Πα', 'Σα', 'Κυ'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: ColorsUI.getSurface(context.brightness),
      child: Row(
        children: weekdays.map((day) {
          return Expanded(
            child: ExcludeSemantics(
              child: Center(
                child: Text(
                  day,
                  style: TypographyUI.labelLarge(Theme.of(context).brightness).copyWith(
                    color: ColorsUI.getTextSecondary(Theme.of(context).brightness),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGridWithTotals(
    BuildContext context,
    bool isTablet,
    bool isDesktop,
    Map<String, _DayData> dayTotalsMap,
  ) {
    final firstDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    );

    final startWeekday = firstDayOfMonth.weekday - 1;

    final totalDays = lastDayOfMonth.day;
    final totalCells = ((startWeekday + totalDays) / 7).ceil() * 7;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: isDesktop ? 1.2 : (isTablet ? 1.0 : 0.75),
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNumber = index - startWeekday + 1;

        if (index < startWeekday) {
          return const SizedBox.shrink();
        }

        if (dayNumber > totalDays) {
          return const SizedBox.shrink();
        }

        final currentDay = DateTime(
          _selectedMonth.year,
          _selectedMonth.month,
          dayNumber,
        );

        final today = _dateOnly(DateTime.now());

        final isToday = _isSameDay(currentDay, today);
        final isSelected =
            _selectedDay != null && _isSameDay(currentDay, _selectedDay!);

        final isFutureDay = currentDay.isAfter(today);

        final key = _dateKey(currentDay);
        final dayData =
            dayTotalsMap[key] ?? _DayData(income: 0.0, expense: 0.0);

        return _buildDayCell(
          context,
          currentDay,
          dayNumber,
          isToday,
          isSelected,
          isFutureDay,
          dayData,
        );
      },
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    int dayNumber,
    bool isToday,
    bool isSelected,
    bool isFutureDay,
    _DayData dayData,
  ) {
    final hasIncome = dayData.income > 0;
    final hasExpense = dayData.expense > 0;
    final balance = dayData.income - dayData.expense;

    // ✅ Πάρε όλες τις υπενθυμίσεις της ημέρας μία φορά
    final allNotifications = context
        .watch<NotificationsProvider>()
        .getNotificationsForDate(day);

    // 1️⃣ Χωρίζουμε απλά & recurring
    final normalNotifications = allNotifications
        .where((n) => !n.isRecurring)
        .toList();

    final recurringNotifications = allNotifications
        .where((n) => n.isRecurring)
        .toList();

    // 2️⃣ Από τα recurring κρατάμε ΜΟΝΟ το επόμενο (αν υπάρχει)
    NotificationModel? nextRecurring;

    if (recurringNotifications.isNotEmpty) {
      recurringNotifications.sort(
        (a, b) => a.scheduledFor.compareTo(b.scheduledFor),
      );

      nextRecurring = recurringNotifications.firstWhere(
        (n) => !n.scheduledFor.isBefore(_dateOnly(DateTime.now())),
        orElse: () => recurringNotifications.first,
      );
    }

    // 3️⃣ Τελική λίστα που θα εμφανιστεί στο ημερολόγιο
    final visibleNotifications = [
      ...normalNotifications,
      ?nextRecurring,
    ];

    final notificationsCount = visibleNotifications.length;
    final hasRecurring = nextRecurring != null;

    final dateLabel = AccessibilityService.dateLabel(day);
    String accessibilityLabel = dateLabel;

    if (isToday) {
      accessibilityLabel += ', Σήμερα';
    }

    if (hasIncome || hasExpense) {
      accessibilityLabel +=
          ', Έσοδα: ${CurrencyFormatter.format(dayData.income)}, '
          'Έξοδα: ${CurrencyFormatter.format(dayData.expense)}, '
          'Διαφορά: ${CurrencyFormatter.format(balance)}';
    } else {
      accessibilityLabel += ', Καμία κίνηση';
    }

    // ✅ NEW: accessibility για υπενθυμίσεις
    // ✅ accessibility για υπενθυμίσεις
    if (notificationsCount > 0) {
      accessibilityLabel += ', Υπενθυμίσεις: $notificationsCount';
      if (hasRecurring) {
        accessibilityLabel += ', Περιλαμβάνει επαναλαμβανόμενη υπενθύμιση';
      }
    }

    return AccessibilityService.accessibleButton(
      label: accessibilityLabel,
      hint: isSelected ? 'Επιλεγμένη ημέρα' : 'Πατήστε για λεπτομέρειες',
      enabled: true,
      onPressed: () {
        _onDaySelected(day);
        _showDayDetailsDialog(day);
      },
      child: Container(
        decoration: BoxDecoration(
          color: _getDayCellColor(context, isToday, isSelected, isFutureDay),
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(
                  color: ColorsUI.getPrimary(context.brightness),
                  width: 2,
                )
              : null,
        ),
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 4,
              right: 4,
              child: Text(
                dayNumber.toString(),
                style: TypographyUI.titleMedium(Theme.of(context).brightness)
                    .copyWith(
                      color: isFutureDay
                          ? ColorsUI.getTextSecondary(
                              Theme.of(context).brightness,
                            ).withValues(alpha: 0.5)
                          : (isSelected || isToday)
                          ? ColorsUI.getPrimary(Theme.of(context).brightness)
                          : ColorsUI.getTextPrimary(
                              Theme.of(context).brightness,
                            ),
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ),

            // ✅ Recurring indicator στη μέση (κάτω από τον αριθμό ημέρας)
            if (hasRecurring)
              Positioned(
                top: 26,
                left: 0,
                right: 0,
                child: ExcludeSemantics(
                  child: Center(
                    child: Icon(Icons.repeat, size: 16, color: Colors.yellow),
                  ),
                ),
              ),

            if (!isFutureDay && (hasIncome || hasExpense))
              Positioned(
                top: 2,
                left: 2,
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasIncome)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: ColorsUI.getIncomeColor(context.brightness),
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (hasIncome && hasExpense) const SizedBox(width: 2),
                      if (hasExpense)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: ColorsUI.getExpenseColor(context.brightness),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // ✅ Μπλε τελεία notifications (πάνω δεξιά)
            if (notificationsCount > 0)
              Positioned(
                top: 2,
                right: 2,
                child: ExcludeSemantics(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

            if (!isFutureDay && (hasIncome || hasExpense))
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: ExcludeSemantics(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      CurrencyFormatter.format(balance, decimalDigits: 0),
                      style:
                          TypographyUI.bodySmall(
                            Theme.of(context).brightness,
                          ).copyWith(
                            color: balance >= 0
                                ? ColorsUI.getIncomeColor(
                                    Theme.of(context).brightness,
                                  )
                                : ColorsUI.getExpenseColor(
                                    Theme.of(context).brightness,
                                  ),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getDayCellColor(
    BuildContext context,
    bool isToday,
    bool isSelected,
    bool isFutureDay,
  ) {
    if (isFutureDay) {
      return ColorsUI.getSurface(context.brightness).withValues(alpha: 0.3);
    }

    if (isSelected) {
      return ColorsUI.getPrimary(context.brightness).withValues(alpha: 0.15);
    }

    if (isToday) {
      return ColorsUI.getPrimary(context.brightness).withValues(alpha: 0.08);
    }

    return ColorsUI.getSurface(context.brightness);
  }
  // ============================================================
  // HELPER METHODS
  // ============================================================

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, _DayData> _buildDayTotalsMap(
    List<TransactionModel> transactions,
    Map<String, String> categoryTypes,
  ) {
    final map = <String, _DayData>{};

    for (final tx in transactions) {
      if (tx.isTransfer) continue;

      final categoryType = tx.categoryId != null
          ? categoryTypes[tx.categoryId]
          : null;
      if (categoryType != 'income' && categoryType != 'expense') continue;

      final key = _dateKey(tx.date);
      final existing = map[key] ?? _DayData(income: 0.0, expense: 0.0);

      if (categoryType == 'income') {
        map[key] = _DayData(
          income: existing.income + tx.amount.abs(),
          expense: existing.expense,
        );
      } else {
        map[key] = _DayData(
          income: existing.income,
          expense: existing.expense + tx.amount.abs(),
        );
      }
    }

    return map;
  }

  DateTime _dateOnly(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  // ============================================================
  // SHOW DAY DETAILS DIALOG
  // ============================================================

  void _showDayDetailsDialog(DateTime day) {
    final today = _dateOnly(DateTime.now());
    final isPastDay = day.isBefore(today);

    // ✅ Παίρνουμε τα δεδομένα ΕΔΩ (έξω από το dialog) όπου έχουμε πρόσβαση στους providers
    final transactionsProvider = context.read<TransactionsProvider>();
    final categoriesProvider = context.read<CategoriesProvider>();
    final notificationsProvider = context.read<NotificationsProvider>();

    final periodKey = _getPeriodKey(_selectedMonth);
    final transactions = transactionsProvider.getTransactionsForPeriod(
      periodKey,
    );

    final categoryTypes = <String, String>{};
    for (final category in categoriesProvider.allCategories) {
      categoryTypes[category.uuid] = category.type;
    }

    final dayTotalsMap = _buildDayTotalsMap(transactions, categoryTypes);
    final dayKey = _dateKey(day);
    final dayData = dayTotalsMap[dayKey] ?? _DayData(income: 0.0, expense: 0.0);

    final dayNotifications = notificationsProvider.getNotificationsForDate(day);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _DayDetailsDialog(
        day: day,
        isPastDay: isPastDay,
        dayData: dayData,
        dayNotifications: dayNotifications,
        notificationsProvider: notificationsProvider, // ✅ Περνάμε τον provider
      ),
    );
  }
}

// ============================================================
// HELPER CLASSES
// ============================================================

class _DayData {
  final double income;
  final double expense;

  _DayData({required this.income, required this.expense});
}

// ============================================================
// DAY DETAILS DIALOG (with expandable notifications)
// ============================================================

class _DayDetailsDialog extends StatefulWidget {
  final DateTime day;
  final bool isPastDay;
  final _DayData dayData;
  final List<NotificationModel> dayNotifications;
  final NotificationsProvider notificationsProvider;

  const _DayDetailsDialog({
    required this.day,
    required this.isPastDay,
    required this.dayData,
    required this.dayNotifications,
    required this.notificationsProvider,
  });

  @override
  State<_DayDetailsDialog> createState() => _DayDetailsDialogState();
}

class _DayDetailsDialogState extends State<_DayDetailsDialog>
    with SingleTickerProviderStateMixin {
  bool _showNotifications = false;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  late List<NotificationModel> _currentNotifications;

  @override
  void initState() {
    super.initState();
    _currentNotifications = List.from(widget.dayNotifications);

    widget.notificationsProvider.addListener(_syncNotificationsFromProvider);
    _syncNotificationsFromProvider();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heightAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    widget.notificationsProvider.removeListener(_syncNotificationsFromProvider);
    _animationController.dispose();
    super.dispose();
  }

  void _toggleNotifications() {
    setState(() {
      _showNotifications = !_showNotifications;
    });

    if (_showNotifications) {
      _animationController.forward();
      AccessibilityService.announcePolite('Εμφάνιση υπενθυμίσεων');
    } else {
      _animationController.reverse();
      AccessibilityService.announcePolite('Απόκρυψη υπενθυμίσεων');
    }
  }

  Future<void> _addNotification() async {
    DebugConfig.print('🔔 [DIALOG] _addNotification called');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => NotificationEditDialog(selectedDate: widget.day),
    );

    DebugConfig.print('🔔 [DIALOG] Result: $result');

    if (result == null || !mounted) return;

    try {
      final scheduledFor = result['scheduledFor'] as DateTime;
      final message = result['message'] as String;

      final isRecurring = (result['isRecurring'] as bool?) ?? false;
      final frequency = result['frequency'] as String?; // daily|weekly|monthly
      final frequencyInterval = result['frequencyInterval'] as int?;
      final skipWeekends = (result['skipWeekends'] as bool?) ?? false;

      final recurringEndAt = result['recurringEndAt'] as DateTime?;
      final maxOccurrences = result['maxOccurrences'] as int?;

      final notificationId = await widget.notificationsProvider
          .createNotification(
            title: 'Υπενθύμιση',
            message: message,
            scheduledFor: scheduledFor,
            isRecurring: isRecurring,
            frequency: frequency,
            frequencyInterval: frequencyInterval,
            skipWeekends: skipWeekends,
            recurringEndAt: recurringEndAt,
            maxOccurrences: maxOccurrences,
          );
      DebugConfig.print('🔔 [DIALOG] Created notification: $notificationId');

      // ✅ UI refresh (χωρίς delays)
      final updatedNotifications = widget.notificationsProvider
          .getNotificationsForDate(widget.day);
      if (!mounted) return;

      setState(() {
        _currentNotifications = List.from(updatedNotifications);
      });

      AccessibilityService.announceSuccess(
        'Η υπενθύμιση δημιουργήθηκε επιτυχώς',
      );
    } catch (e, stackTrace) {
      DebugConfig.print('❌ [DIALOG] ERROR: $e');
      DebugConfig.print('❌ [DIALOG] Stack: $stackTrace');
      if (mounted) {
        AccessibilityService.announceError('Σφάλμα δημιουργίας υπενθύμισης');
      }
    }
  }

  Future<void> _editNotification(NotificationModel notification) async {
    // ✅ Block editing for recurring children (keep only root editable)
    final occIndex = notification.occurrenceIndex ?? 0;
    if (notification.isRecurring && occIndex > 0) {
      if (mounted) {
        AccessibilityService.announcePolite(
          'Αυτή είναι εμφάνιση επαναλαμβανόμενης υπενθύμισης. Δεν επιτρέπεται επεξεργασία.',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Επαναλαμβανόμενο: δεν επιτρέπεται επεξεργασία σε εμφάνιση.',
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => NotificationEditDialog(
        selectedDate: widget.day,
        notification: notification,
      ),
    );

    if (result == null || !mounted) return;

    try {
      final newMessage = result['message'] as String;
      final newScheduledFor = result['scheduledFor'] as DateTime;

      final isRecurring = (result['isRecurring'] as bool?) ?? false;
      final frequency = result['frequency'] as String?;
      final frequencyInterval = result['frequencyInterval'] as int?;
      final skipWeekends = (result['skipWeekends'] as bool?) ?? false;

      final recurringEndAt = result['recurringEndAt'] as DateTime?;
      final maxOccurrences = result['maxOccurrences'] as int?;

      await widget.notificationsProvider.updateNotification(
        notificationId: notification.uuid,
        message: newMessage,
        scheduledFor: newScheduledFor,
        isRecurring: isRecurring,
        frequency: frequency,
        frequencyInterval: frequencyInterval,
        skipWeekends: skipWeekends,
        recurringEndAt: recurringEndAt,
        maxOccurrences: maxOccurrences,
      );

      // ✅ UI refresh
      final updatedNotifications = widget.notificationsProvider
          .getNotificationsForDate(widget.day);
      if (!mounted) return;

      setState(() {
        _currentNotifications = List.from(updatedNotifications);
      });

      AccessibilityService.announceSuccess('Η υπενθύμιση ενημερώθηκε');
    } catch (e) {
      DebugConfig.print('❌ Error updating: $e');
      if (mounted) {
        AccessibilityService.announceError('Σφάλμα ενημέρωσης υπενθύμισης');
      }
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    // Αν είναι recurring, δίνουμε επιλογή: Μόνο αυτό / Όλη η σειρά
    if (notification.isRecurring) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: ColorsUI.getSurface(context.brightness),
          title: Text(
            'Διαγραφή Επαναλαμβανόμενης Υπενθύμισης',
            style: TypographyUI.titleMedium(context.brightness),
          ),
          content: Text(
            'Θέλετε να διαγράψετε μόνο αυτή την εμφάνιση ή όλη τη σειρά;',
            style: TypographyUI.bodyMedium(context.brightness),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: Text(
                'Ακύρωση',
                style: TypographyUI.labelLarge(context.brightness),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'one'),
              child: Text(
                'Μόνο αυτό',
                style: TypographyUI.labelLarge(
                  context.brightness,
                ).copyWith(color: ColorsUI.getError(context.brightness)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'series'),
              child: Text(
                'Όλη η σειρά',
                style: TypographyUI.labelLarge(context.brightness).copyWith(
                  color: ColorsUI.getError(context.brightness),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel' || !mounted) return;

      try {
        if (choice == 'one') {
          // ✅ Skip ONLY this occurrence, but keep series alive (offline-safe)
          await widget.notificationsProvider.skipRecurringOccurrence(
            notification.uuid,
          );
        } else if (choice == 'series') {
          final sid = (notification.seriesId ?? notification.uuid).trim();
          await widget.notificationsProvider.deleteRecurringSeries(sid);
        }

        // ✅ UI refresh
        final updatedNotifications = widget.notificationsProvider
            .getNotificationsForDate(widget.day);
        if (!mounted) return;

        setState(() {
          _currentNotifications = List.from(updatedNotifications);
        });

        AccessibilityService.announceSuccess('Η διαγραφή ολοκληρώθηκε');
      } catch (e) {
        DebugConfig.print('❌ Error deleting recurring: $e');
        if (mounted) {
          AccessibilityService.announceError('Σφάλμα διαγραφής υπενθύμισης');
        }
      }

      return;
    }

    // Μη-recurring: κρατάμε την παλιά συμπεριφορά (confirm)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ColorsUI.getSurface(context.brightness),
        title: Text(
          'Διαγραφή Υπενθύμισης',
          style: TypographyUI.titleMedium(context.brightness),
        ),
        content: Text(
          'Είστε σίγουροι ότι θέλετε να διαγράψετε αυτή την υπενθύμιση;',
          style: TypographyUI.bodyMedium(context.brightness),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Ακύρωση',
              style: TypographyUI.labelLarge(context.brightness),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Διαγραφή',
              style: TypographyUI.labelLarge(
                context.brightness,
              ).copyWith(color: ColorsUI.getError(context.brightness)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await widget.notificationsProvider.deleteNotification(notification.uuid);

      // ✅ UI refresh
      final updatedNotifications = widget.notificationsProvider
          .getNotificationsForDate(widget.day);
      setState(() {
        _currentNotifications = List.from(updatedNotifications);
      });

      if (mounted) {
        AccessibilityService.announceSuccess('Η υπενθύμιση διαγράφηκε');
      }
    } catch (e) {
      DebugConfig.print('❌ Error deleting: $e');
      if (mounted) {
        AccessibilityService.announceError('Σφάλμα διαγραφής υπενθύμισης');
      }
    }
  }

  void _syncNotificationsFromProvider() {
    if (!mounted) return;

    final updated = widget.notificationsProvider.getNotificationsForDate(
      widget.day,
    );

    // Αν δεν άλλαξε κάτι ουσιαστικά, μην κάνεις rebuild
    if (_currentNotifications.length == updated.length) {
      final currentIds = _currentNotifications.map((e) => e.uuid).join(',');
      final updatedIds = updated.map((e) => e.uuid).join(',');
      if (currentIds == updatedIds) return;
    }

    setState(() {
      _currentNotifications = List.from(updated);
    });
  }

  String _formatSelectedDate(DateTime date) {
    const weekdays = [
      'Δευτέρα',
      'Τρίτη',
      'Τετάρτη',
      'Πέμπτη',
      'Παρασκευή',
      'Σάββατο',
      'Κυριακή',
    ];
    final weekday = weekdays[date.weekday - 1];

    const monthNames = [
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

    return '$weekday ${date.day.toString().padLeft(2, '0')} ${monthNames[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.print(
      '🔔 [DIALOG] Building with ${_currentNotifications.length} notifications',
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Λεπτομέρειες ημέρας ${_formatSelectedDate(widget.day)}',
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: ColorsUI.getSurface(context.brightness),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: ColorsUI.shadowLight.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🗓️ Title
                Text(
                  _formatSelectedDate(widget.day),
                  style: TypographyUI.titleLarge(
                    context.brightness,
                  ).copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // 💰 Totals
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        context: context,
                        label: 'Έσοδα',
                        amount: widget.dayData.income,
                        color: ColorsUI.getIncomeColor(context.brightness),
                        icon: Icons.add_circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryItem(
                        context: context,
                        label: 'Έξοδα',
                        amount: widget.dayData.expense,
                        color: ColorsUI.getExpenseColor(context.brightness),
                        icon: Icons.remove_circle,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ✅ Notifications toggle button
                AccessibilityService.accessibleButton(
                  label: _showNotifications
                      ? 'Απόκρυψη υπενθυμίσεων'
                      : widget.isPastDay
                      ? 'Προβολή υπενθυμίσεων'
                      : 'Εμφάνιση υπενθυμίσεων',
                  hint: widget.isPastDay
                      ? 'Μόνο προβολή και διαγραφή υπενθυμίσεων'
                      : 'Πατήστε για διαχείριση υπενθυμίσεων',
                  onPressed: _toggleNotifications,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _showNotifications
                          ? ColorsUI.getPrimary(
                              context.brightness,
                            ).withValues(alpha: 0.1)
                          : ColorsUI.getSurface(context.brightness),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isPastDay
                            ? ColorsUI.getTextSecondary(
                                context.brightness,
                              ).withValues(alpha: 0.3)
                            : ColorsUI.getPrimary(
                                context.brightness,
                              ).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            _showNotifications
                                ? Icons.notifications_active
                                : Icons.notifications_outlined,
                            color: widget.isPastDay
                                ? ColorsUI.getTextSecondary(context.brightness)
                                : ColorsUI.getPrimary(context.brightness),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.isPastDay
                                ? 'Υπενθυμίσεις (μόνο προβολή)'
                                : 'Υπενθυμίσεις',
                            style: TypographyUI.titleSmall(context.brightness)
                                .copyWith(
                                  color: widget.isPastDay
                                      ? ColorsUI.getTextSecondary(
                                          context.brightness,
                                        )
                                      : ColorsUI.getPrimary(context.brightness),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (_currentNotifications.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.isPastDay
                                  ? ColorsUI.getTextSecondary(
                                      context.brightness,
                                    )
                                  : ColorsUI.getPrimary(context.brightness),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentNotifications.length}',
                              style: TypographyUI.labelSmall(context.brightness)
                                  .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        ExcludeSemantics(
                          child: Icon(
                            _showNotifications ? Icons.expand_less : Icons.expand_more,
                            color: widget.isPastDay
                                ? ColorsUI.getTextSecondary(context.brightness)
                                : ColorsUI.getPrimary(context.brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ✅ Animated notifications list
                SizeTransition(
                  sizeFactor: _heightAnimation,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: NotificationsListWidget(
                      notifications: _currentNotifications,
                      onAddNew: widget.isPastDay
                          ? () {
                              AccessibilityService.announcePolite(
                                'Δεν μπορείτε να προσθέσετε υπενθυμίσεις σε παρελθοντική ημέρα',
                              );
                            }
                          : _addNotification,
                      onEdit: widget.isPastDay
                          ? (notification) {
                              AccessibilityService.announcePolite(
                                'Δεν μπορείτε να επεξεργαστείτε υπενθυμίσεις παρελθοντικής ημέρας',
                              );
                            }
                          : _editNotification,
                      onDelete: _deleteNotification,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ✅ Close button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Κλείσιμο',
                      style: TypographyUI.labelLarge(context.brightness),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required BuildContext context,
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    final formattedAmount = CurrencyFormatter.format(amount);

    return Semantics(
      label: '$label: $formattedAmount',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TypographyUI.labelLarge(context.brightness).copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formattedAmount,
              style: TypographyUI.currencySmall(
                context.brightness,
              ).copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
