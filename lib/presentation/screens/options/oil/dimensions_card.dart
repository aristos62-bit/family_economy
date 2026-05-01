import 'package:flutter/material.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'tank_type.dart';
import 'tank_calculations.dart';
import 'utils.dart' as oil_utils;

class DimensionsCard extends StatefulWidget {
  final TankType type;
  final double dim1;
  final double dim2;
  final double dim3;
  final void Function(TankType newType, double dim1, double dim2, double dim3) onChanged;

  const DimensionsCard({
    super.key,
    required this.type,
    required this.dim1,
    required this.dim2,
    required this.dim3,
    required this.onChanged,
  });

  @override
  State<DimensionsCard> createState() => _DimensionsCardState();
}

class _DimensionsCardState extends State<DimensionsCard> {
  late TextEditingController _dim1Ctrl;
  late TextEditingController _dim2Ctrl;
  late TextEditingController _dim3Ctrl;
  late TankType _selectedType;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.type;
    _dim1Ctrl = TextEditingController();
    _dim2Ctrl = TextEditingController();
    _dim3Ctrl = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant DimensionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    DebugConfig.print( 'OIL  📦 didUpdateWidget: oldType=${oldWidget.type}, newType=${widget.type}');
    if (oldWidget.type != widget.type) {
      DebugConfig.print( 'OIL  🔄 Type changed, clearing controllers');
      _selectedType = widget.type;
      _dim1Ctrl.clear();
      _dim2Ctrl.clear();
      _dim3Ctrl.clear();
    }
    _syncControllers();
  }

  @override
  void dispose() {
    _dim1Ctrl.dispose();
    _dim2Ctrl.dispose();
    _dim3Ctrl.dispose();
    super.dispose();
  }

  void _syncControllers() {
    DebugConfig.print( 'OIL  🔍 _syncControllers: _isUpdating=$_isUpdating, widget.dim1=${widget.dim1}, dim2=${widget.dim2}, dim3=${widget.dim3}');
     // if (_isUpdating) return;
    final current1 = double.tryParse(_dim1Ctrl.text) ?? 0.0;
    if (current1 != widget.dim1) {
      DebugConfig.print( 'OIL  🔄 Updating dim1 controller from $current1 to ${widget.dim1}');
      _dim1Ctrl.text = widget.dim1 > 0 ? widget.dim1.toString() : '';
    }

    final current2 = double.tryParse(_dim2Ctrl.text) ?? 0.0;
    if (current2 != widget.dim2) {
      DebugConfig.print( 'OIL  🔄 Updating dim2 controller from $current2 to ${widget.dim2}');
      _dim2Ctrl.text = widget.dim2 > 0 ? widget.dim2.toString() : '';
    }

    if (_selectedType == TankType.rectangular) {
      final current3 = double.tryParse(_dim3Ctrl.text) ?? 0.0;
      if (current3 != widget.dim3) {
        DebugConfig.print( 'OIL  🔄 Updating dim3 controller from $current3 to ${widget.dim3}');
        _dim3Ctrl.text = widget.dim3 > 0 ? widget.dim3.toString() : '';
      }
    } else {
      if (_dim3Ctrl.text.isNotEmpty) {
        DebugConfig.print( 'OIL  🧹 Clearing dim3 controller (non-rectangular type)');
        _dim3Ctrl.clear();
      }
    }
  }

  void _notifyChange() {
    if (_isUpdating) return;

    final newDim1 = oil_utils.parseDouble(_dim1Ctrl.text) ?? 0.0;
    final newDim2 = oil_utils.parseDouble(_dim2Ctrl.text) ?? 0.0;
    final newDim3 = oil_utils.parseDouble(_dim3Ctrl.text) ?? 0.0;

    DebugConfig.print('OIL _notifyChange: dim1Ctrl.text="${_dim1Ctrl.text}" → $newDim1, dim2="${_dim2Ctrl.text}" → $newDim2, dim3="${_dim3Ctrl.text}" → $newDim3');

    if (newDim1 == widget.dim1 && newDim2 == widget.dim2 && newDim3 == widget.dim3) {
      DebugConfig.print('OIL _notifyChange: no change, returning');
      return;
    }

    DebugConfig.print('OIL _notifyChange: calling onChanged with ($newDim1, $newDim2, $newDim3)');
    _isUpdating = true;
    widget.onChanged(_selectedType, newDim1, newDim2, newDim3);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdating = false;
      DebugConfig.print('OIL _notifyChange: _isUpdating reset to false');
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = context.brightness;
    final capacity = TankCalculator(
      type: _selectedType,
      dim1: oil_utils.parseDouble(_dim1Ctrl.text) ?? 0.0,
      dim2: oil_utils.parseDouble(_dim2Ctrl.text) ?? 0.0,
      dim3: oil_utils.parseDouble(_dim3Ctrl.text) ?? 0.0,
    ).capacity;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Διαστάσεις Δεξαμενής',
                style: TypographyUI.titleMedium(brightness),
              ),
            ),
            const SizedBox(height: 12),

            // Tank type selector
            SegmentedButton<TankType>(
              segments: [
                for (final type in TankType.values)
                  ButtonSegment(
                    value: type,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(type.icon),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            type.displayName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<TankType> set) {
                final newType = set.first;
                setState(() {
                  _selectedType = newType;
                  _dim1Ctrl.clear();
                  _dim2Ctrl.clear();
                  _dim3Ctrl.clear();
                });
                // Καλούμε απευθείας, όχι μέσω _notifyChange που μπορεί να μπλοκαριστεί από _isUpdating
                widget.onChanged(newType, 0, 0, 0);
                AccessibilityService.announcePolite(
                  'Επιλέξατε ${newType.displayName} δεξαμενή',
                );
              },
            ),
            const SizedBox(height: 16),

            ..._buildDimensionFields(brightness),
            const SizedBox(height: 12),

            Text(
              capacity > 0
                  ? 'Συνολική χωρητικότητα: ${capacity.toStringAsFixed(1)} λίτρα'
                  : 'Συμπληρώστε διαστάσεις για υπολογισμό χωρητικότητας',
              style: TypographyUI.bodyMedium(brightness),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDimensionFields(Brightness brightness) {
    final labels = _selectedType.dimensionLabels;
    final controllers = [
      _dim1Ctrl,
      _dim2Ctrl,
      if (_selectedType == TankType.rectangular) _dim3Ctrl,
    ];
    final icons = [
      Icons.straighten_rounded,
      Icons.straighten_rounded,
      Icons.height_rounded,
    ];

    List<Widget> fields = [];
    for (int i = 0; i < controllers.length; i++) {
      fields.add(
        oil_utils.buildNumberField(
          label: labels[i],
          controller: controllers[i],
          icon: icons[i],
          onEditingComplete: () => _notifyChange(),
          brightness: brightness,
        ),
      );
      if (i < controllers.length - 1) fields.add(const SizedBox(height: 8));
    }
    return fields;
  }
}