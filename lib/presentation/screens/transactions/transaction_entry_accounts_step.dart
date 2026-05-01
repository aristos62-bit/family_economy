// ============================================================
// FILE: transaction_entry_accounts_step.dart
// VERSION: Firebase Migration - AccountModel
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/presentation/screens/transactions/transaction_entry_state.dart';
import 'package:family_economy/providers/accounts_provider.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/utils/icon_mapper.dart';

class TransactionEntryAccountsStep extends StatelessWidget {
  final List<AccountModel> accounts;

  const TransactionEntryAccountsStep({
    super.key,
    required this.accounts,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionEntryState>();
    final brightness = Theme.of(context).brightness;

    if (state.currentStep != EntryStep.account) {
      return const SizedBox.shrink();
    }

    final isTransfer = state.isTransfer;
    final hasSourceAccount = state.selectedAccountUuid != null;

    final visibleAccounts = isTransfer && hasSourceAccount
        ? accounts.where((a) => a.uuid != state.selectedAccountUuid).toList()
        : accounts;

    final width = MediaQuery.of(context).size.width;
    final double maxExtent = width < 420 ? 120 : (width < 900 ? 140 : 160);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),

        Semantics(
          header: true,
          child: Text(
            _getTitle(state),
            style: TypographyUI.titleMedium(brightness),
          ),
        ),

        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleAccounts.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final account = visibleAccounts[index];

            final String uuid = account.uuid;
            final String name = account.name;
            final int? iconIndex = account.iconIndex;

            final bool isSelected = uuid == state.selectedAccountUuid;

            return AccessibilityService.accessibleButton(
              label: name,
              hint: isSelected
                  ? 'Επιλεγμένος λογαριασμός'
                  : 'Επιλογή λογαριασμού',
              onPressed: () {
                if (isTransfer && hasSourceAccount) {
                  state.selectTargetAccount(uuid, name);
                  AccessibilityService.announcePolite(
                    'Επιλέχθηκε λογαριασμός προορισμού $name',
                  );
                } else {
                  state.selectAccount(uuid, name);
                  AccessibilityService.announcePolite(
                    'Επιλέχθηκε λογαριασμός $name',
                  );
                }
              },
              child: _AccountTile(
                name: name,
                iconIndex: iconIndex,
                isSelected: isSelected,
                onTap: () {
                  if (isTransfer && hasSourceAccount) {
                    state.selectTargetAccount(uuid, name);
                    AccessibilityService.announcePolite(
                      'Επιλέχθηκε λογαριασμός προορισμού $name',
                    );
                  } else {
                    state.selectAccount(uuid, name);
                    AccessibilityService.announcePolite(
                      'Επιλέχθηκε λογαριασμός $name',
                    );
                  }
                },
              ),
            );
          },
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  String _getTitle(TransactionEntryState state) {
    if (!state.isTransfer) {
      return 'Επίλεξε λογαριασμό';
    }

    if (state.selectedAccountUuid == null) {
      return 'Από ποιο λογαριασμό θα γίνει η μεταφορά;';
    }

    return 'Σε ποιο λογαριασμό θα γίνει η μεταφορά;';
  }
}

class _AccountTile extends StatelessWidget {
  final String name;
  final int? iconIndex;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountTile({
    required this.name,
    required this.onTap,
    this.iconIndex,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final surfaceColor = ColorsUI.getSurface(brightness);
    final borderColor = ColorsUI.byBrightness(
      brightness: brightness,
      light: ColorsUI.borderLight,
      dark: ColorsUI.borderDark,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? ColorsUI.getPrimary(brightness).withValues(alpha: 0.15)
              : surfaceColor,
          border: Border.all(
            color: isSelected ? ColorsUI.getPrimary(brightness) : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Image.asset(
                IconMapper.getIconPath('account', iconIndex),
                width: 40,
                height: 40,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.account_balance_wallet,
                  size: 40,
                  color: ColorsUI.getPrimary(brightness),
                ),
              ),
            ),

            const SizedBox(height: 8),

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