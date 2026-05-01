// ============================================================
// FILE: category_actions_dialog.dart
// Path: lib/presentation/dialogs/category_actions_dialog.dart
// Ρόλος: Popup ενεργειών (Επεξεργασία/Διαγραφή/Ακύρωση)
// ============================================================

import 'package:flutter/material.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';

class CategoryActionsDialog extends StatelessWidget {
  final String title;
  final bool canDelete;

  const CategoryActionsDialog({
    super.key,
    required this.title,
    this.canDelete = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Ενέργειες για "$title"',
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
              // Header με εικονίδιο
              ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.cPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 48,
                    color: context.cPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Title
              Semantics(
                header: true,
                child: Text(
                  'Ενέργειες για "$title"',
                  style: context.titleLg,
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // Επεξεργασία Button
              AccessibilityService.accessibleButton(
                label: 'Επεξεργασία',
                hint: 'Πατήστε για να επεξεργαστείτε το όνομα και το εικονίδιο',
                onPressed: () {
                  AccessibilityService.announcePolite('Άνοιξε η επεξεργασία');
                  Navigator.of(context).pop('edit');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: context.cPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.cPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        color: context.cPrimary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Επεξεργασία',
                        style: context.titleMd.copyWith(
                          color: context.cPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Διαγραφή Button (conditionally shown)
              if (canDelete)
                AccessibilityService.accessibleButton(
                  label: 'Διαγραφή',
                  hint:
                      'Πατήστε για να διαγράψετε οριστικά. Προσοχή: Η ενέργεια δεν μπορεί να αναιρεθεί',
                  onPressed: () {
                    AccessibilityService.announceAssertive(
                      'Επιλέχθηκε διαγραφή',
                    );
                    Navigator.of(context).pop('delete');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: ColorsUI.getError(
                        context.brightness,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ColorsUI.getError(
                          context.brightness,
                        ).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: ColorsUI.getError(context.brightness),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Διαγραφή',
                          style: context.titleMd.copyWith(
                            color: ColorsUI.getError(context.brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (!canDelete)
                Semantics(
                  liveRegion: true,
                  label: 'Προειδοποίηση: Δεν μπορεί να διαγραφεί - έχει συνδεδεμένες συναλλαγές',
                  excludeSemantics: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ColorsUI.getWarning(context.brightness).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ColorsUI.getWarning(context.brightness).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: ColorsUI.getWarning(context.brightness),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Δεν μπορεί να διαγραφεί - έχει συνδεδεμένες συναλλαγές',
                            style: context.bodySm.copyWith(
                              color: ColorsUI.getWarning(context.brightness),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Ακύρωση Button
              Semantics(
                hint: 'Κλείνει το dialog χωρίς καμία αλλαγή',
                child: TextButton(
                  onPressed: () {
                    AccessibilityService.announcePolite('Ακυρώθηκε η ενέργεια');
                    Navigator.of(context).pop('cancel');
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
