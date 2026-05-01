// ============================================================
// FILE: category_type_selector_dialog.dart
// Path: lib/presentation/dialogs/category_type_selector_dialog.dart
// Ρόλος: Popup επιλογής τύπου κατηγοριών (Εσόδων/Εξόδων)
// ============================================================

import 'package:flutter/material.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';

class CategoryTypeSelectorDialog extends StatefulWidget {
  const CategoryTypeSelectorDialog({super.key});

  @override
  State<CategoryTypeSelectorDialog> createState() => _CategoryTypeSelectorDialogState();
}

class _CategoryTypeSelectorDialogState extends State<CategoryTypeSelectorDialog> {

  @override
  void initState() {
    super.initState();
    // ✅ Ανακοινώνουμε τις διαθέσιμες επιλογές μετά το πρώτο frame
    // ώστε ο screen reader να έχει χτίσει πλήρως το semantics tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AccessibilityService.announceAfterFirstFrame(
        context,
        'Επιλέξτε τύπο κατηγοριών: Εσόδων ή Εξόδων',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header + subtitle merged
              MergeSemantics(
                child: Column(
                  children: [
                    Semantics(
                      header: true,
                      label: 'Διαχείριση Κατηγοριών',
                      excludeSemantics: true,
                      child: Text(
                        'Διαχείριση Κατηγοριών',
                        style: context.h3,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      label: 'Επιλέξτε τύπο κατηγοριών',
                      excludeSemantics: true,
                      child: Text(
                        'Επιλέξτε τύπο κατηγοριών',
                        style: context.bodyMd.copyWith(color: context.cText2),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Income Button (Πράσινο)
              AccessibilityService.accessibleButton(
                label: 'Διαχείριση Κατηγοριών Εσόδων',
                hint:
                    'Πατήστε για να δείτε και να επεξεργαστείτε τις κατηγορίες εσόδων',
                onPressed: () {
                  AccessibilityService.announcePolite(
                    'Άνοιξαν οι κατηγορίες εσόδων',
                  );
                  Navigator.of(context).pop('income');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ColorsUI.getIncomeColor(context.brightness),
                        ColorsUI.getIncomeColor(
                          context.brightness,
                        ).withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: ColorsUI.getIncomeColor(
                          context.brightness,
                        ).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.trending_up_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Εσόδων',
                        style: context.titleLg.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Expense Button (Κόκκινο)
              AccessibilityService.accessibleButton(
                label: 'Διαχείριση Κατηγοριών Εξόδων',
                hint:
                    'Πατήστε για να δείτε και να επεξεργαστείτε τις κατηγορίες εξόδων',
                onPressed: () {
                  AccessibilityService.announcePolite(
                    'Άνοιξαν οι κατηγορίες εξόδων',
                  );
                  Navigator.of(context).pop('expense');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ColorsUI.getExpenseColor(context.brightness),
                        ColorsUI.getExpenseColor(
                          context.brightness,
                        ).withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: ColorsUI.getExpenseColor(
                          context.brightness,
                        ).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.trending_down_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Εξόδων',
                        style: context.titleLg.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Cancel Button
              Semantics(
                hint: 'Κλείνει το dialog χωρίς καμία επιλογή',
                child: TextButton(
                  onPressed: () {
                    AccessibilityService.announcePolite('Ακυρώθηκε η επιλογή');
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Ακύρωση',
                    style: context.bodyMd.copyWith(
                      color: context.cText2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
