// ============================================================
// FILE: edit_category_dialog.dart
// Path: lib/presentation/dialogs/edit_category_dialog.dart
// Ρόλος: Popup επεξεργασίας κατηγορίας/υποκατηγορίας
// ============================================================

import 'package:flutter/material.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/utils/icon_mapper.dart';

class EditCategoryDialog extends StatefulWidget {
  final String currentName;
  final int? currentIconIndex;
  final String type; // 'income' or 'expense'
  final bool isSubcategory;

  const EditCategoryDialog({
    super.key,
    required this.currentName,
    this.currentIconIndex,
    required this.type,
    this.isSubcategory = false,
  });

  @override
  State<EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<EditCategoryDialog> {
  late TextEditingController _nameController;
  int? _selectedIconIndex;
  bool _showIconPicker = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _selectedIconIndex = widget.currentIconIndex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<int> _getAvailableIcons() {
    if (widget.isSubcategory) {
      // Υποκατηγορίες
      return widget.type == 'income'
          ? IconMapper.incomeSubcategoryIcons.keys.toList()
          : IconMapper.expenseSubcategoryIcons.keys.toList();
    } else {
      // Κατηγορίες
      return widget.type == 'income'
          ? IconMapper.incomeCategoryIcons.keys.toList()
          : IconMapper.expenseCategoryIcons.keys.toList();
    }
  }

  String _getIconPath(int iconIndex) {
    return IconMapper.getIconPath(
      widget.isSubcategory ? 'subcategory' : 'category',
      iconIndex,
      categoryType: widget.type,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: widget.isSubcategory
            ? 'Επεξεργασία Υποκατηγορίας'
            : 'Επεξεργασία Κατηγορίας',
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.cPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: context.cPrimary,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        widget.isSubcategory
                            ? 'Επεξεργασία Υποκατηγορίας'
                            : 'Επεξεργασία Κατηγορίας',
                        style: context.titleLg,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Όνομα TextField
              AccessibilityService.accessibleTextField(
                label: 'Όνομα ${widget.isSubcategory ? 'Υποκατηγορίας' : 'Κατηγορίας'}',
                hint: 'Εισάγετε το νέο όνομα',
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Όνομα',
                    hintText: 'π.χ. Μισθοί, Σούπερ Μάρκετ, κλπ.',
                    prefixIcon: Icon(
                      Icons.label_outline_rounded,
                      color: context.cPrimary,
                    ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Επιλογή εικονιδίου
              Text(
                'Εικονίδιο',
                style: TypographyUI.labelLarge(context.brightness),
              ),

              const SizedBox(height: 12),

              // Τρέχον εικονίδιο + κουμπί αλλαγής
              Row(
                children: [
                  // Προεπισκόπηση τρέχοντος εικονιδίου
                  Semantics(
                    label: _selectedIconIndex != null
                        ? 'Τρέχον εικονίδιο επιλεγμένο'
                        : 'Δεν έχει επιλεγεί εικονίδιο',
                    image: true,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: context.cPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.cPrimary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: _selectedIconIndex != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          _getIconPath(_selectedIconIndex!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.image_not_supported_outlined,
                            size: 40,
                            color: context.cText2,
                          ),
                        ),
                      )
                          : Icon(
                        Icons.image_outlined,
                        size: 40,
                        color: context.cText2,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Κουμπί αλλαγής
                  Expanded(
                    child: Semantics(
                      hint: _showIconPicker
                          ? 'Πατήστε για απόκρυψη της λίστας εικονιδίων'
                          : 'Πατήστε για εμφάνιση της λίστας εικονιδίων',
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showIconPicker = !_showIconPicker;
                          });
                          AccessibilityService.announcePolite(
                            _showIconPicker
                                ? 'Άνοιξε η επιλογή εικονιδίων'
                                : 'Έκλεισε η επιλογή εικονιδίων',
                          );
                        },
                        icon: ExcludeSemantics(
                          child: Icon(_showIconPicker
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded),
                        ),
                        label: Text(_showIconPicker
                            ? 'Απόκρυψη'
                            : 'Επιλογή Εικονιδίου'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Icon Picker Grid (conditionally shown)
              if (_showIconPicker) ...[
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: context.cSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ColorsUI.getBorder(context.brightness),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _getAvailableIcons().length,
                      itemBuilder: (context, index) {
                        final iconIndex = _getAvailableIcons()[index];
                        final isSelected = iconIndex == _selectedIconIndex;

                        return AccessibilityService.accessibleButton(
                          label: 'Εικονίδιο $iconIndex',
                          hint: isSelected
                              ? 'Επιλεγμένο εικονίδιο'
                              : 'Πατήστε για επιλογή',
                          onPressed: () {
                            setState(() {
                              _selectedIconIndex = iconIndex;
                            });
                            AccessibilityService.announcePolite(
                              'Επιλέχθηκε εικονίδιο $iconIndex',
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.cPrimary.withValues(alpha: 0.2)
                                  : context.cSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? context.cPrimary
                                    : ColorsUI.getBorder(context.brightness),
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                _getIconPath(iconIndex),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 24,
                                  color: context.cText2,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      hint: 'Κλείνει το dialog χωρίς αποθήκευση αλλαγών',
                      child: OutlinedButton(
                        onPressed: () {
                          AccessibilityService.announcePolite('Ακυρώθηκε η επεξεργασία');
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Ακύρωση'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final newName = _nameController.text.trim();

                        if (newName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Το όνομα δεν μπορεί να είναι κενό'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        AccessibilityService.announceSuccess(
                          'Αποθηκεύτηκαν οι αλλαγές',
                        );

                        Navigator.of(context).pop({
                          'name': newName,
                          'icon_index': _selectedIconIndex,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Αποθήκευση'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
        ),
    );
  }
}