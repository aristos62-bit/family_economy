// ============================================================
// FILE: categories_provider.dart
// Path: lib/providers/categories_provider.dart
// Ρόλος: Real-time Firestore listener για κατηγορίες + υποκατηγορίες
// VERSION: Added firstLoad readiness (proper provider architecture)
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/core/utils/debug_config.dart';

class CategoryModel {
  final String uuid;
  final String userId;
  final String name;
  final String type;
  final int? iconIndex;
  final String? color;
  final bool isSystem;
  final bool hidden;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  CategoryModel({
    required this.uuid,
    required this.userId,
    required this.name,
    required this.type,
    this.iconIndex,
    this.color,
    required this.isSystem,
    required this.hidden,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CategoryModel(
      uuid: doc.id,
      userId: data['user_id'] as String,
      name: data['name'] as String,
      type: data['type'] as String,
      iconIndex: data['icon_index'] as int?,
      color: data['color'] as String?,
      isSystem: data['is_system'] as bool? ?? false,
      hidden: data['hidden'] as bool? ?? false,
      displayOrder: data['display_order'] as int? ?? 0,
      createdAt: _parseTimestamp(data['created_at']),
      updatedAt: _parseTimestamp(data['updated_at']),
      deleted: data['deleted'] as bool? ?? false,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'type': type,
      'icon_index': iconIndex,
      'color': color,
      'is_system': isSystem,
      'hidden': hidden,
      'display_order': displayOrder,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'deleted': deleted,
    };
  }
}

class SubcategoryModel {
  final String uuid;
  final String userId;
  final String categoryId;
  final String name;
  final int? iconIndex;
  final String? color;
  final bool isSystem;
  final bool hidden;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  SubcategoryModel({
    required this.uuid,
    required this.userId,
    required this.categoryId,
    required this.name,
    this.iconIndex,
    this.color,
    required this.isSystem,
    required this.hidden,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });

  factory SubcategoryModel.fromFirestore(
      DocumentSnapshot doc,
      String categoryId,
      ) {
    final data = doc.data() as Map<String, dynamic>;

    return SubcategoryModel(
      uuid: doc.id,
      userId: data['user_id'] as String,
      categoryId: categoryId,
      name: data['name'] as String,
      iconIndex: data['icon_index'] as int?,
      color: data['color'] as String?,
      isSystem: data['is_system'] as bool? ?? false,
      hidden: data['hidden'] as bool? ?? false,
      displayOrder: data['display_order'] as int? ?? 0,
      createdAt: _parseTimestamp(data['created_at']),
      updatedAt: _parseTimestamp(data['updated_at']),
      deleted: data['deleted'] as bool? ?? false,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'category_id': categoryId,
      'name': name,
      'icon_index': iconIndex,
      'color': color,
      'is_system': isSystem,
      'hidden': hidden,
      'display_order': displayOrder,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'deleted': deleted,
    };
  }
}

class CategoriesProvider extends ChangeNotifier {
  final String userId;

  StreamSubscription<QuerySnapshot>? _categoriesSubscription;
  final Map<String, StreamSubscription<QuerySnapshot>>
  _subcategoriesSubscriptions = {};

  final List<CategoryModel> _categories = [];
  final Map<String, List<SubcategoryModel>> _subcategoriesByCategory = {};

  bool _isLoading = true;
  String? _error;

  bool _disposed = false;

  bool _subcategoriesLoaded = false;
  bool get hasSubcategoriesLoaded => _subcategoriesLoaded;

  // ============================================================
  // ✅ NEW: firstLoad readiness (complete after first snapshot OR error/early-exit)
  // ============================================================
  final Completer<void> _firstLoadCompleter = Completer<void>();
  bool _firstLoadSignaled = false;

  Future<void> get firstLoad => _firstLoadCompleter.future;

  void _signalFirstLoadIfNeeded() {
    if (_firstLoadSignaled) return;
    _firstLoadSignaled = true;
    if (!_firstLoadCompleter.isCompleted) {
      _firstLoadCompleter.complete();
    }
  }

  CategoriesProvider({required this.userId}) {
    _initListener();
  }

  // ============================================================
  // GETTERS
  // ============================================================

  List<CategoryModel> get allCategories {
    final filtered = _categories.where((c) => !c.deleted && !c.hidden).toList();
    filtered.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return filtered;
  }

  List<CategoryModel> getCategoriesByType(String type) {
    return allCategories.where((c) => c.type == type).toList();
  }

  List<SubcategoryModel> getSubcategoriesForCategory(String categoryUuid) {
    final subs = _subcategoriesByCategory[categoryUuid]
        ?.where((s) => !s.deleted && !s.hidden)
        .toList() ??
        <SubcategoryModel>[];
    subs.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return subs;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  // ============================================================
  // INIT
  // ============================================================


  void _initListener() {
    final uid = userId.trim();

    // ✅ Guard: αν για κάποιο λόγο φτιαχτεί provider χωρίς uid, μην ξεκινήσεις listeners
    if (uid.isEmpty) {
      _isLoading = false;
      _error = 'Missing userId for CategoriesProvider';
      DebugConfig.print('⚠️ CategoriesProvider: missing userId, listener not started');
      notifyListeners();

      // ✅ μην μπλοκάρεις το UI (charts/firstLoad)
      _signalFirstLoadIfNeeded();
      return;
    }

    _categoriesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .snapshots()
        .listen(
      _onCategoriesChanged,
      onError: _onError,
    );
    DebugConfig.print('→ CategoriesProvider: listener initialized for userId=$userId');
  }


  // ============================================================
  // LISTENERS
  // ============================================================

  void _onCategoriesChanged(QuerySnapshot snapshot) {
    if (_disposed) return;

    try {
      _categories.clear();
      _categories.addAll(
        snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)),
      );

      // ✅ Active (visible) categories set
      final activeCategoryIds = <String>{};
      for (final category in _categories) {
        if (!category.deleted && !category.hidden) {
          activeCategoryIds.add(category.uuid);
        }
      }

      // ✅ Start / refresh listeners for active categories
      for (final categoryId in activeCategoryIds) {
        if (_disposed) return;
        _listenToSubcategories(categoryId);
      }

      // ✅ Stop listeners for categories that are no longer active
      final existingListenerIds = _subcategoriesSubscriptions.keys.toList();
      for (final categoryId in existingListenerIds) {
        if (!activeCategoryIds.contains(categoryId)) {
          _subcategoriesSubscriptions[categoryId]?.cancel();
          _subcategoriesSubscriptions.remove(categoryId);
          _subcategoriesByCategory.remove(categoryId);

          DebugConfig.print('TP 🔇 stopped subcategories listener for category=$categoryId');
        }
      }

      _isLoading = false;
      _error = null;
      notifyListeners();

      DebugConfig.print(
        '✅ Categories loaded: ${_categories.length} (active: ${activeCategoryIds.length})',
      );

      // ✅ IMPORTANT: first snapshot arrived
      _signalFirstLoadIfNeeded();
    } catch (e) {
      DebugConfig.print('🔴 Error parsing categories: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();

      // ✅ IMPORTANT: do not block charts forever
      _signalFirstLoadIfNeeded();
    }
  }

  void _listenToSubcategories(String categoryUuid) {
    if (_disposed) return;

    final uid = userId.trim();
    if (uid.isEmpty) return;

    _subcategoriesSubscriptions[categoryUuid]?.cancel();

    _subcategoriesSubscriptions[categoryUuid] = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryUuid)
        .collection('subcategories')
        .snapshots()
        .listen(
          (snapshot) {
        if (_disposed) return;
        _onSubcategoriesChanged(categoryUuid, snapshot);
      },
      onError: (Object error) async {
        // ✅ Αν έγινε logout/dispose, απλά αγνόησέ το
        if (_disposed) return;

        // ✅ Αν χάσαμε permissions (συνήθως μετά από logout), σταμάτα τον listener
        final msg = error.toString();
        final isPermissionDenied =
            msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED');

        if (isPermissionDenied) {
          DebugConfig.print(
            '⚠️ Subcategories permission-denied για $categoryUuid -> stopping listener',
          );

          try {
            await _subcategoriesSubscriptions[categoryUuid]?.cancel();
          } catch (_) {}

          _subcategoriesSubscriptions.remove(categoryUuid);
          _subcategoriesByCategory.remove(categoryUuid);
          notifyListeners();
          return;
        }

        DebugConfig.print('🔴 Subcategories error for $categoryUuid: $error');
      },
    );
  }

  void _onSubcategoriesChanged(String categoryUuid, QuerySnapshot snapshot) {
    if (_disposed) return;

    try {
      _subcategoriesByCategory[categoryUuid] = snapshot.docs
          .map((doc) => SubcategoryModel.fromFirestore(doc, categoryUuid))
          .toList();

      // ✅ Μόλις λάβουμε τουλάχιστον ΕΝΑ snapshot subcategories,
      // θεωρούμε ότι τα subcategories έχουν φορτώσει (τουλάχιστον αρχικά).
      if (!_subcategoriesLoaded) {
        _subcategoriesLoaded = true;
      }

      notifyListeners();

      DebugConfig.print(
        '✅ Subcategories loaded for $categoryUuid: ${snapshot.docs.length}',
      );
    } catch (e) {
      DebugConfig.print('🔴 Error parsing subcategories for $categoryUuid: $e');
    }
  }

  void _onError(Object error) {
    if (_disposed) return;

    final msg = error.toString();
    final isPermissionDenied =
        msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED');

    // ✅ Logout / no permission scenario:
    // σταμάτα listeners για να μην πετάνε συνέχεια errors
    if (isPermissionDenied) {
      DebugConfig.print('⚠️ Categories listener permission-denied -> stopping listeners');

      // stop categories listener
      try {
        _categoriesSubscription?.cancel();
      } catch (_) {}
      _categoriesSubscription = null;

      // stop all subcategory listeners
      for (final sub in _subcategoriesSubscriptions.values) {
        try {
          sub.cancel();
        } catch (_) {}
      }
      _subcategoriesSubscriptions.clear();
      _subcategoriesByCategory.clear();

      _isLoading = false;

      // προαιρετικά: μην “κοκκινίζεις” UI σε logout
      _error = null;

      notifyListeners();

      // ✅ μην μπλοκάρεις charts/firstLoad
      _signalFirstLoadIfNeeded();
      return;
    }

    // ✅ Real error (not permission-denied)
    DebugConfig.print('🔴 Categories listener error: $error');
    _error = msg;
    _isLoading = false;
    notifyListeners();

    // ✅ IMPORTANT: do not block charts forever
    _signalFirstLoadIfNeeded();
  }

  // ============================================================
  // LOOKUPS
  // ============================================================

  CategoryModel? getCategoryByUuid(String uuid) {
    try {
      return allCategories.firstWhere((c) => c.uuid == uuid);
    } catch (_) {
      return null;
    }
  }

  SubcategoryModel? getSubcategoryByUuid(
      String categoryUuid,
      String subcategoryUuid,
      ) {
    try {
      final subs = _subcategoriesByCategory[categoryUuid] ?? [];
      return subs.firstWhere((s) => s.uuid == subcategoryUuid);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _disposed = true;

    _categoriesSubscription?.cancel();
    for (final sub in _subcategoriesSubscriptions.values) {
      sub.cancel();
    }
    _subcategoriesSubscriptions.clear();
    _subcategoriesByCategory.clear();

    super.dispose();
  }
}
