// ============================================================
// FILE: notification_model.dart
// Path: lib/models/notification_model.dart
// Ρόλος: Data model για user notifications με reminder
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String uuid;
  final String userId;
  final String? deviceId;
  final String type; // 'reminder', 'budget_alert', 'scheduled_transaction', etc.
  final String title;
  final String message;
  final DateTime scheduledFor; // Πότε θα εμφανιστεί
  final String? relatedId;
  final String? relatedType;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? dismissedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastModifiedDeviceId;
  final bool deleted;

  // ✅ RECURRING SUPPORT
  final bool isRecurring;
  final String? frequency; // daily | weekly | monthly
  final int? frequencyInterval; // 1,2,3...
  final bool skipWeekends;

  // ✅ RECURRING SERIES SUPPORT (optional / backward compatible)
  final String? seriesId; // stable id for recurring chain
  final int? occurrenceIndex; // 0,1,2...

  // ✅ STOP CONDITIONS (optional fields, but will be enforced when isRecurring=true)
  final DateTime? recurringEndAt; // Firestore: recurring_end_at
  final int? maxOccurrences; // Firestore: max_occurrences (total including root)

  NotificationModel({
    required this.uuid,
    required this.userId,
    this.deviceId,
    required this.type,
    required this.title,
    required this.message,
    required this.scheduledFor,
    this.relatedId,
    this.relatedType,
    this.deliveredAt,
    this.readAt,
    this.dismissedAt,
    required this.createdAt,
    required this.updatedAt,
    this.lastModifiedDeviceId,
    required this.deleted,

    // ✅ RECURRING DEFAULTS (backward compatible)
    this.isRecurring = false,
    this.frequency,
    this.frequencyInterval,
    this.skipWeekends = false,

    // ✅ SERIES DEFAULTS (backward compatible)
    this.seriesId,
    this.occurrenceIndex,

    // ✅ STOP CONDITIONS DEFAULTS (backward compatible)
    this.recurringEndAt,
    this.maxOccurrences,
  });

  // ============================================================
  // FACTORY: FROM FIRESTORE
  // ============================================================

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return NotificationModel(
      uuid: doc.id,
      userId: data['user_id'] as String,
      deviceId: data['device_id'] as String?,
      type: data['type'] as String? ?? 'reminder',
      title: data['title'] as String,
      message: data['message'] as String,
      scheduledFor: _parseTimestamp(data['scheduled_for']),
      relatedId: data['related_id'] as String?,
      relatedType: data['related_type'] as String?,
      deliveredAt: _parseTimestampNullable(data['delivered_at']),
      readAt: _parseTimestampNullable(data['read_at']),
      dismissedAt: _parseTimestampNullable(data['dismissed_at']),
      createdAt: _parseTimestamp(data['created_at']),
      updatedAt: _parseTimestamp(data['updated_at']),
      lastModifiedDeviceId: data['last_modified_device_id'] as String?,
      deleted: data['deleted'] as bool? ?? false,

      // ✅ RECURRING (optional fields)
      isRecurring: data['is_recurring'] as bool? ?? false,
      frequency: data['frequency'] as String?,
      frequencyInterval: (data['frequency_interval'] as num?)?.toInt(),
      skipWeekends: data['skip_weekends'] as bool? ?? false,

      // ✅ SERIES (optional fields)
      seriesId: data['series_id'] as String?,
      occurrenceIndex: (data['occurrence_index'] as num?)?.toInt(),

      // ✅ STOP CONDITIONS (optional fields)
      recurringEndAt: _parseTimestampNullable(data['recurring_end_at']),
      maxOccurrences: (data['max_occurrences'] as num?)?.toInt(),
    );
  }

  // ============================================================
  // TO MAP (για Firestore)
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'device_id': deviceId,
      'type': type,
      'title': title,
      'message': message,
      'scheduled_for': Timestamp.fromDate(scheduledFor),
      'related_id': relatedId,
      'related_type': relatedType,
      'delivered_at': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'read_at': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'dismissed_at': dismissedAt != null ? Timestamp.fromDate(dismissedAt!) : null,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'last_modified_device_id': lastModifiedDeviceId,
      'deleted': deleted,

      // ✅ RECURRING
      'is_recurring': isRecurring,
      'frequency': frequency,
      'frequency_interval': frequencyInterval,
      'skip_weekends': skipWeekends,

      // ✅ SERIES
      'series_id': seriesId,
      'occurrence_index': occurrenceIndex,

      // ✅ STOP CONDITIONS
      'recurring_end_at': recurringEndAt != null ? Timestamp.fromDate(recurringEndAt!) : null,
      'max_occurrences': maxOccurrences,
    };
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  static DateTime? _parseTimestampNullable(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.parse(value);
    return null;
  }

  // ✅ Check if notification is pending (not delivered yet)
  bool get isPending => deliveredAt == null && !deleted;

  // ✅ Check if notification should be shown now
  bool get shouldShowNow {
    if (deleted || deliveredAt != null) return false;
    return scheduledFor.isBefore(DateTime.now()) ||
        scheduledFor.isAtSameMomentAs(DateTime.now());
  }

  // ✅ Check if notification is in the future
  bool get isFuture => scheduledFor.isAfter(DateTime.now());

  // ✅ Copy with modifications
  NotificationModel copyWith({
    String? uuid,
    String? userId,
    String? deviceId,
    String? type,
    String? title,
    String? message,
    DateTime? scheduledFor,
    String? relatedId,
    String? relatedType,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? dismissedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastModifiedDeviceId,
    bool? deleted,

    // ✅ recurring
    bool? isRecurring,
    String? frequency,
    int? frequencyInterval,
    bool? skipWeekends,

    // ✅ series
    String? seriesId,
    int? occurrenceIndex,

    // ✅ stop conditions
    DateTime? recurringEndAt,
    int? maxOccurrences,
  }) {
    return NotificationModel(
      uuid: uuid ?? this.uuid,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      relatedId: relatedId ?? this.relatedId,
      relatedType: relatedType ?? this.relatedType,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModifiedDeviceId: lastModifiedDeviceId ?? this.lastModifiedDeviceId,
      deleted: deleted ?? this.deleted,

      // ✅ recurring
      isRecurring: isRecurring ?? this.isRecurring,
      frequency: frequency ?? this.frequency,
      frequencyInterval: frequencyInterval ?? this.frequencyInterval,
      skipWeekends: skipWeekends ?? this.skipWeekends,

      // ✅ series
      seriesId: seriesId ?? this.seriesId,
      occurrenceIndex: occurrenceIndex ?? this.occurrenceIndex,

      // ✅ stop conditions
      recurringEndAt: recurringEndAt ?? this.recurringEndAt,
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
    );
  }
}
