import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'utils.dart' as oil_utils;

class PurchaseHistorySheet extends StatelessWidget {
  final String userId;
  final Future<void> Function(String userId) onRecalculateAvgCost;

  const PurchaseHistorySheet({
    super.key,
    required this.userId,
    required this.onRecalculateAvgCost,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = context.brightness;
    final fmt = DateFormat('dd/MM/yyyy');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ColorsUI.getDivider(brightness),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ExcludeSemantics(child: Icon(Icons.history_rounded, color: ColorsUI.getPrimary(brightness))),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Ιστορικό Αγορών Πετρελαίου', style: TypographyUI.titleMedium(brightness))),
                  IconButton(
                    tooltip: 'Κλείσιμο',
                    onPressed: () => Navigator.pop(context),
                    icon: ExcludeSemantics(child: Icon(Icons.close, color: ColorsUI.getTextSecondary(brightness))),
                  ),
                ],
              ),
            ),
            ExcludeSemantics(child: Divider(color: ColorsUI.getDivider(brightness), height: 1)),
            // List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('oil_purchases')
                    .orderBy('purchase_date', descending: true)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Semantics(
                      liveRegion: true,
                      label: 'Φόρτωση ιστορικού αγορών.',
                      child: Center(child: ExcludeSemantics(child: CircularProgressIndicator(color: ColorsUI.getPrimary(brightness)))),
                    );
                  }

                  final docs = snap.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            'Δεν υπάρχουν καταχωρημένες αγορές.',
                            style: TypographyUI.bodyMedium(brightness).copyWith(color: ColorsUI.getTextSecondary(brightness)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final date = DateTime.tryParse(data['purchase_date'] as String? ?? '') ?? DateTime.now();
                      final price = (data['price_per_liter'] as num).toDouble();
                      final liters = (data['liters'] as num).toDouble();

                      return Semantics(
                        label: '${fmt.format(date.toLocal())}, ${liters.toStringAsFixed(1)} λίτρα, ${price.toStringAsFixed(3)} ευρώ ανά λίτρο',
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ColorsUI.getCard(brightness),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ColorsUI.getBorder(brightness)),
                          ),
                          child: Row(
                            children: [
                              ExcludeSemantics(child: Icon(Icons.local_gas_station_rounded, color: ColorsUI.getPrimary(brightness), size: 20)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(fmt.format(date.toLocal()), style: TypographyUI.labelMedium(brightness)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${liters.toStringAsFixed(1)} λίτρα  •  ${price.toStringAsFixed(3)} €/λίτρο  •  ${(liters * price).toStringAsFixed(2)} €',
                                      style: TypographyUI.bodySmall(brightness).copyWith(color: ColorsUI.getTextSecondary(brightness)),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: ExcludeSemantics(child: Icon(Icons.edit_rounded, size: 20, color: ColorsUI.getPrimary(brightness))),
                                onPressed: () => _showEditPurchaseDialog(context, docId: doc.id, userId: userId, currentDate: date, currentPrice: price, currentLiters: liters),
                              ),
                              IconButton(
                                icon: ExcludeSemantics(child: Icon(Icons.delete_outline_rounded, size: 20, color: ColorsUI.getError(brightness))),
                                onPressed: () => _confirmDeletePurchase(context, docId: doc.id, userId: userId, date: date),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditPurchaseDialog(
      BuildContext context, {
        required String docId,
        required String userId,
        required DateTime currentDate,
        required double currentPrice,
        required double currentLiters,
      }) {
    final brightness = context.brightness;
    final fmt = DateFormat('dd/MM/yyyy');
    final priceCtrl = TextEditingController(text: currentPrice.toStringAsFixed(4));
    final litersCtrl = TextEditingController(text: currentLiters.toStringAsFixed(1));
    DateTime editDate = currentDate;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  ExcludeSemantics(child: Icon(Icons.edit_rounded, color: ColorsUI.getPrimary(brightness), size: 22)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Επεξεργασία Αγοράς')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Ημερομηνία: ${fmt.format(editDate.toLocal())}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: editDate.toLocal(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                            helpText: 'Ημερομηνία αγοράς',
                            cancelText: 'Άκυρο',
                            confirmText: 'Επιλογή',
                          );
                          if (picked != null) setDialogState(() => editDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: ColorsUI.getBorder(brightness)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              ExcludeSemantics(child: Icon(Icons.calendar_today_rounded, size: 16, color: ColorsUI.getPrimary(brightness))),
                              const SizedBox(width: 8),
                              Text(fmt.format(editDate.toLocal()), style: TypographyUI.bodyMedium(brightness)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    oil_utils.buildNumberField(
                      label: 'Τιμή (€/λίτρο)',
                      controller: priceCtrl,
                      icon: Icons.euro_rounded,
                      onEditingComplete: () => {},
                      brightness: brightness,
                    ),
                    const SizedBox(height: 12),
                    oil_utils.buildNumberField(
                      label: 'Λίτρα',
                      controller: litersCtrl,
                      icon: Icons.local_gas_station_rounded,
                      onEditingComplete: () => {},
                      brightness: brightness,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Άκυρο')),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                    final newPrice = oil_utils.parseDouble(priceCtrl.text) ?? 0;
                    final newLiters = oil_utils.parseDouble(litersCtrl.text) ?? 0;
                    if (newPrice <= 0 || newLiters <= 0) return;

                    setDialogState(() => isSaving = true);
                    try {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('oil_purchases')
                          .doc(docId)
                          .update({
                        'purchase_date': editDate.toUtc().toIso8601String(),
                        'price_per_liter': newPrice,
                        'liters': newLiters,
                      });
                      await onRecalculateAvgCost(userId);
                      if (ctx.mounted) {
                        Navigator.pop(dialogCtx);
                        AccessibilityService.announcePolite('Η αγορά ενημερώθηκε.');
                      }
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      AccessibilityService.announceError('Σφάλμα αποθήκευσης.');
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: ExcludeSemantics(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                      : const Text('Αποθήκευση'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeletePurchase(BuildContext context, {required String docId, required String userId, required DateTime date}) {
    final brightness = context.brightness;
    final fmt = DateFormat('dd/MM/yyyy');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            ExcludeSemantics(child: Icon(Icons.warning_rounded, color: ColorsUI.getError(brightness), size: 24)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Διαγραφή Αγοράς')),
          ],
        ),
        content: Text('Διαγραφή αγοράς της ${fmt.format(date.toLocal())};\n\nΤο μέσο κόστος θα επανυπολογιστεί αυτόματα.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Άκυρο')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('oil_purchases')
                    .doc(docId)
                    .delete();
                await onRecalculateAvgCost(userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Η αγορά διαγράφηκε.'), backgroundColor: Colors.green));
                  AccessibilityService.announcePolite('Η αγορά διαγράφηκε. Το μέσο κόστος επανυπολογίστηκε.');
                }
              } catch (e) {
                if (context.mounted) AccessibilityService.announceError('Σφάλμα διαγραφής.');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: ColorsUI.getError(brightness), foregroundColor: Colors.white),
            child: const Text('Διαγραφή'),
          ),
        ],
      ),
    );
  }
}