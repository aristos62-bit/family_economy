import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/session/session_scope.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
import 'oil/oil.dart';

class OilPage extends StatefulWidget {
  const OilPage({super.key});

  @override
  State<OilPage> createState() => _OilPageState();
}

class _OilPageState extends State<OilPage> {
  // Data
  TankSettings? _settings;
  TankCalculator? _calculator;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _settingsLoaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Σελίδα Δεξαμενής Πετρελαίου. Ρυθμίσεις, καταχώρηση αγορών και υπολογισμοί κατανάλωσης.',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_settingsLoaded) {
      _settingsLoaded = true;
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final userId = context.session.userId;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('oil_tank')
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data() ?? {};

        // DEBUG: Εκτύπωση raw τιμών από Firestore
        DebugConfig.print(
          '🔍 OIL Raw Firestore: length_cm=${data['length_cm']}, width_cm=${data['width_cm']}, height_cm=${data['height_cm']}',
        );

        final settings = TankSettings.fromFirestore(data);
        setState(() {
          _settings = settings;
          _calculator = TankCalculator(
            type: settings.type,
            dim1: settings.dim1,
            dim2: settings.dim2,
            dim3: settings.dim3,
          );
          _isLoading = false;
        });
        // Προσθήκη debug: εκτύπωση των διαστάσεων μετά το setState
        DebugConfig.print(
          '📐 OIL after load: type=${settings.type}, dim1=${settings.dim1}, dim2=${settings.dim2}, dim3=${settings.dim3}',
        );
        DebugConfig.print('🗺️ OIL dimensionsByType: ${settings.dimensionsByType}');
      } else {
        // New user, create default rectangular tank
        final defaultDimensions = <String, List<double>>{
          TankType.rectangular.name: [0.0, 0.0, 0.0],
        };
        final defaultSettings = TankSettings(
          type: TankType.rectangular,
          dim1: 0,
          dim2: 0,
          dim3: 0,
          currentHeight: 0,
          lastOrderLiters: 0,
          pricePerLiter: 0,
          showFutureAsHeight: true,
          avgCostPerLiter: 0,
          litersAtLastPurchase: 0,
          dimensionsByType: defaultDimensions,
        );
        setState(() {
          _settings = defaultSettings;
          _calculator = TankCalculator(
            type: defaultSettings.type,
            dim1: defaultSettings.dim1,
            dim2: defaultSettings.dim2,
            dim3: defaultSettings.dim3,
          );
          _isLoading = false;
        });
      }

      DebugConfig.print(
        '🛢 OIL Loaded settings: type=${_settings!.type}, dims=${_settings!.dim1},${_settings!.dim2},${_settings!.dim3}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Σφάλμα φόρτωσης: ${e.toString()}';
      });
    }
  }

  Future<void> _saveSettings() async {
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

    if (_settings == null) return;

    // Ενημέρωση του dimensionsByType map με τις τρέχουσες διαστάσεις
    final updatedMap = Map<String, List<double>>.from(
      _settings!.dimensionsByType,
    );
    updatedMap[_settings!.type.name] = [
      _settings!.dim1,
      _settings!.dim2,
      _settings!.dim3,
    ];
    final settingsToSave = _settings!.copyWith(dimensionsByType: updatedMap);

    final userId = context.session.userId;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await settingsToSave.save(userId);
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Οι ρυθμίσεις της δεξαμενής αποθηκεύτηκαν'),
          backgroundColor: Colors.green,
        ),
      );
      AccessibilityService.announceSuccess(
        'Οι ρυθμίσεις της δεξαμενής αποθηκεύτηκαν.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Αποτυχία αποθήκευσης: ${e.toString()}';
      });
      AccessibilityService.announceError(_errorMessage!);
    }
  }

  Future<void> _recalculateAvgCost(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('oil_purchases')
        .get();

    double totalLiters = 0;
    double totalCost = 0;

    for (final doc in snapshot.docs) {
      final liters = (doc['liters'] as num).toDouble();
      final price = (doc['price_per_liter'] as num).toDouble();
      totalLiters += liters;
      totalCost += liters * price;
    }

    final newAvg = totalLiters > 0 ? totalCost / totalLiters : 0.0;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('oil_tank')
        .set({
      'avg_cost_per_liter': newAvg,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));

    // Ενημέρωση τοπικά χωρίς να ξαναφορτώσουμε όλες τις ρυθμίσεις
    if (mounted) {
      setState(() {
        _settings = _settings!.copyWith(avgCostPerLiter: newAvg);
      });
    }
  }

  void _onTankChanged(TankType newType, double dim1, double dim2, double dim3) {
    if (_settings == null) return;

    DebugConfig.print('🔄 _onTankChanged called: oldType=${_settings!.type}, newType=$newType, incoming dims=$dim1,$dim2,$dim3');

    if (newType != _settings!.type) {
      // Αποθήκευσε τον παλιό τύπο στο map
      final newDimensionsByType = Map<String, List<double>>.from(_settings!.dimensionsByType);
      newDimensionsByType[_settings!.type.name] = [_settings!.dim1, _settings!.dim2, _settings!.dim3];
      DebugConfig.print('💾 Saving dims for ${_settings!.type.name}: ${_settings!.dim1}, ${_settings!.dim2}, ${_settings!.dim3}');
      DebugConfig.print('🗺️ Full dimensionsByType before switch: $newDimensionsByType');

      // Ανάκτησε αποθηκευμένες διαστάσεις για τον νέο τύπο
      final savedDims = newDimensionsByType[newType.name];
      DebugConfig.print('🔍 Looking up dims for ${newType.name}: $savedDims');
      if (savedDims != null) {
        dim1 = savedDims[0];
        dim2 = savedDims[1];
        dim3 = savedDims[2];
        DebugConfig.print('📌 Using saved dimensions for $newType: $dim1,$dim2,$dim3');
      } else {
        // 🔥 ΑΛΛΑΓΗ: ΔΕΝ μηδενίζουμε, κρατάμε ό,τι μας δόθηκε από τα πεδία
        DebugConfig.print('📌 No saved dimensions for $newType, keeping incoming values: $dim1,$dim2,$dim3');
        // Δεν αλλάζουμε τα dim1, dim2, dim3 – παραμένουν όπως ήρθαν
      }

      setState(() {
        _settings = _settings!.copyWith(
          type: newType,
          dim1: dim1,
          dim2: dim2,
          dim3: dim3,
          dimensionsByType: newDimensionsByType,
        );
        _calculator = TankCalculator(type: newType, dim1: dim1, dim2: dim2, dim3: dim3);
        DebugConfig.print('✅ _settings updated after type change: type=${_settings!.type}, dims=${_settings!.dim1},${_settings!.dim2},${_settings!.dim3}');
      });
    } else {
      // Ίδιος τύπος – ενημέρωσε το map με τις νέες διαστάσεις
      final newDimensionsByType = Map<String, List<double>>.from(_settings!.dimensionsByType);
      newDimensionsByType[newType.name] = [dim1, dim2, dim3];

      setState(() {
        _settings = _settings!.copyWith(
          dim1: dim1,
          dim2: dim2,
          dim3: dim3,
          dimensionsByType: newDimensionsByType,
        );
        _calculator = TankCalculator(type: newType, dim1: dim1, dim2: dim2, dim3: dim3);
        DebugConfig.print('✅ _settings updated (same type): dims=$dim1,$dim2,$dim3');
      });
    }
  }

  void _onHeightChanged(double newHeight) {
    if (_settings == null) return;
    setState(() {
      _settings = _settings!.copyWith(currentHeight: newHeight);
    });
  }

  void _onPurchaseSaved(TankSettings updatedSettings) {
    setState(() {
      _settings = updatedSettings;
      _calculator = TankCalculator(
        type: updatedSettings.type,
        dim1: updatedSettings.dim1,
        dim2: updatedSettings.dim2,
        dim3: updatedSettings.dim3,
      );
    });
  }

  double get currentLiters =>
      _calculator?.volumeFromHeight(_settings?.currentHeight ?? 0) ?? 0;

  double get consumedLiters {
    final litersAtLast = _settings?.litersAtLastPurchase ?? 0;
    if (litersAtLast <= 0) return 0;
    return (litersAtLast - currentLiters).clamp(0.0, litersAtLast);
  }

  double get consumedCost => consumedLiters * (_settings?.avgCostPerLiter ?? 0);

  int get activeHeatingDays {
    final lastPurchase = _settings?.lastPurchaseDate;
    if (lastPurchase == null) return 1;
    final endDate = _settings?.lastUsageEndDate ?? DateTime.now();
    if (endDate.isBefore(lastPurchase)) return 1;
    final days = endDate.difference(lastPurchase).inDays;
    return days.clamp(1, 99999);
  }

  double get dailyConsumption =>
      activeHeatingDays > 0 ? consumedLiters / activeHeatingDays : 0;
  double get dailyCost => dailyConsumption * (_settings?.avgCostPerLiter ?? 0);

  // Responsive helpers
  double _getMaxWidth(double screenWidth) {
    if (screenWidth > 1200) return 800;
    if (screenWidth > 600) return 700;
    return screenWidth;
  }

  double _getHorizontalPadding(double screenWidth) {
    if (screenWidth > 1200) return 32.0;
    if (screenWidth > 600) return 24.0;
    return 16.0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();
    if (_settings == null || _calculator == null) {
      return const SizedBox.shrink();
    }

    final currentLiters = this.currentLiters;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Δεξαμενή Πετρελαίου'),
        actions: [
          IconButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: ColorsUI.getSurface(context.brightness),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => PurchaseHistorySheet(
                userId: context.session.userId,
                onRecalculateAvgCost: _recalculateAvgCost,
              ),
            ),
            icon: const ExcludeSemantics(child: Icon(Icons.history_rounded)),
            tooltip: 'Ιστορικό αγορών',
          ),
          IconButton(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: ExcludeSemantics(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const ExcludeSemantics(child: Icon(Icons.save_rounded)),
            tooltip: 'Αποθήκευση ρυθμίσεων',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = _getMaxWidth(constraints.maxWidth);
                  final padding = _getHorizontalPadding(constraints.maxWidth);
                  final fillFraction = _calculator!.capacity > 0
                      ? (_settings!.currentHeight /
                                _calculator!.heightFromVolume(
                                  _calculator!.capacity,
                                ))
                            .clamp(0.0, 1.0)
                      : 0.0;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TankVisual(
                              type: _settings!.type,
                              fillFraction: fillFraction,
                              dim1: _settings!.dim1,
                              dim2: _settings!.dim2,
                              dim3: _settings!.dim3,
                            ),
                            const SizedBox(height: 16),
                            DimensionsCard(
                              type: _settings!.type,
                              dim1: _settings!.dim1,
                              dim2: _settings!.dim2,
                              dim3: _settings!.dim3,
                              onChanged: _onTankChanged,
                            ),
                            const SizedBox(height: 12),
                            CurrentLevelCard(
                              type: _settings!.type,
                              dim1: _settings!.dim1,
                              dim2: _settings!.dim2,
                              dim3: _settings!.dim3,
                              currentHeight: _settings!.currentHeight,
                              currentLiters: currentLiters,
                              onHeightChanged: _onHeightChanged,
                            ),
                            const SizedBox(height: 12),
                            PurchaseCard(
                              settings: _settings!,
                              calculator: _calculator!,
                              onPurchaseSaved: _onPurchaseSaved,
                              recalculateAvgCost: _recalculateAvgCost,
                            ),
                            const SizedBox(height: 12),
                            ConsumptionCard(
                              settings: _settings!,
                              calculator: _calculator!,
                              currentLiters: currentLiters,
                              consumedLiters: consumedLiters,
                              consumedCost: consumedCost,
                              activeHeatingDays: activeHeatingDays,
                              dailyConsumption: dailyConsumption,
                              dailyCost: dailyCost,
                            ),
                            const SizedBox(height: 12),
                            FutureLevelCard(
                              settings: _settings!,
                              calculator: _calculator!,
                              currentLiters: currentLiters,
                              currentHeight: _settings!.currentHeight,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Semantics(
      liveRegion: true,
      label: 'Φόρτωση ρυθμίσεων δεξαμενής. Παρακαλώ περιμένετε.',
      excludeSemantics: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: CircularProgressIndicator(color: context.cPrimary),
              ),
              const SizedBox(height: 16),
              ExcludeSemantics(
                child: Text(
                  'Φόρτωση ρυθμίσεων δεξαμενής...',
                  style: context.bodyMd,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Άγνωστο σφάλμα',
              style: context.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Κλείσιμο'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loadSettings,
                  child: const Text('Προσπάθεια ξανά'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
