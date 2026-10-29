// ============================================================
// FILE: budget_model.dart
// Path: lib/models/budget_model.dart
// Ρόλος: Budget model class matching EXACT Firestore schema
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String uuid;
  final String userId;
  final String? name;
  final String budgetType; // 'subcategory' | 'category' | 'total'
  final String? categoryId; // nullable for total budgets
  final String? subcategoryId; // nullable for category-level budgets
  final String? accountId; // nullable = all accounts
  final String periodType; // 'monthly' | 'weekly' | 'yearly' | 'custom'
  final DateTime startDate;
  final DateTime endDate;
  final double amount;
  final String currency;
  final int alertThreshold; // percentage (0-100)
  final bool allowOverspend;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastModifiedDeviceId;
  final bool deleted;

  BudgetModel({
    required this.uuid,
    required this.userId,
    this.name,
    required this.budgetType,
    this.categoryId,
    this.subcategoryId,
    this.accountId,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.amount,
    this.currency = 'EUR',
    this.alertThreshold = 80,
    this.allowOverspend = true,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.lastModifiedDeviceId = '',
    this.deleted = false,
  });

  // ============================================================
  // GETTERS
  // ============================================================

  bool get isSubcategoryBudget => budgetType == 'subcategory';
  bool get isCategoryBudget => budgetType == 'category';
  bool get isTotalBudget => budgetType == 'total';
  bool get isAllAccounts => accountId == null;

  // ============================================================
  // FIRESTORE CONVERSION
  // ============================================================

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return BudgetModel(
      uuid: doc.id,
      userId: data['user_id'] as String,
      name: data['name'] as String?,
      budgetType: data['budget_type'] as String? ?? 'category',
      categoryId: data['category_id'] as String?,
      subcategoryId: data['subcategory_id'] as String?,
      accountId: data['account_id'] as String?,
      periodType: data['period_type'] as String? ?? 'monthly',
      startDate: _parseDate(data['start_date']),
      endDate: _parseDate(data['end_date']),
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] as String? ?? 'EUR',
      alertThreshold: data['alert_threshold'] as int? ?? 80,
      allowOverspend: data['allow_overspend'] as bool? ?? true,
      isActive: data['is_active'] as bool? ?? true,
      createdAt: _parseTimestamp(data['created_at']),
      updatedAt: _parseTimestamp(data['updated_at']),
      lastModifiedDeviceId: data['last_modified_device_id'] as String? ?? '',
      deleted: data['deleted'] as bool? ?? false,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'budget_type': budgetType,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'account_id': accountId,
      'period_type': periodType,
      'start_date': startDate.toIso8601String().split('T')[0], // YYYY-MM-DD
      'end_date': endDate.toIso8601String().split('T')[0],
      'amount': amount,
      'currency': currency,
      'alert_threshold': alertThreshold,
      'allow_overspend': allowOverspend,
      'is_active': isActive,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'last_modified_device_id': lastModifiedDeviceId,
      'deleted': deleted,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  BudgetModel copyWith({
    String? uuid,
    String? userId,
    String? name,
    String? budgetType,
    String? categoryId,
    String? subcategoryId,
    String? accountId,
    String? periodType,
    DateTime? startDate,
    DateTime? endDate,
    double? amount,
    String? currency,
    int? alertThreshold,
    bool? allowOverspend,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastModifiedDeviceId,
    bool? deleted,
  }) {
    return BudgetModel(
      uuid: uuid ?? this.uuid,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      budgetType: budgetType ?? this.budgetType,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      accountId: accountId ?? this.accountId,
      periodType: periodType ?? this.periodType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      allowOverspend: allowOverspend ?? this.allowOverspend,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModifiedDeviceId: lastModifiedDeviceId ?? this.lastModifiedDeviceId,
      deleted: deleted ?? this.deleted,
    );
  }
}