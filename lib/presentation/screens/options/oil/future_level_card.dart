import 'package:flutter/material.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'utils.dart' as oil_utils;
import 'package:family_economy/presentation/screens/options/oil/oil.dart';

class FutureLevelCard extends StatefulWidget {
  final TankSettings settings;
  final TankCalculator calculator;
  final double currentLiters;
  final double currentHeight;

  const FutureLevelCard({
    super.key,
    required this.settings,
    required this.calculator,
    required this.currentLiters,
    required this.currentHeight,
  });

  @override
  State<FutureLevelCard> createState() => _FutureLevelCardState();
}

class _FutureLevelCardState extends State<FutureLevelCard> {
  final _priceCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();
  bool _showAsHeight = true;

  @override
  void initState() {
    super.initState();
    _showAsHeight = widget.settings.showFutureAsHeight;
    _priceCtrl.text = widget.settings.pricePerLiter.toString();
    _litersCtrl.text = widget.settings.lastOrderLiters.toString();
  }

  @override
  void didUpdateWidget(covariant FutureLevelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.pricePerLiter != widget.settings.pricePerLiter) {
      _priceCtrl.text = widget.settings.pricePerLiter.toString();
    }
    if (oldWidget.settings.lastOrderLiters != widget.settings.lastOrderLiters) {
      _litersCtrl.text = widget.settings.lastOrderLiters.toString();
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _litersCtrl.dispose();
    super.dispose();
  }

  double get orderLiters => oil_utils.parseDouble(_litersCtrl.text) ?? 0;
  double get price => oil_utils.parseDouble(_priceCtrl.text) ?? 0;

  double get futureLiters {
    final total = widget.currentLiters + orderLiters;
    final cap = widget.calculator.capacity;
    return cap > 0 ? total.clamp(0.0, cap) : total;
  }

  double get futureHeight => widget.calculator.heightFromVolume(futureLiters);

  void _notifyChange() {
    setState(() {});
    // Optionally save these values as temporary? They are saved only when user clicks save in main page.
  }

  @override
  Widget build(BuildContext context) {
    final brightness = context.brightness;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Μελλοντικό Επίπεδο', style: TypographyUI.titleMedium(brightness)),
            ),
            const SizedBox(height: 12),
            oil_utils.buildNumberField(
              label: 'Τιμή ανά λίτρο (€)',
              controller: _priceCtrl,
              icon: Icons.euro_rounded,
              onEditingComplete: () => _notifyChange(),
              brightness: brightness,
            ),
            const SizedBox(height: 8),
            oil_utils.buildNumberField(
              label: 'Λίτρα παραγγελίας',
              controller: _litersCtrl,
              icon: Icons.local_gas_station_rounded,
              onEditingComplete: () => _notifyChange(),
              brightness: brightness,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Εμφάνιση Συνολικής μελλοντικής στάθμης ως:',
                    style: TypographyUI.bodySmall(brightness),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Πόντοι')),
                    ButtonSegment(value: false, label: Text('Λίτρα')),
                  ],
                  selected: {_showAsHeight},
                  onSelectionChanged: (set) {
                    final value = set.first;
                    setState(() => _showAsHeight = value);
                    AccessibilityService.announcePolite(
                      value
                          ? 'Εμφάνιση Συνολικής μελλοντικής στάθμης σε πόντους'
                          : 'Εμφάνιση Συνολικής μελλοντικής στάθμης σε λίτρα',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_showAsHeight)
              Text(
                'Μελλοντικό ύψος: ${futureHeight.toStringAsFixed(1)} πόντοι',
                style: TypographyUI.bodyMedium(brightness),
              )
            else
              Text(
                'Μελλοντική ποσότητα: ${futureLiters.toStringAsFixed(1)} λίτρα',
                style: TypographyUI.bodyMedium(brightness),
              ),
            const SizedBox(height: 8),
            Text(
              'Κόστος παραγγελίας: ${(price * orderLiters).toStringAsFixed(2)} €',
              style: TypographyUI.bodySmall(brightness),
            ),
          ],
        ),
      ),
    );
  }
}