// ============================================================
// FILE: transaction_entry_state.dart
// Ρόλος: Καθαρή λογική flow & state για Transaction Entry
// VERSION: Firebase Migration - UUID-based
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:family_economy/core/utils/debug_config.dart';

enum TransactionKind {
  income,
  expense,
  transfer,
}

enum EntryStep {
  type,
  account,
  category,
  subcategory,
  details,
}

class TransactionEntryState extends ChangeNotifier {
  // ============================================================
  // FLOW CONTROL
  // ============================================================

  TransactionKind? _kind;
  EntryStep _currentStep = EntryStep.type;

  TransactionKind? get kind => _kind;
  EntryStep get currentStep => _currentStep;

  // ============================================================
  // SELECTED ENTITIES (✅ UUID-based)
  // ============================================================

  String? selectedAccountUuid;
  String? selectedAccountName;

  String? selectedTargetAccountUuid;
  String? selectedTargetAccountName;

  String? selectedCategoryUuid;
  String? selectedCategoryName;

  String? selectedSubcategoryUuid;
  String? selectedSubcategoryName;

  // ============================================================
  // DETAILS
  // ============================================================

  DateTime _selectedDate = DateTime.now();

  DateTime get selectedDate => _selectedDate;

  set selectedDate(DateTime value) {
    _selectedDate = value;
    notifyListeners();
  }

  String? notes;
  double? amount;

  // ─── TAGS ──────────────────────────────────────────────
  List<String> selectedTagIds = [];

  void setSelectedTagIds(List<String> ids) {
    selectedTagIds = List<String>.from(ids);
    notifyListeners();
  }

  // ============================================================
  // SETTERS / FLOW
  // ============================================================

  void selectTransactionKind(TransactionKind kind) {
    _kind = kind;
    _currentStep = EntryStep.account;
    _clearAfterKind();
    notifyListeners();
  }

  void selectAccount(String uuid, String name) {
    selectedAccountUuid = uuid;
    selectedAccountName = name;

    if (_kind == TransactionKind.transfer) {
      selectedTargetAccountUuid = null;
      selectedTargetAccountName = null;
      _currentStep = EntryStep.account;
    } else {
      _currentStep = EntryStep.category;
    }

    notifyListeners();
  }

  void selectTargetAccount(String uuid, String name) {
    selectedTargetAccountUuid = uuid;
    selectedTargetAccountName = name;
    _currentStep = EntryStep.details;
    notifyListeners();
  }

  void selectCategory(String uuid, String name) {
    selectedCategoryUuid = uuid;
    selectedCategoryName = name;
    _currentStep = EntryStep.subcategory;
    notifyListeners();
  }

  void selectSubcategory(String? uuid, String? name) {
    selectedSubcategoryUuid = uuid;
    selectedSubcategoryName = name;
    _currentStep = EntryStep.details;
    notifyListeners();
  }

  // ============================================================
  // BACK NAVIGATION
  // ============================================================

  void goBackTo(EntryStep step) {
    _currentStep = step;

    switch (step) {
      case EntryStep.type:
        resetAll();
        break;
      case EntryStep.account:
        _clearAfterAccount();
        break;
      case EntryStep.category:
        _clearAfterCategory();
        break;
      case EntryStep.subcategory:
        _clearAfterSubcategory();
        break;
      case EntryStep.details:
        break;
    }

    notifyListeners();
  }

  void goBackToAccountForTransfer({required bool resetSource}) {
    _currentStep = EntryStep.account;

    if (resetSource) {
      selectedAccountUuid = null;
      selectedAccountName = null;
    }

    selectedTargetAccountUuid = null;
    selectedTargetAccountName = null;

    selectedCategoryUuid = null;
    selectedCategoryName = null;
    selectedSubcategoryUuid = null;
    selectedSubcategoryName = null;

    amount = null;
    notes = null;
    _selectedDate = DateTime.now();

    notifyListeners();
  }

  // ============================================================
  // RESET
  // ============================================================

  void resetAll() {
    DebugConfig.print('🔄 TransactionEntryState.resetAll() called');
    DebugConfig.print('   Current step before reset: $_currentStep');
    DebugConfig.print('   Kind before reset: $_kind');

    _kind = null;
    _currentStep = EntryStep.type;

    selectedAccountUuid = null;
    selectedAccountName = null;
    selectedTargetAccountUuid = null;
    selectedTargetAccountName = null;
    selectedCategoryUuid = null;
    selectedCategoryName = null;
    selectedSubcategoryUuid = null;
    selectedSubcategoryName = null;

    amount = null;
    notes = null;
    _selectedDate = DateTime.now();
    selectedTagIds = [];

    DebugConfig.print('   Step after reset: $_currentStep');
    DebugConfig.print('   Kind after reset: $_kind');
    DebugConfig.print('✅ TransactionEntryState reset complete');

    notifyListeners();
  }

  void _clearAfterKind() {
    selectedAccountUuid = null;
    selectedAccountName = null;
    selectedTargetAccountUuid = null;
    selectedTargetAccountName = null;
    _clearAfterAccount();
  }

  void _clearAfterAccount() {
    selectedCategoryUuid = null;
    selectedCategoryName = null;
    _clearAfterCategory();
  }

  void _clearAfterCategory() {
    selectedSubcategoryUuid = null;
    selectedSubcategoryName = null;
    _clearAfterSubcategory();
  }

  void _clearAfterSubcategory() {
    amount = null;
    notes = null;
    _selectedDate = DateTime.now();
    selectedTagIds = [];
  }

  // ============================================================
  // COMPUTED
  // ============================================================

  bool get isIncome => _kind == TransactionKind.income;
  bool get isExpense => _kind == TransactionKind.expense;
  bool get isTransfer => _kind == TransactionKind.transfer;

  bool get hasSourceAccount => selectedAccountUuid != null;
  bool get hasTargetAccount => selectedTargetAccountUuid != null;

  bool get canEnterDetails {
    if (isTransfer) {
      return selectedAccountUuid != null && selectedTargetAccountUuid != null;
    }
    return selectedAccountUuid != null && selectedCategoryUuid != null;
  }
}