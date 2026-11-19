import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/providers/theme_provider.dart';
import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/transactions_provider.dart';

import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/presentation/auth/login_page.dart';

// ✅ ΝΕΑ IMPORTS
import 'package:family_economy/presentation/dialogs/category_type_selector_dialog.dart';
import 'package:family_economy/presentation/screens/categories/income_categories_page.dart';
import 'package:family_economy/presentation/screens/categories/expense_categories_page.dart';
import 'package:family_economy/core/widgets/helper_calculator_sheet.dart';
import 'package:family_economy/core/services/biometric_auth_service.dart';
import 'package:family_economy/core/services/biometric_settings_service.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/presentation/screens/options/change_password_page.dart';
import 'package:family_economy/presentation/screens/options/delete_account_page.dart';
import 'package:family_economy/presentation/screens/options/database_cleanup_page.dart';
import 'package:family_economy/presentation/screens/stats/stats_page.dart';
import 'package:family_economy/presentation/screens/stats/stats2_averages_page.dart';
import 'package:family_economy/presentation/screens/stats/stats3_page.dart';
import 'package:family_economy/presentation/screens/stats/stats4_budget_page.dart';
import 'package:family_economy/presentation/screens/options/oil_page.dart';
import 'package:family_economy/presentation/screens/tags/tags_management_page.dart';
import 'package:family_economy/presentation/screens/stats/tag_stats_page.dart';
import 'package:family_economy/providers/tags_provider.dart';
import 'package:family_economy/presentation/screens/options/unit_converter_page.dart';


class OptionsPage extends StatefulWidget {
  const OptionsPage({super.key});

  @override
  State<OptionsPage> createState() => _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage> {
  // Track which cards are expanded
  bool _isToolsExpanded = false;
  bool _isStatsExpanded = false;
  bool _isDatabaseExpanded = false;
  bool _isAccountExpanded = false;

  @override
  void initState() {
    super.initState();
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Σελίδα Επιλογών. Διαχείριση κατηγοριών, εργαλεία, στατιστικά και ρυθμίσεις λογαριασμού.',
    );
  }

  // ✅ ΝΕΑ ΜΕΘΟΔΟΣ: Άνοιγμα popup επιλογής τύπου κατηγοριών
  Future<void> _handleCategoryManagement() async {
    final categoryType = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const CategoryTypeSelectorDialog(),
    );

    if (!mounted || categoryType == null) return;

    // Navigation based on selection
    if (categoryType == 'income') {
      final session = context.session; // 👈 παίρνεις το υπάρχον

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SessionScope(
            session: session, // ✅ ΤΟ ΚΡΙΣΙΜΟ ΣΗΜΕΙΟ
            child: const IncomeCategoriesPage(),
          ),
        ),
      );
    } else if (categoryType == 'expense') {
      final session = context.session;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SessionScope(
            session: session,
            child: const ExpenseCategoriesPage(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Χρήση SessionScope για να πάρουμε τον userId
    final userId = context.session.userId;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive width calculation
            final maxWidth = _getMaxWidth(constraints.maxWidth);

            return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: _getHorizontalPadding(constraints.maxWidth),
                    vertical: 1.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Page Title
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 12.0,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ✅ ΤΡΟΠΟΠΟΙΗΜΕΝΗ ΚΑΡΤΕΛΑ: Διαχείριση Κατηγοριών (Standalone, όχι expandable)
                      _CategoryManagementCard(onTap: _handleCategoryManagement),

                      const SizedBox(height: 12),

                      // ✅ Διαχείριση Tags
                      _TagsManagementCard(),

                      const SizedBox(height: 12),

                      // 2. Tools Card (Εργαλεία)
                      _ExpandableCard(
                        title: 'Εργαλεία',
                        icon: Icons.build_rounded,
                        isExpanded: _isToolsExpanded,
                        onToggle: () {
                          setState(() => _isToolsExpanded = !_isToolsExpanded);
                          AccessibilityService.announcePolite(
                            _isToolsExpanded
                                ? 'Άνοιξε η καρτέλα Εργαλεία'
                                : 'Έκλεισε η καρτέλα Εργαλεία',
                          );
                        },
                        children: [
                          _ThemeSwitchTile(),
                          AccessibilityService.accessibleButton(
                            label: 'Αριθμομηχανή',
                            hint: 'Άνοιγμα βοηθητικής αριθμομηχανής',
                            onPressed: () {
                              HelperCalculator.open(
                                context,
                                announceOpened: 'Άνοιξε αριθμομηχανή',
                                onResult: (value) {
                                  AccessibilityService.announcePolite(
                                    'Τελικό αποτέλεσμα $value',
                                  );
                                },
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: context.cPrimary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: Icon(
                                      Icons.calculate_rounded,
                                      size: 20,
                                      color: context.cPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Αριθμομηχανή',
                                          style: context.bodyMd,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Γρήγοροι υπολογισμοί',
                                          style: context.bodySm.copyWith(
                                            color: context.cText2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: context.cText2.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          _PlaceholderOption(
                            icon: Icons.local_gas_station_rounded,
                            title: 'Δεξαμενή Πετρελαίου',
                            subtitle: 'Παρακολούθηση ποσότητας πετρελαίου',
                            onTap: () {
                              final session = context.session;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SessionScope(
                                    session: session,
                                    child: const OilPage(),
                                  ),
                                ),
                              );
                            },
                          ),

                          // ✅ ΝΕΟ
                          _PlaceholderOption(
                            icon: Icons.currency_exchange_rounded,
                            title: 'Μετατροπέας Μονάδων',
                            subtitle: 'Μήκος · Βάρος · Υγρά · Νομίσματα',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ConverterPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),


                      const SizedBox(height: 12),

                      // 3. Statistics Card (Στατιστικά)
                      _ExpandableCard(
                        title: 'Στατιστικά',
                        icon: Icons.analytics_rounded,
                        isExpanded: _isStatsExpanded,
                        onToggle: () {
                          setState(() => _isStatsExpanded = !_isStatsExpanded);
                          AccessibilityService.announcePolite(
                            _isStatsExpanded
                                ? 'Άνοιξε η καρτέλα Στατιστικά'
                                : 'Έκλεισε η καρτέλα Στατιστικά',
                          );
                        },
                        children: [
                          _PlaceholderOption(
                            icon: Icons.pie_chart_rounded,
                            title: 'Ανάλυση Εσόδων Εξόδων',
                            subtitle: 'Κατανομή Εσόδων Εξόδων ανά κατηγορία',
                            onTap: () {
                              final session = context.session;
                              final userId = session.userId;

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SessionScope(
                                    session: session,
                                    child: MultiProvider(
                                      providers: [
                                        ChangeNotifierProvider(create: (_) => AccountsProvider(userId: userId)),
                                        ChangeNotifierProvider(create: (_) => CategoriesProvider(userId: userId)),
                                        ChangeNotifierProvider(create: (_) => TransactionsProvider(userId: userId)),
                                        ChangeNotifierProvider(create: (_) => TagsProvider(userId: userId)),
                                      ],
                                      child: const StatsPage(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          _PlaceholderOption(
                            icon: Icons.trending_up_rounded,
                            title: 'Μέσοι Όροι',
                            subtitle: 'Προβολή Μέσων Όρων',
                            onTap: () {
                              final session = context.session;
                              final userId = session.userId;

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SessionScope(
                                    session: session,
                                    child: MultiProvider(
                                      providers: [
                                        ChangeNotifierProvider(create: (_) => AccountsProvider(userId: userId)),
                                        ChangeNotifierProvider(create: (_) => CategoriesProvider(userId: userId)),
                                        ChangeNotifierProvider(create: (_) => TransactionsProvider(userId: userId)),
                                      ],
                                      child: const Stats2AveragesPage(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // ✅ ΝΕΟ: Συνολα ανά Μήνα
                          _PlaceholderOption(
                            icon: Icons.table_chart_rounded,
                            title: 'Σύνολα ανα Μήνα',
                            subtitle: 'Σύγκριση Εσόδων / Εξόδων ανά μήνα έτους',
                            onTap: () {
                              final session = context.session;
                              final userId  = session.userId;

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SessionScope(
                                    session: session,
                                    child: MultiProvider(
                                      providers: [
                                        ChangeNotifierProvider(
                                          create: (_) => CategoriesProvider(userId: userId),
                                        ),
                                        ChangeNotifierProvider(
                                          create: (_) => TransactionsProvider(userId: userId),
                                        ),
                                      ],
                                      child: const Stats3Page(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // ✅ ΝΕΟ: Στόχος Εξοικονόμησης
                          _PlaceholderOption(
                            icon: Icons.savings_rounded,
                            title: 'Στόχος Εξοικονόμησης',
                            subtitle: 'Πρόβλεψη ανά κατηγορία για επίτευξη στόχου',
                            onTap: () {
                              final session = context.session;
                              final userId  = session.userId;

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SessionScope(
                                    session: session,
                                    child: MultiProvider(
                                      providers: [
                                        ChangeNotifierProvider(
                                          create: (_) => CategoriesProvider(userId: userId),
                                        ),
                                        ChangeNotifierProvider(
                                          create: (_) => ConnectivityService(),
                                        ),
                                      ],
                                      child: const Stats4BudgetPage(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // ✅ ΝΕΟ: Στατιστικά από Tags
                          _PlaceholderOption(
                            icon: Icons.label_rounded,
                            title: 'Στατιστικά από Tags',
                            subtitle: 'Αναφορά κινήσεων φιλτραρισμένη ανά Tags',
                            onTap: () {
                              final session = context.session;
                              final userId  = session.userId;

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SessionScope(
                                    session: session,
                                    child: MultiProvider(
                                      providers: [
                                        ChangeNotifierProvider(
                                          create: (_) => AccountsProvider(userId: userId),
                                        ),
                                        ChangeNotifierProvider(
                                          create: (_) => CategoriesProvider(userId: userId),
                                        ),
                                        ChangeNotifierProvider(
                                          create: (_) => TransactionsProvider(userId: userId),
                                        ),
                                        ChangeNotifierProvider(
                                          create: (_) => TagsProvider(userId: userId),
                                        ),
                                        ChangeNotifierProvider(
                                          create: (_) => ConnectivityService(),
                                        ),
                                      ],
                                      child: const TagStatsPage(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // _PlaceholderOption(
                          //   icon: Icons.file_download_rounded,
                          //   title: 'Εξαγωγή Αναφορών',
                          //   subtitle: 'Λήψη αναφορών σε PDF/Excel',
                          // ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ✅ 4. Database Maintenance Card (Συντήρηση Βάσης)
                      _ExpandableCard(
                        title: 'Συντήρηση Βάσης',
                        icon: Icons.cleaning_services_rounded,
                        isExpanded: _isDatabaseExpanded,
                        onToggle: () {
                          setState(() => _isDatabaseExpanded = !_isDatabaseExpanded);
                          AccessibilityService.announcePolite(
                            _isDatabaseExpanded
                                ? 'Άνοιξε η καρτέλα Συντήρηση Βάσης'
                                : 'Έκλεισε η καρτέλα Συντήρηση Βάσης',
                          );
                        },
                        children: [
                          _PlaceholderOption(
                            icon: Icons.delete_sweep_rounded,
                            title: 'Καθαρισμός Δεδομένων',
                            subtitle: 'Διαγραφή παλιών υπενθυμίσεων, προϋπολογισμών, συναλλαγών',
                            onTap: () {
                              final session = context.session;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SessionScope(
                                    session: session,
                                    child: const DatabaseCleanupPage(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 5. Account Card (Λογαριασμός)
                      _ExpandableCard(
                        title: 'Λογαριασμός',
                        icon: Icons.account_circle_rounded,
                        isExpanded: _isAccountExpanded,
                        onToggle: () {
                          setState(
                            () => _isAccountExpanded = !_isAccountExpanded,
                          );
                          AccessibilityService.announcePolite(
                            _isAccountExpanded
                                ? 'Άνοιξε η καρτέλα Λογαριασμός'
                                : 'Έκλεισε η καρτέλα Λογαριασμός',
                          );
                        },
                        children: [
                          _UserDetailsOption(userId: userId),
                          AccessibilityService.accessibleButton(
                            label: 'Αλλαγή Κωδικού',
                            hint:
                                'Άνοιγμα σελίδας αλλαγής κωδικού. Απαιτείται σύνδεση στο internet.',
                            onPressed: () {
                              final isOnline = context
                                  .read<ConnectivityService>()
                                  .isOnline;

                              if (!isOnline) {
                                AccessibilityService.announceError(
                                  'Δεν υπάρχει σύνδεση στο internet',
                                );

                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Χωρίς σύνδεση'),
                                    content: const Text(
                                      'Για λόγους ασφαλείας, η αλλαγή κωδικού απαιτεί ενεργή σύνδεση στο internet.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }

                              final session = context.session;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SessionScope(
                                    session: session,
                                    child: const ChangePasswordPage(),
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: context.cPrimary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: ExcludeSemantics(
                                      child: Icon(
                                        Icons.lock_rounded,
                                        size: 20,
                                        color: context.cPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Αλλαγή Κωδικού',
                                          style: context.bodyMd,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Ενημέρωση κωδικού πρόσβασης',
                                          style: context.bodySm.copyWith(
                                            color: context.cText2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ExcludeSemantics(
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: context.cText2.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const _BiometricOptionTile(),
                          AccessibilityService.accessibleButton(
                            label: 'Διαγραφή Λογαριασμού',
                            hint:
                                'Απαιτείται σύνδεση στο internet. Πατήστε για άνοιγμα.',
                            onPressed: () async {
                              final isOnline = context
                                  .read<ConnectivityService>()
                                  .isOnline;

                              if (!isOnline) {
                                AccessibilityService.announceError(
                                  'Δεν υπάρχει σύνδεση στο internet',
                                );

                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Χωρίς σύνδεση'),
                                    content: const Text(
                                      'Για λόγους ασφαλείας, η διαγραφή λογαριασμού απαιτεί ενεργή σύνδεση στο internet.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }

                              final session = context.session;

                              final result = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => SessionScope(
                                        session: session,
                                        child: const DeleteAccountPage(),
                                      ),
                                    ),
                                  );

                              // ✅ αν η σελίδα γύρισε true (διαγράφηκε), εδώ ΔΕΝ κάνουμε τίποτα ακόμα.
                              // Το "πήγαινε στο Login" θα το βάλουμε στο επόμενο βήμα για να είναι καθαρό.
                              if (result == true && context.mounted) {
                                // ✅ Σταματάμε άμεσα οποιαδήποτε Firestore πρόσβαση από providers/screens
                                await FirebaseAuth.instance.signOut();

                                if (!context.mounted) return;

                                AccessibilityService.announceSuccess('Ο λογαριασμός διαγράφηκε');

                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
                                      (route) => false,
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: ColorsUI.getError(
                                        context.brightness,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: ExcludeSemantics(
                                      child: Icon(
                                        Icons.delete_forever_rounded,
                                        size: 20,
                                        color: ColorsUI.getError(context.brightness),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Διαγραφή Λογαριασμού',
                                          style: context.bodyMd,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Οριστική διαγραφή του λογαριασμού',
                                          style: context.bodySm.copyWith(
                                            color: context.cText2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ExcludeSemantics(
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: context.cText2.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 6. Logout Card (Αποσύνδεση)
                      _LogoutCard(userId: userId),
                    ],
                    )
                  ),
            );
          },
        ),
      ),
    );
  }

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
}

// ============================================================
// ✅ ΝΕΑ ΚΑΡΤΕΛΑ: ΔΙΑΧΕΙΡΙΣΗ ΚΑΤΗΓΟΡΙΩΝ (Standalone)
// ============================================================

class _CategoryManagementCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CategoryManagementCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: AccessibilityService.accessibleButton(
        label: 'Διαχείριση Κατηγοριών',
        hint: 'Πατήστε για να επιλέξετε τύπο κατηγοριών (Εσόδων ή Εξόδων)',
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.category_rounded, size: 24, color: context.cPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Διαχείριση Κατηγοριών', style: context.titleMd),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: context.cText2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAGS MANAGEMENT CARD (Standalone)
// ============================================================

class _TagsManagementCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: AccessibilityService.accessibleButton(
        label: 'Διαχείριση Tags',
        hint: 'Πατήστε για δημιουργία, επεξεργασία και διαγραφή tags',
        onPressed: () {
          final session = context.session;
          final tagsProvider = context.read<TagsProvider>();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider<TagsProvider>.value(
                value: tagsProvider,
                child: SessionScope(
                  session: session,
                  child: const TagsManagementPage(),
                ),
              ),
            ),
          );
          AccessibilityService.announcePolite('Άνοιξε η διαχείριση Tags');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.label_rounded, size: 24, color: context.cPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Διαχείριση Tags', style: context.titleMd),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: context.cText2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PLACEHOLDER OPTION (για μελλοντικές επιλογές)
// ============================================================

class _PlaceholderOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  // ✅ NEW
  final VoidCallback? onTap;

  const _PlaceholderOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.info_outline, color: context.cPrimary),
            ),
            const SizedBox(width: 12),
            const Text('Σύντομα Διαθέσιμο'),
          ],
        ),
        content: Text(
          'Η λειτουργία "$title" θα είναι διαθέσιμη σε επόμενη έκδοση.',
          style: context.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AccessibilityService.accessibleButton(
      label: '$title, $subtitle',
      hint: onTap != null ? 'Πατήστε για άνοιγμα' : 'Πατήστε για περισσότερες πληροφορίες',
      onPressed: onTap ?? () => _showComingSoonDialog(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: context.cPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: ExcludeSemantics(
                child: Icon(icon, size: 20, color: context.cPrimary),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.bodyMd),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.bodySm.copyWith(color: context.cText2),
                  ),
                ],
              ),
            ),
            ExcludeSemantics(
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.cText2.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// USER DETAILS OPTION (Στοιχεία Χρήστη)
// ============================================================

class _UserDetailsOption extends StatelessWidget {
  final String userId;

  const _UserDetailsOption({required this.userId});

  Future<void> _showUserDetailsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _UserDetailsDialog(userId: userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AccessibilityService.accessibleButton(
      label: 'Στοιχεία Χρήστη',
      hint: 'Πατήστε για προβολή και επεξεργασία των στοιχείων σας',
      onPressed: () => _showUserDetailsDialog(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: context.cPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: ExcludeSemantics(
                child: Icon(
                  Icons.person_rounded,
                  size: 20,
                  color: context.cPrimary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text('Στοιχεία Χρήστη', style: context.bodyMd)),
            ExcludeSemantics(
              child: Icon(Icons.chevron_right_rounded, size: 24, color: context.cText2),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// USER DETAILS DIALOG (Popup)
// ============================================================

class _UserDetailsDialog extends StatefulWidget {
  final String userId;

  const _UserDetailsDialog({required this.userId});

  @override
  State<_UserDetailsDialog> createState() => _UserDetailsDialogState();
}

class _UserDetailsDialogState extends State<_UserDetailsDialog> {
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
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
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
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
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

      Navigator.of(context).pop();
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
            ? _buildErrorState()
            : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Semantics(
      liveRegion: true,
      label: 'Φόρτωση στοιχείων χρήστη. Παρακαλώ περιμένετε.',
      excludeSemantics: true,
      child: Container(
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
    );
  }

  Widget _buildErrorState() {
    return Container(
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Κλείσιμο'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.cPrimary,
                  context.cPrimary.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const ExcludeSemantics(
                    child: Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text(
                    'Στοιχεία Χρήστη',
                    style: context.titleLg.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 4),
                ExcludeSemantics(
                  child: Text(
                    _userData?['email'] ?? '',
                    style: context.bodyMd.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
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
                    const DropdownMenuItem(
                      value: 'EUR',
                      child: Text('EUR (€)'),
                    ),
                    const DropdownMenuItem(
                      value: 'USD',
                      child: Text('USD (\$)'),
                    ),
                    const DropdownMenuItem(
                      value: 'GBP',
                      child: Text('GBP (£)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCurrency = value);
                    }
                  },
                ),

                const SizedBox(height: 24),

                // Read-only info
                _buildInfoCard(),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
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
        Text(label, style: TypographyUI.labelLarge(context.brightness)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: ExcludeSemantics(
              child: Icon(icon, size: 20),
            ),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        Text(label, style: TypographyUI.labelLarge(context.brightness)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
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
        border: Border.all(color: context.cPrimary.withValues(alpha: 0.2)),
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
                style: TypographyUI.labelMedium(
                  context.brightness,
                ).copyWith(color: context.cPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('User ID', '${widget.userId.substring(0, 12)}...'),
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

// ============================================================
// EXPANDABLE CARD WIDGET
// ============================================================

class _ExpandableCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _ExpandableCard({
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        children: [
          // Header
          AccessibilityService.accessibleButton(
            label:
                '$title, ${isExpanded ? "ανοιχτό" : "κλειστό"}. Πατήστε για ${isExpanded ? "κλείσιμο" : "άνοιγμα"}',
            hint: 'Διπλό πάτημα για ${isExpanded ? "κλείσιμο" : "άνοιγμα"}',
            onPressed: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(icon, size: 24, color: context.cPrimary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(title, style: context.titleMd)),
                  // Animated arrow icon
                  ExcludeSemantics(
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 28,
                        color: context.cText2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                ExcludeSemantics(
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: ColorsUI.getDivider(context.brightness),
                  ),
                ),
                ...children,
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// THEME SWITCH TILE
// ============================================================

class _ThemeSwitchTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    return Semantics(
      label: 'Φωτεινή/Σκοτεινή λειτουργία',
      hint: isDarkMode
          ? 'Ενεργοποιημένη σκοτεινή λειτουργία. Πατήστε για αλλαγή σε φωτεινή'
          : 'Ενεργοποιημένη φωτεινή λειτουργία. Πατήστε για αλλαγή σε σκοτεινή',
      toggled: isDarkMode,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Icon indicator
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: context.cPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: ExcludeSemantics(
                child: Icon(
                  isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  size: 20,
                  color: context.cPrimary,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Φωτεινή/Σκοτεινή λειτουργία', style: context.bodyMd),
                  const SizedBox(height: 4),
                  Text(
                    isDarkMode ? 'Σκοτεινή' : 'Φωτεινή',
                    style: context.bodySm.copyWith(color: context.cText2),
                  ),
                ],
              ),
            ),

            // Switch
            Switch(
              value: isDarkMode,
              onChanged: (value) async {
                if (value) {
                  await themeProvider.setDarkMode();
                  AccessibilityService.announcePolite(
                    'Ενεργοποιήθηκε η σκοτεινή λειτουργία',
                  );
                } else {
                  await themeProvider.setLightMode();
                  AccessibilityService.announcePolite(
                    'Ενεργοποιήθηκε η φωτεινή λειτουργία',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOGOUT CARD
// ============================================================

class _LogoutCard extends StatelessWidget {
  final String userId;

  const _LogoutCard({required this.userId});

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Αποσύνδεση'),
        content: Text(
          'Είστε σίγουροι ότι θέλετε να αποσυνδεθείτε;\n\nUser ID: $userId',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
              AccessibilityService.announcePolite('Ακυρώθηκε η αποσύνδεση');
            },
            child: const Text('Άκυρο'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Αποσύνδεση'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      AccessibilityService.announcePolite('Αποσυνδεθήκατε επιτυχώς');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;

      AccessibilityService.announceError(
        'Αποτυχία αποσύνδεσης. Δοκιμάστε ξανά.',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Αποτυχία αποσύνδεσης. Δοκιμάστε ξανά.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: AccessibilityService.accessibleButton(
        label: 'Αποσύνδεση',
        hint: 'Πατήστε για αποσύνδεση από την εφαρμογή',
        onPressed: () => _handleLogout(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.logout_rounded, size: 24, color: Colors.red.shade700),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Αποσύνδεση',
                  style: context.titleMd.copyWith(color: Colors.red.shade700),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: context.cText2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ============================================================
// BIOMETRIC OPTION TILE + DIALOG (SessionScope-based)
// ============================================================

class _BiometricOptionTile extends StatelessWidget {
  const _BiometricOptionTile();

  Future<void> _openDialog(BuildContext context) async {
    final session = context.session; // ✅ παίρνουμε session από σωστό context

    await showDialog(
      context: context,
      builder: (_) => SessionScope(
        session: session, // ✅ περνάμε το ίδιο session μέσα στο dialog tree
        child: const _BiometricSettingsDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AccessibilityService.accessibleButton(
      label: 'Βιομετρική Ταυτοποίηση',
      hint: 'Ρύθμιση εισόδου με δακτυλικό αποτύπωμα ή Face ID',
      onPressed: () => _openDialog(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: context.cPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: ExcludeSemantics(
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 20,
                  color: context.cPrimary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Βιομετρική Ταυτοποίηση', style: context.bodyMd),
                  const SizedBox(height: 2),
                  Text(
                    'Face ID / Δακτυλικό αποτύπωμα',
                    style: context.bodySm.copyWith(color: context.cText2),
                  ),
                ],
              ),
            ),
            ExcludeSemantics(
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.cText2.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BiometricSettingsDialog extends StatefulWidget {
  const _BiometricSettingsDialog();

  @override
  State<_BiometricSettingsDialog> createState() =>
      _BiometricSettingsDialogState();
}

class _BiometricSettingsDialogState extends State<_BiometricSettingsDialog> {
  bool _loading = true;
  bool _saving = false;

  bool _enabled = false;
  String _mode = 'always'; // 'always' | 'on_demand'
  bool _remember = false;

  String? _error;

  late final String _userId;

  @override
  void initState() {
    super.initState();

    // ✅ Πάρε τον userId ΑΦΟΥ ολοκληρωθεί το initState (σωστά για InheritedWidget)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _userId = context.session.userId; // ✅ από SessionScope
      _load(); // τώρα είναι safe
    });
  }

  Future<void> _load() async {
    DebugConfig.print('🧬 BiometricSettingsDialog._load() userId=$_userId');

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ignore: avoid_print
      DebugConfig.print('🔎 scope userId: $_userId');
      DebugConfig.print(
        '🔎 firebase uid: ${FirebaseAuth.instance.currentUser?.uid}',
      );

      final s = await BiometricSettingsService.instance.load(_userId);
      if (!mounted) return;

      setState(() {
        _enabled = s.enabled;
        _mode = s.mode;
        _remember = s.remember;
        _loading = false;
      });
    } catch (e, st) {
      if (!mounted) return;

      setState(() {
        _error = 'LOAD ERROR:\n$e\n\nSTACK:\n$st';
        _loading = false;
      });
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    if (_saving) return; // extra guard

    DebugConfig.print('🧬 toggleEnabled tapped value=$value userId=$_userId');

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Αν ενεργοποιεί, ζητάμε άμεσα βιομετρικό (επιβεβαίωση)
      if (value) {
        final available = await BiometricAuthService.instance.isAvailable();
        DebugConfig.print('🧬 isAvailable=$available');

        if (!available) {
          if (!mounted) return;
          AccessibilityService.announceError(
            'Η συσκευή δεν υποστηρίζει βιομετρικά',
          );
          setState(() {
            _enabled = false;
            _error = 'Η συσκευή δεν υποστηρίζει βιομετρικά';
            _saving = false;
          });
          return;
        }

        final ok = await BiometricAuthService.instance.authenticate(
          reason: 'Επιβεβαίωση ενεργοποίησης βιομετρικής εισόδου',
        );
        DebugConfig.print('🧬 authenticate ok=$ok');

        if (!ok) {
          if (!mounted) return;
          AccessibilityService.announceError('Αποτυχία επιβεβαίωσης');
          setState(() {
            _enabled = false;
            _saving = false;
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _enabled = value;
        _saving = false;
      });

      AccessibilityService.announcePolite(
        value
            ? 'Ενεργοποιήθηκαν τα βιομετρικά'
            : 'Απενεργοποιήθηκαν τα βιομετρικά',
      );
    } catch (e, st) {
      DebugConfig.print('❌ toggleEnabled error: $e');
      DebugConfig.print('$st');

      if (!mounted) return;
      setState(() {
        _enabled = false;
        _saving = false;
        _error = 'Σφάλμα βιομετρικών: $e';
      });

      AccessibilityService.announceError('Σφάλμα βιομετρικών');
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final s = BiometricSettings(
        enabled: _enabled,
        mode: _mode,
        remember: _remember,
      );

      await BiometricSettingsService.instance.saveAll(_userId, s);

      if (!mounted) return;

      AccessibilityService.announceSuccess(
        'Αποθηκεύτηκαν οι ρυθμίσεις βιομετρικών',
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Αποτυχία αποθήκευσης';
        _saving = false;
      });

      AccessibilityService.announceError(_error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: _loading
              ? _buildLoading(context)
              : _error != null
              ? _buildError(context)
              : _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Φόρτωση ρυθμίσεων βιομετρικών. Παρακαλώ περιμένετε.',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: CircularProgressIndicator(color: context.cPrimary),
          ),
          const SizedBox(height: 14),
          ExcludeSemantics(
            child: Text('Φόρτωση...', style: context.bodyMd),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(Icons.error_outline, size: 44, color: Colors.red.shade700),
        ),
        const SizedBox(height: 10),
        Text(_error!, style: context.bodyMd, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Κλείσιμο'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Βιομετρική Ταυτοποίηση', style: context.titleLg),
        ),
        const SizedBox(height: 8),
        Text(
          'Ενεργοποίησε είσοδο με δακτυλικό/Face ID και διάλεξε πότε θα ζητείται.',
          style: context.bodySm,
        ),
        const SizedBox(height: 14),

        // Enable switch
        SwitchListTile(
          value: _enabled,
          onChanged: _saving ? null : (v) => _toggleEnabled(v),
          title: Text('Ενεργοποίηση', style: context.bodyMd),
          subtitle: Text(
            _enabled ? 'Ενεργό' : 'Ανενεργό',
            style: context.bodySm.copyWith(color: context.cText2),
          ),
        ),

        const SizedBox(height: 8),

        // Mode
        Opacity(
          opacity: _enabled ? 1 : 0.5,
          child: IgnorePointer(
            ignoring: !_enabled || _saving,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Πότε να ζητείται;', style: context.bodyMd),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'always',
                      label: Text('Κάθε φορά'),
                      icon: Icon(Icons.lock),
                    ),
                    ButtonSegment(
                      value: 'on_demand',
                      label: Text('Όταν το ζητήσω'),
                      icon: Icon(Icons.lock_open),
                    ),
                  ],
                  selected: <String>{_mode},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _mode = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  _mode == 'always'
                      ? 'Θα ζητάει βιομετρικό σε κάθε είσοδο.'
                      : 'Θα ζητάει βιομετρικό μόνο όταν το επιλέξεις.',
                  style: context.bodySm.copyWith(color: context.cText2),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Remember
        Opacity(
          opacity: _enabled ? 1 : 0.5,
          child: IgnorePointer(
            ignoring: !_enabled || _saving,
            child: CheckboxListTile(
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? false),
              title: Text('Να το θυμάται', style: context.bodyMd),
              subtitle: Text(
                'Αν είναι ενεργό, θα προτιμάται βιομετρικό αντί για κωδικό όπου γίνεται.',
                style: context.bodySm.copyWith(color: context.cText2),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        ),

        const SizedBox(height: 12),

        if (_saving) ...[
          Semantics(
            liveRegion: true,
            label: 'Αποθήκευση ρυθμίσεων. Παρακαλώ περιμένετε.',
            excludeSemantics: true,
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: ExcludeSemantics(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.cPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ExcludeSemantics(
                  child: Text('Αποθήκευση...', style: context.bodySm),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Άκυρο'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: const Text('Αποθήκευση'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
