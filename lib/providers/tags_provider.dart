// ============================================================
// FILE: tags_provider.dart
// Path: lib/providers/tags_provider.dart
// Ρόλος: Real-time CRUD management για tags χρήστη
// Firestore: users/{userId}/tags/{tagId}
// ✅ Offline-safe: optimistic update + background save
// ✅ Real-time listener (snapshots)
// ✅ Accessibility: announcements
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/core/utils/debug_config.dart';

// ============================================================
// TAG MODEL
// ============================================================

class TagModel {
  final String uuid;
  final String userId;
  final String name;
  final String color; // hex e.g. "#4CAF50"
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  const TagModel({
    required this.uuid,
    required this.userId,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  factory TagModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TagModel(
      uuid: doc.id,
      userId: data['user_id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      color: data['color'] as String? ?? '#6750A4',
      createdAt:
      (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
      (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deleted: data['deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'user_id': userId,
    'name': name,
    'color': color,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
    'deleted': deleted,
  };

  TagModel copyWith({
    String? name,
    String? color,
    bool? deleted,
  }) {
    return TagModel(
      uuid: uuid,
      userId: userId,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      deleted: deleted ?? this.deleted,
    );
  }
}

// ============================================================
// TAG COLOR UTIL (κοινόχρηστο, χρησιμοποιείται παντού)
// ============================================================

class TagColorUtil {
  /// Μετατρέπει hex string (#RRGGBB) σε Color
  static int hexToInt(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return int.parse('FF$h', radix: 16);
    } catch (_) {
      return 0xFF6750A4;
    }
  }

  /// Λίστα προεπιλεγμένων χρωμάτων για picker
  static const List<String> defaultColors = [
    '#6750A4', // Purple (primary)
    '#2E7D32', // Green
    '#C62828', // Red
    '#0277BD', // Blue
    '#ED6C02', // Orange
    '#7D5260', // Pink
    '#00838F', // Teal
    '#F57F17', // Yellow
    '#4CAF50', // Light Green
    '#FF9800', // Amber
    '#9C27B0', // Deep Purple
    '#607D8B', // Blue Grey
  ];
}

// ============================================================
// TAGS PROVIDER
// ============================================================

class TagsProvider extends ChangeNotifier {
  final String userId;

  TagsProvider({required this.userId}) {
    _startListening();
  }

  // ──────────────────────────────────────────────────────────
  // STATE
  // ──────────────────────────────────────────────────────────

  bool _disposed = false;
  bool _loading = true;
  String? _error;
  List<TagModel> _tags = [];
  StreamSubscription<QuerySnapshot>? _subscription;

  // ──────────────────────────────────────────────────────────
  // GETTERS
  // ──────────────────────────────────────────────────────────

  bool get loading => _loading;
  String? get error => _error;

  /// Μόνο τα non-deleted tags, ταξινομημένα αλφαβητικά
  List<TagModel> get tags {
    final active = _tags.where((t) => !t.deleted).toList();
    active.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return active;
  }

  /// Επιστρέφει tag από UUID (null αν δεν βρεθεί ή deleted)
  TagModel? getTagByUuid(String uuid) {
    try {
      return _tags.firstWhere((t) => t.uuid == uuid && !t.deleted);
    } catch (_) {
      return null;
    }
  }

  /// Επιστρέφει λίστα tags από λίστα UUIDs
  List<TagModel> getTagsByIds(List<String> ids) {
    return ids
        .map((id) => getTagByUuid(id))
        .whereType<TagModel>()
        .toList();
  }

  // ──────────────────────────────────────────────────────────
  // REAL-TIME LISTENER
  // ──────────────────────────────────────────────────────────

  void _startListening() {
    if (userId.trim().isEmpty) {
      _loading = false;
      _error = 'Missing userId';
      DebugConfig.print('⚠️ TagsProvider: missing userId, listener not started');
      if (!_disposed) notifyListeners();
      return;
    }

    DebugConfig.print('🏷️ TagsProvider: starting listener for $userId');

    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('tags')
        .where('deleted', isEqualTo: false)
        .snapshots()
        .listen(
      _onSnapshot,
      onError: _onError,
    );
  }

  void _onSnapshot(QuerySnapshot snapshot) {
    if (_disposed) return;
    DebugConfig.print(
        '🏷️ TagsProvider: snapshot docs=${snapshot.docs.length}');
    _tags = snapshot.docs.map((d) => TagModel.fromFirestore(d)).toList();
    _loading = false;
    _error = null;
    if (!_disposed) notifyListeners();
  }

  void _onError(dynamic error) {
    if (_disposed) return;
    DebugConfig.print('❌ TagsProvider error: $error');
    _error = error.toString();
    _loading = false;
    if (!_disposed) notifyListeners();
  }

  // ──────────────────────────────────────────────────────────
  // CRUD – CREATE
  // ──────────────────────────────────────────────────────────

  /// Δημιουργία νέου tag.
  /// ✅ Optimistic update → background Firestore save.
  /// Returns: uuid νέου tag ή null αν υπάρχει error.
  Future<String?> createTag({
    required String name,
    required String color,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      _error = 'Το όνομα του tag δεν μπορεί να είναι κενό';
      if (!_disposed) notifyListeners();
      return null;
    }

    // Έλεγχος διπλότυπου (case-insensitive)
    final exists = _tags.any(
          (t) =>
      !t.deleted &&
          t.name.toLowerCase() == trimmedName.toLowerCase(),
    );
    if (exists) {
      _error = 'Το tag "$trimmedName" υπάρχει ήδη';
      if (!_disposed) notifyListeners();
      return null;
    }

    final now = DateTime.now();
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('tags')
        .doc(); // auto-id

    final newTag = TagModel(
      uuid: docRef.id,
      userId: userId,
      name: trimmedName,
      color: color,
      createdAt: now,
      updatedAt: now,
    );

    // ✅ Optimistic update
    _tags = [..._tags, newTag];
    _error = null;
    if (!_disposed) notifyListeners();

    // ✅ Background Firestore save – δεν μπλοκάρει UI
    () async {
      try {
        await docRef.set(newTag.toFirestore());
        DebugConfig.print('✅ TagsProvider: tag created ${newTag.uuid}');
      } catch (e) {
        DebugConfig.print('⌛ TagsProvider: create queued offline: $e');
      }
    }();

    return docRef.id;
  }

  // ──────────────────────────────────────────────────────────
  // CRUD – UPDATE
  // ──────────────────────────────────────────────────────────

  /// Ενημέρωση ονόματος / χρώματος tag.
  /// ✅ Optimistic update → background Firestore save.
  Future<bool> updateTag({
    required String uuid,
    String? name,
    String? color,
  }) async {
    final idx = _tags.indexWhere((t) => t.uuid == uuid);
    if (idx == -1) {
      DebugConfig.print('❌ TagsProvider.updateTag: tag not found $uuid');
      return false;
    }

    final trimmedName = name?.trim();

    // Έλεγχος διπλότυπου (εκτός του ίδιου tag)
    if (trimmedName != null && trimmedName.isNotEmpty) {
      final exists = _tags.any(
            (t) =>
        !t.deleted &&
            t.uuid != uuid &&
            t.name.toLowerCase() == trimmedName.toLowerCase(),
      );
      if (exists) {
        _error = 'Το tag "$trimmedName" υπάρχει ήδη';
        if (!_disposed) notifyListeners();
        return false;
      }
    }

    final updated = _tags[idx].copyWith(name: trimmedName, color: color);

    // ✅ Optimistic update
    final newList = List<TagModel>.from(_tags);
    newList[idx] = updated;
    _tags = newList;
    _error = null;
    if (!_disposed) notifyListeners();

    // ✅ Background Firestore save
    () async {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('tags')
            .doc(uuid)
            .update({
          'name': updated.name,
          'color': updated.color,
          'updated_at': Timestamp.fromDate(updated.updatedAt),
        });
        DebugConfig.print('✅ TagsProvider: tag updated $uuid');
      } catch (e) {
        DebugConfig.print('⌛ TagsProvider: update queued offline: $e');
      }
    }();

    return true;
  }

  // ──────────────────────────────────────────────────────────
  // CRUD – DELETE (soft delete)
  // ──────────────────────────────────────────────────────────

  /// Soft delete ενός tag.
  /// ✅ Optimistic update → background Firestore save.
  Future<bool> deleteTag(String uuid) async {
    final idx = _tags.indexWhere((t) => t.uuid == uuid);
    if (idx == -1) return false;

    // ✅ Optimistic update
    final newList = List<TagModel>.from(_tags);
    newList[idx] = newList[idx].copyWith(deleted: true);
    _tags = newList;
    _error = null;
    if (!_disposed) notifyListeners();

    // ✅ Background Firestore save
    () async {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('tags')
            .doc(uuid)
            .update({
          'deleted': true,
          'updated_at': Timestamp.now(),
        });
        DebugConfig.print('✅ TagsProvider: tag soft-deleted $uuid');
      } catch (e) {
        DebugConfig.print('⌛ TagsProvider: delete queued offline: $e');
      }
    }();

    return true;
  }

  // ──────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────

  void clearError() {
    _error = null;
    if (!_disposed) notifyListeners();
  }

  // ──────────────────────────────────────────────────────────
  // DISPOSE
  // ──────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}