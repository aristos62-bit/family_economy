// ============================================================
// FILE: create_type_selector_dialog.dart
// Path: lib/presentation/dialogs/create_type_selector_dialog.dart
// Ρόλος: Popup επιλογής τύπου (Κατηγορία ή Υποκατηγορία)
// ============================================================

import 'package:flutter/material.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';

class CreateTypeSelectorDialog extends StatefulWidget {
  final String categoryType;

  const CreateTypeSelectorDialog({
    super.key,
    required this.categoryType,
  });

  @override
  State<CreateTypeSelectorDialog> createState() => _CreateTypeSelectorDialogState();
}

class _CreateTypeSelectorDialogState extends State<CreateTypeSelectorDialog> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AccessibilityService.announceAfterFirstFrame(
        context,
        'Επιλέξτε τι θέλετε να δημιουργήσετε: Κατηγορία ή Υποκατηγορία',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.categoryType == 'income'
        ? ColorsUI.getIncomeColor(context.brightness)
        : ColorsUI.getExpenseColor(context.brightness);

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Δημιουργία — επιλέξτε Κατηγορία ή Υποκατηγορία',
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
            // Header
            MergeSemantics(
              child: Column(
                children: [
                  Semantics(
                    header: true,
                    label: 'Δημιουργία',
                    excludeSemantics: true,
                    child: Text(
                      'Δημιουργία',
                      style: context.h3,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Τι θέλετε να δημιουργήσετε;',
                    style: context.bodyMd.copyWith(color: context.cText2),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Τι θέλετε να δημιουργήσετε;',
              style: context.bodyMd.copyWith(color: context.cText2),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Κατηγορία Button
            AccessibilityService.accessibleButton(
              label: 'Νέα Κατηγορία',
              hint: 'Πατήστε για δημιουργία νέας κατηγορίας',
              onPressed: () {
                AccessibilityService.announcePolite('Επιλέχθηκε δημιουργία κατηγορίας');
                Navigator.of(context).pop('category');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.category_rounded,
                        size: 48,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Κατηγορία',
                      style: context.titleLg.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Υποκατηγορία Button
            AccessibilityService.accessibleButton(
              label: 'Νέα Υποκατηγορία',
              hint: 'Πατήστε για δημιουργία νέας υποκατηγορίας',
              onPressed: () {
                AccessibilityService.announcePolite('Επιλέχθηκε δημιουργία υποκατηγορίας');
                Navigator.of(context).pop('subcategory');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 48,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Υποκατηγορία',
                      style: context.titleLg.copyWith(
                        color: color,
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
              hint: 'Κλείνει το dialog χωρίς καμία δημιουργία',
              child: TextButton(
                onPressed: () {
                  AccessibilityService.announcePolite('Ακυρώθηκε η δημιουργία');
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