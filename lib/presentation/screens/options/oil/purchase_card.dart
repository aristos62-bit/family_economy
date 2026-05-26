import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'tank_type.dart';
import 'tank_calculations.dart';
import 'utils.dart' as oil_utils;
import 'tank_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/core/session/session_scope.dart';

class PurchaseCard extends StatefulWidget {
  final TankSettings settings;
  final TankCalculator calculator;
  final void Function(TankSettings) onPurchaseSaved;  // changed
  final Future<void> Function(String userId) recalculateAvgCost;

  const PurchaseCard({
    super.key,
    required this.settings,
    required this.calculator,
    required this.onPurchaseSaved,
    required this.recalculateAvgCost,
  });

  @override
  State<PurchaseCard> createState() => _PurchaseCardState();
}

class _PurchaseCardState extends State<PurchaseCard> {
  final _priceCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();
  final _existingPriceCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.settings.lastPurchaseDate ?? DateTime.now();
    if (widget.settings.avgCostPerLiter <= 0 &&
        widget.settings.currentHeight > 0) {
      // If we have oil but no avg cost, we may need to ask for existing price
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _litersCtrl.dispose();
    _existingPriceCtrl.dispose();
    super.dispose();
  }

  double get currentLiters =>
      widget.calculator.volumeFromHeight(widget.settings.currentHeight);
  double get tankCapacity => widget.calculator.capacity;

  Future<void> _savePurchase() async {

    // Κλείνουμε το πληκτρολόγιο για να ενημερωθούν τυχόν επεξεργαζόμενα πεδία
    FocusScope.of(context).unfocus();
    await Future.delayed(Duration.zero); // δίνουμε χρόνο να ολοκληρωθεί το unfocus

    final liters = oil_utils.parseDouble(_litersCtrl.text) ?? 0;
    final price = oil_utils.parseDouble(_priceCtrl.text) ?? 0;

    if (liters <= 0 || price <= 0) {
      if (!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Συμπληρώστε τιμή ανά λίτρο και λίτρα αγοράς.'),
        ),
      );
      AccessibilityService.announceError(
        'Συμπληρώστε τιμή ανά λίτρο και λίτρα αγοράς.',
      );
      return;
    }
    if (!mounted)return;
    final connectivity = context.read<ConnectivityService>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Εκτός σύνδεσης — δεν είναι δυνατή η αποθήκευση.'),
        ),
      );
      AccessibilityService.announceError(
        'Εκτός σύνδεσης. Δεν είναι δυνατή η αποθήκευση.',
      );
      return;
    }

    final userId = context.session.userId;
    setState(() => _isSaving = true);

    try {
      final oldLiters = currentLiters;
      final totalLiters = oldLiters + liters;

      final existingPrice = widget.settings.avgCostPerLiter > 0
          ? widget.settings.avgCostPerLiter
          : (oil_utils.parseDouble(_existingPriceCtrl.text) ?? 0);

      final newAvgCost = totalLiters > 0
          ? (oldLiters * existingPrice + liters * price) / totalLiters
          : price;

      final cappedTotal = tankCapacity > 0
          ? totalLiters.clamp(0.0, tankCapacity)
          : totalLiters;
      final newHeight = widget.calculator.heightFromVolume(cappedTotal);

      final purchaseDateStr = _selectedDate.toUtc().toIso8601String();

      // Save purchase record
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('oil_purchases')
          .doc()
          .set({
            'purchase_date': purchaseDateStr,
            'price_per_liter': price,
            'liters': liters,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });

      // Update tank settings
      final updatedSettings = TankSettings(
        type: widget.settings.type,
        dim1: widget.settings.dim1,
        dim2: widget.settings.dim2,
        dim3: widget.settings.dim3,
        currentHeight: newHeight,
        lastOrderLiters: widget.settings.lastOrderLiters,
        pricePerLiter: widget.settings.pricePerLiter,
        showFutureAsHeight: widget.settings.showFutureAsHeight,
        avgCostPerLiter: newAvgCost,
        litersAtLastPurchase: cappedTotal,
        lastPurchaseDate: _selectedDate,
        lastUsageEndDate: widget.settings.lastUsageEndDate,
      );

      await updatedSettings.save(userId);

      // Refresh parent με τα ενημερωμένα στοιχεία
      widget.onPurchaseSaved(updatedSettings);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _priceCtrl.clear();
        _litersCtrl.clear();
        _existingPriceCtrl.clear();
        _selectedDate = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Αγορά καταχωρήθηκε! '
            '${cappedTotal.toStringAsFixed(1)} λίτρα στη δεξαμενή | '
            '${newAvgCost.toStringAsFixed(3)} €/λίτρο (μέσο)',
          ),
          backgroundColor: Colors.green,
        ),
      );
      AccessibilityService.announcePolite(
        'Αγορά καταχωρήθηκε. Νέα ποσότητα ${cappedTotal.toStringAsFixed(1)} λίτρα. '
        'Μέσο κόστος ${newAvgCost.toStringAsFixed(3)} ευρώ ανά λίτρο.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final msg = 'Αποτυχία καταχώρησης αγοράς: ${e.toString()}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      AccessibilityService.announceError(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = context.brightness;
    final primary = ColorsUI.getPrimary(brightness);
    final fmt = DateFormat('dd/MM/yyyy');
    final connectivity = context.watch<ConnectivityService>();

    final previewLiters =
        currentLiters + (oil_utils.parseDouble(_litersCtrl.text) ?? 0);
    final capped = tankCapacity > 0
        ? previewLiters.clamp(0.0, tankCapacity)
        : previewLiters;
    final hasDims =
        widget.settings.dim1 > 0 &&
        (widget.settings.type == TankType.rectangular
            ? widget.settings.dim2 > 0 && widget.settings.dim3 > 0
            : widget.settings.dim2 > 0);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.local_gas_station_rounded,
                      color: primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Αγορά Πετρελαίου',
                    style: TypographyUI.titleMedium(brightness),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (connectivity.isOffline) _OfflineBanner(brightness: brightness),
            if (connectivity.isOffline) const SizedBox(height: 12),

            // Date picker
            _buildDatePicker(brightness, fmt),
            const SizedBox(height: 12),

            // Existing price warning
            if (widget.settings.currentHeight > 0 &&
                widget.settings.avgCostPerLiter < 0.001) ...[
              _buildExistingPriceWarning(brightness),
              const SizedBox(height: 8),
              oil_utils.buildNumberField(
                label: 'Τιμή υπάρχοντος αποθέματος (€/λίτρο)',
                controller: _existingPriceCtrl,
                icon: Icons.history_rounded,
                onEditingComplete: () => setState(() {}),
                brightness: brightness,
              ),

              oil_utils.buildNumberField(
                label: 'Τιμή αγοράς ανά λίτρο (€)',
                controller: _priceCtrl,
                icon: Icons.euro_rounded,
                onEditingComplete: () => setState(() {}),
                brightness: brightness,
              ),
              const SizedBox(height: 8),

              oil_utils.buildNumberField(
                label: 'Λίτρα που βάλατε',
                controller: _litersCtrl,
                icon: Icons.local_gas_station_rounded,
                onEditingComplete: () => setState(() {}),
                brightness: brightness,
              ),
              const SizedBox(height: 12),

              if (hasDims &&
                  (oil_utils.parseDouble(_litersCtrl.text) ?? 0) > 0) ...[
                _buildPreview(brightness, previewLiters, capped),
                const SizedBox(height: 12),
              ],

              ElevatedButton.icon(
                onPressed: (_isSaving || connectivity.isOffline)
                    ? null
                    : _savePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: ColorsUI.getOnPrimary(brightness),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: ExcludeSemantics(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const ExcludeSemantics(
                        child: Icon(Icons.add_circle_rounded, size: 20),
                      ),
                label: Text(_isSaving ? 'Αποθήκευση...' : 'Καταχώρηση Αγοράς'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(Brightness brightness, DateFormat fmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ημερομηνία αγοράς',
          style: TypographyUI.labelMedium(
            brightness,
          ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label:
              'Επιλογή ημερομηνίας αγοράς. Τρέχουσα: ${fmt.format(_selectedDate)}',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                helpText: 'Ημερομηνία αγοράς πετρελαίου',
                cancelText: 'Άκυρο',
                confirmText: 'Επιλογή',
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                AccessibilityService.announcePolite(
                  'Ημερομηνία αγοράς: ${fmt.format(picked)}',
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: ColorsUI.getInputFill(brightness),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorsUI.getBorder(brightness)),
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: ColorsUI.getPrimary(brightness),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fmt.format(_selectedDate),
                      style: TypographyUI.bodyMedium(
                        brightness,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ColorsUI.getTextSecondary(brightness),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingPriceWarning(Brightness brightness) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ColorsUI.getWarning(brightness).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ColorsUI.getWarning(brightness).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: ColorsUI.getWarning(brightness),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Υπάρχει ήδη ${currentLiters.toStringAsFixed(1)} λίτρα στη δεξαμενή. '
                'Συμπληρώστε την τιμή αγοράς τους για σωστό υπολογισμό μέσου κόστους.',
                style: TypographyUI.bodySmall(
                  brightness,
                ).copyWith(color: ColorsUI.getWarning(brightness)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(
    Brightness brightness,
    double previewLiters,
    double capped,
  ) {
    final primary = ColorsUI.getPrimary(brightness);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewRow(
            brightness,
            'Τρέχουσα ποσότητα:',
            '${currentLiters.toStringAsFixed(1)} λίτρα',
          ),
          _previewRow(
            brightness,
            'Προστίθενται:',
            '+ ${(oil_utils.parseDouble(_litersCtrl.text) ?? 0).toStringAsFixed(1)} λίτρα',
          ),
          const Divider(height: 16),
          _previewRow(
            brightness,
            'Νέα ποσότητα:',
            '${capped.toStringAsFixed(1)} λίτρα',
            bold: true,
          ),
          if (tankCapacity > 0 && previewLiters > tankCapacity)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  '⚠ Υπέρβαση χωρητικότητας — περικόπτεται στα ${tankCapacity.toStringAsFixed(1)} λίτρα',
                  style: TypographyUI.bodySmall(
                    brightness,
                  ).copyWith(color: ColorsUI.getWarning(brightness)),
                ),
              ),
            ),
          if ((oil_utils.parseDouble(_priceCtrl.text) ?? 0) > 0) ...[
            const SizedBox(height: 4),
            _previewRow(
              brightness,
              'Κόστος αγοράς:',
              '${((oil_utils.parseDouble(_priceCtrl.text) ?? 0) * (oil_utils.parseDouble(_litersCtrl.text) ?? 0)).toStringAsFixed(2)} €',
            ),
            if (widget.settings.currentHeight > 0) ...[
              const SizedBox(height: 8),
              if (widget.settings.avgCostPerLiter > 0)
                _previewRow(
                  brightness,
                  'Κόστος παλιού αποθέματος:',
                  '${widget.settings.avgCostPerLiter.toStringAsFixed(3)} €/λίτρο',
                )
              else
                Text(
                  'Κόστος παλιού αποθέματος (€/λίτρο)',
                  style: TypographyUI.bodySmall(brightness).copyWith(
                    color: ColorsUI.getWarning(brightness),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
            _previewRow(
              brightness,
              'Νέο μέσο κόστος/λίτρο:',
              _calculateNewAvgCost(brightness),
            ),
          ],
        ],
      ),
    );
  }

  String _calculateNewAvgCost(Brightness brightness) {
    final ol = currentLiters;
    final nl = oil_utils.parseDouble(_litersCtrl.text) ?? 0;
    final np = oil_utils.parseDouble(_priceCtrl.text) ?? 0;
    final tot = ol + nl;
    if (tot <= 0) return '—';
    final existingPrice = widget.settings.avgCostPerLiter > 0
        ? widget.settings.avgCostPerLiter
        : (oil_utils.parseDouble(_existingPriceCtrl.text) ?? 0);
    if (existingPrice <= 0 && ol > 0) {
      return '⚠ Λείπει παλιά τιμή';
    }
    final avg = (ol * existingPrice + nl * np) / tot;
    return '${avg.toStringAsFixed(3)} €';
  }

  Widget _previewRow(
    Brightness brightness,
    String label,
    String value, {
    bool bold = false,
  }) {
    final style = TypographyUI.bodySmall(
      brightness,
    ).copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Semantics(
      label: '$label $value',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: style),
              Text(value, style: style),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final Brightness brightness;
  const _OfflineBanner({required this.brightness});

  @override
  Widget build(BuildContext context) {
    final color = brightness == Brightness.dark
        ? ColorsUI.warningDark
        : ColorsUI.warningLight;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.wifi_off_rounded, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Εκτός σύνδεσης — η αποθήκευση δεν είναι δυνατή.',
                style: TypographyUI.bodySmall(
                  brightness,
                ).copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
