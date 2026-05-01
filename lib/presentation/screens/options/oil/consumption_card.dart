import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'tank_settings.dart';
import 'tank_calculations.dart';

class ConsumptionCard extends StatelessWidget {
  final TankSettings settings;
  final TankCalculator calculator;
  final double currentLiters;
  final double consumedLiters;
  final double consumedCost;
  final int activeHeatingDays;
  final double dailyConsumption;
  final double dailyCost;

  const ConsumptionCard({
    super.key,
    required this.settings,
    required this.calculator,
    required this.currentLiters,
    required this.consumedLiters,
    required this.consumedCost,
    required this.activeHeatingDays,
    required this.dailyConsumption,
    required this.dailyCost,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = context.brightness;
    final primary = ColorsUI.getPrimary(brightness);
    final hasData = settings.lastPurchaseDate != null &&
        settings.litersAtLastPurchase > 0 &&
        settings.avgCostPerLiter > 0;
    final fmt = DateFormat('dd/MM/yyyy');
    final infoColor = brightness == Brightness.dark ? ColorsUI.infoDark : ColorsUI.infoLight;

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
                  ExcludeSemantics(child: Icon(Icons.analytics_rounded, color: primary, size: 20)),
                  const SizedBox(width: 8),
                  Text('Κατανάλωση & Κόστος', style: TypographyUI.titleMedium(brightness)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (!hasData) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: infoColor.withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: infoColor.withValues(alpha:0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(child: Icon(Icons.info_outline_rounded, size: 16, color: infoColor)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Καταχωρήστε μια αγορά πετρελαίου για να εμφανιστούν στατιστικά κατανάλωσης.',
                        style: TypographyUI.bodySmall(brightness).copyWith(color: infoColor),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _statRow(brightness, icon: Icons.calendar_today_rounded, label: 'Τελευταία αγορά', value: fmt.format(settings.lastPurchaseDate!)),
              _divider(brightness),
              _statRow(brightness, icon: Icons.water_drop_rounded, label: 'Λίτρα μετά αγορά', value: '${settings.litersAtLastPurchase.toStringAsFixed(1)} λίτρα'),
              _divider(brightness),
              _statRow(brightness, icon: Icons.arrow_downward_rounded, label: 'Τρέχοντα λίτρα (slider)', value: '${currentLiters.toStringAsFixed(1)} λίτρα'),
              _divider(brightness),
              _statRow(brightness, icon: Icons.local_fire_department_rounded, label: 'Συνολική κατανάλωση', value: '${consumedLiters.toStringAsFixed(1)} λίτρα', highlight: true),
              _divider(brightness),
              _statRow(brightness, icon: Icons.euro_rounded, label: 'Συνολικό κόστος', value: '${consumedCost.toStringAsFixed(2)} €', highlight: true),
              _divider(brightness),
              _statRow(brightness, icon: Icons.schedule_rounded, label: 'Ενεργές ημέρες θέρμανσης', value: '$activeHeatingDays ημ.'),
              _statRow(brightness, icon: Icons.price_change_rounded, label: 'Μέσο κόστος/λίτρο', value: '${settings.avgCostPerLiter.toStringAsFixed(3)} €'),
              _divider(brightness),
              _statRow(brightness, icon: Icons.trending_down_rounded, label: 'Ημερήσια κατανάλωση', value: '${dailyConsumption.toStringAsFixed(2)} λίτρα/ημ'),
              _divider(brightness),
              _statRow(brightness, icon: Icons.payments_rounded, label: 'Ημερήσιο κόστος', value: '${dailyCost.toStringAsFixed(2)} €/ημ', highlight: true),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statRow(Brightness brightness, {required IconData icon, required String label, required String value, bool highlight = false}) {
    final primary = ColorsUI.getPrimary(brightness);
    final textColor = highlight ? primary : ColorsUI.getTextPrimary(brightness);
    return Semantics(
      label: '$label $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(icon, size: 16, color: ColorsUI.getTextSecondary(brightness))),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TypographyUI.bodySmall(brightness).copyWith(color: ColorsUI.getTextSecondary(brightness)))),
            Text(value, style: TypographyUI.bodyMedium(brightness).copyWith(color: textColor, fontWeight: highlight ? FontWeight.bold : FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _divider(Brightness brightness) => ExcludeSemantics(child: Divider(color: ColorsUI.getDivider(brightness), height: 1));
}