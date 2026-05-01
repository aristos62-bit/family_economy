// Model for tank settings (holds all tank-related data)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tank_type.dart';

class TankSettings {
  final TankType type;
  final double dim1;
  final double dim2;
  final double dim3; // only for rectangular
  final double currentHeight;
  final double lastOrderLiters;
  final double pricePerLiter;
  final bool showFutureAsHeight;
  final double avgCostPerLiter;
  final double litersAtLastPurchase;
  final DateTime? lastPurchaseDate;
  final DateTime? lastUsageEndDate;
  final Map<String, List<double>> dimensionsByType;

  TankSettings({
    required this.type,
    required this.dim1,
    required this.dim2,
    required this.dim3,
    required this.currentHeight,
    required this.lastOrderLiters,
    required this.pricePerLiter,
    required this.showFutureAsHeight,
    required this.avgCostPerLiter,
    required this.litersAtLastPurchase,
    this.lastPurchaseDate,
    this.lastUsageEndDate,
    this.dimensionsByType = const {},
  });

  factory TankSettings.fromFirestore(Map<String, dynamic> data) {
    final typeStr = data['tank_type'] as String? ?? 'rectangular';
    final type = TankType.values.firstWhere(
          (e) => e.name == typeStr,
      orElse: () => TankType.rectangular,
    );

    // Διάβασε dimensionsByType (αν υπάρχει)
    final dimensionsMap = <String, List<double>>{};
    final rawMap = data['dimensions_by_type'] as Map<String, dynamic>?;
    if (rawMap != null) {
      rawMap.forEach((key, value) {
        final list = (value as List<dynamic>).map((e) => (e as num).toDouble()).toList();
        dimensionsMap[key] = list;
      });
    }

    // Αν δεν υπάρχει dimensionsMap, δημιούργησέ το από τα παλιά πεδία για τον τρέχοντα τύπο
    if (dimensionsMap.isEmpty) {
      double dim1 = (data['dim1_cm'] ?? 0).toDouble();
      if (dim1 == 0) dim1 = (data['length_cm'] ?? 0).toDouble();
      double dim2 = (data['dim2_cm'] ?? 0).toDouble();
      if (dim2 == 0) dim2 = (data['width_cm'] ?? 0).toDouble();
      double dim3 = (data['dim3_cm'] ?? 0).toDouble();
      if (dim3 == 0) dim3 = (data['height_cm'] ?? 0).toDouble();
      dimensionsMap[type.name] = [dim1, dim2, dim3];
    }

    // Ανάκτηση τρεχουσών διαστάσεων από το map για τον τρέχοντα τύπο
    final currentDims = dimensionsMap[type.name] ?? [0.0, 0.0, 0.0];
    final dim1 = currentDims[0];
    final dim2 = currentDims[1];
    final dim3 = currentDims[2];

    return TankSettings(
      type: type,
      dim1: dim1,
      dim2: dim2,
      dim3: dim3,
      currentHeight: (data['current_height_cm'] ?? 0).toDouble(),
      lastOrderLiters: (data['last_order_liters'] ?? 0).toDouble(),
      pricePerLiter: (data['price_per_liter'] ?? 0).toDouble(),
      showFutureAsHeight: data['show_future_as_height'] ?? true,
      avgCostPerLiter: (data['avg_cost_per_liter'] ?? 0).toDouble(),
      litersAtLastPurchase: (data['liters_at_last_purchase'] ?? 0).toDouble(),
      lastPurchaseDate: data['last_purchase_date'] != null
          ? DateTime.tryParse(data['last_purchase_date'])
          : null,
      lastUsageEndDate: data['last_usage_end_date'] != null
          ? DateTime.tryParse(data['last_usage_end_date'])
          : null,
      dimensionsByType: dimensionsMap,
    );
  }

  Map<String, dynamic> toMap() {
    // Μετατροπή dimensionsByType σε Map<String, List<num>>
    final dimensionsMap = dimensionsByType.map((key, value) => MapEntry(key, value.map((e) => e).toList()));

    return {
      'tank_type': type.name,
      'dim1_cm': dim1,
      'dim2_cm': dim2,
      'dim3_cm': dim3,
      'length_cm': dim1,
      'width_cm': dim2,
      'height_cm': dim3,
      'current_height_cm': currentHeight,
      'last_order_liters': lastOrderLiters,
      'price_per_liter': pricePerLiter,
      'show_future_as_height': showFutureAsHeight,
      'avg_cost_per_liter': avgCostPerLiter,
      'liters_at_last_purchase': litersAtLastPurchase,
      'last_purchase_date': lastPurchaseDate?.toUtc().toIso8601String(),
      'last_usage_end_date': lastUsageEndDate?.toUtc().toIso8601String(),
      'dimensions_by_type': dimensionsMap,
    };
  }

  Future<void> save(String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('oil_tank')
        .set(toMap(), SetOptions(merge: true));
  }
  TankSettings copyWith({
    TankType? type,
    double? dim1,
    double? dim2,
    double? dim3,
    double? currentHeight,
    double? lastOrderLiters,
    double? pricePerLiter,
    bool? showFutureAsHeight,
    double? avgCostPerLiter,
    double? litersAtLastPurchase,
    DateTime? lastPurchaseDate,
    DateTime? lastUsageEndDate,
    Map<String, List<double>>? dimensionsByType,
  }) {
    return TankSettings(
      type: type ?? this.type,
      dim1: dim1 ?? this.dim1,
      dim2: dim2 ?? this.dim2,
      dim3: dim3 ?? this.dim3,
      currentHeight: currentHeight ?? this.currentHeight,
      lastOrderLiters: lastOrderLiters ?? this.lastOrderLiters,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      showFutureAsHeight: showFutureAsHeight ?? this.showFutureAsHeight,
      avgCostPerLiter: avgCostPerLiter ?? this.avgCostPerLiter,
      litersAtLastPurchase: litersAtLastPurchase ?? this.litersAtLastPurchase,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      lastUsageEndDate: lastUsageEndDate ?? this.lastUsageEndDate,
      dimensionsByType: dimensionsByType ?? this.dimensionsByType,
    );
  }
}