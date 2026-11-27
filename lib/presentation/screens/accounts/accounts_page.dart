// ============================================================
// ACCOUNTS PAGE – FIREBASE VERSION
// Path: lib/presentation/screens/accounts/accounts_page.dart
// ============================================================

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

// Core imports
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/messaging/app_messenger.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/core/utils/icon_mapper.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/utils/account_delete_guard.dart';
import 'package:family_economy/core/utils/account_totals.dart';
// Providers
import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/services/account_duplicate_service.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/services/transactions_actions_service.dart';
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

  /// E24: offline η ανάγνωση κινήσεων μπορεί να είναι κενή/μερική (cache).
  /// Η διαγραφή λογαριασμού απαιτεί σύνδεση για να μη μείνουν ορφανές κινήσεις.
  bool _isOfflineConfirmed(BuildContext context) {
    try {
      return context.read<ConnectivityService>().isConfirmedOffline;
    } catch (_) {
      return false;
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
    AppMessenger.success(context, message);
  }

  void _showErrorSnack(BuildContext context, String message) {
    AppMessenger.error(context, message);
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

  /// Υπολογισμός συνολικού υπολοίπου (E26: ενεργοί **και** αρχειοθετημένοι,
  /// μείον τις εξαιρέσεις του χρήστη — E27: οι εξαιρέσεις ζουν στον provider).
  double _calculateTotalBalance(AccountsProvider provider) {
    return AccountTotals.sum(
      provider.allAccounts,
      excluded: provider.excludedAccountUuids,
    );
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

  /// Toggle συμπερίληψης/αποκλεισμού λογαριασμού από το σύνολο (E27).
  /// Η κατάσταση ζει στον `AccountsProvider` — έτσι την βλέπουν και τα
  /// γραφήματα, με ένα rebuild μέσω `notifyListeners`.
  void _toggleAccountInTotal(String uuid, String accountName) {
    final provider = context.read<AccountsProvider>();
    final wasExcluded = provider.isExcludedFromTotal(uuid);

    provider.setExcludedFromTotal(uuid, excluded: !wasExcluded);

    AccessibilityService.announcePolite(
      wasExcluded
          ? 'Ο λογαριασμός $accountName συμπεριλήφθηκε στο συνολικό υπόλοιπο'
          : 'Ο λογαριασμός $accountName αποκλείστηκε από το συνολικό υπόλοιπο',
    );
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
    String? nameError;

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
                    errorText: nameError,
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
                  setDialogState(
                    () => nameError = 'Το Όνομα είναι Υποχρεωτικό',
                  );
                  return;
                }
                setDialogState(() => nameError = null);

                // ✅ Έλεγχος διπλότυπων με το service (E33: 3 καταστάσεις)
                final check = await AccountDuplicateService.instance
                    .checkForCreateAccount(context, userId, name);

                DebugConfig.print(
                  '🧾 [CREATE] duplicate check outcome=${check.outcome}',
                );

                if (!dialogContext.mounted) return;

                if (check.outcome == CreateAccountOutcome.keepDialog) {
                  // Ακύρωση/αποτυχία επαναφοράς → μένει ανοιχτή η δημιουργία
                  final message = check.message;
                  if (message != null) {
                    setDialogState(() => nameError = message);
                  }
                  return;
                }

                if (check.outcome == CreateAccountOutcome.closeDialog) {
                  // Διπλότυπο ή επιτυχής επαναφορά → κλείσε το dialog
                  final message = check.message;
                  Navigator.pop(dialogContext);
                  if (message != null && context.mounted) {
                    if (check.kind == CreateMessageKind.success) {
                      AppMessenger.success(context, message);
                    } else {
                      AppMessenger.error(context, message);
                    }
                  }
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
    String? nameError;

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
                    errorText: nameError,
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
                  setDialogState(
                    () => nameError = 'Το Όνομα είναι Υποχρεωτικό',
                  );
                  return;
                }
                setDialogState(() => nameError = null);
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
                final check = await AccountDuplicateService.instance
                    .checkForEditAccount(context, newName, account.uuid);

                if (!dialogContext.mounted) return;
                if (check.outcome != CreateAccountOutcome.proceed) {
                  final message = check.message;
                  if (message != null) {
                    setDialogState(() => nameError = message);
                  }
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

    // E24: offline η ανάγνωση κινήσεων μπορεί να είναι κενή/μερική (cache).
    if (_isOfflineConfirmed(context)) {
      const offlineMessage = 'Ο επανυπολογισμός απαιτεί σύνδεση στο internet';
      _showErrorSnack(context, offlineMessage);
      AccessibilityService.announceError(offlineMessage);
      return;
    }

    // Το AccountsProvider είναι κάτω από το Navigator (route-scoped), άρα δεν
    // είναι ορατό από το context του dialog — το κρατάμε πριν το άνοιγμα.
    final accountsProvider = context.read<AccountsProvider>();
    var isWorking = false;

    showDialog<void>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return PopScope(
              canPop: !isWorking,
              child: AlertDialog(
                backgroundColor: ColorsUI.getSurface(brightness),
                title: Text(
                  'Επαναϋπολογισμός Υπολοίπου',
                  style: TypographyUI.titleLarge(brightness),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Το υπόλοιπο του λογαριασμού "${account.name}" θα '
                        'υπολογιστεί ξανά από το αρχικό ποσό και τις κινήσεις '
                        'που έχουν ήδη εφαρμοστεί.',
                        style: TypographyUI.bodyMedium(brightness),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Οι εκκρεμείς προγραμματισμένες κινήσεις που δεν έχουν '
                        'εκτελεστεί δεν μετράνε.',
                        style: TypographyUI.bodySmall(brightness),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isWorking
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: Text(
                      'Ακύρωση',
                      style: TypographyUI.buttonBase().copyWith(
                        color: ColorsUI.getTextSecondary(brightness),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isWorking
                        ? null
                        : () async {
                            setDialogState(() => isWorking = true);

                            final outcome = await accountsProvider
                                .recalculateAccountBalance(account.uuid);

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);

                            if (!mounted) return;

                            final message = outcome.message(
                              currency: account.currency,
                            );

                            if (outcome.isSuccess) {
                              _showSuccessSnack(context, message);
                              AccessibilityService.announceSuccess(message);
                            } else {
                              _showErrorSnack(context, message);
                              AccessibilityService.announceError(message);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorsUI.getPrimary(brightness),
                      foregroundColor: ColorsUI.getOnPrimary(brightness),
                    ),
                    child: isWorking
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ColorsUI.getOnPrimary(brightness),
                            ),
                          )
                        : const Text('Επαναϋπολογισμός'),
                  ),
                ],
              ),
            );
          },
        );
      },
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
                if (account.isArchived)
                  Text(
                    'Κατάσταση: Αρχειοθετημένος'
                    '${account.archivedAt == null ? '' : ' από ${_formatShortDate(account.archivedAt!)}'}',
                    style: TypographyUI.bodyMedium(
                      brightness,
                    ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
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
    final isArchived = account.isArchived;
    final deleteDecision = AccountDeleteGuard.evaluate(
      context.read<AccountsProvider>().accounts.length,
    );

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

            // Edit (μόνο για ενεργούς — E26)
            if (!isArchived)
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

            // Recalculate (μόνο για ενεργούς — E26)
            if (!isArchived)
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

            // Επαναφορά (E26) — μόνο για αρχειοθετημένους
            if (isArchived)
              ListTile(
                leading: Icon(
                  Icons.unarchive_outlined,
                  color: ColorsUI.getPrimary(brightness),
                ),
                title: Text(
                  'Επαναφορά',
                  style: TypographyUI.bodyMedium(brightness),
                ),
                subtitle: Text(
                  'Επιστρέφει στις λίστες επιλογής',
                  style: TypographyUI.labelSmall(
                    brightness,
                  ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _handleRestoreAccount(context, account);
                },
              ),

            // Αρχειοθέτηση (E26) — μόνο για ενεργούς, όχι τον τελευταίο
            if (!isArchived && deleteDecision.canDelete)
              ListTile(
                leading: Icon(
                  Icons.archive_outlined,
                  color: ColorsUI.getTextPrimary(brightness),
                ),
                title: Text(
                  'Αρχειοθέτηση',
                  style: TypographyUI.bodyMedium(brightness),
                ),
                subtitle: Text(
                  'Κρατά ιστορικό και υπόλοιπο',
                  style: TypographyUI.labelSmall(
                    brightness,
                  ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _handleArchiveAccount(context, account);
                },
              ),

            // Delete: πραγματική διαγραφή μόνο για «καθαρούς» (E26).
            if (isArchived || deleteDecision.canDelete)
              ListTile(
                leading: Icon(
                  Icons.delete,
                  color: ColorsUI.getError(brightness),
                ),
                title: Text(
                  'Διαγραφή',
                  style: TypographyUI.bodyMedium(
                    brightness,
                  ).copyWith(color: ColorsUI.getError(brightness)),
                ),
                onTap: () async {
                  // 1) Κλείσε το bottom sheet
                  Navigator.pop(context);

                  // 2) E24 + preflight + επιβεβαίωση + εφαρμογή
                  await _handleDeleteAccount(
                    context,
                    account,
                    allowArchiveFallback: !isArchived,
                  );
                },
              )
            else
              _buildDeleteBlockedTile(brightness, deleteDecision.message),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Εναλλακτικό περιεχόμενο όταν η διαγραφή δεν επιτρέπεται
  /// (τελευταίος ενεργός λογαριασμός). Ίδιο pattern με CategoryActionsDialog.
  Widget _buildDeleteBlockedTile(Brightness brightness, String message) {
    final warning = ColorsUI.getWarning(brightness);

    return Semantics(
      liveRegion: true,
      label: 'Διαγραφή ή αρχειοθέτηση μη διαθέσιμη. $message',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.lock_outline, color: warning, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TypographyUI.bodySmall(
                  brightness,
                ).copyWith(color: warning),
              ),
            ),
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
    AccountModel account, {
    AccountDeletePlan? plan,
  }) async {
    final brightness = Theme.of(context).brightness;

    final transferCount = plan?.transferCount ?? 0;
    final completedPairs = plan?.completedPairs ?? 0;
    final pendingPairs = plan?.pendingPairs ?? 0;
    final orphanLegs = (plan?.partialPairs ?? 0) + (plan?.unknownPairs ?? 0);
    final hasTransfers = transferCount > 0 || orphanLegs > 0;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ColorsUI.getSurface(brightness),
        title: Text(
          'Διαγραφή Λογαριασμού',
          style: TypographyUI.titleLarge(brightness),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Είστε σίγουροι ότι θέλετε να διαγράψετε τον λογαριασμό "${account.name}";',
              style: TypographyUI.bodyMedium(brightness),
            ),
            if (hasTransfers) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColorsUI.getWarning(brightness).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ColorsUI.getWarning(
                      brightness,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (transferCount > 0)
                      Text(
                        'Ο λογαριασμός μετέχει σε $transferCount '
                        '${transferCount == 1 ? "μεταφορά" : "μεταφορές"}:',
                        style: TypographyUI.bodyMedium(brightness),
                      ),
                    if (completedPairs > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '• $completedPairs ολοκληρωμένες: θα ακυρωθούν και '
                          'στα δύο σκέλη και τα ποσά θα επιστραφούν στα '
                          'υπόλοιπα.',
                          style: TypographyUI.bodySmall(brightness),
                        ),
                      ),
                    if (pendingPairs > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '• $pendingPairs εκκρεμείς: θα ακυρωθούν (δεν είχαν '
                          'επηρεάσει υπόλοιπα).',
                          style: TypographyUI.bodySmall(brightness),
                        ),
                      ),
                    if (orphanLegs > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '• $orphanLegs ημιτελή/μη ταυτοποιημένα ζεύγη: θα '
                          'κρυφτούν μόνο ως προς αυτόν τον λογαριασμό.',
                          style: TypographyUI.bodySmall(brightness),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
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

  /// Διαγραφή λογαριασμού (soft delete) μαζί με τις κινήσεις του:
  /// - Κινήσεις εκτός μεταφορών → κρύβονται.
  /// - Μεταφορές → ακυρώνεται **ολόκληρο** το ζεύγος και αντιστρέφονται τα
  ///   υπόλοιπα (E11), με marker για συμμετρική επαναφορά.
  /// - Λογαριασμός γράφεται **τελευταίος**· >499 writes → chunks.
  Future<void> _handleDeleteAccount(
    BuildContext context,
    AccountModel account, {
    bool allowArchiveFallback = true,
  }) async {
    final scaffoldContext = context;
    final uuid = account.uuid;

    // E24: offline η ανάγνωση κινήσεων μπορεί να είναι κενή/μερική (cache).
    if (_isOfflineConfirmed(scaffoldContext)) {
      _showErrorSnack(
        scaffoldContext,
        'Η διαγραφή λογαριασμού απαιτεί σύνδεση στο internet',
      );
      AccessibilityService.announceError(
        'Η διαγραφή λογαριασμού απαιτεί σύνδεση στο internet',
      );
      return;
    }

    final userId = scaffoldContext.session.userId;
    final actions = TransactionsActionsService();
    // E27: κρατάμε τον provider πριν από τα async gaps (καθαρισμός εξαίρεσης
    // μετά τη διαγραφή) — αποφεύγει `use_build_context_synchronously`.
    final accountsProvider = scaffoldContext.read<AccountsProvider>();

    // 1) Preflight για τον διάλογο (καμία εγγραφή).
    AccountDeletePlan plan;
    try {
      plan = await actions.previewAccountDelete(
        userId: userId,
        accountUuid: uuid,
      );
    } catch (error) {
      DebugConfig.print('Delete account preflight error: $error');
      if (!scaffoldContext.mounted) return;
      _showErrorSnack(
        scaffoldContext,
        'Σφάλμα ανάγνωσης δεδομένων λογαριασμού',
      );
      AccessibilityService.announceError(
        'Σφάλμα ανάγνωσης δεδομένων λογαριασμού',
      );
      return;
    }
    if (!scaffoldContext.mounted) return;

    // 1β) E26/L26: διαγραφή μόνο «καθαρού» λογαριασμού· αλλιώς αρχειοθέτηση.
    final budgetsCount = plan.budgetsCount;
    final actionDecision = AccountDeleteGuard.decide(
      activeAccountCount: accountsProvider.accounts.length,
      hasAnyTransaction: plan.hasAnyTransaction,
      budgetsCount: budgetsCount,
      pendingCount: plan.pendingLegUuids.length,
      targetIsVisible: account.isActive,
    );

    if (actionDecision.isBlocked) {
      await _showArchiveBlockedDialog(scaffoldContext, actionDecision.message);
      return;
    }

    // L26: αν η απόφαση είναι διαγραφή αλλά τα budgets δεν διαβάστηκαν,
    // δεν προχωράμε (fail-closed **μόνο** για τη διαγραφή).
    if (plan.budgetsUnknown && actionDecision.action == AccountAction.delete) {
      await _showArchiveBlockedDialog(
        scaffoldContext,
        'Σφάλμα ανάγνωσης δεδομένων λογαριασμού. Δεν άλλαξε τίποτα. '
        'Δοκιμάστε ξανά.',
        title: 'Διαγραφή μη διαθέσιμη',
      );
      return;
    }

    if (actionDecision.action == AccountAction.archive) {
      if (!allowArchiveFallback) {
        // Αρχειοθετημένος με ιστορικό → μένει αρχειοθετημένος.
        await _showArchiveBlockedDialog(
          scaffoldContext,
          'Ο λογαριασμός έχει ιστορικό (${_historySummary(plan)}) και '
          'δεν μπορεί να διαγραφεί. Παραμένει αρχειοθετημένος.',
        );
        return;
      }

      final wantsArchive = await _confirmArchiveDialog(
        scaffoldContext,
        account,
        transactionsCount: plan.activeLegCount,
        budgetsCount: plan.budgetsCount,
        inactiveBudgetsCount: plan.inactiveBudgetsCount,
        intro:
            'Ο λογαριασμός "${account.name}" έχει ιστορικό, οπότε δεν '
            'διαγράφεται. Μπορείτε να τον αρχειοθετήσετε:',
      );
      if (!wantsArchive) return;
      if (!scaffoldContext.mounted) return;

      await _handleArchiveAccount(
        scaffoldContext,
        account,
        plan: plan,
        skipConfirm: true,
      );
      return;
    }

    // 2) Επιβεβαίωση (με ενημέρωση για τις μεταφορές).
    final confirmed = await _confirmDeleteAccountDialog(
      scaffoldContext,
      account,
      plan: plan,
    );
    if (!confirmed) return;
    if (!scaffoldContext.mounted) return;

    try {
      // 3) Φρέσκο preflight πριν τη γραφή (μπορεί να άλλαξαν τα δεδομένα).
      plan = await actions.previewAccountDelete(
        userId: userId,
        accountUuid: uuid,
      );
      if (!scaffoldContext.mounted) return;

      // 3β) L26/E50: επαναξιολόγηση με τα **φρέσκα** πλήθη. Αν προέκυψαν
      // κινήσεις/budgets ή αν τα budgets δεν διαβάστηκαν → καμία εγγραφή.
      final freshDecision = AccountDeleteGuard.decide(
        activeAccountCount: accountsProvider.accounts.length,
        hasAnyTransaction: plan.hasAnyTransaction,
        budgetsCount: plan.budgetsCount,
        pendingCount: plan.pendingLegUuids.length,
        targetIsVisible: account.isActive,
      );
      if (freshDecision.action != AccountAction.delete || plan.budgetsUnknown) {
        DebugConfig.print(
          '⚠️ Delete drift: action=${freshDecision.action.name}, '
          'legs=${plan.activeLegCount}, budgets=${plan.budgetsCount}, '
          'budgetsUnknown=${plan.budgetsUnknown}',
        );
        if (!scaffoldContext.mounted) return;
        await _showArchiveBlockedDialog(
          scaffoldContext,
          plan.budgetsUnknown
              ? 'Σφάλμα ανάγνωσης δεδομένων λογαριασμού. Δεν άλλαξε τίποτα. '
                    'Δοκιμάστε ξανά.'
              : 'Τα δεδομένα άλλαξαν (βρέθηκαν κινήσεις ή προϋπολογισμοί). '
                    'Δεν έγινε καμία αλλαγή. Δοκιμάστε ξανά.',
          title: 'Διαγραφή μη διαθέσιμη',
        );
        return;
      }

      // 4) Εφαρμογή: κινήσεις/ζεύγη → deltas → λογαριασμός τελευταίος.
      await actions.applyAccountDeletePlan(userId: userId, plan: plan);

      // 5) Καθαρισμός τοπικής προτίμησης (αποκλεισμός από το συνολικό υπόλοιπο)
      await accountsProvider.setExcludedFromTotal(uuid, excluded: false);

      DebugConfig.print(
        '✅ Account deleted: $uuid (plain=${plan.plainLegUuids.length}, '
        'pairs=${plan.transferCount}, writes=${plan.totalWrites})',
      );

      if (!scaffoldContext.mounted) return;
      _showSuccessSnack(scaffoldContext, 'Ο λογαριασμός διαγράφηκε');
      AccessibilityService.announceSuccess('Ο λογαριασμός διαγράφηκε');
    } catch (error) {
      DebugConfig.print('Delete account error: $error');
      if (!scaffoldContext.mounted) return;

      _showErrorSnack(scaffoldContext, 'Σφάλμα Διαγραφής');
      AccessibilityService.announceError('Σφάλμα διαγραφής λογαριασμού');
    }
  }

  // ============================================================
  // E26 — ΑΡΧΕΙΟΘΕΤΗΣΗ / ΕΠΑΝΑΦΟΡΑ ΛΟΓΑΡΙΑΣΜΟΥ
  // ============================================================

  Future<void> _handleArchiveAccount(
    BuildContext context,
    AccountModel account, {
    AccountDeletePlan? plan,
    bool skipConfirm = false,
  }) async {
    final scaffoldContext = context;
    final userId = scaffoldContext.session.userId;

    // 1) Φραγή τελευταίου ενεργού (0 reads).
    final activeDecision = AccountDeleteGuard.evaluate(
      scaffoldContext.read<AccountsProvider>().accounts.length,
    );
    if (!activeDecision.canDelete) {
      await _showArchiveBlockedDialog(scaffoldContext, activeDecision.message);
      return;
    }

    // 2) Πλάνο κινήσεων (1 read, μόνο αν δεν δόθηκε).
    AccountDeletePlan? current = plan;
    if (current == null) {
      try {
        current = await TransactionsActionsService().previewAccountDelete(
          userId: userId,
          accountUuid: account.uuid,
        );
      } catch (error) {
        DebugConfig.print('Archive account preview error: $error');
        if (!scaffoldContext.mounted) return;
        _showErrorSnack(
          scaffoldContext,
          'Σφάλμα ανάγνωσης δεδομένων λογαριασμού',
        );
        AccessibilityService.announceError(
          'Σφάλμα ανάγνωσης δεδομένων λογαριασμού',
        );
        return;
      }
      if (!scaffoldContext.mounted) return;
    }

    // 3) Εκκρεμείς προγραμματισμένες → φραγή (ο executor δεν ελέγχει is_active).
    if (current.hasPendingScheduled) {
      final pendingCount = current.pendingLegUuids.length;
      final pendingText = pendingCount == 1
          ? 'Υπάρχει 1 εκκρεμής προγραμματισμένη κίνηση. '
          : 'Υπάρχουν $pendingCount εκκρεμείς προγραμματισμένες κινήσεις. ';
      await _showArchiveBlockedDialog(
        scaffoldContext,
        '$pendingText'
        'Ακυρώστε ${pendingCount == 1 ? 'την' : 'τις'} πρώτα από την '
        'καρτέλα «Προγραμματισμένες».',
      );
      return;
    }

    // 4) Επιβεβαίωση.
    if (!skipConfirm) {
      final confirmed = await _confirmArchiveDialog(
        scaffoldContext,
        account,
        transactionsCount: current.activeLegCount,
        budgetsCount: current.budgetsCount,
        inactiveBudgetsCount: current.inactiveBudgetsCount,
      );
      if (!confirmed) return;
      if (!scaffoldContext.mounted) return;
    }

    // 5) Εγγραφή: 1 doc update, offline-safe, καμία κίνηση δεν αγγίζεται.
    try {
      await TransactionsActionsService().archiveAccount(
        userId: userId,
        accountUuid: account.uuid,
      );

      if (!scaffoldContext.mounted) return;
      _showSuccessSnack(scaffoldContext, 'Ο λογαριασμός αρχειοθετήθηκε');
      AccessibilityService.announceSuccess('Ο λογαριασμός αρχειοθετήθηκε');
    } catch (error) {
      DebugConfig.print('Archive account error: $error');
      if (!scaffoldContext.mounted) return;
      _showErrorSnack(scaffoldContext, 'Σφάλμα Αρχειοθέτησης');
      AccessibilityService.announceError('Σφάλμα αρχειοθέτησης λογαριασμού');
    }
  }

  Future<void> _handleRestoreAccount(
    BuildContext context,
    AccountModel account,
  ) async {
    final scaffoldContext = context;
    final userId = scaffoldContext.session.userId;

    try {
      await TransactionsActionsService().restoreArchivedAccount(
        userId: userId,
        accountUuid: account.uuid,
      );

      if (!scaffoldContext.mounted) return;
      _showSuccessSnack(scaffoldContext, 'Ο λογαριασμός επανήλθε');
      AccessibilityService.announceSuccess('Ο λογαριασμός επανήλθε');
    } catch (error) {
      DebugConfig.print('Restore account error: $error');
      if (!scaffoldContext.mounted) return;
      _showErrorSnack(scaffoldContext, 'Σφάλμα Επαναφοράς');
      AccessibilityService.announceError('Σφάλμα επαναφοράς λογαριασμού');
    }
  }

  /// Σύνοψη ιστορικού για μηνύματα φραγής (L26: budgets χωρίς κινήσεις).
  String _historySummary(AccountDeletePlan plan) {
    final transactions = plan.activeLegCount == 1
        ? '1 κίνηση'
        : '${plan.activeLegCount} κινήσεις';
    if (plan.budgetsUnknown) return transactions;
    final budgets = plan.budgetsCount == 1
        ? '1 προϋπολογισμός'
        : '${plan.budgetsCount} προϋπολογισμοί';
    return '$transactions, $budgets';
  }

  Future<void> _showArchiveBlockedDialog(
    BuildContext context,
    String message, {
    String title = 'Αρχειοθέτηση μη διαθέσιμη',
  }) async {
    final brightness = Theme.of(context).brightness;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ColorsUI.getSurface(brightness),
        title: Text(title, style: TypographyUI.titleLarge(brightness)),
        content: Text(message, style: TypographyUI.bodyMedium(brightness)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Εντάξει',
              style: TypographyUI.buttonBase().copyWith(
                color: ColorsUI.getPrimary(brightness),
              ),
            ),
          ),
        ],
      ),
    );

    AccessibilityService.announcePolite(message);
  }

  Future<bool> _confirmArchiveDialog(
    BuildContext context,
    AccountModel account, {
    required int transactionsCount,
    required int budgetsCount,
    int inactiveBudgetsCount = 0,
    String? intro,
  }) async {
    final brightness = Theme.of(context).brightness;
    final offline = _isOfflineConfirmed(context);
    final balanceText = CurrencyFormatter.format(
      account.currentBalance,
      currency: account.currency,
    );
    final transactionsText = transactionsCount == 0
        ? 'Καμία κίνηση· το υπόλοιπο $balanceText διατηρείται'
        : transactionsCount == 1
        ? 'Η 1 κίνηση και το υπόλοιπο $balanceText διατηρούνται'
        : 'Οι $transactionsCount κινήσεις και το υπόλοιπο $balanceText '
              'διατηρούνται';
    final inactiveText = inactiveBudgetsCount == 0
        ? ''
        : ' ($inactiveBudgetsCount '
              '${inactiveBudgetsCount == 1 ? "ανενεργός" : "ανενεργοί"})';
    final budgetsText = budgetsCount == 1
        ? '1 προϋπολογισμός συνεχίζει να τον χρησιμοποιεί$inactiveText.'
        : '$budgetsCount προϋπολογισμοί συνεχίζουν να τον '
              'χρησιμοποιούν$inactiveText.';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ColorsUI.getSurface(brightness),
        title: Text(
          'Αρχειοθέτηση Λογαριασμού',
          style: TypographyUI.titleLarge(brightness),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              intro ?? 'Ο λογαριασμός "${account.name}" θα αρχειοθετηθεί.',
              style: TypographyUI.bodyMedium(brightness),
            ),
            const SizedBox(height: 12),
            Text(
              '• Κρύβεται από τις λίστες επιλογής.\n'
              '• $transactionsText.\n'
              '• Συνεχίζει να μετράει στο συνολικό υπόλοιπο.\n'
              '• Μπορείτε να τον επαναφέρετε όποτε θέλετε.',
              style: TypographyUI.bodySmall(brightness),
            ),
            if (budgetsCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '• $budgetsText',
                  style: TypographyUI.bodySmall(brightness),
                ),
              ),
            if (offline)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '• Χωρίς σύνδεση δεν ελέγχονται εκκρεμείς κινήσεις άλλης '
                  'συσκευής.',
                  style: TypographyUI.bodySmall(
                    brightness,
                  ).copyWith(color: ColorsUI.getWarning(brightness)),
                ),
              ),
          ],
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
              backgroundColor: ColorsUI.getPrimary(brightness),
              foregroundColor: ColorsUI.getOnPrimary(brightness),
            ),
            child: const Text('Αρχειοθέτηση'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      AccessibilityService.announcePolite('Ακυρώθηκε η αρχειοθέτηση');
      return false;
    }

    return true;
  }

  // ============================================================
  // BUILD METHOD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accountsProvider = context.watch<AccountsProvider>();
    final accounts = accountsProvider.accounts;
    final archivedAccounts = accountsProvider.archivedAccounts;
    final isLoading = accountsProvider.isLoading;
    final error = accountsProvider.error;

    final totalBalance = _calculateTotalBalance(accountsProvider);

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
      content = _buildErrorState(brightness);
    } else if (accounts.isEmpty && archivedAccounts.isEmpty) {
      content = _buildEmptyState(brightness);
    } else {
      content = useGrid
          ? _buildAccountsGrid(
              brightness,
              accounts,
              crossAxisCount,
              childAspectRatio,
              archivedAccounts,
            )
          : _buildAccountsList(brightness, accounts, archivedAccounts);
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

  Widget _buildErrorState(Brightness brightness) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Semantics(
          liveRegion: true,
          label: 'Σφάλμα φόρτωσης λογαριασμών',
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
                'Αποτυχία φόρτωσης λογαριασμών. Δοκιμάστε ξανά.',
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
    List<AccountModel> archivedAccounts,
  ) {
    // ✅ extra bottom space για να μην καλύπτει ο FAB το τελευταίο row
    const bottomSafeSpace = 96.0;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _buildAccountCard(brightness, accounts[index]),
              childCount: accounts.length,
            ),
          ),
        ),
        if (archivedAccounts.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildArchivedSection(brightness, archivedAccounts),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: bottomSafeSpace)),
      ],
    );
  }

  Widget _buildAccountsList(
    Brightness brightness,
    List<AccountModel> accounts,
    List<AccountModel> archivedAccounts,
  ) {
    // ✅ extra bottom space για να μην καλύπτει ο FAB το τελευταίο item
    const bottomSafeSpace = 96.0;
    final hasArchived = archivedAccounts.isNotEmpty;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, bottomSafeSpace),
      itemCount: accounts.length + (hasArchived ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        if (index < accounts.length) {
          return _buildAccountCard(brightness, accounts[index]);
        }
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _buildArchivedSection(brightness, archivedAccounts),
        );
      },
    );
  }

  // ============================================================
  // E26 — ΑΡΧΕΙΟΘΕΤΗΜΕΝΟΙ ΛΟΓΑΡΙΑΣΜΟΙ
  // ============================================================

  Widget _buildArchivedSection(
    Brightness brightness,
    List<AccountModel> archivedAccounts,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: ColorsUI.getCard(brightness),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorsUI.getBorder(brightness), width: 1),
        ),
        child: ExpansionTile(
          key: const PageStorageKey<String>('archived_accounts_section'),
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.only(bottom: 4),
          leading: ExcludeSemantics(
            child: Icon(
              Icons.archive_outlined,
              color: ColorsUI.getTextSecondary(brightness),
            ),
          ),
          title: Text(
            'Αρχειοθετημένοι (${archivedAccounts.length})',
            style: TypographyUI.titleSmall(brightness),
          ),
          subtitle: Text(
            'Μετράνε στο σύνολο · δεν εμφανίζονται στις επιλογές',
            style: TypographyUI.labelSmall(
              brightness,
            ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
          ),
          children: [
            for (final account in archivedAccounts)
              _buildArchivedTile(brightness, account),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedTile(Brightness brightness, AccountModel account) {
    final archivedAt = account.archivedAt;
    final archivedText = archivedAt == null
        ? ''
        : ' · Αρχειοθετήθηκε: ${_formatShortDate(archivedAt)}';
    final balanceText = CurrencyFormatter.format(
      account.currentBalance,
      currency: account.currency,
    );

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        account.name,
        style: TypographyUI.bodyMedium(
          brightness,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${_accountTypeLabel(account.accountType)} · $balanceText$archivedText',
        style: TypographyUI.labelSmall(
          brightness,
        ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
      ),
      trailing: SizedBox(
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
      onTap: () => _showAccountInfo(context, account),
    );
  }

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildAccountCard(Brightness brightness, AccountModel account) {
    final isExcluded = context.read<AccountsProvider>().isExcludedFromTotal(
      account.uuid,
    );

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
