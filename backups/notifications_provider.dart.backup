// ============================================================
// FILE: notifications_provider.dart (OFFLINE-FIRST)
// Path: lib/providers/notifications_provider.dart
// Ρόλος: Firestore listener + Offline-first local scheduling
// ✅ IMPROVED: diff-based reschedule on startup (no cancelAll sweep)
// ✅ IMPROVED: cancel local on delivered
// ✅ IMPROVED: fewer service calls, better logs, stable "now"
// ✅ IMPROVED: best-effort permission checks for local scheduling
// ✅ IMPROVED: recurring fields persisted (create/update)
// ✅ NEW: recurring engine (spawn next occurrence on delivered) + catch-up on startup
// ✅ NEW: autonomous recurring engine (periodic catch-up while app is running)
// ✅ NEW: REQUIRED stop condition for recurring (end date OR max occurrences)
// ============================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/models/notification_model.dart';
import 'package:family_economy/services/notifications_service.dart';

class NotificationsProvider extends ChangeNotifier {
  final String userId;

  StreamSubscription<QuerySnapshot>? _subscription;

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _error;

  bool _didInitialReschedule = false;
  Timer? _rescheduleDebounce;

  // ✅ NEW: autonomous recurring catch-up timer
  Timer? _autoRecurringTimer;

  // ✅ Guard to prevent duplicate catch-up processing (offline-safe)
  final Set<String> _catchUpInProgress = <String>{};

  bool _disposed = false;

  NotificationsProvider({required this.userId}) {
    _initListener();

    // ✅ NEW: start autonomous recurring engine
    _startAutoRecurringEngine();
  }

  // ============================================================
  // GETTERS
  // ============================================================

  List<NotificationModel> get allNotifications => _notifications;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasNotifications => _notifications.isNotEmpty;

  // ✅ Get notifications for specific date
  List<NotificationModel> getNotificationsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _notifications
        .where((n) {
      return !n.deleted &&
          n.scheduledFor.isAfter(
            startOfDay.subtract(const Duration(seconds: 1)),
          ) &&
          n.scheduledFor.isBefore(
            endOfDay.add(const Duration(seconds: 1)),
          );
    })
        .toList()
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
  }

  // ✅ Pending = not delivered and not deleted
  List<NotificationModel> get pendingNotifications {
    return _notifications.where((n) => n.isPending).toList()
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
  }

  List<NotificationModel> get notificationsDueNow {
    return _notifications.where((n) => n.shouldShowNow).toList();
  }

  // ============================================================
  // REAL-TIME LISTENER
  // ============================================================

  void _initListener() {
    DebugConfig.print('→ NotificationsProvider: start listener (userId=$userId)');

    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .snapshots()
        .listen(
      _onNotificationsChanged,
      onError: _onError,
    );
  }

  void _onNotificationsChanged(QuerySnapshot snapshot) {
    try {
      final parsed =
      snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList();

      _notifications = parsed;

      _isLoading = false;
      _error = null;
      notifyListeners();

      DebugConfig.print(
        '✅ Notifications loaded: ${_notifications.length} '
            '(fromCache=${snapshot.metadata.isFromCache}, '
            'pendingWrites=${snapshot.metadata.hasPendingWrites})',
      );

      // ✅ 1-time initial reschedule (debounced)
      if (!_didInitialReschedule) {
        _didInitialReschedule = true;

        _rescheduleDebounce?.cancel();
        _rescheduleDebounce = Timer(const Duration(milliseconds: 300), () {
          // ignore: unawaited_futures
          _rescheduleFutureLocalNotificationsOnce();
        });
      }
    } catch (e) {
      DebugConfig.print('🔴 Error parsing notifications: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onError(Object error) {
    DebugConfig.print('🔴 Notifications listener error: $error');
    _error = error.toString();
    _isLoading = false;
    notifyListeners();
  }

  // ============================================================
  // STARTUP RESCHEDULE (DIFF-BASED)
  // ============================================================

  Future<void> _rescheduleFutureLocalNotificationsOnce() async {
    try {
      final svc = NotificationsService();
      final now = DateTime.now();

      // ✅ Catch-up missed recurring (best-effort)
      await _catchUpMissedRecurring(now);

      // Future + not deleted + pending
      final future = _notifications
          .where((n) => !n.deleted && n.isPending && n.scheduledFor.isAfter(now))
          .toList()
        ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));

      DebugConfig.print('🔁 Reschedule (startup): ${future.length} future reminders');

      // Αν δεν έχουμε permissions, skip local reschedule
      final hasPerm = await svc.hasPermissions();
      if (!hasPerm) {
        DebugConfig.print('⚠️ No notification permissions. Skipping local reschedule.');
        return;
      }

      // Pending from plugin
      final pending = await svc.getPendingNotifications();

      // Desired ids from Firestore list
      final desiredIds = future.map((n) => _stableIdFromUuid(n.uuid)).toSet();

      // 1) Cancel pending we don't want
      for (final p in pending) {
        if (!desiredIds.contains(p.id)) {
          final uuid = _uuidFromPayloadOrNull(p);
          try {
            if (uuid != null) {
              await svc.cancelNotification(uuid);
            } else {
              await svc.cancelNotificationById(p.id);
            }
          } catch (e) {
            DebugConfig.print(
              '⚠️ Reschedule cancel failed (id=${p.id}, uuid=${uuid ?? "null"}): $e',
            );
          }
        }
      }

      // 2) Schedule desired that are missing
      final pendingIds = pending.map((p) => p.id).toSet();
      for (final n in future) {
        final id = _stableIdFromUuid(n.uuid);
        if (!pendingIds.contains(id)) {
          await svc.scheduleNotification(n);
        }
      }

      DebugConfig.print('✅ Reschedule complete (diff-based)');
    } catch (e) {
      DebugConfig.print('⚠️ Reschedule failed: $e');
    }
  }

  // ✅ stable-id (same algo as service)
  int _stableIdFromUuid(String uuid) {
    const int fnvPrime = 16777619;
    const int fnvOffset = 2166136261;

    var hash = fnvOffset;
    for (final c in uuid.codeUnits) {
      hash ^= c;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  String? _uuidFromPayloadOrNull(PendingNotificationRequest p) {
    final payload = p.payload;
    if (payload == null || payload.trim().isEmpty) return null;
    return payload.trim();
  }

  // ============================================================
  // ✅ AUTONOMOUS RECURRING ENGINE (NO TAP NEEDED)
  // ============================================================

  void _startAutoRecurringEngine() {
    // prevent duplicates (hot-restart safety)
    _autoRecurringTimer?.cancel();

    // Run soon once (after a tiny delay) to avoid racing initial build
    Timer(const Duration(seconds: 3), () async {
      if (_disposed) return;
      try {
        final now = DateTime.now();

        // ✅ 1) Catch-up missed recurring
        await _catchUpMissedRecurring(now);

        // ✅ 2) Auto-deliver overdue non-recurring (so pending doesn't stay forever)
        await _autoDeliverOverdueNonRecurring(now);
      } catch (e) {
        DebugConfig.print('⚠️ Auto engine initial run failed: $e');
      }
    });

    // Then keep running periodically
    _autoRecurringTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      if (_disposed) return;
      try {
        // avoid work if still loading first snapshot
        if (_isLoading) return;

        final now = DateTime.now();

        // ✅ 1) Catch-up missed recurring
        await _catchUpMissedRecurring(now);

        // ✅ 2) Auto-deliver overdue non-recurring
        await _autoDeliverOverdueNonRecurring(now);
      } catch (e) {
        DebugConfig.print('⚠️ Auto engine periodic run failed: $e');
      }
    });

    DebugConfig.print('🤖 Auto engine started (every 2 minutes)');
  }


  // ============================================================
  // RECURRING ENGINE HELPERS
  // ============================================================

  DateTime _shiftToMondayIfWeekend(DateTime dt) {
    // Saturday = 6, Sunday = 7
    if (dt.weekday == DateTime.saturday) return dt.add(const Duration(days: 2));
    if (dt.weekday == DateTime.sunday) return dt.add(const Duration(days: 1));
    return dt;
  }

  DateTime _safeAddMonths(DateTime base, int monthsToAdd) {
    final y = base.year;
    final m = base.month + monthsToAdd;

    final targetYear = y + ((m - 1) ~/ 12);
    final targetMonth = ((m - 1) % 12) + 1;

    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final day = base.day <= lastDay ? base.day : lastDay;

    return DateTime(
      targetYear,
      targetMonth,
      day,
      base.hour,
      base.minute,
      base.second,
      base.millisecond,
      base.microsecond,
    );
  }

  DateTime _computeNextOccurrence(NotificationModel n) {
    final freq = (n.frequency ?? 'daily').trim();
    final interval = (n.frequencyInterval ?? 1).clamp(1, 365);

    DateTime next;
    switch (freq) {
      case 'weekly':
        next = n.scheduledFor.add(Duration(days: 7 * interval));
        break;
      case 'monthly':
        next = _safeAddMonths(n.scheduledFor, interval);
        break;
      case 'daily':
      default:
        next = n.scheduledFor.add(Duration(days: interval));
        break;
    }

    if (n.skipWeekends) {
      next = _shiftToMondayIfWeekend(next);
    }

    return next;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isNextAllowedByStopCondition({
    required NotificationModel current,
    required DateTime nextScheduledFor,
  }) {
    // If neither is present, treat as "not allowed" (because recurring must have stop condition)
    final hasEnd = current.recurringEndAt != null;
    final hasMax = (current.maxOccurrences ?? 0) > 0;

    if (!hasEnd && !hasMax) return false;

    var ok = true;

    // ✅ end date (inclusive by date)
    if (hasEnd) {
      final endOnly = _dateOnly(current.recurringEndAt!);
      final nextOnly = _dateOnly(nextScheduledFor);
      if (nextOnly.isAfter(endOnly)) ok = false;
    }

    // ✅ max occurrences: occurrenceIndex starts at 0 (root). Total allowed = maxOccurrences.
    if (hasMax) {
      final nextIndex = (current.occurrenceIndex ?? 0) + 1;
      final max = current.maxOccurrences!;
      // indices allowed: 0 .. max-1
      if (nextIndex >= max) ok = false;
    }

    return ok;
  }

  Future<void> _spawnNextRecurringOccurrence(NotificationModel current) async {
    if (!current.isRecurring) return;
    if (current.deleted) return;

    final now = DateTime.now();

    // compute next
    var nextScheduledFor = _computeNextOccurrence(current);

    // ensure it's in the future (guard to avoid loops)
    int guard = 0;
    while (!nextScheduledFor.isAfter(now) && guard < 10) {
      final temp = current.copyWith(scheduledFor: nextScheduledFor);
      nextScheduledFor = _computeNextOccurrence(temp);
      guard++;
    }

    // ✅ stop condition check (MUST stop if out of bounds)
    if (!_isNextAllowedByStopCondition(
      current: current,
      nextScheduledFor: nextScheduledFor,
    )) {
      DebugConfig.print(
        '⛔ Recurring stopped (series=${current.seriesId ?? current.uuid}) '
            'next=$nextScheduledFor endAt=${current.recurringEndAt} maxOcc=${current.maxOccurrences}',
      );
      return;
    }

    final newUuid = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc()
        .id;

    final seriesId = current.seriesId ?? current.uuid;

    final next = NotificationModel(
      uuid: newUuid,
      userId: userId,
      deviceId: current.deviceId,
      type: current.type,
      title: current.title,
      message: current.message,
      scheduledFor: nextScheduledFor,
      relatedId: current.relatedId,
      relatedType: current.relatedType,
      deliveredAt: null,
      readAt: null,
      dismissedAt: null,
      createdAt: now,
      updatedAt: now,
      lastModifiedDeviceId: current.lastModifiedDeviceId,
      deleted: false,

      isRecurring: true,
      frequency: current.frequency,
      frequencyInterval: current.frequencyInterval ?? 1,
      skipWeekends: current.skipWeekends,

      seriesId: seriesId,
      occurrenceIndex: (current.occurrenceIndex ?? 0) + 1,

      // ✅ stop condition propagated
      recurringEndAt: current.recurringEndAt,
      maxOccurrences: current.maxOccurrences,
    );

    final svc = NotificationsService();

    // local schedule best-effort
    final hasPerm = await svc.hasPermissions();
    if (hasPerm) {
      await svc.scheduleNotification(next);
    } else {
      DebugConfig.print('⚠️ No permissions -> skipping local schedule for next occurrence');
    }

    // Firestore write (offline-safe)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(newUuid)
        .set(next.toMap());

    DebugConfig.print(
      '🔁 Spawned next recurring occurrence: $newUuid (series=$seriesId, at=$nextScheduledFor)',
    );
  }

  Future<void> _catchUpMissedRecurring(DateTime now) async {
    // Grace so we don't race with "due now"
    final grace = now.subtract(const Duration(minutes: 2));

    final missed = _notifications
        .where(
          (n) =>
      !n.deleted &&
          n.isRecurring &&
          n.isPending &&
          n.scheduledFor.isBefore(grace),
    )
        .toList()
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));

    if (missed.isEmpty) return;

    // guard: avoid huge loops on startup
    final toProcess = missed.length > 25 ? missed.take(25).toList() : missed;

    // ✅ Filter out ones already being processed (prevents double spawn in offline)
    final filtered = <NotificationModel>[];
    for (final n in toProcess) {
      if (_catchUpInProgress.contains(n.uuid)) continue;
      filtered.add(n);
    }

    if (filtered.isEmpty) return;

    DebugConfig.print('🧹 Catch-up missed recurring: ${filtered.length}');

    for (final n in filtered) {
      // lock
      _catchUpInProgress.add(n.uuid);

      try {
        await markAsDelivered(n.uuid);
      } catch (e) {
        DebugConfig.print('⚠️ Catch-up failed for ${n.uuid}: $e');
      } finally {
        // unlock
        _catchUpInProgress.remove(n.uuid);
      }
    }
  }

  // ✅ NEW: auto-deliver overdue NON-recurring notifications (offline-safe)
  Future<void> _autoDeliverOverdueNonRecurring(DateTime now) async {
    // Same grace window as recurring catch-up to avoid racing "due now"
    final grace = now.subtract(const Duration(minutes: 2));

    final overdue = _notifications
        .where(
          (n) =>
      !n.deleted &&
          !n.isRecurring &&
          n.isPending &&
          n.scheduledFor.isBefore(grace),
    )
        .toList()
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));

    if (overdue.isEmpty) return;

    // Guard: avoid huge loops on startup
    final toProcess = overdue.length > 25 ? overdue.take(25).toList() : overdue;

    // Reuse existing guard set to prevent double processing (offline-safe)
    final filtered = <NotificationModel>[];
    for (final n in toProcess) {
      if (_catchUpInProgress.contains(n.uuid)) continue;
      filtered.add(n);
    }

    if (filtered.isEmpty) return;

    DebugConfig.print('🧾 Auto-deliver overdue non-recurring: ${filtered.length}');

    for (final n in filtered) {
      _catchUpInProgress.add(n.uuid);
      try {
        await markAsDelivered(n.uuid);
      } catch (e) {
        DebugConfig.print('⚠️ Auto-deliver failed for ${n.uuid}: $e');
      } finally {
        _catchUpInProgress.remove(n.uuid);
      }
    }
  }


  // ============================================================
  // CRUD OPERATIONS (OFFLINE-FIRST local scheduling)
  // ============================================================

  /// Create new notification (offline-first)
  Future<String> createNotification({
    required String title,
    required String message,
    required DateTime scheduledFor,
    String type = 'reminder',
    String? relatedId,
    String? relatedType,

    // ✅ recurring
    bool isRecurring = false,
    String? frequency, // daily|weekly|monthly
    int? frequencyInterval, // 1,2,3...
    bool skipWeekends = false,

    // ✅ REQUIRED stop condition (when recurring)
    DateTime? recurringEndAt, // date-only preferred
    int? maxOccurrences, // total (including root)
  }) async {
    final now = DateTime.now();

    // ✅ Validate recurring constraints (only daily/weekly/monthly)
    if (isRecurring) {
      const allowed = {'daily', 'weekly', 'monthly'};
      final f = (frequency ?? '').trim();
      if (!allowed.contains(f)) {
        throw Exception('Invalid frequency. Use: daily | weekly | monthly');
      }
      if ((frequencyInterval ?? 1) <= 0) {
        throw Exception('Invalid frequency_interval (must be >= 1)');
      }

      // ✅ stop condition required: end date OR max occurrences
      final hasEnd = recurringEndAt != null;
      final hasMax = (maxOccurrences ?? 0) > 0;
      if (!hasEnd && !hasMax) {
        throw Exception('Recurring requires end date OR max occurrences');
      }
      if (hasEnd && hasMax) {
        // keep safe: allow but it will stop on whichever triggers first
        DebugConfig.print('⚠️ Recurring has BOTH endAt and maxOccurrences; will stop by both limits.');
      }
      if (hasEnd) {
        final endOnly = DateTime(recurringEndAt.year, recurringEndAt.month, recurringEndAt.day);
        final firstOnly = DateTime(scheduledFor.year, scheduledFor.month, scheduledFor.day);
        if (endOnly.isBefore(firstOnly)) {
          throw Exception('Recurring end date cannot be before first occurrence');
        }
        recurringEndAt = endOnly;
      }
      if (hasMax && (maxOccurrences ?? 0) < 1) {
        throw Exception('maxOccurrences must be >= 1');
      }
    } else {
      recurringEndAt = null;
      maxOccurrences = null;
    }

    final uuid = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc()
        .id;

    final notification = NotificationModel(
      uuid: uuid,
      userId: userId,
      type: type,
      title: title,
      message: message,
      scheduledFor: scheduledFor,
      relatedId: relatedId,
      relatedType: relatedType,
      deliveredAt: null,
      readAt: null,
      dismissedAt: null,
      createdAt: now,
      updatedAt: now,
      deleted: false,

      // ✅ RECURRING
      isRecurring: isRecurring,
      frequency: isRecurring ? frequency : null,
      frequencyInterval: isRecurring ? (frequencyInterval ?? 1) : null,
      skipWeekends: isRecurring ? skipWeekends : false,

      // ✅ SERIES (only for recurring)
      seriesId: isRecurring ? uuid : null,
      occurrenceIndex: isRecurring ? 0 : null,

      // ✅ STOP CONDITION
      recurringEndAt: isRecurring ? recurringEndAt : null,
      maxOccurrences: isRecurring ? maxOccurrences : null,
    );

    final svc = NotificationsService();

    try {
      // 1) Local schedule first (best-effort)
      final hasPerm = await svc.hasPermissions();
      if (hasPerm) {
        await svc.scheduleNotification(notification);
      } else {
        DebugConfig.print('⚠️ No permissions -> skipping local schedule for $uuid');
      }

      // 2) Firestore write (offline → pending writes)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(uuid)
          .set(notification.toMap());

      DebugConfig.print('✅ Notification created: $uuid');
      return uuid;
    } catch (e) {
      DebugConfig.print('🔴 Error creating notification: $e');

      // cleanup possible local schedule
      try {
        await svc.cancelNotification(uuid);
      } catch (_) {}

      rethrow;
    }
  }

  /// Update existing notification (offline-first)
  Future<void> updateNotification({
    required String notificationId,
    String? title,
    String? message,
    DateTime? scheduledFor,

    // ✅ recurring (optional)
    bool? isRecurring,
    String? frequency,
    int? frequencyInterval,
    bool? skipWeekends,

    // ✅ stop condition (optional)
    DateTime? recurringEndAt,
    int? maxOccurrences,
  }) async {
    final svc = NotificationsService();
    final now = DateTime.now();

    try {
      final existing = _notifications.cast<NotificationModel?>().firstWhere(
            (n) => n?.uuid == notificationId,
        orElse: () => null,
      );

      final newTitle = title ?? existing?.title ?? 'Υπενθύμιση';
      final newMessage = message ?? existing?.message ?? '';
      final newScheduledFor = scheduledFor ?? existing?.scheduledFor ?? now;

      // ✅ Determine final recurring state (keep existing if null)
      final finalIsRecurring = isRecurring ?? existing?.isRecurring ?? false;

      // ✅ Determine final stop condition values (keep existing if null)
      DateTime? finalEndAt = recurringEndAt ?? existing?.recurringEndAt;
      int? finalMaxOcc = maxOccurrences ?? existing?.maxOccurrences;

      if (finalIsRecurring) {
        const allowed = {'daily', 'weekly', 'monthly'};
        final f = (frequency ?? existing?.frequency ?? '').trim();
        if (!allowed.contains(f)) {
          throw Exception('Invalid frequency. Use: daily | weekly | monthly');
        }
        final interval = frequencyInterval ?? existing?.frequencyInterval ?? 1;
        if (interval <= 0) {
          throw Exception('Invalid frequency_interval (must be >= 1)');
        }

        // ✅ stop condition required
        final hasEnd = finalEndAt != null;
        final hasMax = (finalMaxOcc ?? 0) > 0;
        if (!hasEnd && !hasMax) {
          throw Exception('Recurring requires end date OR max occurrences');
        }
        if (hasEnd) {
          final endOnly = DateTime(finalEndAt.year, finalEndAt.month, finalEndAt.day);
          final firstOnly = DateTime(newScheduledFor.year, newScheduledFor.month, newScheduledFor.day);
          if (endOnly.isBefore(firstOnly)) {
            throw Exception('Recurring end date cannot be before first occurrence');
          }
          finalEndAt = endOnly;
        }
        if (hasMax && (finalMaxOcc ?? 0) < 1) {
          throw Exception('maxOccurrences must be >= 1');
        }
      } else {
        finalEndAt = null;
        finalMaxOcc = null;
      }

      // 1) Local cancel first (best-effort)
      try {
        await svc.cancelNotification(notificationId);
      } catch (_) {}

      // If new time is in the past -> don't reschedule locally
      if (newScheduledFor.isBefore(now)) {
        DebugConfig.print('⚠️ Update scheduledFor in the past -> local not scheduled');
      } else {
        final hasPerm = await svc.hasPermissions();
        if (hasPerm) {
          final localUpdated = NotificationModel(
            uuid: notificationId,
            userId: userId,
            type: existing?.type ?? 'reminder',
            title: newTitle,
            message: newMessage,
            scheduledFor: newScheduledFor,
            relatedId: existing?.relatedId,
            relatedType: existing?.relatedType,
            deliveredAt: existing?.deliveredAt,
            readAt: existing?.readAt,
            dismissedAt: existing?.dismissedAt,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            deleted: existing?.deleted ?? false,

            // ✅ RECURRING
            isRecurring: finalIsRecurring,
            frequency: finalIsRecurring ? (frequency ?? existing?.frequency) : null,
            frequencyInterval: finalIsRecurring
                ? (frequencyInterval ?? existing?.frequencyInterval ?? 1)
                : null,
            skipWeekends: finalIsRecurring
                ? (skipWeekends ?? existing?.skipWeekends ?? false)
                : false,

            // (seriesId/occurrenceIndex αφήνονται ως έχουν)
            seriesId: existing?.seriesId,
            occurrenceIndex: existing?.occurrenceIndex,

            // ✅ STOP CONDITION
            recurringEndAt: finalIsRecurring ? finalEndAt : null,
            maxOccurrences: finalIsRecurring ? finalMaxOcc : null,
          );

          await svc.scheduleNotification(localUpdated);
        } else {
          DebugConfig.print('⚠️ No permissions -> skipping local reschedule for $notificationId');
        }
      }

      // 2) Firestore update (offline-safe)
      final updates = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (title != null) updates['title'] = title;
      if (message != null) updates['message'] = message;
      if (scheduledFor != null) {
        updates['scheduled_for'] = Timestamp.fromDate(scheduledFor);
      }

      // ✅ recurring updates
      if (isRecurring != null) updates['is_recurring'] = isRecurring;
      if (frequency != null) updates['frequency'] = frequency;
      if (frequencyInterval != null) updates['frequency_interval'] = frequencyInterval;
      if (skipWeekends != null) updates['skip_weekends'] = skipWeekends;

      // ✅ stop condition updates
// IMPORTANT: keep Firestore consistent when recurring stays ON.
// If user chose end_date -> max_occurrences should be null (and vice versa).
      if (finalIsRecurring) {
        updates['recurring_end_at'] = finalEndAt == null
            ? null
            : Timestamp.fromDate(
          DateTime(finalEndAt.year, finalEndAt.month, finalEndAt.day),
        );

        updates['max_occurrences'] = finalMaxOcc; // can be null
      }

// If caller explicitly turned off recurring -> clear stop fields
      if (isRecurring == false) {
        updates['recurring_end_at'] = null;
        updates['max_occurrences'] = null;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update(updates);

      DebugConfig.print('✅ Notification updated + local sync: $notificationId');
    } catch (e) {
      DebugConfig.print('🔴 Error updating notification: $e');
      rethrow;
    }
  }

  /// Delete notification (soft delete) + cancel local
  Future<void> deleteNotification(String notificationId) async {
    final svc = NotificationsService();

    try {
      // 1) Cancel local FIRST (best-effort)
      try {
        await svc.cancelNotification(notificationId);
      } catch (_) {}

      // 2) Soft delete in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'deleted': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      DebugConfig.print('✅ Notification deleted + local cancelled: $notificationId');
    } catch (e) {
      DebugConfig.print('🔴 Error deleting notification: $e');
      rethrow;
    }
  }

  /// ✅ Skip ONE recurring occurrence without breaking the series:
  /// - cancels local
  /// - marks as delivered (so next occurrence will spawn)
  /// - sets deleted=true so it disappears from UI
  /// Offline-safe (pending writes ok)
  Future<void> skipRecurringOccurrence(String notificationId) async {
    final svc = NotificationsService();

    try {
      // 1) Cancel local FIRST (best-effort)
      try {
        await svc.cancelNotification(notificationId);
      } catch (_) {}

      final current = _notifications.cast<NotificationModel?>().firstWhere(
            (n) => n?.uuid == notificationId,
        orElse: () => null,
      );

      // 2) Firestore: mark delivered + deleted (so it won't show)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'delivered_at': FieldValue.serverTimestamp(),
        'dismissed_at': FieldValue.serverTimestamp(),
        'deleted': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      DebugConfig.print('✅ Recurring occurrence skipped: $notificationId');

      // 3) Spawn next occurrence (keep the chain alive)
      if (current != null && current.isRecurring) {
        await _spawnNextRecurringOccurrence(current);
      }
    } catch (e) {
      DebugConfig.print('🔴 Error skipping recurring occurrence: $e');
      rethrow;
    }
  }

  /// Delete entire recurring series (soft delete) + cancel local for all occurrences
  /// ✅ Offline-first: cache-first query, fallback to server when available
  Future<void> deleteRecurringSeries(String seriesId) async {
    final sid = seriesId.trim();
    if (sid.isEmpty) return;

    final svc = NotificationsService();

    try {
      DebugConfig.print('🗑️ Deleting recurring series: $sid');

      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications');

      QuerySnapshot<Map<String, dynamic>> qSnap;

      // ✅ 1) Cache-first (true offline-safe)
      try {
        qSnap = await col
            .where('series_id', isEqualTo: sid)
            .get(const GetOptions(source: Source.cache));
      } catch (e) {
        DebugConfig.print('⚠️ Series query cache failed, fallback to server: $e');
        qSnap = await col.where('series_id', isEqualTo: sid).get();
      }

      // Build unique document ids (avoid duplicates + include root)
      final ids = <String>{};
      for (final d in qSnap.docs) {
        ids.add(d.id);
      }

      // Backward/edge-case safety:
      // Ensure the "root" doc (id == sid) is also included even if series_id missing.
      ids.add(sid);

      // ✅ 2) Cancel local notifications (best-effort)
      for (final id in ids) {
        try {
          await svc.cancelNotification(id);
        } catch (_) {}
      }

      // ✅ 3) Soft delete all in batch (offline-safe)
      final finalIds = ids.toList();

      const int chunkSize = 450;
      for (var i = 0; i < finalIds.length; i += chunkSize) {
        final chunk = finalIds.sublist(
          i,
          (i + chunkSize) > finalIds.length ? finalIds.length : (i + chunkSize),
        );

        final batch = FirebaseFirestore.instance.batch();
        for (final id in chunk) {
          batch.update(col.doc(id), {
            'deleted': true,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      DebugConfig.print('✅ Recurring series deleted: $sid (count=${finalIds.length})');
    } catch (e) {
      DebugConfig.print('🔴 Error deleting recurring series: $e');
      rethrow;
    }
  }


  /// Mark delivered (+ cancel local)
  Future<void> markAsDelivered(String notificationId) async {
    final svc = NotificationsService();

    try {
      // Cancel local so it doesn't remain pending in weird cases
      try {
        await svc.cancelNotification(notificationId);
      } catch (_) {}

      final current = _notifications.cast<NotificationModel?>().firstWhere(
            (n) => n?.uuid == notificationId,
        orElse: () => null,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'delivered_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      DebugConfig.print('✅ Notification marked as delivered: $notificationId');

      // ✅ Recurring engine: spawn next occurrence (respects stop condition)
      if (current != null && current.isRecurring && !current.deleted) {
        await _spawnNextRecurringOccurrence(current);
      }
    } catch (e) {
      DebugConfig.print('🔴 Error marking notification as delivered: $e');
      rethrow;
    }
  }

  /// Mark read
  Future<void> markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      DebugConfig.print('✅ Notification marked as read: $notificationId');
    } catch (e) {
      DebugConfig.print('🔴 Error marking notification as read: $e');
      rethrow;
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _disposed = true;
    _catchUpInProgress.clear();
    _autoRecurringTimer?.cancel();
    _rescheduleDebounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
