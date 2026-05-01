// ============================================================
// FILE: expense_categories_page.dart
// Path: lib/presentation/screens/categories/expense_categories_page.dart
// Ρόλος: Διαχείριση κατηγοριών εξόδων με υποκατηγορίες
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/utils/icon_mapper.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/presentation/dialogs/category_actions_dialog.dart';
import 'package:family_economy/presentation/dialogs/edit_category_dialog.dart';
import 'package:family_economy/presentation/dialogs/create_type_selector_dialog.dart';

class ExpenseCategoriesPage extends StatefulWidget {
  const ExpenseCategoriesPage({super.key});

  @override
  State<ExpenseCategoriesPage> createState() => _ExpenseCategoriesPageState();
}

class _ExpenseCategoriesPageState extends State<ExpenseCategoriesPage> {
  // Κρατάμε ποιες κατηγορίες είναι ανοιχτές
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Σελίδα Κατηγοριών Εξόδων. Διαχειριστείτε τις κατηγορίες και υποκατηγορίες σας.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.session.userId;
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return ChangeNotifierProvider<CategoriesProvider>(
      create: (_) => CategoriesProvider(userId: userId),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Κατηγορίες Εξόδων'),
          centerTitle: true,
          elevation: 0,
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 720, // 👈 πλάτος για tablet/desktop
            ),
            child: Consumer<CategoriesProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return _buildLoadingState();
                }

                if (provider.error != null) {
                  return _buildErrorState(provider.error!);
                }

                final categories = provider.getCategoriesByType('expense');

                if (categories.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildCategoriesList(categories, provider, isOffline);
              },
            ),
          ),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton(
            onPressed: () => _handleCreate(ctx),
            backgroundColor: ColorsUI.getExpenseColor(ctx.brightness),
            tooltip: 'Δημιουργία νέας κατηγορίας ή υποκατηγορίας',
            child: const ExcludeSemantics(
              child: Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Semantics(
      liveRegion: true,
      label: 'Φόρτωση κατηγοριών. Παρακαλώ περιμένετε.',
      excludeSemantics: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: CircularProgressIndicator(
                color: ColorsUI.getPrimary(context.brightness),
              ),
            ),
            const SizedBox(height: 16),
            Text('Φόρτωση κατηγοριών...', style: context.bodyMd),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: ColorsUI.getError(context.brightness),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Σφάλμα φόρτωσης',
              style: context.titleLg.copyWith(
                color: ColorsUI.getError(context.brightness),
              ),
            ),
            const SizedBox(height: 8),
            Text(error, style: context.bodyMd, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.category_outlined,
                size: 64,
                color: context.cText2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Δεν υπάρχουν κατηγορίες εξόδων',
              style: context.titleMd,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList(
    List<CategoryModel> categories,
    CategoriesProvider provider,
    bool isOffline,
  ) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom + 80,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isExpanded = _expandedCategories.contains(category.uuid);
        final subcategories = provider.getSubcategoriesForCategory(
          category.uuid,
        );

        return _CategoryCard(
          category: category,
          subcategories: subcategories,
          isExpanded: isExpanded,
          isOffline: isOffline,
          onToggleExpand: () {
            setState(() {
              if (isExpanded) {
                _expandedCategories.remove(category.uuid);
                AccessibilityService.announcePolite(
                  'Έκλεισε η κατηγορία ${category.name}',
                );
              } else {
                _expandedCategories.add(category.uuid);
                AccessibilityService.announcePolite(
                  'Άνοιξε η κατηγορία ${category.name} με ${subcategories.length} υποκατηγορίες',
                );
              }
            });
          },
          onCategoryTap: () => _handleCategoryTap(category),
          onSubcategoryTap: (subcategory) =>
              _handleSubcategoryTap(category, subcategory),
        );
      },
    );
  }

  Future<void> _handleCategoryTap(CategoryModel category) async {
    // Έλεγχος αν έχει συναλλαγές
    final canDelete = await _canDeleteCategory(category.uuid);

    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          CategoryActionsDialog(title: category.name, canDelete: canDelete),
    );

    if (!mounted || action == null || action == 'cancel') return;

    if (action == 'edit') {
      await _editCategory(category);
    } else if (action == 'delete') {
      await _deleteCategory(category);
    }
  }

  Future<void> _handleSubcategoryTap(
    CategoryModel category,
    SubcategoryModel subcategory,
  ) async {
    final canDelete = await _canDeleteSubcategory(subcategory.uuid);

    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          CategoryActionsDialog(title: subcategory.name, canDelete: canDelete),
    );

    if (!mounted || action == null || action == 'cancel') return;

    if (action == 'edit') {
      await _editSubcategory(category, subcategory);
    } else if (action == 'delete') {
      await _deleteSubcategory(category, subcategory);
    }
  }

  Future<void> _editCategory(CategoryModel category) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => EditCategoryDialog(
        currentName: category.name,
        currentIconIndex: category.iconIndex,
        type: 'expense',
        isSubcategory: false,
      ),
    );

    if (!mounted || result == null) return;

    try {
      final userId = context.session.userId;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(category.uuid)
          .update({
            'name': result['name'],
            'icon_index': result['icon_index'],
            'updated_at': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Η κατηγορία ενημερώθηκε επιτυχώς'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Σφάλμα: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editSubcategory(
    CategoryModel category,
    SubcategoryModel subcategory,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => EditCategoryDialog(
        currentName: subcategory.name,
        currentIconIndex: subcategory.iconIndex,
        type: 'expense',
        isSubcategory: true,
      ),
    );

    if (!mounted || result == null) return;

    try {
      final userId = context.session.userId;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(category.uuid)
          .collection('subcategories')
          .doc(subcategory.uuid)
          .update({
            'name': result['name'],
            'icon_index': result['icon_index'],
            'updated_at': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Η υποκατηγορία ενημερώθηκε επιτυχώς'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Σφάλμα: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Επιβεβαίωση Διαγραφής'),
        content: Text(
          'Είστε σίγουροι ότι θέλετε να διαγράψετε την κατηγορία "${category.name}";\n\nΗ ενέργεια δεν μπορεί να αναιρεθεί.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ακύρωση'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Διαγραφή'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      final userId = context.session.userId;

      // Soft delete
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(category.uuid)
          .update({
            'deleted': true,
            'updated_at': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Η κατηγορία διαγράφηκε επιτυχώς'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Σφάλμα: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSubcategory(
    CategoryModel category,
    SubcategoryModel subcategory,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Επιβεβαίωση Διαγραφής'),
        content: Text(
          'Είστε σίγουροι ότι θέλετε να διαγράψετε την υποκατηγορία "${subcategory.name}";\n\nΗ ενέργεια δεν μπορεί να αναιρεθεί.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ακύρωση'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Διαγραφή'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      final userId = context.session.userId;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(category.uuid)
          .collection('subcategories')
          .doc(subcategory.uuid)
          .update({
            'deleted': true,
            'updated_at': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Η υποκατηγορία διαγράφηκε επιτυχώς'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Σφάλμα: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _canDeleteCategory(String categoryUuid) async {
    try {
      final userId = context.session.userId;

      // Έλεγχος για συναλλαγές με αυτή την κατηγορία
      final transactions = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('category_id', isEqualTo: categoryUuid)
          .where('deleted', isEqualTo: false)
          .limit(1)
          .get();

      return transactions.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _canDeleteSubcategory(String subcategoryUuid) async {
    try {
      final userId = context.session.userId;

      final transactions = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('subcategory_id', isEqualTo: subcategoryUuid)
          .where('deleted', isEqualTo: false)
          .limit(1)
          .get();

      return transactions.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }
  // ============================================================
  // CREATE (Category / Subcategory) - Expense
  // ============================================================

  Future<void> _handleCreate(BuildContext ctx) async {
    final isOffline = ctx.read<ConnectivityService>().isOffline;
    if (isOffline) {
      _showInfo(ctx, 'Offline: θα συγχρονιστεί όταν επανέλθει η σύνδεση');
    }

    final createType = await showDialog<String>(
      context: ctx,
      builder: (_) => const CreateTypeSelectorDialog(categoryType: 'expense'),
    );

    if (!mounted || createType == null) return;

    if (createType == 'category') {
      if (!context.mounted) return;
      await _createCategory(ctx);
    } else if (createType == 'subcategory') {
      if (!context.mounted) return;
      await _createSubcategory(ctx);
    }
  }

  Future<void> _createCategory(BuildContext ctx) async {
    final provider = ctx.read<CategoriesProvider>();

    final result = await showDialog<Map<String, dynamic>>(
      context: ctx,
      builder: (_) => const EditCategoryDialog(
        currentName: '',
        currentIconIndex: null,
        type: 'expense',
        isSubcategory: false,
      ),
    );

    if (!mounted || result == null) return;

    final newName = (result['name'] as String).trim();
    if (newName.isEmpty) return;

    final existingNames = provider
        .getCategoriesByType('expense')
        .map((c) => c.name.toLowerCase().trim())
        .toList();

    if (existingNames.contains(newName.toLowerCase())) {
      if (!context.mounted) return;
      _showError(ctx, 'Η κατηγορία υπάρχει ήδη');
      return;
    }
    if (!context.mounted) return;
    try {
      final userId = ctx.session.userId;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc();

      await docRef.set({
        'uuid': docRef.id,
        'user_id': userId,
        'name': newName,
        'type': 'expense',
        'icon_index': result['icon_index'],
        'color': null,
        'is_system': false,
        'hidden': false,
        'display_order': existingNames.length,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'deleted': false,
      });

      if (!mounted) return;
      if (!context.mounted) return;
      _showSuccess(ctx, 'Η κατηγορία δημιουργήθηκε');
    } catch (e) {
      if (!mounted) return;
      _showError(ctx, 'Σφάλμα δημιουργίας: ${e.toString()}');
    }
  }

  Future<void> _createSubcategory(BuildContext ctx) async {
    final provider = ctx.read<CategoriesProvider>();
    final categories = provider.getCategoriesByType('expense');

    if (categories.isEmpty) {
      _showError(ctx, 'Δημιουργήστε πρώτα μια κατηγορία');
      return;
    }

    final selectedCategory = await _showCategorySelector(ctx, categories);
    if (!mounted || selectedCategory == null) return;
    if (!context.mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: ctx,
      builder: (_) => const EditCategoryDialog(
        currentName: '',
        currentIconIndex: null,
        type: 'expense',
        isSubcategory: true,
      ),
    );

    if (!mounted || result == null) return;

    final newName = (result['name'] as String).trim();
    if (newName.isEmpty) return;

    final existingNames = provider
        .getSubcategoriesForCategory(selectedCategory.uuid)
        .map((s) => s.name.toLowerCase().trim())
        .toList();

    if (existingNames.contains(newName.toLowerCase())) {
      if (!context.mounted) return;
      _showError(ctx, 'Η υποκατηγορία υπάρχει ήδη σε αυτή την κατηγορία');
      return;
    }
    if (!context.mounted) return;
    try {
      final userId = ctx.session.userId;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(selectedCategory.uuid)
          .collection('subcategories')
          .doc();

      await docRef.set({
        'uuid': docRef.id,
        'user_id': userId,
        'category_id': selectedCategory.uuid,
        'name': newName,
        'icon_index': result['icon_index'],
        'color': null,
        'is_system': false,
        'hidden': false,
        'display_order': existingNames.length,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'deleted': false,
      });

      if (!mounted) return;
      if (!context.mounted) return;
      _showSuccess(ctx, 'Η υποκατηγορία δημιουργήθηκε');
    } catch (e) {
      if (!mounted) return;
      _showError(ctx, 'Σφάλμα δημιουργίας: ${e.toString()}');
    }
  }

  Future<CategoryModel?> _showCategorySelector(
    BuildContext ctx,
    List<CategoryModel> categories,
  ) async {
    return showDialog<CategoryModel>(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Επιλογή Κατηγορίας'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final iconPath = IconMapper.getIconPath(
                'category',
                cat.iconIndex,
                categoryType: 'expense',
              );

              return ListTile(
                leading: ExcludeSemantics(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ColorsUI.getExpenseColor(
                        context.brightness,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        iconPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.folder_outlined,
                          color: ColorsUI.getExpenseColor(context.brightness),
                        ),
                      ),
                    ),
                  ),
                ),
                title: Text(cat.name),
                onTap: () => Navigator.of(dialogContext).pop(cat),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Ακύρωση'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Snack helpers
  // ============================================================

  void _showSuccess(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showInfo(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  void _showError(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// ============================================================
// CATEGORY CARD WIDGET
// ============================================================

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final List<SubcategoryModel> subcategories;
  final bool isExpanded;
  final bool isOffline;
  final VoidCallback onToggleExpand;
  final VoidCallback onCategoryTap;
  final void Function(SubcategoryModel) onSubcategoryTap;

  const _CategoryCard({
    required this.category,
    required this.subcategories,
    required this.isExpanded,
    required this.isOffline,
    required this.onToggleExpand,
    required this.onCategoryTap,
    required this.onSubcategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconPath = IconMapper.getIconPath(
      'category',
      category.iconIndex,
      categoryType: 'expense',
    );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Κύρια κάρτα κατηγορίας
          InkWell(
            onTap: onCategoryTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Icon
                  ExcludeSemantics(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: ColorsUI.getExpenseColor(
                          context.brightness,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          iconPath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.category_rounded,
                            size: 32,
                            color: ColorsUI.getExpenseColor(context.brightness),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.name, style: context.titleMd),
                        if (subcategories.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          ExcludeSemantics(
                            child: Text(
                              '${subcategories.length} υποκατηγορίες',
                              style: context.bodySm.copyWith(
                                color: context.cText2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Expand button (αν έχει υποκατηγορίες)
                  if (subcategories.isNotEmpty)
                    AccessibilityService.accessibleButton(
                      label: isExpanded ? 'Κλείσιμο' : 'Άνοιγμα',
                      hint:
                          'Πατήστε για ${isExpanded ? 'κλείσιμο' : 'εμφάνιση'} υποκατηγοριών',
                      onPressed: onToggleExpand,
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 32,
                          color: context.cPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Υποκατηγορίες (expandable)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: ColorsUI.getDivider(context.brightness),
                ),
                ...subcategories.map(
                  (sub) => _SubcategoryTile(
                    subcategory: sub,
                    onTap: () => onSubcategoryTap(sub),
                  ),
                ),
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
// SUBCATEGORY TILE WIDGET
// ============================================================

class _SubcategoryTile extends StatelessWidget {
  final SubcategoryModel subcategory;
  final VoidCallback onTap;

  const _SubcategoryTile({required this.subcategory, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final iconPath = IconMapper.getIconPath(
      'subcategory',
      subcategory.iconIndex,
      categoryType: 'expense',
    );

    return AccessibilityService.accessibleButton(
      label: subcategory.name,
      hint: 'Πατήστε για επεξεργασία ή διαγραφή',
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const SizedBox(width: 32), // Indent
            // Icon
            ExcludeSemantics(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorsUI.getExpenseColor(
                    context.brightness,
                  ).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    iconPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 20,
                      color: ColorsUI.getExpenseColor(context.brightness),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Name
            Expanded(child: Text(subcategory.name, style: context.bodyMd)),

            // Arrow
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
