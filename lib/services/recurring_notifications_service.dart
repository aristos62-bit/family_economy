// ============================================================
// FILE: recurring_notifications_service.dart
// Path: lib/services/recurring_notifications_service.dart
// Ρόλος: Δημιουργεί future notification occurrences από recurring rules
// ✅ Offline-first: schedule local first + firestore writes (pending ok)
// ✅ Killed-app safe: παράγει occurrences μπροστά (horizon days)
// ✅ Supports: daily/weekly/monthly + interval + skip_weekends→next Monday
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/models/notification_model.dart';
import 'package:family_economy/services/notifications_service.dart';

class RecurringNotificationsService {
  static final RecurringNotificationsService _instance =
  RecurringNotificationsService._internal();
  factory RecurringNotificationsService() => _instance;
  RecurringNotificationsService._internal();

  static const String _collection = 'recurring_notifications';

  /// Παράγει occurrences έως horizonDays μπροστά.
  /// Κάλεσέ το στο app start + όποτε δημιουργείς/ενημερώνεις κανόνα.
  Future<void> generateAhead(
      String userId, {
        int horizonDays = 45,
      }) async {
    try {
      final now = DateTime.now();
      final horizon = now.add(Duration(days: horizonDays));

      final rulesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collection)
          .where('deleted', isEqualTo: false)
          .where('is_active', isEqualTo: true)
          .where('auto_generate', isEqualTo: true)
          .get();

      if (rulesSnap.docs.isEmpty) {
        DebugConfig.print('ℹ️ RecurringNotifications: no active rules');
        return;
      }

      DebugConfig.print(
        '🔁 RecurringNotifications: ${rulesSnap.docs.length} rules, horizon=$horizonDays days',
      );

      for (final doc in rulesSnap.docs) {
        await _processRule(userId, doc, horizon);
      }

      DebugConfig.print('✅ RecurringNotifications: generateAhead complete');
    } catch (e) {
      DebugConfig.print('⚠️ RecurringNotifications: generateAhead failed: $e');
    }
  }

  Future<void> _processRule(
      String userId,
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      DateTime horizon,
      ) async {
    final data = doc.data();
    final recId = doc.id;

    final title = (data['title'] as String?) ??
        (data['schedule_name'] as String?) ??
        'Υπενθύμιση';

    final message = (data['message'] as String?) ??
        (data['notes'] as String?) ??
        '';

    final frequency = (data['frequency'] as String?)?.trim().toLowerCase();
    final interval = (data['frequency_interval'] as num?)?.toInt() ?? 1;

    final skipWeekends = (data['skip_weekends'] as bool?) ?? false;

    final nextTs = data['next_occurrence'] as Timestamp?;
    if (nextTs == null) {
      DebugConfig.print('⚠️ Rule $recId has no next_occurrence -> skip');
      return;
    }

    final endTs = data['end_date'] as Timestamp?;
    final endDate = endTs?.toDate();

    var next = nextTs.toDate();

    // Αν έχει end_date και είμαστε ήδη μετά, απενεργοποιούμε.
    if (endDate != null && next.isAfter(endDate)) {
      await _deactivateRule(userId, recId);
      return;
    }

    // Κανονικοποίηση: αν next είναι στο παρελθόν, προχωράμε μέχρι να πάει >= now
    final now = DateTime.now();
    if (next.isBefore(now)) {
      next = _advanceUntilAfterNow(
        next: next,
        now: now,
        frequency: frequency,
        interval: interval,
        skipWeekends: skipWeekends,
      );
    }

    // Παράγουμε occurrences μέχρι horizon ή end_date
    int created = 0;

    while (true) {
      if (endDate != null && next.isAfter(endDate)) {
        await _deactivateRule(userId, recId);
        break;
      }

      if (next.isAfter(horizon)) break;

      // ✅ deterministic occurrence doc id (idempotent):
      // recId + epochMinutes => αν ξανατρέξει δεν θα διπλογράψει (set merge)
      final occId = _occurrenceId(recId, next);

      final occ = NotificationModel(
        uuid: occId,
        userId: userId,
        type: 'reminder',
        title: title,
        message: message,
        scheduledFor: next,
        relatedId: recId,
        relatedType: 'recurring_notification',
        deliveredAt: null,
        readAt: null,
        dismissedAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deleted: false,
      );

      // ✅ 1) Local schedule first
      await NotificationsService().scheduleNotification(occ);

      // ✅ 2) Firestore write (merge=true => idempotent)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(occId)
          .set(occ.toMap(), SetOptions(merge: true));

      created++;

      // advance next
      final prev = next;
      next = _computeNextOccurrence(
        from: next,
        frequency: frequency,
        interval: interval,
        skipWeekends: skipWeekends,
      );

      // ενημέρωση rule progress (κάθε loop)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collection)
          .doc(recId)
          .update({
        'last_generated_date': Timestamp.fromDate(prev),
        'next_occurrence': Timestamp.fromDate(next),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    DebugConfig.print('↪️ Rule $recId generated $created occurrences');
  }

  Future<void> _deactivateRule(String userId, String recId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collection)
          .doc(recId)
          .update({
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
      DebugConfig.print('ℹ️ Rule $recId deactivated (end_date reached)');
    } catch (_) {}
  }

  String _occurrenceId(String recId, DateTime dt) {
    // epoch minutes για σταθερότητα + μικρότερο id
    final minutes = dt.millisecondsSinceEpoch ~/ 60000;
    return '${recId}_$minutes';
  }

  DateTime _advanceUntilAfterNow({
    required DateTime next,
    required DateTime now,
    required String? frequency,
    required int interval,
    required bool skipWeekends,
  }) {
    var n = next;
    // Προχωράμε με upper bound ώστε να μη κολλήσει ποτέ
    for (int i = 0; i < 5000; i++) {
      if (!n.isBefore(now)) return n;
      n = _computeNextOccurrence(
        from: n,
        frequency: frequency,
        interval: interval,
        skipWeekends: skipWeekends,
      );
    }
    return now;
  }

  DateTime _computeNextOccurrence({
    required DateTime from,
    required String? frequency,
    required int interval,
    required bool skipWeekends,
  }) {
    DateTime next;

    switch (frequency) {
      case 'daily':
        next = from.add(Duration(days: interval));
        break;

      case 'weekly':
        next = from.add(Duration(days: 7 * interval));
        break;

      case 'monthly':
        next = _addMonthsKeepingDay(from, interval);
        break;

      default:
      // fallback: daily
        next = from.add(const Duration(days: 1));
        break;
    }

    if (skipWeekends) {
      next = _shiftToNextWorkingDay(next);
    }

    return next;
  }

  DateTime _shiftToNextWorkingDay(DateTime d) {
    var x = d;
    // Σάββατο (6) -> +2, Κυριακή (7) -> +1
    while (x.weekday == DateTime.saturday || x.weekday == DateTime.sunday) {
      x = x.add(const Duration(days: 1));
    }
    return x;
  }

  DateTime _addMonthsKeepingDay(DateTime from, int months) {
    final year = from.year;
    final month = from.month;

    final targetMonthIndex = (month - 1) + months;
    final targetYear = year + (targetMonthIndex ~/ 12);
    final targetMonth = (targetMonthIndex % 12) + 1;

    final day = from.day;
    final hour = from.hour;
    final minute = from.minute;
    final second = from.second;
    final millisecond = from.millisecond;
    final microsecond = from.microsecond;

    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final safeDay = day <= lastDayOfTargetMonth ? day : lastDayOfTargetMonth;

    return DateTime(
      targetYear,
      targetMonth,
      safeDay,
      hour,
      minute,
      second,
      millisecond,
      microsecond,
    );
  }
}
