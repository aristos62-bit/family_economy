// ============================================================
// ACCOUNTS PAGE – FIREBASE VERSION
// Path: lib/presentation/screens/accounts/accounts_page.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core imports
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/core/utils/icon_mapper.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/utils/debug_config.dart';
// Providers
import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/services/account_duplicate_service.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
// Pages
import 'package:family_economy/presentation/screens/transactions/transactions_show_page.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

final _uuid = const Uuid();

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // STATE VARIABLES
  // ============================================================

  // Animation Controller για FAB
  late final AnimationController _fabController;
  late final Animation<double> _fabScale;

  // UI State
  bool _isBalanceHidden = true;
  Set<String> _excludedAccountUuids = <String>{}; // ✅ UUID-based

  //============= DEBUG ===================================
  void _log(String msg) {
    DebugConfig.print('🧾 [AccountsPage] $msg');
  }

  // ========================================================

  bool _isOfflineNow(BuildContext context) {
    try {
      return context.read<ConnectivityService>().isOffline;
    } catch (_) {
      return false; // αν δεν υπάρχει provider για κάποιο λόγο
    }
  }

  //==============================================================
  // ============================================================
  // HELPER METHODS
  // ============================================================

  String _accountTypeLabel(String type) {
    switch (type) {
      case 'cash':
        return 'Μετρητά';
      case 'bank':
        return 'Τραπεζικός';
      case 'credit_card':
        return 'Πιστωτική Κάρτα';
      case 'savings':
        return 'Ταμιευτήριο';
      case 'investment':
        return 'Επένδυση';
      default:
        return type;
    }
  }

  void _showSuccessSnack(BuildContext context, String message) {
    final b = Theme.of(context).brightness;

    ScaffoldMessenger.of(context).showSnackBar(
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

  void _showErrorSnack(BuildContext context, String message) {
    final b = Theme.of(context).brightness;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: ColorsUI.getOnError(b))),
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

    // Animation setup
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScale = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );
    _fabController.forward();

    // Load preferences
    _loadExcludedAccounts();

    // Accessibility announcement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AccessibilityService.announcePolite('Σελίδα Λογαριασμών');
      }
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATA LOADING
  // ============================================================

  /// Φόρτωση αποκλεισμένων λογαριασμών από SharedPreferences
  Future<void> _loadExcludedAccounts() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // ignore: use_build_context_synchronously
      final userId = context.session.userId;
      final key = 'excluded_accounts_$userId';
      final excluded = prefs.getStringList(key) ?? [];

      if (mounted) {
        setState(() {
          _excludedAccountUuids = excluded.toSet();
        });
      }
    } catch (e) {
      DebugConfig.print('Error loading excluded accounts: $e');
    }
  }

  /// Αποθήκευση αποκλεισμένων λογαριασμών
  Future<void> _saveExcludedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ignore: use_build_context_synchronously
      final userId = context.session.userId;
      final key = 'excluded_accounts_$userId';
      await prefs.setStringList(key, _excludedAccountUuids.toList());
    } catch (e) {
      DebugConfig.print('Error saving excluded accounts: $e');
    }
  }

  /// Υπολογισμός συνολικού υπολοίπου
  double _calculateTotalBalance(List<AccountModel> accounts) {
    return accounts
        .where((a) => !_excludedAccountUuids.contains(a.uuid))
        .fold(0.0, (total, account) => total + account.currentBalance);
  }

  // ============================================================
  // TOGGLE HANDLERS
  // ============================================================

  /// Toggle απόκρυψης υπολοίπου
  void _toggleBalanceVisibility() {
    setState(() => _isBalanceHidden = !_isBalanceHidden);

    AccessibilityService.announcePolite(
      _isBalanceHidden ? 'Το υπόλοιπο είναι κρυφό' : 'Το υπόλοιπο είναι ορατό',
    );
  }

  /// Toggle συμπερίληψης/αποκλεισμού λογαριασμού από το σύνολο
  void _toggleAccountInTotal(String uuid, String accountName) {
    setState(() {
      if (_excludedAccountUuids.contains(uuid)) {
        _excludedAccountUuids.remove(uuid);
        AccessibilityService.announcePolite(
          'Ο λογαριασμός $accountName συμπεριλήφθηκε στο συνολικό υπόλοιπο',
        );
      } else {
        _excludedAccountUuids.add(uuid);
        AccessibilityService.announcePolite(
          'Ο λογαριασμός $accountName αποκλείστηκε από το συνολικό υπόλοιπο',
        );
      }
    });

    _saveExcludedAccounts();
  }

  // ============================================================
  // ADD ACCOUNT DIALOG
  // ============================================================

  void _showAddAccountDialog(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final userId = context.session.userId;
    final defaultCurrency = context.session.defaultCurrency;

    final nameController = TextEditingController();
    final initialBalanceController = TextEditingController(text: '0');

    String selectedType = 'bank';
    String selectedCurrency = defaultCurrency;
    int selectedIconIndex = 0;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: ColorsUI.getSurface(brightness),
          title: Text(
            'Νέος Λογαριασμός',
            style: TypographyUI.titleLarge(brightness),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Όνομα
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Όνομα',
                    border: const OutlineInputBorder(),
                    labelStyle: TypographyUI.bodyMedium(brightness),
                  ),
                  style: TypographyUI.bodyMedium(brightness),
                ),
                const SizedBox(height: 16),

                // Αρχικό Υπόλοιπο
                TextField(
                  controller: initialBalanceController,
                  decoration: InputDecoration(
                    labelText: 'Αρχικό Υπόλοιπο',
                    border: const OutlineInputBorder(),
                    labelStyle: TypographyUI.bodyMedium(brightness),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TypographyUI.bodyMedium(brightness),
                ),
                const SizedBox(height: 16),

                // Icon Picker
                _buildIconPicker(brightness, selectedIconIndex, (newIndex) {
                  setDialogState(() {
                    selectedIconIndex = newIndex;
                  });
                }),
                const SizedBox(height: 16),

                // Τύπος Λογαριασμού
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Τύπος Λογαριασμού',
                    border: const OutlineInputBorder(),
                    labelStyle: TypographyUI.bodyMedium(brightness),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Μετρητά')),
                    DropdownMenuItem(value: 'bank', child: Text('Τραπεζικός')),
                    DropdownMenuItem(
                      value: 'credit_card',
                      child: Text('Πιστωτική Κάρτα'),
                    ),
                    DropdownMenuItem(
                      value: 'savings',
                      child: Text('Ταμιευτήριο'),
                    ),
                    DropdownMenuItem(
                      value: 'investment',
                      child: Text('Επένδυση'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedType = v);
                    }
                  },
                  style: TypographyUI.bodyMedium(brightness),
                ),
                const SizedBox(height: 16),

                // Νόμισμα
                DropdownButtonFormField<String>(
                  initialValue: selectedCurrency,
                  decoration: InputDecoration(
                    labelText: 'Νόμισμα',
                    border: const OutlineInputBorder(),
                    labelStyle: TypographyUI.bodyMedium(brightness),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedCurrency = v);
                    }
                  },
                  style: TypographyUI.bodyMedium(brightness),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Ακύρωση',
                style: TypographyUI.buttonBase().copyWith(
                  color: ColorsUI.getTextSecondary(brightness),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                DebugConfig.print(
                  '🧾 [CREATE] pressed name="$name" '
                  'balanceText="${initialBalanceController.text}"',
                );
                if (name.isEmpty) {
                  _showErrorSnack(context, 'Το Όνομα είναι Υποχρεωτικό');
                  return;
                }
                // ✅ Έλεγχος διπλότυπων με το service
                final canContinue = await AccountDuplicateService.instance
                    .checkForCreateAccount(context, userId, name);

                DebugConfig.print(
                  '🧾 [CREATE] duplicate check result=$canContinue',
                );

                if (!canContinue) {
                  // Αν βρέθηκε διπλότυπο ή έγινε επαναφορά, κλείσε το dialog
                  if (!dialogContext.mounted) return;

                  DebugConfig.print(
                    '🧾 [CREATE] dialog closing – starting background create',
                  );

                  Navigator.pop(dialogContext);
                  return;
                }
                final initialBalance =
                    CurrencyFormatter.parseInput(
                      initialBalanceController.text,
                    ) ??
                    0.0;
                if (!context.mounted) return;
                Navigator.pop(dialogContext);

                // ✅ Success αμέσως (ONLINE/OFFLINE)
                _showSuccessSnack(context, 'Ο λογαριασμός δημιουργήθηκε');

                // ✅ Save στο background
                _createAccount(
                  userId: userId,
                  name: name,
                  initialBalance: initialBalance,
                  currency: selectedCurrency,
                  accountType: selectedType,
                  iconIndex: selectedIconIndex,
                ).catchError((e) {
                  _log('CREATE_ACCOUNT catchError → $e');
                  if (!context.mounted) return;
                  if (_isOfflineNow(dialogContext)) {
                    _log('CREATE_ACCOUNT failed while OFFLINE');
                  } else {
                    _log('CREATE_ACCOUNT failed while ONLINE');
                  }

                  if (!context.mounted) return;

                  _showErrorSnack(context, 'Σφάλμα Δημιουργίας');
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorsUI.getPrimary(brightness),
                foregroundColor: ColorsUI.getOnPrimary(brightness),
              ),
              child: const Text('Δημιουργία'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EDIT ACCOUNT DIALOG
  // ============================================================

  void _showEditAccountDialog(BuildContext context, AccountModel account) {
    final brightness = Theme.of(context).brightness;

    final nameController = TextEditingController(text: account.name);
    String selectedType = account.accountType;
    String selectedCurrency = account.currency;
    int selectedIconIndex = account.iconIndex ?? 0;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: ColorsUI.getSurface(brightness),
          title: Text(
            'Επεξεργασία Λογαριασμού',
            style: TypographyUI.titleLarge(brightness),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Όνομα
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Όνομα',
                    border: const OutlineInputBorder(),
                    labelStyle: TypographyUI.bodyMedium(brightness),
                  ),
                  style: TypographyUI.bodyMedium(brightness),
                ),
                const SizedBox(height: 16),

                // Icon Picker
                _buildIconPicker(brightness, selectedIconIndex, (newIndex) {
                  setDialogState(() {
                    selectedIconIndex = newIndex;
                  });
                }),
                const SizedBox(height: 16),

                // ======================
                // Υπόλοιπα (μόνο εμφάνιση) - ίδιο border με τα υπόλοιπα πεδία
                // ======================
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Υπόλοιπα',
                    border: const OutlineInputBorder(),
                    labelStyle: TypographyUI.bodyMedium(brightness),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Τρέχον: ${CurrencyFormatter.format(account.currentBalance, currency: account.currency)}',
                        style: TypographyUI.bodyMedium(brightness),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Αρχικό: ${CurrencyFormatter.format(account.initialBalance, currency: account.currency)}',
                        style: TypographyUI.bodyMedium(brightness).copyWith(
                          color: ColorsUI.getTextSecondary(brightness),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Τύπος Λογαριασμού
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Τύπος Λογαριασμού',
                    border: const OutlineInputBorder(),
                    labelStyle: TypographyUI.bodyMedium(brightness),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Μετρητά')),
                    DropdownMenuItem(value: 'bank', child: Text('Τραπεζικός')),
                    DropdownMenuItem(
                      value: 'credit_card',
                      child: Text('Πιστωτική Κάρτα'),
                    ),
                    DropdownMenuItem(
                      value: 'savings',
                      child: Text('Ταμιευτήριο'),
                    ),
                    DropdownMenuItem(
                      value: 'investment',
                      child: Text('Επένδυση'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedType = v);
                    }
                  },
                  style: TypographyUI.bodyMedium(brightness),
                ),
                const SizedBox(height: 16),

                // Νόμισμα
                DropdownButtonFormField<String>(
                  initialValue: selectedCurrency,
                  decoration: InputDecoration(
                    labelText: 'Νόμισμα',
                    border: const OutlineInputBorder(),
                    labelStyle: TypographyUI.bodyMedium(brightness),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedCurrency = v);
                    }
                  },
                  style: TypographyUI.bodyMedium(brightness),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Ακύρωση',
                style: TypographyUI.buttonBase().copyWith(
                  color: ColorsUI.getTextSecondary(brightness),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  _showErrorSnack(context, 'Το Όνομα είναι Υποχρεωτικό');
                  return;
                }
                // ✅ Αν δεν άλλαξε το όνομα, δεν χρειάζεται duplicate check
                if (newName.trim().toLowerCase() ==
                    account.name.trim().toLowerCase()) {
                  Navigator.pop(dialogContext);

                  // ✅ Success αμέσως (ONLINE/OFFLINE)
                  _showSuccessSnack(context, 'Ο λογαριασμός ενημερώθηκε');

                  // ✅ Update στο background
                  _updateAccount(
                    uuid: account.uuid,
                    name: newName,
                    accountType: selectedType,
                    currency: selectedCurrency,
                    iconIndex: selectedIconIndex,
                  ).catchError((e) {
                    if (!context.mounted) return;

                    _showErrorSnack(context, 'Σφάλμα Ενημέρωσης');
                    DebugConfig.print('Background update error: $e');
                  });

                  return;
                }
                // ✅ Έλεγχος διπλότυπων με το service
                final canContinue = await AccountDuplicateService.instance
                    .checkForEditAccount(context, newName, account.uuid);

                if (!context.mounted) return;
                if (!canContinue) {
                  return;
                }
                Navigator.pop(dialogContext);
                // ✅ Update στο background
                _updateAccount(
                      uuid: account.uuid,
                      name: newName,
                      accountType: selectedType,
                      currency: selectedCurrency,
                      iconIndex: selectedIconIndex,
                    )
                    .then((_) {
                      // ✅ Success message εδώ
                      if (!context.mounted) return;
                      if (mounted) {
                        _showSuccessSnack(context, 'Ο λογαριασμός ενημερώθηκε');
                      }
                    })
                    .catchError((e) {
                      if (!context.mounted) return;

                      _showErrorSnack(context, 'Σφάλμα Ενημέρωσης');

                      DebugConfig.print('Background update error: $e');
                    });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorsUI.getPrimary(brightness),
                foregroundColor: ColorsUI.getOnPrimary(brightness),
              ),
              child: const Text('Αποθήκευση'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ICON PICKER WIDGET
  // ============================================================

  Widget _buildIconPicker(
    Brightness brightness,
    int selectedIndex,
    ValueChanged<int> onIconSelected,
  ) {
    // Παίρνουμε τα entries του map, τα ταξινομούμε κατά key
    final iconEntries = IconMapper.accountIcons.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Ο αριθμός είναι το μήκος των entries (π.χ. 12)
    final iconCount = iconEntries.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Επιλογή Εικονιδίου',
          style: TypographyUI.bodyMedium(
            brightness,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(iconCount, (i) {
                // ← Άλλαξε από (index) σε (i) – απλή μετονομασία για σαφήνεια
                final entry =
                    iconEntries[i]; // ← Νέα γραμμή: Παίρνουμε το entry
                final iconIndex = entry
                    .key; // ← Νέα γραμμή: Το πραγματικό key (π.χ. 0,1,2,...,71,72,...)
                final isSelected =
                    iconIndex ==
                    selectedIndex; // ← Άλλαξε: Συγκρίνουμε με iconIndex, όχι index/i
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onIconSelected(
                      iconIndex,
                    ), // ← Άλλαξε: Περνάμε iconIndex, όχι index/i
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ColorsUI.getPrimary(
                                brightness,
                              ).withValues(alpha: 0.2)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? ColorsUI.getPrimary(brightness)
                              : ColorsUI.getBorder(brightness),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Image.asset(
                          IconMapper.getIconPath(
                            'account',
                            iconIndex,
                          ), // ← Άλλαξε: Χρησιμοποιούμε iconIndex, όχι index/i
                          width: 28,
                          height: 28,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RECALCULATE BALANCE DIALOG
  // ============================================================

  void _showRecalculateConfirmDialog(
    BuildContext context,
    AccountModel account,
  ) {
    final brightness = Theme.of(context).brightness;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ColorsUI.getSurface(brightness),
        title: Text(
          'Επαναϋπολογισμός Υπολοίπου',
          style: TypographyUI.titleLarge(brightness),
        ),
        content: Text(
          'Θέλετε να επαναϋπολογίσετε το υπόλοιπο του λογαριασμού "${account.name}"; '
          'Αυτό θα υπολογίσει το υπόλοιπο από το αρχικό ποσό και τις συναλλαγές.',
          style: TypographyUI.bodyMedium(brightness),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Ακύρωση',
              style: TypographyUI.buttonBase().copyWith(
                color: ColorsUI.getTextSecondary(brightness),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final newBalance = await _recalculateAccountBalance(
                  account.uuid,
                );

                if (!context.mounted) return; // ✅ πολύ σημαντικό

                _showSuccessSnack(
                  context,
                  'Επανυπολογισμός ολοκληρώθηκε: ${CurrencyFormatter.format(newBalance, currency: account.currency)}',
                );
              } catch (e) {
                if (!mounted) return;

                DebugConfig.print('❌ Recalculate error: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Αποτυχία Επαναυπολογισμού'),
                    backgroundColor: ColorsUI.getError(brightness),
                  ),
                );
              }
            },

            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsUI.getPrimary(brightness),
              foregroundColor: ColorsUI.getOnPrimary(brightness),
            ),
            child: const Text('Επαναϋπολογισμός'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FIRESTORE OPERATIONS
  // ============================================================

  /// Δημιουργία λογαριασμού
  Future<void> _createAccount({
    required String userId,
    required String name,
    required double initialBalance,
    required String currency,
    required String accountType,
    required int iconIndex,
  }) async {
    try {
      final accountUuid = _uuid.v4();
      final now = DateTime.now();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc(accountUuid)
          .set({
            'user_id': userId,
            'name': name,
            'initial_balance': initialBalance,
            'current_balance': initialBalance,
            'currency': currency,
            'account_type': accountType,
            'icon_index': iconIndex,
            'color': null,
            'is_active': true,
            'display_order': 0,
            'created_at': Timestamp.fromDate(now),
            'updated_at': Timestamp.fromDate(now),
            'deleted': false,
          });

      DebugConfig.print('✅ Account created: $accountUuid - $name');
    } catch (e) {
      DebugConfig.print('❌ Error creating account: $e');
      rethrow;
    }
  }

  /// Ενημέρωση λογαριασμού
  Future<void> _updateAccount({
    required String uuid,
    required String name,
    required String accountType,
    required String currency,
    required int iconIndex,
  }) async {
    try {
      // ignore: use_build_context_synchronously
      final userId = context.session.userId;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc(uuid)
          .update({
            'name': name,
            'account_type': accountType,
            'currency': currency,
            'icon_index': iconIndex,
            'updated_at': FieldValue.serverTimestamp(),
          });

      DebugConfig.print('✅ Account updated: $uuid');
    } catch (e) {
      DebugConfig.print('❌ Error updating account: $e');

      rethrow;
    }
  }

  /// Επαναϋπολογισμός υπολοίπου λογαριασμού
  Future<double> _recalculateAccountBalance(String accountUuid) async {
    try {
      // ignore: use_build_context_synchronously
      final userId = context.session.userId;

      // 1. Get account's initial_balance
      final accountDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc(accountUuid)
          .get();

      if (!accountDoc.exists) {
        throw Exception('Account not found');
      }

      final accountData = accountDoc.data()!;
      final initialBalance =
          (accountData['initial_balance'] as num?)?.toDouble() ?? 0.0;

      // 2. Sum all transactions for this account
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = startOfToday.add(const Duration(days: 1));

      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('account_id', isEqualTo: accountUuid)
          .where('date', isLessThan: endOfToday)      // ← νέο φίλτρο
          .where('deleted', isEqualTo: false)
          .get();

      double transactionSum = 0.0;
      for (final doc in transactionsSnapshot.docs) {
        final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
        transactionSum += amount;
      }

      // 3. Calculate new balance
      final newBalance = initialBalance + transactionSum;

      // 4. Update current_balance
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc(accountUuid)
          .update({
            'current_balance': newBalance,
            'updated_at': FieldValue.serverTimestamp(),
          });

      DebugConfig.print('✅ Balance recalculated for $accountUuid: $newBalance');
      return newBalance;
    } catch (e) {
      DebugConfig.print('❌ Error recalculating balance: $e');
      rethrow;
    }
  }
  // ============================================================
  // INFO BOTTOM SHEET
  // ============================================================

  void _showAccountInfo(BuildContext context, AccountModel account) {
    final brightness = Theme.of(context).brightness;
    final createdAtText =
        '${account.createdAt.day.toString().padLeft(2, '0')}/'
        '${account.createdAt.month.toString().padLeft(2, '0')}/'
        '${account.createdAt.year}';

    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(brightness),
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: TypographyUI.titleLarge(brightness)),
                const SizedBox(height: 16),
                Text(
                  'Τρέχον Υπόλοιπο: ${CurrencyFormatter.format(account.currentBalance, currency: account.currency)}',
                  style: TypographyUI.bodyMedium(brightness),
                ),
                Text(
                  'Αρχικό Υπόλοιπο: ${CurrencyFormatter.format(account.initialBalance, currency: account.currency)}',
                  style: TypographyUI.bodyMedium(brightness),
                ),
                Text(
                  'Νόμισμα: ${account.currency}',
                  style: TypographyUI.bodyMedium(brightness),
                ),
                Text(
                  'Τύπος: ${_accountTypeLabel(account.accountType)}',
                  style: TypographyUI.bodyMedium(brightness),
                ),
                Row(
                  children: [
                    Text(
                      'Δημιουργήθηκε: ',
                      style: TypographyUI.bodyMedium(brightness),
                    ),
                    Text(
                      createdAtText,
                      style: TypographyUI.bodyMedium(
                        brightness,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // OPTIONS MENU BOTTOM SHEET
  // ============================================================

  void _showAccountOptions(BuildContext context, AccountModel account) {
    final brightness = Theme.of(context).brightness;

    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(brightness),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Edit
            ListTile(
              leading: Icon(
                Icons.edit,
                color: ColorsUI.getTextPrimary(brightness),
              ),
              title: Text(
                'Επεξεργασία',
                style: TypographyUI.bodyMedium(brightness),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditAccountDialog(context, account);
              },
            ),

            // Transactions
            ListTile(
              leading: Icon(
                Icons.list,
                color: ColorsUI.getTextPrimary(brightness),
              ),
              title: Text(
                'Κινήσεις',
                style: TypographyUI.bodyMedium(brightness),
              ),
              onTap: () {
                // ✅ Κλείσε ΠΡΩΤΑ το bottom sheet
                Navigator.pop(context);

                // ✅ Πάρε providers από το parent context (το ίδιο context του AccountsPage)
                final accountsProvider = context.read<AccountsProvider>();
                final categoriesProvider = context.read<CategoriesProvider>();

                // ✅ Μετά κάνε navigate
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (newContext) => MultiProvider(
                      providers: [
                        ChangeNotifierProvider.value(value: accountsProvider),
                        ChangeNotifierProvider.value(value: categoriesProvider),
                      ],
                      child: SessionScope(
                        session: context.session,
                        child: TransactionsShowPage(
                          accountUuid: account.uuid,
                          accountName: account.name,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Recalculate
            ListTile(
              leading: Icon(
                Icons.calculate,
                color: ColorsUI.getTextPrimary(brightness),
              ),
              title: Text(
                'Επαναϋπολογισμός Υπολοίπου',
                style: TypographyUI.bodyMedium(brightness),
              ),
              onTap: () {
                Navigator.pop(context);
                _showRecalculateConfirmDialog(context, account);
              },
            ),

            // Delete
            // Delete
            ListTile(
              leading: Icon(Icons.delete, color: ColorsUI.getError(brightness)),
              title: Text(
                'Διαγραφή',
                style: TypographyUI.bodyMedium(
                  brightness,
                ).copyWith(color: ColorsUI.getError(brightness)),
              ),
              onTap: () async {
                // 1) Κλείσε το bottom sheet
                Navigator.pop(context);

                // 2) Επιβεβαίωση διαγραφής (Dialog)
                final confirmed = await _confirmDeleteAccountDialog(
                  context,
                  account,
                );
                if (!confirmed) return;

                // 3) Background operation
                final scaffoldContext = context;
                if (!context.mounted) return;

                // ✅ Success αμέσως (ONLINE/OFFLINE)
                _showSuccessSnack(scaffoldContext, 'Ο λογαριασμός διαγράφηκε');
                AccessibilityService.announceSuccess(
                  'Ο λογαριασμός διαγράφηκε',
                );
                _deleteAccount(account.uuid).catchError((error) {
                  if (!scaffoldContext.mounted) return;

                  _showErrorSnack(scaffoldContext, 'Σφάλμα Διαγραφής');
                  DebugConfig.print('Delete account error: $error');
                });
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONFIRM DELETE ACCOUNT (same logic as TransactionsShowPage)
  // ============================================================

  Future<bool> _confirmDeleteAccountDialog(
    BuildContext context,
    AccountModel account,
  ) async {
    final brightness = Theme.of(context).brightness;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ColorsUI.getSurface(brightness),
        title: Text(
          'Διαγραφή Λογαριασμού',
          style: TypographyUI.titleLarge(brightness),
        ),
        content: Text(
          'Είστε σίγουροι ότι θέλετε να διαγράψετε τον λογαριασμό "${account.name}";',
          style: TypographyUI.bodyMedium(brightness),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Ακύρωση',
              style: TypographyUI.buttonBase().copyWith(
                color: ColorsUI.getTextSecondary(brightness),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsUI.getError(brightness),
              foregroundColor: Colors.white,
            ),
            child: const Text('Διαγραφή'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      // ✅ Accessibility για cancel (όπως στην TransactionsShowPage)
      AccessibilityService.announcePolite('Ακυρώθηκε η διαγραφή');
      return false;
    }

    return true;
  }

  /// Διαγραφή λογαριασμού (soft delete)
  /// Διαγραφή λογαριασμού (soft delete) + soft delete των κινήσεων του
  Future<void> _deleteAccount(String uuid) async {
    try {
      // ignore: use_build_context_synchronously
      final userId = context.session.userId;

      final accountRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc(uuid);

      // 1) Soft delete account
      await accountRef.update({
        'deleted': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 2) Soft delete ΟΛΕΣ τις κινήσεις του λογαριασμού
      final txSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('account_id', isEqualTo: uuid)
          .where('deleted', isEqualTo: false)
          .get();

      if (txSnap.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in txSnap.docs) {
          batch.update(doc.reference, {
            'deleted': true,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      DebugConfig.print('✅ Account deleted: $uuid (and tx soft-deleted)');
    } catch (e) {
      DebugConfig.print('❌ Error deleting account: $e');
      rethrow;
    }
  }

  // ============================================================
  // BUILD METHOD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accountsProvider = context.watch<AccountsProvider>();
    final accounts = accountsProvider.accounts;
    final isLoading = accountsProvider.isLoading;
    final error = accountsProvider.error;

    final totalBalance = _calculateTotalBalance(accounts);

    // Responsive layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 600 && screenWidth <= 1200;

    // ✅ Grid settings
    final bool useGrid = isTablet || isDesktop;
    final int crossAxisCount = isDesktop ? 3 : 2;
    final double childAspectRatio = isDesktop ? 2.6 : 2.4;

    Widget content;
    if (isLoading) {
      content = _buildLoadingState(brightness);
    } else if (error != null) {
      content = _buildErrorState(brightness, error);
    } else if (accounts.isEmpty) {
      content = _buildEmptyState(brightness);
    } else {
      content = useGrid
          ? _buildAccountsGrid(
              brightness,
              accounts,
              crossAxisCount,
              childAspectRatio,
            )
          : _buildAccountsList(brightness, accounts);
    }

    return Scaffold(
      backgroundColor: ColorsUI.getBackground(brightness),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(brightness, totalBalance),
            Expanded(child: content),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: FloatingActionButton(
          onPressed: () => _showAddAccountDialog(context),
          backgroundColor: ColorsUI.getPrimary(brightness),
          foregroundColor: ColorsUI.getOnPrimary(brightness),
          tooltip: 'Προσθήκη νέου λογαριασμού',
          child: ExcludeSemantics(child: const Icon(Icons.add)),
        ),
      ),
    );
  }

  // ============================================================
  // UI COMPONENTS
  // ============================================================

  Widget _buildHeader(Brightness brightness, double totalBalance) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Card(
        elevation: 2,
        color: ColorsUI.getCard(brightness),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ColorsUI.getBorder(brightness), width: 1),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ColorsUI.getPrimary(brightness),
                ColorsUI.getSecondary(brightness),
              ],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Αριστερά: Ετικέτα
              Expanded(
                child: Text(
                  'Συνολικό Υπόλοιπο',
                  style: TypographyUI.titleLarge(
                    brightness,
                  ).copyWith(color: ColorsUI.getOnPrimary(brightness)),
                ),
              ),

              const SizedBox(width: 12),

              // Δεξιά: μάτι + ποσό
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isBalanceHidden
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: ColorsUI.getOnPrimary(brightness),
                    ),
                    onPressed: _toggleBalanceVisibility,
                    tooltip: _isBalanceHidden
                        ? 'Εμφάνιση υπολοίπου'
                        : 'Απόκρυψη υπολοίπου',
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    label: _isBalanceHidden
                        ? 'Συνολικό υπόλοιπο κρυφό'
                        : 'Συνολικό υπόλοιπο: ${CurrencyFormatter.format(totalBalance, currency: context.session.defaultCurrency)}',
                    liveRegion: true,
                    excludeSemantics: true,
                    child: Text(
                      _isBalanceHidden
                          ? '••••••'
                          : CurrencyFormatter.format(
                              totalBalance,
                              currency: context.session.defaultCurrency,
                            ),
                      style: TypographyUI.titleLarge(brightness).copyWith(
                        color: ColorsUI.getOnPrimary(brightness),
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(Brightness brightness) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Φόρτωση λογαριασμών. Παρακαλώ περιμένετε.',
        excludeSemantics: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: CircularProgressIndicator(
                color: ColorsUI.getPrimary(brightness),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Φόρτωση λογαριασμών...',
              style: TypographyUI.bodyMedium(brightness),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Brightness brightness, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Semantics(
          liveRegion: true,
          label: 'Σφάλμα φόρτωσης: $error',
          excludeSemantics: true,
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
                style: TypographyUI.titleLarge(brightness),
              ),
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
      child: Semantics(
        label:
            'Δεν υπάρχουν λογαριασμοί. Πατήστε το κουμπί προσθήκης για να δημιουργήσετε έναν.',
        excludeSemantics: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 30,
                color: ColorsUI.getTextSecondary(brightness),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Δεν υπάρχουν λογαριασμοί',
              style: TypographyUI.titleMedium(brightness),
            ),
            const SizedBox(height: 8),
            Text(
              'Πατήστε το κουμπί για να προσθέσετε',
              style: TypographyUI.bodyMedium(
                brightness,
              ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsGrid(
    Brightness brightness,
    List<AccountModel> accounts,
    int crossAxisCount,
    double childAspectRatio,
  ) {
    // ✅ extra bottom space για να μην καλύπτει ο FAB το τελευταίο row
    const bottomSafeSpace = 96.0;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, bottomSafeSpace),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        return _buildAccountCard(brightness, accounts[index]);
      },
    );
  }

  Widget _buildAccountsList(
    Brightness brightness,
    List<AccountModel> accounts,
  ) {
    // ✅ extra bottom space για να μην καλύπτει ο FAB το τελευταίο item
    const bottomSafeSpace = 96.0;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, bottomSafeSpace),
      itemCount: accounts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        return _buildAccountCard(brightness, accounts[index]);
      },
    );
  }

  Widget _buildAccountCard(Brightness brightness, AccountModel account) {
    final isExcluded = _excludedAccountUuids.contains(account.uuid);

    return Card(
      elevation: 2,
      color: ColorsUI.getCard(brightness),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ColorsUI.getBorder(brightness), width: 1),
      ),
      child: InkWell(
        onTap: () => _showAccountInfo(context, account),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          // ↓↓↓ ΜΟΝΗ αλλαγή εδώ: λίγο μικρότερο κάθετο padding για να φύγει το κάτω κενό
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ============================================================
              // LEFT SIDE
              // ============================================================
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon
                    // Icon — διακοσμητικό
                    ExcludeSemantics(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: ColorsUI.getPrimary(
                            brightness,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Image.asset(
                            IconMapper.getIconPath(
                              'account',
                              account.iconIndex ?? 0,
                            ),
                            width: 40,
                            height: 40,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Name + Amount + Type (κάθετα)
                    Expanded(
                      child: MergeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─────────────────────────────
                            // Όνομα + Ποσό στην ίδια γραμμή
                            // ─────────────────────────────
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Όνομα
                                Expanded(
                                  child: Text(
                                    account.name,
                                    style: TypographyUI.titleSmall(brightness),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                const SizedBox(width: 1),

                                // Ποσό
                                Text(
                                  CurrencyFormatter.format(
                                    account.currentBalance,
                                    currency: account.currency,
                                  ),
                                  style: TypographyUI.bodyMedium(brightness)
                                      .copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: account.currentBalance >= 0
                                            ? ColorsUI.getIncomeColor(
                                                brightness,
                                              )
                                            : ColorsUI.getExpenseColor(
                                                brightness,
                                              ),
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            // Τύπος λογαριασμού (από κάτω)
                            Text(
                              _accountTypeLabel(account.accountType),
                              style: TypographyUI.labelSmall(brightness)
                                  .copyWith(
                                    color: ColorsUI.getTextSecondary(
                                      brightness,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ============================================================
              // RIGHT SIDE (centered, overflow-safe)
              // ============================================================
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.more_vert,
                          color: ColorsUI.getTextSecondary(brightness),
                        ),
                        onPressed: () => _showAccountOptions(context, account),
                        tooltip: 'Επιλογές',
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          isExcluded
                              ? Icons.check_box_outline_blank
                              : Icons.check_box,
                          color: isExcluded
                              ? ColorsUI.getTextSecondary(brightness)
                              : ColorsUI.getPrimary(brightness),
                        ),
                        onPressed: () =>
                            _toggleAccountInTotal(account.uuid, account.name),
                        tooltip: isExcluded
                            ? 'Συμπερίληψη στο σύνολο'
                            : 'Αποκλεισμός από το σύνολο',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
