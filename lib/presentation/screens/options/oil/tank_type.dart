// Tank type enum and helper functions
enum TankType {
  rectangular,
  verticalCylinder,
  horizontalCylinder,
}

extension TankTypeExtension on TankType {
  String get displayName {
    switch (this) {
      case TankType.rectangular:
        return 'Ορθογώνια';
      case TankType.verticalCylinder:
        return 'Κατακόρυφη Κυλινδρική';
      case TankType.horizontalCylinder:
        return 'Οριζόντια Κυλινδρική';
    }
  }

  String get icon {
    switch (this) {
      case TankType.rectangular:
        return '📦';
      case TankType.verticalCylinder:
        return '⭕';
      case TankType.horizontalCylinder:
        return '🔘';
    }
  }

  List<String> get dimensionLabels {
    switch (this) {
      case TankType.rectangular:
        return ['Μήκος (cm)', 'Πλάτος (cm)', 'Ύψος (cm)'];
      case TankType.verticalCylinder:
        return ['Διάμετρος (cm)', 'Ύψος (cm)'];
      case TankType.horizontalCylinder:
        return ['Διάμετρος (cm)', 'Μήκος (cm)'];
    }
  }
}