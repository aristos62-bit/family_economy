// ============================================================
// FILE: notifications_service.dart
// Path: lib/services/notifications_service.dart
// Ρόλος: Διαχείριση local notifications (flutter_local_notifications)
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/models/notification_model.dart';

class NotificationsService {
  static final NotificationsService _instance =
      NotificationsService._internal();
  factory NotificationsService() => _instance;
  NotificationsService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ✅ NEW: callback when user taps a notification (payload = notification.uuid)
  ValueChanged<String?>? onTap;

  // ============================================================
  // STABLE LOCAL NOTIFICATION ID
  // Avoid uuid.hashCode (not stable across app restarts + possible collisions)
  // ============================================================
  int _stableIdFromUuid(String uuid) {
    // Deterministic 32-bit FNV-1a hash
    const int fnvPrime = 16777619;
    const int fnvOffset = 2166136261;

    var hash = fnvOffset;
    for (final c in uuid.codeUnits) {
      hash ^= c;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }

    // Keep it positive 31-bit (safer for Android notification IDs)
    return hash & 0x7FFFFFFF;
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      DebugConfig.print('✅ Notifications already initialized');
      return;
    }

    try {
      // ✅ Initialize timezone (best-effort; don't crash scheduling)
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Athens'));
      } catch (e) {
        DebugConfig.print(
          '⚠️ TZ location Europe/Athens not found, using default tz.local: $e',
        );
      }

      // ✅ Android settings
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      // ✅ iOS settings
      const iOSSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iOSSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // ✅ Request permissions
      await _requestPermissions();

      _initialized = true;
      // DebugConfig.print('✅ NotificationsService initialized');
    } catch (e) {
      DebugConfig.print('🔴 Error initializing notifications: $e');
      // Best-effort: don't crash app flows; scheduling will be skipped if not initialized.
      return;
    }
  }

  // ============================================================
  // PERMISSIONS
  // ============================================================

  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Android 13+ requires notification permission
        final status = await Permission.notification.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          DebugConfig.print('⚠️ Notification permission denied on Android');
          return false;
        }
      }

      if (Platform.isIOS) {
        final granted = await _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);

        if (granted != true) {
          DebugConfig.print('⚠️ Notification permission denied on iOS');
          return false;
        }
      }

      DebugConfig.print('✅ Notification permissions granted');
      return true;
    } catch (e) {
      DebugConfig.print('🔴 Error requesting permissions: $e');
      return false;
    }
  }

  /// Best-effort permission check (doesn't block scheduling logic)
  Future<bool> hasPermissions() async {
    try {
      if (Platform.isAndroid) {
        return await Permission.notification.isGranted;
      }
      if (Platform.isIOS) {
        // Δεν υπάρχει reliable "isGranted" API από το plugin σε όλες τις εκδόσεις.
        // Κάνουμε best-effort: αν το initialize() έχει τρέξει και δεν έχουμε exception,
        // θεωρούμε ότι είναι ΟΚ. (Το iOS θα αγνοήσει/μην δείξει αν δεν επιτρέπεται.)
        return true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // SCHEDULE NOTIFICATION
  // ============================================================

  Future<void> scheduleNotification(NotificationModel notification) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) {
        DebugConfig.print(
          '⚠️ NotificationsService not initialized. Skipping schedule.',
        );
        return;
      }
    }

    try {
      final notificationId = _stableIdFromUuid(notification.uuid);

      // ✅ Cancel existing notification with same ID first (edit/update safe)
      await _notifications.cancel(notificationId);
      DebugConfig.print('🔕 Cancelled existing notification: $notificationId');

      // ✅ Convert DateTime to TZDateTime
      final scheduledDate = tz.TZDateTime.from(
        notification.scheduledFor,
        tz.local,
      );

      // ✅ Check if date is in the future
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        DebugConfig.print('⚠️ Cannot schedule notification in the past');
        return;
      }

      // ✅ Notification details
      const androidDetails = AndroidNotificationDetails(
        'reminders_channel',
        'Υπενθυμίσεις',
        channelDescription: 'Υπενθυμίσεις που δημιουργήσατε',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

      const iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      // ✅ Schedule notification
      await _notifications.zonedSchedule(
        notificationId, // ✅ stable deterministic ID
        notification.title,
        notification.message,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: notification.uuid,
      );

      DebugConfig.print(
        '✅ Notification scheduled for ${notification.scheduledFor} (id=$notificationId)',
      );
    } catch (e) {
      DebugConfig.print('🔴 Error scheduling notification: $e');
      rethrow;
    }
  }

  // ============================================================
  // CANCEL NOTIFICATION (by UUID)
  // ============================================================

  Future<void> cancelNotification(String notificationUuid) async {
    if (notificationUuid.trim().isEmpty) return;

    try {
      if (!_initialized) {
        await initialize();
        if (!_initialized) {
          DebugConfig.print(
            '⚠️ NotificationsService not initialized. Skipping cancel.',
          );
          return;
        }
      }

      final id = _stableIdFromUuid(notificationUuid);
      await _notifications.cancel(id);
      DebugConfig.print('✅ Notification cancelled: $notificationUuid (id=$id)');
    } catch (e) {
      DebugConfig.print('🔴 Error cancelling notification: $e');
      rethrow;
    }
  }

  // ============================================================
  // CANCEL NOTIFICATION (by raw ID)
  // ✅ Needed for diff-based cleanup when payload/uuid is missing
  // ============================================================

  Future<void> cancelNotificationById(int id) async {
    try {
      if (!_initialized) {
        await initialize();
        if (!_initialized) {
          DebugConfig.print(
            '⚠️ NotificationsService not initialized. Skipping cancel by id.',
          );
          return;
        }
      }
      await _notifications.cancel(id);
      DebugConfig.print('✅ Notification cancelled by id: $id');
    } catch (e) {
      DebugConfig.print('🔴 Error cancelling notification by id: $e');
      rethrow;
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    try {
      if (!_initialized) {
        await initialize();
      }
      await _notifications.cancelAll();
      DebugConfig.print('✅ All notifications cancelled');
    } catch (e) {
      DebugConfig.print('🔴 Error cancelling all notifications: $e');
      rethrow;
    }
  }

  // ============================================================
  // GET PENDING NOTIFICATIONS
  // ============================================================

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      if (!_initialized) {
        await initialize();
      }
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      DebugConfig.print('🔴 Error getting pending notifications: $e');
      return [];
    }
  }

  // ============================================================
  // NOTIFICATION TAPPED CALLBACK
  // ============================================================

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    DebugConfig.print('📲 Notification tapped: $payload');

    // ✅ NEW: let app/provider handle delivered + recurring spawn
    onTap?.call(payload);
  }

  // ============================================================
  // SHOW IMMEDIATE NOTIFICATION (for testing)
  // ============================================================

  Future<void> showImmediateNotification({
    required String title,
    required String message,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'reminders_channel',
        'Υπενθυμίσεις',
        channelDescription: 'Υπενθυμίσεις που δημιουργήσατε',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        message,
        details,
        payload: payload,
      );

      DebugConfig.print('✅ Immediate notification shown');
    } catch (e) {
      DebugConfig.print('🔴 Error showing immediate notification: $e');
      rethrow;
    }
  }
}
