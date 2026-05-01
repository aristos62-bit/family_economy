// ============================================================
// FILE: notifications_list_widget.dart
// Path: lib/presentation/widgets/notifications_list_widget.dart
// Ρόλος: Widget για εμφάνιση notifications συγκεκριμένης ημέρας
// ============================================================


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/models/notification_model.dart';

class NotificationsListWidget extends StatelessWidget {
  final List<NotificationModel> notifications;
  final VoidCallback onAddNew;
  final Function(NotificationModel) onEdit;
  final Function(NotificationModel) onDelete;
  final bool showAddButton;

  const NotificationsListWidget({
    super.key,
    required this.notifications,
    required this.onAddNew,
    required this.onEdit,
    required this.onDelete,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        if (notifications.isEmpty) _buildEmptyState(context) else _buildNotificationsList(context),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.notifications_active,
            color: ColorsUI.getPrimary(context.brightness),
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Υπενθυμίσεις',
            style: TypographyUI.titleMedium(context.brightness).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (showAddButton)
          AccessibilityService.accessibleButton(
            label: 'Προσθήκη νέας υπενθύμισης',
            hint: 'Πατήστε για να δημιουργήσετε νέα υπενθύμιση',
            onPressed: onAddNew,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ColorsUI.getPrimary(context.brightness),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add,
                    color: ColorsUI.getOnPrimary(context.brightness),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Νέα',
                    style: TypographyUI.labelMedium(context.brightness).copyWith(
                      color: ColorsUI.getOnPrimary(context.brightness),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(BuildContext context) {
    return Semantics(
      label: 'Δεν υπάρχουν υπενθυμίσεις για αυτή την ημέρα',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ColorsUI.getSurface(context.brightness).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: ColorsUI.getBorder(context.brightness),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.notifications_none,
                size: 32,
                color: ColorsUI.getTextSecondary(context.brightness),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Δεν υπάρχουν υπενθυμίσεις',
              style: TypographyUI.bodySmall(context.brightness).copyWith(
                color: ColorsUI.getTextSecondary(context.brightness),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NOTIFICATIONS LIST
  // ============================================================

  Widget _buildNotificationsList(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(context, notification);
      },
    );
  }

  // ============================================================
  // NOTIFICATION CARD
  // ============================================================

  Widget _buildNotificationCard(BuildContext context, NotificationModel notification) {
    final timeFormat = DateFormat('HH:mm');
    final timeText = timeFormat.format(notification.scheduledFor);
    final isPast = notification.scheduledFor.isBefore(DateTime.now());

    // ✅ Optional recurring badge (μόνο αν υπάρχει στο model)
    final bool isRecurring = _safeIsRecurring(notification);
    final String? recurringLabel = _safeRecurringLabel(notification);

    return Semantics(
      label: 'Υπενθύμιση: ${notification.message}, ώρα $timeText${isRecurring && recurringLabel != null ? ', $recurringLabel' : ''}${isPast ? ', παρελθοντική' : ''}',
      hint: 'Πατήστε για επεξεργασία ή διαγραφή',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: isPast
              ? ColorsUI.getSurface(context.brightness).withValues(alpha: 0.3)
              : ColorsUI.getSurface(context.brightness),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPast
                ? ColorsUI.getBorder(context.brightness).withValues(alpha: 0.5)
                : ColorsUI.getPrimary(context.brightness).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onEdit(notification),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // ✅ Time badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPast
                          ? ColorsUI.getTextSecondary(context.brightness).withValues(alpha: 0.2)
                          : ColorsUI.getPrimary(context.brightness).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      timeText,
                      style: TypographyUI.labelMedium(context.brightness).copyWith(
                        color: isPast
                            ? ColorsUI.getTextSecondary(context.brightness)
                            : ColorsUI.getPrimary(context.brightness),
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ✅ Message + optional recurring label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.message,
                          style: TypographyUI.bodyMedium(context.brightness).copyWith(
                            color: isPast
                                ? ColorsUI.getTextSecondary(context.brightness)
                                : ColorsUI.getTextPrimary(context.brightness),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isRecurring && recurringLabel != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: ColorsUI.getPrimary(context.brightness).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: ColorsUI.getPrimary(context.brightness).withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              recurringLabel,
                              style: TypographyUI.labelSmall(context.brightness).copyWith(
                                color: ColorsUI.getPrimary(context.brightness),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ✅ Delete button — Semantics.includeSemantics επαναφέρει
                  // το node παρά το excludeSemantics του γονέα
                  Semantics(
                    excludeSemantics: false,
                    child: AccessibilityService.accessibleButton(
                      label: 'Διαγραφή υπενθύμισης ${notification.message}',
                      hint: 'Πατήστε για να διαγράψετε αυτή την υπενθύμιση',
                      onPressed: () => onDelete(notification),
                      child: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: ColorsUI.getError(context.brightness),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SAFE HELPERS (για να μην σπάει αν αλλάξει το model)
  // ============================================================

  bool _safeIsRecurring(NotificationModel n) {
    try {
      // Αν έχεις πεδίο isRecurring στο model
      // ignore: invalid_use_of_visible_for_testing_member
      return (n as dynamic).isRecurring == true;
    } catch (_) {
      return false;
    }
  }

  String? _safeRecurringLabel(NotificationModel n) {
    try {
      final dynamic dn = n as dynamic;

      // 1) Αν έχεις νέα πεδία frequency/frequencyInterval
      final String? freq = dn.frequency as String?;
      final int? interval = dn.frequencyInterval as int?;
      if (freq != null) {
        final int i = (interval ?? 1).clamp(1, 9999);
        switch (freq) {
          case 'daily':
            return i == 1 ? 'Επαναλ. καθημερινά' : 'Επαναλ. κάθε $i ημέρες';
          case 'weekly':
            return i == 1 ? 'Επαναλ. εβδομαδιαία' : 'Επαναλ. κάθε $i εβδομάδες';
          case 'monthly':
            return i == 1 ? 'Επαναλ. μηνιαία' : 'Επαναλ. κάθε $i μήνες';
        }
      }

      // 2) Fallback: παλιό πεδίο recurringIntervalDays
      final int? days = dn.recurringIntervalDays as int?;
      if (days != null) {
        final int d = days.clamp(1, 9999);
        return d == 1 ? 'Επαναλ. καθημερινά' : 'Επαναλ. κάθε $d ημέρες';
      }

      return 'Επαναλαμβανόμενο';
    } catch (_) {
      return null;
    }
  }
}
