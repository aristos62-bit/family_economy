import 'dart:async';
import 'package:flutter/material.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/presentation/screens/transactions/transaction_entry_page.dart';
import 'package:family_economy/presentation/screens/options/options_page.dart';
import 'package:family_economy/presentation/screens/accounts/accounts_page.dart';
import 'package:family_economy/presentation/screens/scheduled/scheduled_transactions_page.dart';
import 'package:family_economy/presentation/screens/budget/budget_page.dart';
import 'package:family_economy/services/scheduled_transactions_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/presentation/screens/charts/general_view_page.dart';
import 'package:family_economy/presentation/screens/calendar/calendar_page.dart';
import 'package:family_economy/core/widgets/offline_banner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // ✅ PageController για swipe functionality
  late final PageController _pageController;

  // ✅ Timer για periodic check
  Timer? _scheduledCheckTimer;

  // 7 tabs
  final List<IconData> _icons = const [
    Icons.home_rounded,
    Icons.swap_horiz_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.event_available_rounded,
    Icons.calendar_month_rounded,
    Icons.pie_chart_rounded,
    Icons.settings_rounded,
  ];

  final List<String> _tabNames = const [
    'Αρχική',
    'Συναλλαγές',
    'Λογαριασμοί',
    'Προγραμματισμένες Κινήσεις',
    'Ημερολόγιο',
    'Προϋπολογισμοί',
    'Ρυθμίσεις',
  ];

  @override
  void initState() {
    super.initState();

    // ✅ ΔΙΟΡΘΩΣΗ: ΔΕΝ cache-άρουμε το userId εδώ (SessionScope δεν είναι διαθέσιμο)

    // ✅ Initialize PageController
    _pageController = PageController(initialPage: _selectedIndex);

    // ✅ Timer για scheduled transactions check
    _scheduledCheckTimer = Timer.periodic(
      const Duration(hours: 1),
          (_) => _checkScheduledTransactions(),
    );

    // ✅ ΠΡΟΣΘΗΚΗ: Κλήση για startup executions check
    _checkStartupExecutions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scheduledCheckTimer?.cancel();
    super.dispose();
  }

  // ✅ ΝΕΟΣ ΜΕΘΟΔΟΣ 1: Check αν εκτελέστηκαν κινήσεις στο startup
  void _checkStartupExecutions() {
    // Use PostFrameCallback to ensure HomePage is fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Check if there were executions on app start
      final count = ScheduledTransactionsService.lastExecutedCount;
      DebugConfig.print('🚀 Startup check: Last executed scheduled transactions count=$count');
      if (count > 0) {
        // Reset the counter
        ScheduledTransactionsService.lastExecutedCount = 0;

        // Show notification
        _showScheduledTransactionsNotification(count);
      }
    });
  }

  // ✅ ΔΙΟΡΘΩΣΗ: Παίρνουμε το userId ΕΔΩ (όχι στο initState)
  Future<void> _checkScheduledTransactions() async {
    try {
      // ✅ Safe: Το context είναι διαθέσιμο εδώ (μέσα στο callback)
      if (!mounted) return;

      final userId = context.session.userId;

      DebugConfig.print('⏰ Periodic check: Checking scheduled transactions...');

      final scheduledService = ScheduledTransactionsService();
      final executed = await scheduledService.checkAndExecutePendingTransactions(userId);

      if (executed.isNotEmpty) {
        DebugConfig.print('✅ Periodic check: Executed ${executed.length} scheduled transactions');

        if (mounted) {
          _showScheduledTransactionsNotification(executed.length);
        }
      }
    } catch (e) {
      DebugConfig.print('❌ Periodic check error: $e');
    }
  }

  // ✅ ΝΕΟΣ ΜΕΘΟΔΟΣ 2: Show notification
  void _showScheduledTransactionsNotification(int count) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            ExcludeSemantics(
              child: const Icon(Icons.event_available, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                count == 1
                    ? 'Εκτελέστηκε 1 προγραμματισμένη κίνηση'
                    : 'Εκτελέστηκαν $count προγραμματισμένες κινήσεις',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'ΟΚ',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _onTabTap(int index) {
    if (index >= _icons.length) return;
    if (index == _selectedIndex) return; // ✅ αν είμαστε ήδη εκεί, μην κάνεις τίποτα

    // ✅ Κρατάμε το jump (tap) αλλά ΔΕΝ κάνουμε setState εδώ
    _pageController.jumpToPage(index);
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    if (index == _selectedIndex) return; // ✅ αποφυγή άσκοπου rebuild

    DebugConfig.print('📖 Page changed to index=$index (${_tabNames[index]})');
    // ✅ ΜΟΝΟ εδώ ενημερώνουμε state (καλύπτει και swipe και tap)
    setState(() => _selectedIndex = index);

    AccessibilityService.announcePolite('Άνοιξε: ${_tabNames[index]}');
  }


  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const GeneralViewPage(),
      const TransactionEntryPage(),
      const AccountsPage(),
      const ScheduledTransactionsPage(),
      const CalendarPage(),
      const BudgetPage(),
      const OptionsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabNames[_selectedIndex]),
        centerTitle: true,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: OfflineAppBarChip()),
          ),
        ],
      ),


      // ✅ Smooth swipe με BouncingScrollPhysics
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: pages,
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary.withValues(alpha:0.88),
            ],
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: Theme.of(context).colorScheme.onPrimary,
          unselectedItemColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha:0.6),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          iconSize: 28,
          elevation: 0,
          items: List.generate(_icons.length, (i) {
            return BottomNavigationBarItem(
              icon: Icon(_icons[i]),
              label: _tabNames[i],
            );
          }),
        ),
      ),
    );
  }
}


