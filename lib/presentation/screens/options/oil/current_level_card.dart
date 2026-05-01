import 'package:flutter/material.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'tank_type.dart';
import 'utils.dart' as oil_utils;

class CurrentLevelCard extends StatefulWidget {
  final TankType type;
  final double dim1;
  final double dim2;
  final double dim3;
  final double currentHeight;
  final double currentLiters;
  final void Function(double newHeight) onHeightChanged;

  const CurrentLevelCard({
    super.key,
    required this.type,
    required this.dim1,
    required this.dim2,
    required this.dim3,
    required this.currentHeight,
    required this.currentLiters,
    required this.onHeightChanged,
  });

  @override
  State<CurrentLevelCard> createState() => _CurrentLevelCardState();
}

class _CurrentLevelCardState extends State<CurrentLevelCard> {
  final _heightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _heightCtrl.text = widget.currentHeight.toStringAsFixed(1);
  }

  @override
  void didUpdateWidget(covariant CurrentLevelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentHeight != widget.currentHeight) {
      _heightCtrl.text = widget.currentHeight.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    super.dispose();
  }

  double get maxHeight {
    switch (widget.type) {
      case TankType.rectangular:
        return widget.dim3;
      case TankType.verticalCylinder:
        return widget.dim2;
      case TankType.horizontalCylinder:
        return widget.dim1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = context.brightness;
    final maxForSlider = maxHeight > 0 ? maxHeight : 100.0;
    final divisions = maxForSlider.clamp(1, 500).round();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Τρέχον Επίπεδο',
                    style: TypographyUI.titleMedium(brightness),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Εισαγωγή ύψους από πληκτρολόγιο',
                  onPressed: () async {
                    _heightCtrl.text = widget.currentHeight.toStringAsFixed(1);
                    final result = await showDialog<double>(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: const Text('Εισαγωγή ύψους (πόντοι)'),
                          content: TextField(
                            controller: _heightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: false,
                              signed: false,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Πόντοι',
                              hintText: 'π.χ. 45',
                            ),
                            autofocus: true,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Άκυρο'),
                            ),
                            FilledButton(
                              onPressed: () {
                                final value = oil_utils.parseDouble(
                                  _heightCtrl.text,
                                );
                                if (value == null || value < 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Δώστε έγκυρο αριθμό πόντων.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final clamped = value.clamp(0.0, maxForSlider);
                                Navigator.of(ctx).pop(clamped.toDouble());
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                    if (result != null) {
                      widget.onHeightChanged(result);
                      AccessibilityService.announceLiveRegion(
                        'Τρέχον ύψος ${result.toStringAsFixed(0)} πόντοι',
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Ύψος πετρελαίου (πόντοι)',
              style: TypographyUI.bodySmall(brightness),
            ),
            Slider(
              value: widget.currentHeight.clamp(0, maxForSlider).toDouble(),
              min: 0,
              max: maxForSlider,
              divisions: divisions,
              label: '${widget.currentHeight.toStringAsFixed(0)} πόντοι',
              onChanged: (value) {
                widget.onHeightChanged(value);
              },
              onChangeEnd: (value) {
                AccessibilityService.announceLiveRegion(
                  'Τρέχον ύψος ${value.toStringAsFixed(0)} πόντοι',
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Τρέχον ποσό: ${widget.currentLiters.toStringAsFixed(1)} λίτρα',
              style: TypographyUI.bodyMedium(brightness),
            ),
          ],
        ),
      ),
    );
  }
}