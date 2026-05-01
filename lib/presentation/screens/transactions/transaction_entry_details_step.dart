// ============================================================
// FILE: transaction_entry_details_step.dart
// PART 1 OF 3 (Lines 1-316)
// Ρόλος: Categories, Subcategories, Details & Save
// VERSION: Firebase Migration - Fixed
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/presentation/screens/transactions/transaction_entry_state.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/utils/icon_mapper.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/widgets/custom_text_field.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/services/scheduled_transactions_service.dart';
import 'package:family_economy/core/services/transactions_actions_service.dart';
import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/core/widgets/custom_currency_field.dart';
import 'package:family_economy/core/widgets/tag_selector_widget.dart';

class TransactionEntryDetailsStep extends StatelessWidget {
  final List<CategoryModel> categories;
  final CategoriesProvider categoriesProvider;

  const TransactionEntryDetailsStep({
    super.key,
    required this.categories,
    required this.categoriesProvider,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionEntryState>();

    // ============================================================
    // TRANSFER → ΔΕΝ ΕΧΕΙ CATEGORIES / SUBCATEGORIES
    // ============================================================
    if (state.isTransfer && state.currentStep == EntryStep.details) {
      return const _TransferDetails();
    }

    // ============================================================
    // INCOME / EXPENSE FLOW
    // ============================================================

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ========================================================
        // STEP: CATEGORY
        // ========================================================
        if (state.currentStep == EntryStep.category)
          _CategoryGrid(categories: categories),

        // ========================================================
        // STEP: SUBCATEGORY
        // ========================================================
        if (state.currentStep == EntryStep.subcategory &&
            state.selectedCategoryUuid != null)
          _SubcategoryGrid(
            categoryUuid: state.selectedCategoryUuid!,
            categoriesProvider: categoriesProvider,
            actualCategoryType: state.isIncome ? 'income' : 'expense',
          ),

        // ========================================================
        // STEP: DETAILS
        // ========================================================
        if (state.currentStep == EntryStep.details && state.canEnterDetails)
          const _IncomeExpenseDetails(),
      ],
    );
  }
}

// ============================================================
// CATEGORY GRID
// ============================================================

class _CategoryGrid extends StatelessWidget {
  final List<CategoryModel> categories;

  const _CategoryGrid({required this.categories});

  @override
  Widget build(BuildContext context) {
    final state = context.read<TransactionEntryState>();
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            'Επίλεξε κατηγορία',
            style: TypographyUI.titleMedium(brightness),
          ),
        ),
        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getCrossAxisCount(context),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            final String uuid = category.uuid;
            final String name = category.name;
            final int? iconIndex = category.iconIndex;
            final String type = category.type;

            return AccessibilityService.accessibleButton(
              label: name,
              hint: 'Επιλογή κατηγορίας',
              onPressed: () {
                state.selectCategory(uuid, name);
                AccessibilityService.announcePolite('Επιλέχθηκε $name');
              },
              child: _SelectableTile(
                name: name,
                iconPath: IconMapper.getIconPath(
                  'category',
                  iconIndex,
                  categoryType: type,
                ),
                onTap: () {
                  state.selectCategory(uuid, name);
                  AccessibilityService.announcePolite('Επιλέχθηκε $name');
                },
              ),
            );
          },
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 900) return 5;
    if (width > 600) return 4;
    return 3;
  }
}

// ============================================================
// SUBCATEGORY GRID
// ============================================================

class _SubcategoryGrid extends StatelessWidget {
  final String categoryUuid;
  final CategoriesProvider categoriesProvider;
  final String actualCategoryType;

  const _SubcategoryGrid({
    required this.categoryUuid,
    required this.categoriesProvider,
    required this.actualCategoryType,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.read<TransactionEntryState>();
    final brightness = Theme.of(context).brightness;

    final subcategories = categoriesProvider.getSubcategoriesForCategory(
      categoryUuid,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Επίλεξε υποκατηγορία',
                style: TypographyUI.titleMedium(brightness),
              ),
            ),
            Semantics(
              button: true,
              label: 'Παράλειψη υποκατηγορίας',
              child: TextButton(
                onPressed: () {
                  state.selectSubcategory(null, null);
                  AccessibilityService.announcePolite(
                    'Παράλειψη υποκατηγορίας',
                  );
                },
                child: Text(
                  'Παράλειψη',
                  style: TypographyUI.bodyMedium(
                    brightness,
                  ).copyWith(color: ColorsUI.getPrimary(brightness)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (subcategories.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                'Δεν υπάρχουν υποκατηγορίες',
                style: TypographyUI.bodyMedium(brightness),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: subcategories.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getCrossAxisCount(context),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) {
              final subcategory = subcategories[index];
              final String uuid = subcategory.uuid;
              final String name = subcategory.name;
              final int? iconIndex = subcategory.iconIndex;

              return AccessibilityService.accessibleButton(
                label: name,
                hint: 'Επιλογή υποκατηγορίας',
                onPressed: () {
                  state.selectSubcategory(uuid, name);
                  AccessibilityService.announcePolite('Επιλέχθηκε $name');
                },
                child: _SelectableTile(
                  name: name,
                  iconPath: IconMapper.getIconPath(
                    'subcategory',
                    iconIndex,
                    categoryType: actualCategoryType,
                  ),
                  onTap: () {
                    state.selectSubcategory(uuid, name);
                    AccessibilityService.announcePolite('Επιλέχθηκε $name');
                  },
                ),
              );
            },
          ),

        const SizedBox(height: 8),
      ],
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 900) return 5;
    if (width > 600) return 4;
    return 3;
  }
}

// ============================================================
// INCOME/EXPENSE DETAILS
// ============================================================

class _IncomeExpenseDetails extends StatelessWidget {
  const _IncomeExpenseDetails();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const _AccountBalanceCard(),
        const SizedBox(height: 12),
        const _DateSelector(),
        const SizedBox(height: 16),
        const _AmountField(),
        const SizedBox(height: 16),
        const _NotesField(),
        const SizedBox(height: 16),
        const _TagsSection(),
        const SizedBox(height: 24),
        _SaveButton(onSaveStart: () {}, onSaveComplete: () {}),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ============================================================
// TRANSFER DETAILS
// ============================================================

class _TransferDetails extends StatelessWidget {
  const _TransferDetails();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const _AccountBalanceCard(),
        const SizedBox(height: 12),
        const _DateSelector(),
        const SizedBox(height: 16),
        const _AmountField(),
        const SizedBox(height: 16),
        const _NotesField(),
        const SizedBox(height: 16),
        const _TagsSection(),
        const SizedBox(height: 24),
        _SaveButton(onSaveStart: () {}, onSaveComplete: () {}),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AccountBalanceCard extends StatelessWidget {
  const _AccountBalanceCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionEntryState>();
    final accountsProvider = context.watch<AccountsProvider>();
    final brightness = Theme.of(context).brightness;

    final accountUuid = state.selectedAccountUuid;
    final account = (accountUuid == null)
        ? null
        : accountsProvider.getAccountByUuid(accountUuid);

    // Αν δεν έχει επιλεγεί ακόμα account ή δεν βρέθηκε, μην δείχνεις τίποτα
    if (account == null) return const SizedBox.shrink();

    final balance = account.currentBalance;

    return Semantics(
      label:
          'Υπόλοιπο λογαριασμού ${account.name}: ${CurrencyFormatter.format(balance)}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ColorsUI.getSurface(brightness),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorsUI.getBorder(brightness)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: ColorsUI.getPrimary(brightness),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Υπόλοιπο λογαριασμού',
                      style: TypographyUI.labelLarge(brightness),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(balance),
                      style: TypographyUI.titleMedium(brightness),
                    ),
                  ],
                ),
              ),
              Text(
                account.name,
                style: TypographyUI.bodySmall(brightness),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DATE SELECTOR
// ============================================================

class _DateSelector extends StatelessWidget {
  const _DateSelector();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionEntryState>();
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text('Ημερομηνία', style: TypographyUI.labelLarge(brightness)),
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label:
              'Ημερομηνία: ${state.selectedDate.day}/${state.selectedDate.month}/${state.selectedDate.year}. Πατήστε για αλλαγή.',
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: state.selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                locale: const Locale('el', 'GR'),
              );

              if (picked != null) {
                state.selectedDate = picked;
                AccessibilityService.announcePolite(
                  'Επιλέχθηκε ημερομηνία: ${picked.day}/${picked.month}/${picked.year}',
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ColorsUI.getInputFill(brightness),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorsUI.getInputBorder(brightness)),
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.calendar_today,
                      color: ColorsUI.getPrimary(brightness),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ExcludeSemantics(
                    child: Text(
                      '${state.selectedDate.day}/${state.selectedDate.month}/${state.selectedDate.year}',
                      style: TypographyUI.bodyMedium(brightness),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
// ✂️ PART 2 OF 3 (Lines 317-632)
// Continue from PART 1 - paste this directly below PART 1

// ============================================================
// AMOUNT FIELD
// ============================================================
class _AmountField extends StatefulWidget {
  const _AmountField();

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionEntryState>();
    final brightness = Theme.of(context).brightness;

    // ✅ Sync UI όταν γίνει resetAll
    if (state.amount == null && _controller.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.clear();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ποσό', style: TypographyUI.labelLarge(brightness)),
        const SizedBox(height: 8),

        CustomCurrencyField(
          controller: _controller,
          label: null,
          hint: '0,00',
          required: true,
          allowNegative: false,

          // ✅ Το state ενημερώνεται από το field
          onChanged: (value) {
            state.amount = value;
          },

          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

// ============================================================
// NOTES FIELD
// ============================================================

class _NotesField extends StatefulWidget {
  const _NotesField();

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionEntryState>();

    // ✅ Αν έγινε resetAll (notes=null), άδειασε οπτικά το πεδίο
    if (state.notes == null && _controller.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.clear();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        CustomTextField(
          controller: _controller,
          label: 'Προσθέστε σημειώσεις',
          maxLines: 3,
          onChanged: (value) {
            state.notes = value.trim().isEmpty ? null : value.trim();
          },
        ),
      ],
    );
  }
}

// ============================================================
// SAVE BUTTON
// ============================================================

class _SaveButton extends StatelessWidget {
  final VoidCallback onSaveStart;
  final VoidCallback onSaveComplete;

  const _SaveButton({required this.onSaveStart, required this.onSaveComplete});

  @override
  Widget build(BuildContext context) {
    final state = context.read<TransactionEntryState>();

    return SizedBox(
      width: double.infinity,
      child: Semantics(
        button: true,
        label: 'Αποθήκευση κίνησης',
        child: ElevatedButton(
          onPressed: () async {
            // ============================================================
            // VALIDATION
            // ============================================================
            if (state.amount == null || state.amount! <= 0) {
              AccessibilityService.announceError('Συμπληρώστε το ποσό');
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Παρακαλώ συμπληρώστε το ποσό'),
                    backgroundColor: Colors.red,
                  ),
                );
              return;
            }

            // ✅ Validation για required επιλογές
            if (state.isTransfer && state.selectedTargetAccountUuid == null) {
              AccessibilityService.announceError(
                'Επιλέξτε λογαριασμό προορισμού',
              );
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Παρακαλώ επιλέξτε λογαριασμό προορισμού'),
                    backgroundColor: Colors.red,
                  ),
                );
              return;
            }

            if (!state.isTransfer && state.selectedCategoryUuid == null) {
              AccessibilityService.announceError('Επιλέξτε κατηγορία');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Παρακαλώ επιλέξτε κατηγορία'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            // ============================================================
            // ✅ BALANCE CHECK (NO NEGATIVE BALANCE ALLOWED)
            // ============================================================
            final accProvider = context.read<AccountsProvider>();
            final sourceAcc = accProvider.getAccountByUuid(
              state.selectedAccountUuid!,
            );

            if (sourceAcc != null) {
              final currentBalance = sourceAcc.currentBalance;
              final amountToCheck = state.amount!.abs();

              if ((state.isExpense || state.isTransfer) &&
                  amountToCheck > currentBalance) {
                AccessibilityService.announceError('Το υπόλοιπο δεν επαρκεί');
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Το υπόλοιπο δεν επαρκεί'),
                      backgroundColor: Colors.red,
                    ),
                  );
                return;
              }
            }

            // ✅ SNAPSHOT values BEFORE dialog
            final isTransferSnap = state.isTransfer;
            final isIncomeSnap = state.isIncome;
            final userIdSnap = context.session.userId;
            final currencySnap = context.session.defaultCurrency;
            final accountUuidSnap = state.selectedAccountUuid!;
            final targetAccountUuidSnap = state.selectedTargetAccountUuid;
            final categoryUuidSnap = state.selectedCategoryUuid;
            final subcategoryUuidSnap = state.selectedSubcategoryUuid;
            final amountSnap = state.amount!;
            final dateSnap = state.selectedDate;
            final notesSnap = state.notes;
            final tagIdsSnap = List<String>.from(state.selectedTagIds);

            // ============================================================
            // GET DATA
            // ============================================================
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final selectedDay = DateTime(
              state.selectedDate.year,
              state.selectedDate.month,
              state.selectedDate.day,
            );

            // ✅ Future date handling - ΔΙΟΡΘΩΜΕΝΟΣ
            if (selectedDay.isAfter(today)) {
              DebugConfig.print(
                '📅 Future date detected - showing schedule dialog',
              );

              // ============================================================
              // ✅ BALANCE CHECK for SCHEDULED choice too (no negative balance)
              // ============================================================
              final accProvider = context.read<AccountsProvider>();
              final sourceAcc = accProvider.getAccountByUuid(accountUuidSnap);

              if (sourceAcc != null) {
                final currentBalance = sourceAcc.currentBalance;
                final amountToCheck = amountSnap.abs();

                if ((isTransferSnap || (!isIncomeSnap && !isTransferSnap)) &&
                    amountToCheck > currentBalance) {
                  AccessibilityService.announceError('Το υπόλοιπο δεν επαρκεί');
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Το υπόλοιπο δεν επαρκεί'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  return;
                }
              }

              final scheduleChoice = await _showScheduleTransactionDialog(
                context,
                state.selectedDate,
                state.isIncome
                    ? 'income'
                    : state.isExpense
                    ? 'expense'
                    : 'transfer',
                amountSnap,
              );

              DebugConfig.print('👉 Schedule choice: $scheduleChoice');

              // ✅ ΔΙΟΡΘΩΣΗ: User cancelled
              if (scheduleChoice == null) {
                DebugConfig.print('❌ User cancelled - resetting immediately');
                if (!context.mounted) return;

                state.resetAll();
                AccessibilityService.announcePolite('Η εισαγωγή ακυρώθηκε');
                return;
              }

              // ✅ ΔΙΟΡΘΩΣΗ: Scheduled transaction
              // ✅ ΔΙΟΡΘΩΣΗ: Scheduled transaction
              if (scheduleChoice == ScheduleChoice.scheduled) {
                DebugConfig.print('📅 Scheduling (UI first)...');

                // 1) UI first: reset άμεσα
                state.resetAll();

                // 2) Snack άμεσα
                if (context.mounted) {
                  final brightness = Theme.of(context).brightness;
                  final successColor = brightness == Brightness.light
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF81C784);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Η κίνηση προγραμματίστηκε για ${dateSnap.day}/${dateSnap.month}/${dateSnap.year}'
                        '${ /* προαιρετικό */ ''}',
                      ),
                      backgroundColor: successColor,
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }

                // 3) Save στο background (δεν μπλοκάρει το return)
                () async {
                  try {
                    await _saveScheduledTransaction(
                      context: context,
                      userId: userIdSnap,
                      isTransfer: isTransferSnap,
                      isIncome: isIncomeSnap,
                      accountUuid: accountUuidSnap,
                      targetAccountUuid: targetAccountUuidSnap,
                      categoryUuid: categoryUuidSnap,
                      subcategoryUuid: subcategoryUuidSnap,
                      amount: amountSnap,
                      date: dateSnap,
                      notes: notesSnap,
                      currency: currencySnap,
                    ).timeout(
                      const Duration(seconds: 3),
                      onTimeout: () {
                        DebugConfig.print(
                          '⏱️ Save timeout - offline mode detected',
                        );
                      },
                    );
                    DebugConfig.print('✅ Scheduled save queued/completed');
                  } catch (e) {
                    DebugConfig.print('⌛ Scheduled save queued (offline): $e');
                  }
                }();

                return;
              }

              // scheduleChoice == ScheduleChoice.immediate
              DebugConfig.print(
                '⚡ Continuing with immediate save (future date)',
              );
            }

            // ============================================================
            // ✅ UI FIRST (ONLINE / OFFLINE)
            // ============================================================
            DebugConfig.print('💾 Saving immediate transaction...');
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Η κίνηση αποθηκεύτηκε'),
                backgroundColor: ColorsUI.getSuccess(
                  Theme.of(context).brightness,
                ),
              ),
            );

            AccessibilityService.announceSuccess('Η κίνηση αποθηκεύτηκε');
            if (!context.mounted) return;

            // ✅ RESET UI ΑΜΕΣΩΣ
            DebugConfig.print('🔄 Resetting state after immediate save');
            state.resetAll();

            // ============================================================
            // ✅ BACKGROUND SAVE (ΔΕΝ ΜΠΛΟΚΑΡΕΙ)
            // ✅ One source of truth: TransactionsActionsService
            // ============================================================
            () async {
              try {
                final type = isTransferSnap
                    ? 'transfer'
                    : (isIncomeSnap ? 'income' : 'expense');

                await TransactionsActionsService().create(
                  userId: userIdSnap,
                  transactionType: type,
                  date: dateSnap,
                  amountAbs: amountSnap.abs(),
                  currency: currencySnap,
                  accountUuid: accountUuidSnap,
                  targetAccountUuid: targetAccountUuidSnap,
                  categoryUuid: categoryUuidSnap,
                  subcategoryUuid: subcategoryUuidSnap,
                  notes: notesSnap,
                  tagIds: tagIdsSnap,
                );

                DebugConfig.print(
                  '✅ Transaction saved in background (actions service)',
                );
              } catch (e) {
                DebugConfig.print('⌛ Background save queued (offline): $e');
              }
            }();
          },

          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Αποθήκευση',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAGS SECTION (για χρήση μέσα στο Details step)
// ============================================================

class _TagsSection extends StatelessWidget {
  const _TagsSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionEntryState>();
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Divider(color: ColorsUI.getDivider(brightness), height: 1),
        ),
        const SizedBox(height: 12),
        TagSelectorWidget(
          selectedTagIds: state.selectedTagIds,
          onChanged: (ids) => state.setSelectedTagIds(ids),
          allowCreate: true,
        ),
      ],
    );
  }
}
// ============================================================
// SCHEDULE TRANSACTION DIALOG
// ============================================================

enum ScheduleChoice { scheduled, immediate }

Future<ScheduleChoice?> _showScheduleTransactionDialog(
  BuildContext context,
  DateTime date,
  String transactionType,
  double amount,
) async {
  final brightness = Theme.of(context).brightness;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final selectedDay = DateTime(date.year, date.month, date.day);
  final daysAhead = selectedDay.difference(today).inDays;

  String typeLabel;
  Color typeColor;
  IconData typeIcon;

  switch (transactionType) {
    case 'income':
      typeLabel = 'Έσοδο';
      typeColor = brightness == Brightness.light
          ? const Color(0xFF2E7D32)
          : const Color(0xFF81C784);
      typeIcon = Icons.add_circle;
      break;
    case 'expense':
      typeLabel = 'Έξοδο';
      typeColor = brightness == Brightness.light
          ? const Color(0xFFC62828)
          : const Color(0xFFE57373);
      typeIcon = Icons.remove_circle;
      break;
    case 'transfer':
      typeLabel = 'Μεταφορά';
      typeColor = brightness == Brightness.light
          ? const Color(0xFF0277BD)
          : const Color(0xFF64B5F6);
      typeIcon = Icons.swap_horiz;
      break;
    default:
      typeLabel = 'Κίνηση';
      typeColor = brightness == Brightness.light
          ? const Color(0xFF6750A4)
          : const Color(0xFFD0BCFF);
      typeIcon = Icons.receipt;
  }

  final result = await showDialog<ScheduleChoice>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          ExcludeSemantics(
            child: Icon(Icons.event_available, color: typeColor, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              header: true,
              child: Text('Προγραμματισμός Κίνησης'),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Επιλέξατε μελλοντική ημερομηνία:',
              style: TextStyle(
                fontSize: 15,
                color: brightness == Brightness.light
                    ? const Color(0xFF1C1B1F)
                    : const Color(0xFFE6E1E5),
              ),
            ),
            const SizedBox(height: 16),

            // Date card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: typeColor, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(typeIcon, color: typeColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '€${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: typeColor.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ExcludeSemantics(
                        child: Icon(Icons.calendar_today, color: typeColor, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'σε $daysAhead ${daysAhead == 1 ? 'ημέρα' : 'ημέρες'}',
                    style: TextStyle(fontSize: 12, color: typeColor),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Options explanation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (brightness == Brightness.light
                            ? const Color(0xFF0277BD)
                            : const Color(0xFF64B5F6))
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      (brightness == Brightness.light
                              ? const Color(0xFF0277BD)
                              : const Color(0xFF64B5F6))
                          .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.info_outline,
                          color: brightness == Brightness.light
                              ? const Color(0xFF0277BD)
                              : const Color(0xFF64B5F6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Επιλέξτε τρόπο εκτέλεσης:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: brightness == Brightness.light
                              ? const Color(0xFF0277BD)
                              : const Color(0xFF64B5F6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildOption(
                    brightness,
                    icon: Icons.schedule,
                    title: 'Προγραμματισμός',
                    description:
                        'Η κίνηση θα εκτελεστεί αυτόματα την προγραμματισμένη ημερομηνία. Τα υπόλοιπα θα ενημερωθούν τότε.',
                  ),
                  const SizedBox(height: 8),
                  _buildOption(
                    brightness,
                    icon: Icons.flash_on,
                    title: 'Άμεση Εκτέλεση',
                    description:
                        'Η κίνηση θα καταχωρηθεί τώρα με μελλοντική ημερομηνία. Τα υπόλοιπα θα ενημερωθούν αμέσως.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Cancel
        TextButton(
          onPressed: () {
            DebugConfig.print('❌ User clicked Cancel in schedule dialog');
            Navigator.pop(dialogContext);
          },
          child: const Text('Ακύρωση'),
        ),

        // Immediate
        TextButton.icon(
          onPressed: () {
            DebugConfig.print('⚡ User clicked Immediate in schedule dialog');
            Navigator.pop(dialogContext, ScheduleChoice.immediate);
          },
          icon: const ExcludeSemantics(
            child: Icon(Icons.flash_on, size: 20),
          ),
          label: const Text('Άμεση'),
        ),

        ElevatedButton.icon(
          onPressed: () {
            DebugConfig.print('📅 User clicked Schedule in schedule dialog');
            Navigator.pop(dialogContext, ScheduleChoice.scheduled);
          },
          icon: const ExcludeSemantics(
            child: Icon(Icons.schedule, size: 20),
          ),
          label: const Text('Προγραμματισμός'),
          style: ElevatedButton.styleFrom(
            backgroundColor: typeColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );

  return result;
}

Widget _buildOption(
  Brightness brightness, {
  required IconData icon,
  required String title,
  required String description,
}) {
  final textColor = brightness == Brightness.light
      ? const Color(0xFF49454F)
      : const Color(0xFFCAC4D0);

  return Semantics(
    label: '$title. $description',
    child: ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 12, color: textColor)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
// SAVE SCHEDULED TRANSACTION
// ============================================================

Future<void> _saveScheduledTransaction({
  required BuildContext context,
  required String userId,
  required bool isTransfer,
  required bool isIncome,
  required String accountUuid,
  String? targetAccountUuid,
  String? categoryUuid,
  String? subcategoryUuid,
  required double amount,
  required DateTime date,
  String? notes,
  required String currency,
}) async {
  final scheduledService = ScheduledTransactionsService();

  try {
    if (isTransfer) {
      if (targetAccountUuid == null) {
        throw Exception('Target account is required for transfers');
      }

      await scheduledService.createScheduledTransfer(
        userId: userId,
        sourceAccountUuid: accountUuid,
        targetAccountUuid: targetAccountUuid,
        amount: amount,
        scheduledDate: date,
        notes: notes,
        currency: currency,
      );
    } else {
      if (categoryUuid == null) {
        throw Exception('Category is required for transactions');
      }

      await scheduledService.createScheduledTransaction(
        userId: userId,
        accountUuid: accountUuid,
        categoryUuid: categoryUuid,
        subcategoryUuid: subcategoryUuid,
        amount: amount,
        transactionType: isIncome ? 'income' : 'expense',
        scheduledDate: date,
        notes: notes,
        currency: currency,
      );
    }

    DebugConfig.print('✅ Scheduled transaction saved successfully');
  } catch (e) {
    DebugConfig.print('❌ Error saving scheduled transaction: $e');
    rethrow;
  }
}

// ============================================================
// SELECTABLE TILE (Reusable for Categories & Subcategories)
// ============================================================

class _SelectableTile extends StatelessWidget {
  final String name;
  final String iconPath;
  final VoidCallback onTap;

  const _SelectableTile({
    required this.name,
    required this.iconPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ColorsUI.getSurface(brightness),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorsUI.getBorder(brightness)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            ExcludeSemantics(
              child: Image.asset(
                iconPath,
                width: 48,
                height: 48,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.category,
                    size: 48,
                    color: ColorsUI.getPrimary(brightness),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Name
            ExcludeSemantics(
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: TypographyUI.bodySmall(brightness),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// END OF FILE
// ============================================================
