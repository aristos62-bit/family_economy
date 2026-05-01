import 'package:flutter/material.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/currency_formatter.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/providers/categories_provider.dart';
import 'package:family_economy/providers/accounts_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';

class TransactionEditResult {
  final DateTime date;
  final String? accountId;
  final String? categoryId;
  final String? subcategoryId;
  final double amountAbs;
  final String? notes;

  TransactionEditResult({
    required this.date,
    required this.accountId,
    required this.categoryId,
    required this.subcategoryId,
    required this.amountAbs,
    required this.notes,
  });
}

class TransactionEditSheet extends StatefulWidget {
  final Map<String, dynamic> tx;

  const TransactionEditSheet({super.key, required this.tx});

  static Future<TransactionEditResult?> show(
    BuildContext context, {
    required Map<String, dynamic> tx,
  }) {
    final brightness = Theme.of(context).brightness;

    // ✅ Παίρνουμε τους υπάρχοντες providers από το parent context
    final categoriesProvider = context.read<CategoriesProvider>();
    final accountsProvider = context.read<AccountsProvider>();

    return showModalBottomSheet<TransactionEditResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorsUI.getSurface(brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        // ✅ Τους “περνάμε” μέσα στο bottom sheet route
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: categoriesProvider),
            ChangeNotifierProvider.value(value: accountsProvider),
          ],
          child: TransactionEditSheet(tx: tx),
        );
      },
    );
  }

  @override
  State<TransactionEditSheet> createState() => _TransactionEditSheetState();
}

class _TransactionEditSheetState extends State<TransactionEditSheet> {
  late DateTime _date;
  String? _accountId;
  String? _categoryId;
  String? _subcategoryId;

  late TextEditingController _amountController;
  late TextEditingController _notesController; // ✅ ΝΕΟ


  @override
  void initState() {
    super.initState();
    final tx = widget.tx;

    final ts = tx['date'];
    _date = ts is Timestamp ? ts.toDate() : DateTime.now();

    _accountId = tx['account_id'] as String?;
    _categoryId = tx['category_id'] as String?;
    _subcategoryId = tx['subcategory_id'] as String?;

    final amount = (tx['amount'] as num?)?.toDouble().abs() ?? 0.0;
    _amountController = TextEditingController(text: amount.toStringAsFixed(2));

    final notes = (tx['notes'] as String?)?.trim();
    _notesController = TextEditingController(text: notes ?? '');

    AccessibilityService.announceAfterFirstFrame(
      context,
      'Επεξεργασία Κίνησης. Τροποποιήστε τα στοιχεία και πατήστε Αποθήκευση.',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose(); // ✅ ΝΕΟ
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final categoriesProvider = context.watch<CategoriesProvider>();
    final accountsProvider = context.watch<AccountsProvider>();

    // ✅ transaction_type: "expense" ή "income" (για μεταφορά το αφήνουμε όπως είναι)
    final txType = (widget.tx['transaction_type'] as String?) ?? 'expense';
    final isTransfer = txType == 'transfer';

    // ✅ Μόνο κατηγορίες του τύπου της κίνησης
    final categories = isTransfer
        ? categoriesProvider.getCategoriesByType(
            'expense',
          ) // δεν θα χρησιμοποιηθεί, απλά για να μην είναι null
        : categoriesProvider.getCategoriesByType(txType);

    // ✅ Reset category ΜΟΝΟ για income/expense
    if (!isTransfer && _categoryId != null && _categoryId!.isNotEmpty) {
      final existsInFiltered = categories.any((c) => c.uuid == _categoryId);
      if (!existsInFiltered) {
        _categoryId = null;
        _subcategoryId = null;
      }
    }

    // ✅ Υποκατηγορίες μόνο για την επιλεγμένη κατηγορία
    final subcategories = (_categoryId == null || _categoryId!.isEmpty)
        ? const <SubcategoryModel>[]
        : categoriesProvider.getSubcategoriesForCategory(_categoryId!);

    final accounts = accountsProvider.accounts;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // handle
            // handle
            ExcludeSemantics(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: ColorsUI.getDivider(brightness),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Επεξεργασία Κίνησης',
                      style: TypographyUI.titleMedium(brightness),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Κλείσιμο',
                  child: IconButton(
                    tooltip: 'Κλείσιμο',
                    onPressed: () => Navigator.pop(context),
                    icon: ExcludeSemantics(
                      child: Icon(
                        Icons.close,
                        color: ColorsUI.getTextSecondary(brightness),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date
            _fieldCard(
              brightness,
              title: 'Ημερομηνία',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_date.day}/${_date.month}/${_date.year}',
                      style: TypographyUI.bodyMedium(brightness),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    icon: const ExcludeSemantics(
                      child: Icon(Icons.date_range),
                    ),
                    label: const Text('Αλλαγή'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Account
            _fieldCard(
              brightness,
              title: 'Λογαριασμός',
              child: DropdownButtonFormField<String>(
                initialValue: _accountId,
                items: accounts
                    .map(
                      (a) =>
                          DropdownMenuItem(value: a.uuid, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: isTransfer
                    ? null
                    : (v) => setState(() => _accountId = v),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),

            const SizedBox(height: 12),

            if (!isTransfer) ...[
              // ✅ Category
              _fieldCard(
                brightness,
                title: 'Κατηγορία',
                child: DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.uuid,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _categoryId = v;
                      _subcategoryId = null;
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ✅ Subcategory
              _fieldCard(
                brightness,
                title: 'Υποκατηγορία',
                child: DropdownButtonFormField<String>(
                  initialValue: _subcategoryId,
                  items: subcategories
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.uuid,
                          child: Text(s.name),
                        ),
                      )
                      .toList(),
                  onChanged: (_categoryId == null || _categoryId!.isEmpty)
                      ? null
                      : (v) => setState(() => _subcategoryId = v),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],

            // Amount
            _fieldCard(
              brightness,
              title: 'Ποσό',
              child: TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onTap: () => _amountController.clear(),
              ),
            ),

            const SizedBox(height: 12),

            _fieldCard(
              brightness,
              title: 'Παρατηρήσεις',
              child: TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Γράψε παρατηρήσεις...',
                ),
              ),
            ),

            const SizedBox(height: 12),

            Semantics(
              button: true,
              label: 'Αποθήκευση κίνησης',
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: ColorsUI.getSuccess(brightness),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  final parsed = CurrencyFormatter.parseInput(
                    _amountController.text,
                  );
                  if (parsed == null || parsed <= 0) return;

                  Navigator.pop(
                    context,
                    TransactionEditResult(
                      date: _date,
                      accountId: _accountId,
                      categoryId: _categoryId,
                      subcategoryId: _subcategoryId,
                      amountAbs: parsed.abs(),
                      notes: _notesController.text.trim().isEmpty
                          ? null
                          : _notesController.text.trim(),
                    ),
                  );
                },
                icon: const ExcludeSemantics(
                  child: Icon(Icons.save),
                ),
                label: const Text('Αποθήκευση'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldCard(
      Brightness brightness, {
        required String title,
        required Widget child,
      }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorsUI.getCard(brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorsUI.getBorder(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(title, style: TypographyUI.labelLarge(brightness)),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: title,
            child: child,
          ),
        ],
      ),
    );
  }
}
