// ============================================================
// FILE: transaction_entry_page.dart
// VERSION: Firebase Migration
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/presentation/screens/transactions/transaction_entry_state.dart';
import 'package:family_economy/presentation/screens/transactions/transaction_entry_accounts_step.dart';
import 'package:family_economy/presentation/screens/transactions/transaction_entry_details_step.dart';

import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/providers/categories_provider.dart';

import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/utils/debug_config.dart';

class TransactionEntryPage extends StatelessWidget {
  const TransactionEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TransactionEntryState(),
      child: const _TransactionEntryView(),
    );
  }
}

class _TransactionEntryView extends StatelessWidget {
  const _TransactionEntryView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionEntryState>();
    final brightness = Theme.of(context).brightness;

    return PopScope(
      canPop: state.currentStep == EntryStep.type && state.kind == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Αν δεν είμαστε στην αρχή, πήγαινε πίσω ένα step
          if (state.currentStep != EntryStep.type || state.kind != null) {
            DebugConfig.print('🔙 Back button pressed - going back one step');
            DebugConfig.print('   Current step: ${state.currentStep}');

            if (state.currentStep == EntryStep.details) {
              if (state.isTransfer) {
                state.goBackTo(EntryStep.account);
              } else {
                state.goBackTo(EntryStep.subcategory);
              }
            } else if (state.currentStep == EntryStep.subcategory) {
              state.goBackTo(EntryStep.category);
            } else if (state.currentStep == EntryStep.category) {
              state.goBackTo(EntryStep.account);
            } else if (state.currentStep == EntryStep.account) {
              state.goBackTo(EntryStep.type);
            } else if (state.kind != null) {
              state.resetAll();
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: ColorsUI.getBackground(brightness),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                _SelectionBreadcrumbs(),

                const SizedBox(height: 14),

                if (state.currentStep == EntryStep.type)
                  const _TransactionTypeSelector(),

                if (state.currentStep == EntryStep.account)
                  Builder(
                    builder: (context) {
                      final accountsProvider = context
                          .watch<AccountsProvider>();

                      if (accountsProvider.isLoading) {
                        return Semantics(
                          liveRegion: true,
                          label: 'Φόρτωση λογαριασμών. Παρακαλώ περιμένετε.',
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: ExcludeSemantics(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                        );
                      }

                      if (accountsProvider.error != null) {
                        AccessibilityService.announceAssertive(
                          'Σφάλμα φόρτωσης λογαριασμών',
                        );
                        return Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Σφάλμα: ${accountsProvider.error}',
                              style: TypographyUI.bodyMedium(brightness),
                            ),
                          ),
                        );
                      }

                      return TransactionEntryAccountsStep(
                        accounts: accountsProvider.accounts,
                      );
                    },
                  ),

                if (state.currentStep == EntryStep.category ||
                    state.currentStep == EntryStep.subcategory ||
                    state.currentStep == EntryStep.details)
                  Builder(
                    builder: (context) {
                      final categoriesProvider = context
                          .watch<CategoriesProvider>();

                      if (categoriesProvider.isLoading) {
                        return Semantics(
                          liveRegion: true,
                          label: 'Φόρτωση κατηγοριών. Παρακαλώ περιμένετε.',
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: ExcludeSemantics(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                        );
                      }

                      if (categoriesProvider.error != null) {
                        return Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Σφάλμα: ${categoriesProvider.error}',
                              style: TypographyUI.bodyMedium(brightness),
                            ),
                          ),
                        );
                      }

                      final type = state.isIncome ? 'income' : 'expense';
                      final categories = categoriesProvider.getCategoriesByType(
                        type,
                      );

                      return TransactionEntryDetailsStep(
                        categories: categories,
                        categoriesProvider: categoriesProvider,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionBreadcrumbs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionEntryState>();
    final brightness = Theme.of(context).brightness;

    if (state.currentStep == EntryStep.type && state.kind == null) {
      return const SizedBox.shrink();
    }

    Widget chip({
      required String text,
      required VoidCallback onTap,
      required String semanticLabel,
      required Color chipColor,
    }) {
      return AccessibilityService.accessibleButton(
        label: semanticLabel,
        hint: 'Επιστροφή σε αυτό το βήμα',
        onPressed: onTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: chipColor.withValues(
                alpha: brightness == Brightness.light ? 0.15 : 0.25,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: chipColor.withValues(
                  alpha: brightness == Brightness.light ? 0.5 : 0.7,
                ),
                width: 1.5,
              ),
            ),
            child: ExcludeSemantics(
              child: Text(
                text,
                style: TypographyUI.bodySmall(brightness).copyWith(
                  color: brightness == Brightness.light
                      ? chipColor.withValues(alpha: 0.9)
                      : chipColor.withValues(alpha: 1.0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final items = <Widget>[];

    if (state.kind != null) {
      final kindLabel = state.isIncome
          ? 'Έσοδο'
          : state.isExpense
          ? 'Έξοδο'
          : 'Μεταφορά';

      items.add(
        chip(
          text: kindLabel,
          semanticLabel: 'Επιστροφή στην επιλογή τύπου κίνησης',
          onTap: () => state.goBackTo(EntryStep.type),
          chipColor: state.isIncome
              ? ColorsUI.getIncomeColor(brightness)
              : state.isExpense
              ? ColorsUI.getExpenseColor(brightness)
              : ColorsUI.getTransferColor(brightness),
        ),
      );
    }

    if (state.selectedAccountName != null) {
      items.add(const SizedBox(width: 8));
      items.add(
        chip(
          text: state.selectedAccountName!,
          semanticLabel: 'Επιστροφή στην επιλογή λογαριασμού',
          onTap: () {
            if (state.isTransfer) {
              state.goBackToAccountForTransfer(resetSource: true);
            } else {
              state.goBackTo(EntryStep.account);
            }
          },
          chipColor: ColorsUI.getSuccess(brightness),
        ),
      );
    }

    if (state.isTransfer && state.selectedTargetAccountName != null) {
      items.add(const SizedBox(width: 8));
      items.add(
        chip(
          text: state.selectedTargetAccountName!,
          semanticLabel: 'Επιστροφή στην επιλογή λογαριασμού προορισμού',
          onTap: () {
            state.goBackToAccountForTransfer(resetSource: false);
          },
          chipColor: ColorsUI.getSuccess(brightness).withValues(alpha: 0.7),
        ),
      );
    }

    if (state.selectedCategoryName != null) {
      items.add(const SizedBox(width: 8));
      items.add(
        chip(
          text: state.selectedCategoryName!,
          semanticLabel: 'Επιστροφή στην επιλογή κατηγορίας',
          onTap: () => state.goBackTo(EntryStep.category),
          chipColor: ColorsUI.getPrimary(brightness),
        ),
      );
    }

    if (state.selectedSubcategoryName != null) {
      items.add(const SizedBox(width: 8));
      items.add(
        chip(
          text: state.selectedSubcategoryName!,
          semanticLabel: 'Επιστροφή στην επιλογή υποκατηγορίας',
          onTap: () => state.goBackTo(EntryStep.subcategory),
          chipColor: ColorsUI.getWarning(brightness),
        ),
      );
    }

    return Semantics(
      container: true,
      label: 'Επιλεγμένα βήματα. Πατήστε για επιστροφή.',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: items),
      ),
    );
  }
}

class _TransactionTypeSelector extends StatelessWidget {
  const _TransactionTypeSelector();

  @override
  Widget build(BuildContext context) {
    final state = context.read<TransactionEntryState>();
    final brightness = Theme.of(context).brightness;
    final media = MediaQuery.of(context);

    final double size = media.size.width < 400 ? 56 : 64;
    final double iconSize = media.size.width < 400 ? 28 : 32;

    return Semantics(
      container: true,
      label: 'Επιλογή είδους κίνησης',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TypeButton(
            color: ColorsUI.getIncomeColor(brightness),
            icon: Icons.add,
            semanticLabel: 'Εισαγωγή Εσόδου',
            size: size,
            iconSize: iconSize,
            onTap: () {
              AccessibilityService.announcePolite('Επιλέχθηκε εισαγωγή εσόδου');
              state.selectTransactionKind(TransactionKind.income);
            },
          ),
          const SizedBox(width: 80),
          _TypeButton(
            color: ColorsUI.getExpenseColor(brightness),
            icon: Icons.add,
            semanticLabel: 'Εισαγωγή Εξόδου',
            size: size,
            iconSize: iconSize,
            onTap: () {
              AccessibilityService.announcePolite('Επιλέχθηκε εισαγωγή εξόδου');
              state.selectTransactionKind(TransactionKind.expense);
            },
          ),
          const SizedBox(width: 80),
          _TypeButton(
            color: ColorsUI.getTransferColor(brightness),
            icon: Icons.swap_horiz,
            semanticLabel: 'Μεταφορά ποσού',
            size: size,
            iconSize: iconSize,
            onTap: () {
              AccessibilityService.announcePolite('Επιλέχθηκε μεταφορά ποσού');
              state.selectTransactionKind(TransactionKind.transfer);
            },
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String semanticLabel;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _TypeButton({
    required this.color,
    required this.icon,
    required this.semanticLabel,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AccessibilityService.accessibleButton(
      label: semanticLabel,
      hint: 'Επιλέξτε',
      onPressed: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: ExcludeSemantics(
              child: Icon(icon, size: iconSize, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
