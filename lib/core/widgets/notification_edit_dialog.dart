// ============================================================
// FILE: notification_edit_dialog.dart (RECURRING: daily/weekly/monthly + skip weekends)
// Path: lib/presentation/widgets/notification_edit_dialog.dart
// Ρόλος: Dialog για δημιουργία/επεξεργασία notification με RECURRING
// ✅ Recurring supports ONLY: daily | weekly | monthly
// ✅ skip_weekends=true -> shift to next working day (Monday)
// ✅ NEW: REQUIRED stop condition for recurring (end date OR max occurrences)
// ============================================================

import 'package:flutter/material.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/models/notification_model.dart';

class NotificationEditDialog extends StatefulWidget {
  final DateTime selectedDate;
  final NotificationModel? notification; // null για νέο, non-null για edit

  const NotificationEditDialog({
    super.key,
    required this.selectedDate,
    this.notification,
  });

  @override
  State<NotificationEditDialog> createState() => _NotificationEditDialogState();
}

class _NotificationEditDialogState extends State<NotificationEditDialog> {
  late final TextEditingController _messageController;
  late TimeOfDay _selectedTime;
  bool _isSaving = false;

  // ✅ Recurring state - daily/weekly/monthly only
  bool _isRecurring = false;
  String _recurringFrequency = 'daily'; // 'daily' | 'weekly' | 'monthly'
  int _recurringInterval = 1; // every N units
  bool _skipWeekends = false; // if true -> shift to next working day (Monday)

  // ✅ REQUIRED STOP CONDITION (when recurring)
  // One of these must be set if _isRecurring == true
  DateTime?
  _recurringEndAt; // date-only (end of day will be handled by engine/provider)
  int? _maxOccurrences; // total occurrences including the root

  // UI selector: 'end_date' | 'max_occ'
  String _stopMode = 'end_date';

  @override
  void initState() {
    super.initState();

    if (widget.notification != null) {
      // ✅ Edit mode: pre-fill message + time + recurring fields
      final n = widget.notification!;
      _messageController = TextEditingController(text: n.message);
      _selectedTime = TimeOfDay.fromDateTime(n.scheduledFor);

      _isRecurring = n.isRecurring;
      _recurringFrequency = _sanitizeFrequency(n.frequency);
      _recurringInterval = (n.frequencyInterval ?? 1).clamp(1, 365);
      _skipWeekends = n.skipWeekends;

      // ✅ stop condition prefill
      _recurringEndAt = n.recurringEndAt;
      _maxOccurrences = n.maxOccurrences;

      // decide initial mode
      if (_maxOccurrences != null && (_maxOccurrences ?? 0) > 0) {
        _stopMode = 'max_occ';
      } else {
        _stopMode = 'end_date';
      }

      // If recurring but neither present (old data), set a safe default UI
      if (_isRecurring && _recurringEndAt == null && _maxOccurrences == null) {
        _stopMode = 'end_date';
        _recurringEndAt = DateTime(
          n.scheduledFor.year,
          n.scheduledFor.month,
          n.scheduledFor.day,
        ).add(const Duration(days: 30));
      }
    } else {
      // ✅ Create mode: empty message, current time + 1 hour
      _messageController = TextEditingController();
      final now = DateTime.now();
      _selectedTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);

      _isRecurring = false;
      _recurringFrequency = 'daily';
      _recurringInterval = 1;
      _skipWeekends = false;

      // defaults for stop condition (will be enforced only when recurring toggled on)
      _stopMode = 'end_date';
      _recurringEndAt = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 30));
      _maxOccurrences = null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AccessibilityService.announceAfterFirstFrame(
        context,
        widget.notification != null
            ? 'Επεξεργασία υπενθύμισης'
            : 'Δημιουργία νέας υπενθύμισης',
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _sanitizeFrequency(String? f) {
    final v = (f ?? '').trim();
    if (v == 'daily' || v == 'weekly' || v == 'monthly') return v;
    return 'daily';
  }

  DateTime _shiftToMondayIfWeekend(DateTime dt) {
    // Saturday = 6, Sunday = 7
    if (dt.weekday == DateTime.saturday) {
      return dt.add(const Duration(days: 2));
    }
    if (dt.weekday == DateTime.sunday) {
      return dt.add(const Duration(days: 1));
    }
    return dt;
  }

  Future<void> _pickRecurringEndDate() async {
    final initial =
        _recurringEndAt ?? DateTime.now().add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              backgroundColor: ColorsUI.getSurface(context.brightness),
            ),
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: ColorsUI.getPrimary(context.brightness),
              onPrimary: ColorsUI.getOnPrimary(context.brightness),
              surface: ColorsUI.getSurface(context.brightness),
              onSurface: ColorsUI.getTextPrimary(context.brightness),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _recurringEndAt = DateTime(picked.year, picked.month, picked.day);
      });
      AccessibilityService.announcePolite(
        'Ημερομηνία λήξης: ${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}',
      );
    }
  }

  String _formatDateShort(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  // ============================================================
  // TIME PICKER
  // ============================================================

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              backgroundColor: ColorsUI.getSurface(context.brightness),
            ),
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: ColorsUI.getPrimary(context.brightness),
              onPrimary: ColorsUI.getOnPrimary(context.brightness),
              surface: ColorsUI.getSurface(context.brightness),
              onSurface: ColorsUI.getTextPrimary(context.brightness),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
      AccessibilityService.announcePolite(
        'Ώρα επιλέχθηκε: ${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _save() async {
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      AccessibilityService.announceError(
        'Παρακαλώ γράψτε ένα μήνυμα υπενθύμισης',
      );
      return;
    }

    // ✅ Combine date and time
    var scheduledFor = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // ✅ If recurring + skip weekends, shift initial occurrence too
    if (_isRecurring && _skipWeekends) {
      scheduledFor = _shiftToMondayIfWeekend(scheduledFor);
    }

    if (_isRecurring) {
      // sanitize frequency (always returns daily|weekly|monthly)
      _recurringFrequency = _sanitizeFrequency(_recurringFrequency);

      // clamp interval to safe range
      _recurringInterval = _recurringInterval.clamp(1, 365);

      // ✅ REQUIRED stop condition: end date OR max occurrences
      if (_stopMode == 'end_date') {
        if (_recurringEndAt == null) {
          AccessibilityService.announceError(
            'Ορίστε ημερομηνία λήξης για την επανάληψη',
          );
          return;
        }
        // end date cannot be before the first scheduled date (date-only compare)
        final endOnly = DateTime(
          _recurringEndAt!.year,
          _recurringEndAt!.month,
          _recurringEndAt!.day,
        );
        final firstOnly = DateTime(
          scheduledFor.year,
          scheduledFor.month,
          scheduledFor.day,
        );
        if (endOnly.isBefore(firstOnly)) {
          AccessibilityService.announceError(
            'Η ημερομηνία λήξης δεν μπορεί να είναι πριν από την πρώτη εμφάνιση',
          );
          return;
        }
        // ensure maxOccurrences is null in this mode
        _maxOccurrences = null;
      } else {
        final mo = (_maxOccurrences ?? 0);
        if (mo <= 0) {
          AccessibilityService.announceError(
            'Ορίστε μέγιστο αριθμό επαναλήψεων',
          );
          return;
        }
        // root is occurrenceIndex=0, so min total is 1
        if (mo < 1) {
          AccessibilityService.announceError(
            'Ο μέγιστος αριθμός επαναλήψεων πρέπει να είναι ≥ 1',
          );
          return;
        }
        // ensure end date is null in this mode
        _recurringEndAt = null;
      }
    } else {
      // not recurring -> clear stop fields
      _recurringEndAt = null;
      _maxOccurrences = null;
    }

    // ✅ Check if in the past
    if (scheduledFor.isBefore(DateTime.now())) {
      AccessibilityService.announceError(
        'Δεν μπορείτε να δημιουργήσετε υπενθύμιση για το παρελθόν',
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: ColorsUI.getSurface(context.brightness),
          title: Text(
            'Μη έγκυρη ώρα',
            style: TypographyUI.titleMedium(context.brightness),
          ),
          content: Text(
            'Η υπενθύμιση δεν μπορεί να είναι στο παρελθόν. Παρακαλώ επιλέξτε μελλοντική ώρα.',
            style: TypographyUI.bodyMedium(context.brightness),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Εντάξει',
                style: TypographyUI.labelLarge(context.brightness),
              ),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    if (!mounted) return;

    Navigator.pop(context, {
      'message': message,
      'scheduledFor': scheduledFor,
      'isRecurring': _isRecurring,

      // ✅ recurring config (μόνο αν isRecurring=true)
      'frequency': _isRecurring
          ? _recurringFrequency
          : null, // daily|weekly|monthly
      'frequencyInterval': _isRecurring ? _recurringInterval : null, // int
      'skipWeekends': _isRecurring ? _skipWeekends : null, // bool
      // ✅ stop condition (μόνο αν isRecurring=true)
      'recurringEndAt': _isRecurring ? _recurringEndAt : null, // DateTime?
      'maxOccurrences': _isRecurring ? _maxOccurrences : null, // int?
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.notification != null;
    final timeText =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: isEdit
            ? 'Επεξεργασία υπενθύμισης'
            : 'Δημιουργία νέας υπενθύμισης',
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: ColorsUI.getSurface(context.brightness),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: ColorsUI.shadowLight.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        isEdit ? Icons.edit_notifications : Icons.add_alert,
                        color: ColorsUI.getPrimary(context.brightness),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEdit ? 'Επεξεργασία Υπενθύμισης' : 'Νέα Υπενθύμιση',
                        style: TypographyUI.titleLarge(
                          context.brightness,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                AccessibilityService.accessibleTextField(
                  label: 'Μήνυμα υπενθύμισης',
                  hint: 'Γράψτε το μήνυμα που θέλετε να λάβετε',
                  child: TextField(
                    controller: _messageController,
                    maxLines: 3,
                    style: TypographyUI.bodyMedium(context.brightness),
                    decoration: InputDecoration(
                      labelText: 'Μήνυμα υπενθύμισης',
                      hintText: 'π.χ. Να πληρώσω τον λογαριασμό ρεύματος',
                      labelStyle: TypographyUI.bodyMedium(context.brightness),
                      hintStyle: TypographyUI.bodySmall(context.brightness)
                          .copyWith(
                            color: ColorsUI.getTextSecondary(
                              context.brightness,
                            ),
                          ),
                      filled: true,
                      fillColor: ColorsUI.getInputFill(context.brightness),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ColorsUI.getInputBorder(context.brightness),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ColorsUI.getInputBorder(context.brightness),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ColorsUI.getInputFocusBorder(
                            context.brightness,
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                AccessibilityService.accessibleButton(
                  label: 'Επιλογή ώρας: $timeText',
                  hint: 'Πατήστε για να επιλέξετε την ώρα της υπενθύμισης',
                  onPressed: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ColorsUI.getInputFill(context.brightness),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ColorsUI.getInputBorder(context.brightness),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: ColorsUI.getPrimary(context.brightness),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ώρα υπενθύμισης',
                                style:
                                    TypographyUI.labelSmall(
                                      context.brightness,
                                    ).copyWith(
                                      color: ColorsUI.getTextSecondary(
                                        context.brightness,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeText,
                                style:
                                    TypographyUI.titleMedium(
                                      context.brightness,
                                    ).copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: ColorsUI.getTextSecondary(context.brightness),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                _buildRecurringSwitch(),

                if (_isRecurring) ...[
                  const SizedBox(height: 12),
                  _buildRecurringConfigCard(),
                  const SizedBox(height: 12),
                  _buildRecurringStopCard(),
                ],

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: ColorsUI.getBorder(context.brightness),
                          ),
                        ),
                        child: Text(
                          'Ακύρωση',
                          style: TypographyUI.labelLarge(context.brightness),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorsUI.getPrimary(
                            context.brightness,
                          ),
                          foregroundColor: ColorsUI.getOnPrimary(
                            context.brightness,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? Semantics(
                          label: isEdit
                              ? 'Αποθήκευση σε εξέλιξη. Παρακαλώ περιμένετε.'
                              : 'Δημιουργία σε εξέλιξη. Παρακαλώ περιμένετε.',
                          liveRegion: true,
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                ColorsUI.getOnPrimary(context.brightness),
                              ),
                            ),
                          ),
                        )
                            : Text(
                          isEdit ? 'Αποθήκευση' : 'Δημιουργία',
                                style:
                                    TypographyUI.labelLarge(
                                      context.brightness,
                                    ).copyWith(
                                      color: ColorsUI.getOnPrimary(
                                        context.brightness,
                                      ),
                                    ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPER WIDGETS
  // ============================================================

  Widget _buildRecurringSwitch() {
    final label = _isRecurring
        ? 'Επαναλαμβανόμενο μήνυμα ενεργοποιημένο'
        : 'Επαναλαμβανόμενο μήνυμα απενεργοποιημένο';

    return AccessibilityService.accessibleButton(
      label: label,
      hint:
          'Πατήστε για να ${_isRecurring ? 'απενεργοποιήσετε' : 'ενεργοποιήσετε'} την επανάληψη',
      onPressed: () {
        setState(() {
          _isRecurring = !_isRecurring;

          // when enabling recurring, ensure we have a visible default stop mode/value
          if (_isRecurring) {
            if (_stopMode == 'end_date' && _recurringEndAt == null) {
              _recurringEndAt = DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              ).add(const Duration(days: 30));
            }
            if (_stopMode == 'max_occ' && (_maxOccurrences ?? 0) <= 0) {
              _maxOccurrences = 12;
            }
          }
        });

        AccessibilityService.announcePolite(
          _isRecurring
              ? 'Επαναλαμβανόμενο μήνυμα ενεργοποιήθηκε'
              : 'Επαναλαμβανόμενο μήνυμα απενεργοποιήθηκε',
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isRecurring
              ? ColorsUI.getPrimary(context.brightness).withValues(alpha: 0.1)
              : ColorsUI.getInputFill(context.brightness),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isRecurring
                ? ColorsUI.getPrimary(context.brightness)
                : ColorsUI.getInputBorder(context.brightness),
            width: _isRecurring ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isRecurring ? Icons.repeat : Icons.repeat_outlined,
              color: _isRecurring
                  ? ColorsUI.getPrimary(context.brightness)
                  : ColorsUI.getTextSecondary(context.brightness),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Επαναλαμβανόμενο μήνυμα',
                    style: TypographyUI.titleSmall(context.brightness).copyWith(
                      color: _isRecurring
                          ? ColorsUI.getPrimary(context.brightness)
                          : ColorsUI.getTextPrimary(context.brightness),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isRecurring
                        ? 'Θα επαναλαμβάνεται την ίδια ώρα'
                        : 'Το μήνυμα θα σταλεί μία φορά',
                    style: TypographyUI.bodySmall(context.brightness).copyWith(
                      color: ColorsUI.getTextSecondary(context.brightness),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isRecurring,
              onChanged: (v) {
                setState(() {
                  _isRecurring = v;

                  if (_isRecurring) {
                    if (_stopMode == 'end_date' && _recurringEndAt == null) {
                      _recurringEndAt = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      ).add(const Duration(days: 30));
                    }
                    if (_stopMode == 'max_occ' && (_maxOccurrences ?? 0) <= 0) {
                      _maxOccurrences = 12;
                    }
                  }
                });

                AccessibilityService.announcePolite(
                  _isRecurring
                      ? 'Επαναλαμβανόμενο μήνυμα ενεργοποιήθηκε'
                      : 'Επαναλαμβανόμενο μήνυμα απενεργοποιήθηκε',
                );
              },
              activeThumbColor: ColorsUI.getPrimary(context.brightness),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringConfigCard() {
    String freqLabel;
    switch (_recurringFrequency) {
      case 'weekly':
        freqLabel = 'Εβδομαδιαία';
        break;
      case 'monthly':
        freqLabel = 'Μηνιαία';
        break;
      default:
        freqLabel = 'Καθημερινά';
    }

    final unit = _recurringFrequency == 'monthly'
        ? (_recurringInterval == 1 ? 'μήνα' : 'μήνες')
        : _recurringFrequency == 'weekly'
        ? (_recurringInterval == 1 ? 'εβδομάδα' : 'εβδομάδες')
        : (_recurringInterval == 1 ? 'ημέρα' : 'ημέρες');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorsUI.getInputFill(context.brightness),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorsUI.getInputBorder(context.brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                color: ColorsUI.getPrimary(context.brightness),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _recurringFrequency,
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Καθημερινά')),
                    DropdownMenuItem(
                      value: 'weekly',
                      child: Text('Εβδομαδιαία'),
                    ),
                    DropdownMenuItem(value: 'monthly', child: Text('Μηνιαία')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _recurringFrequency = v;
                      if (_recurringInterval < 1) _recurringInterval = 1;
                    });
                    AccessibilityService.announcePolite(
                      'Συχνότητα: ${v == 'daily'
                          ? 'Καθημερινά'
                          : v == 'weekly'
                          ? 'Εβδομαδιαία'
                          : 'Μηνιαία'}',
                    );
                  },
                  decoration: InputDecoration(
                    labelText: 'Συχνότητα',
                    labelStyle: TypographyUI.bodySmall(context.brightness),
                    filled: true,
                    fillColor: ColorsUI.getSurface(context.brightness),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: ColorsUI.getInputBorder(context.brightness),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: ColorsUI.getInputFocusBorder(context.brightness),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Περίοδος επανάληψης',
                  value: 'Κάθε $_recurringInterval $unit',
                  child: Text(
                    'Κάθε $_recurringInterval $unit ($freqLabel)',
                    style: TypographyUI.bodyMedium(
                      context.brightness,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Μείωση περιόδου επανάληψης',
                onPressed: _recurringInterval > 1
                    ? () {
                        setState(() => _recurringInterval--);
                        AccessibilityService.announcePolite(
                          'Κάθε $_recurringInterval $unit',
                        );
                      }
                    : null,
                icon: const ExcludeSemantics(
                  child: Icon(Icons.remove_circle_outline),
                ),
              ),
              IconButton(
                tooltip: 'Αύξηση περιόδου επανάληψης',
                onPressed: _recurringInterval < 365
                    ? () {
                        setState(() => _recurringInterval++);
                        AccessibilityService.announcePolite(
                          'Κάθε $_recurringInterval $unit',
                        );
                      }
                    : null,
                icon: const ExcludeSemantics(
                  child: Icon(Icons.add_circle_outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Αν πέσει Σ/Κ → μετάθεση στη Δευτέρα',
                  style: TypographyUI.bodySmall(context.brightness).copyWith(
                    color: ColorsUI.getTextSecondary(context.brightness),
                  ),
                ),
              ),
              Switch(
                value: _skipWeekends,
                onChanged: (v) {
                  setState(() => _skipWeekends = v);
                  AccessibilityService.announcePolite(
                    v
                        ? 'Μετάθεση Σαββατοκύριακου ενεργή'
                        : 'Μετάθεση Σαββατοκύριακου ανενεργή',
                  );
                },
                activeThumbColor: ColorsUI.getPrimary(context.brightness),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringStopCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorsUI.getInputFill(context.brightness),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorsUI.getInputBorder(context.brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag_outlined,
                color: ColorsUI.getPrimary(context.brightness),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Τερματισμός επανάληψης (υποχρεωτικό)',
                  style: TypographyUI.titleSmall(
                    context.brightness,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mode selector
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ColorsUI.getSurface(context.brightness),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ColorsUI.getInputBorder(context.brightness),
              ),
            ),
            child: RadioGroup<String>(
              groupValue: _stopMode,
              onChanged: (v) {
                if (v == null) return;

                setState(() {
                  _stopMode = v;

                  if (_stopMode == 'end_date') {
                    _recurringEndAt ??= DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ).add(const Duration(days: 30));
                    _maxOccurrences = null;
                  } else {
                    _maxOccurrences ??= 12;
                    _recurringEndAt = null;
                  }
                });

                AccessibilityService.announcePolite(
                  _stopMode == 'end_date'
                      ? 'Τερματισμός: μέχρι ημερομηνία'
                      : 'Τερματισμός: μέχρι αριθμό επαναλήψεων',
                );
              },
              child: Column(
                children: const [
                  RadioListTile<String>(
                    value: 'end_date',
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Μέχρι ημερομηνία'),
                  ),
                  SizedBox(height: 6),
                  RadioListTile<String>(
                    value: 'max_occ',
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Μέχρι αριθμό επαναλήψεων'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Mode content
          if (_stopMode == 'end_date') ...[
            AccessibilityService.accessibleButton(
              label: _recurringEndAt == null
                  ? 'Επιλογή ημερομηνίας λήξης'
                  : 'Ημερομηνία λήξης: ${_formatDateShort(_recurringEndAt!)}',
              hint: 'Πατήστε για να επιλέξετε ημερομηνία λήξης',
              onPressed: _pickRecurringEndDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ColorsUI.getSurface(context.brightness),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ColorsUI.getInputBorder(context.brightness),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event,
                      color: ColorsUI.getPrimary(context.brightness),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _recurringEndAt == null
                            ? 'Επιλογή ημερομηνίας λήξης'
                            : 'Μέχρι: ${_formatDateShort(_recurringEndAt!)}',
                        style: TypographyUI.bodyMedium(
                          context.brightness,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: ColorsUI.getTextSecondary(context.brightness),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Θα σταματήσει όταν περάσει αυτή η ημερομηνία.',
              style: TypographyUI.bodySmall(
                context.brightness,
              ).copyWith(color: ColorsUI.getTextSecondary(context.brightness)),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Μέγιστος αριθμός επαναλήψεων',
                    value: '${_maxOccurrences ?? 0}',
                    child: Text(
                      'Επαναλήψεις: ${_maxOccurrences ?? 0}',
                      style: TypographyUI.bodyMedium(
                        context.brightness,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Μείωση αριθμού επαναλήψεων',
                  onPressed: (_maxOccurrences ?? 0) > 1
                      ? () {
                          setState(
                            () => _maxOccurrences = (_maxOccurrences ?? 1) - 1,
                          );
                          AccessibilityService.announcePolite(
                            'Επαναλήψεις: ${_maxOccurrences ?? 0}',
                          );
                        }
                      : null,
                  icon: const ExcludeSemantics(
                    child: Icon(Icons.remove_circle_outline),
                  ),
                ),
                IconButton(
                  tooltip: 'Αύξηση αριθμού επαναλήψεων',
                  onPressed: (_maxOccurrences ?? 0) < 365
                      ? () {
                          setState(
                            () => _maxOccurrences = (_maxOccurrences ?? 0) + 1,
                          );
                          AccessibilityService.announcePolite(
                            'Επαναλήψεις: ${_maxOccurrences ?? 0}',
                          );
                        }
                      : null,
                  icon: const ExcludeSemantics(
                    child: Icon(Icons.add_circle_outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Μετράει το σύνολο (μαζί με το πρώτο).',
              style: TypographyUI.bodySmall(
                context.brightness,
              ).copyWith(color: ColorsUI.getTextSecondary(context.brightness)),
            ),
          ],
        ],
      ),
    );
  }
}
