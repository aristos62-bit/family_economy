import 'dart:math';
import 'tank_type.dart';

class TankCalculator {
  final TankType type;
  final double dim1; // length or diameter
  final double dim2; // width or height/length
  final double dim3; // height (only for rectangular)

  TankCalculator({
    required this.type,
    required this.dim1,
    required this.dim2,
    this.dim3 = 0,
  });

  // Capacity in liters
  double get capacity {
    switch (type) {
      case TankType.rectangular:
        if (dim1 <= 0 || dim2 <= 0 || dim3 <= 0) return 0;
        return dim1 * dim2 * dim3 / 1000.0;
      case TankType.verticalCylinder:
        if (dim1 <= 0 || dim2 <= 0) return 0;
        final radius = dim1 / 2;
        return pi * radius * radius * dim2 / 1000.0;
      case TankType.horizontalCylinder:
        if (dim1 <= 0 || dim2 <= 0) return 0;
        final radius = dim1 / 2;
        return pi * radius * radius * dim2 / 1000.0;
    }
  }

  // Volume in liters given fill height (cm)
  double volumeFromHeight(double heightCm) {
    if (heightCm <= 0) return 0;
    switch (type) {
      case TankType.rectangular:
        if (dim1 <= 0 || dim2 <= 0 || dim3 <= 0) return 0;
        return dim1 * dim2 * heightCm / 1000.0;
      case TankType.verticalCylinder:
        if (dim1 <= 0 || dim2 <= 0) return 0;
        final radius = dim1 / 2;
        return pi * radius * radius * heightCm / 1000.0;
      case TankType.horizontalCylinder:
        if (dim1 <= 0 || dim2 <= 0) return 0;
        final radius = dim1 / 2;
        final height = heightCm.clamp(0.0, dim1);
        // Segment area formula: area = r^2 * acos((r - h)/r) - (r - h) * sqrt(2rh - h^2)
        final r = radius;
        final h = height;
        final segmentArea = r * r * acos((r - h) / r) - (r - h) * sqrt(2 * r * h - h * h);
        return segmentArea * dim2 / 1000.0;
    }
  }

  // Fill height (cm) given volume (liters)
  double heightFromVolume(double liters) {
    if (liters <= 0) return 0;
    if (liters >= capacity) {
      switch (type) {
        case TankType.rectangular:
          return dim3;
        case TankType.verticalCylinder:
          return dim2;
        case TankType.horizontalCylinder:
          return dim1;
      }
    }

    switch (type) {
      case TankType.rectangular:
        if (dim1 <= 0 || dim2 <= 0) return 0;
        return liters * 1000.0 / (dim1 * dim2);
      case TankType.verticalCylinder:
        if (dim1 <= 0) return 0;
        final radius = dim1 / 2;
        return liters * 1000.0 / (pi * radius * radius);
      case TankType.horizontalCylinder:
        if (dim1 <= 0 || dim2 <= 0) return 0;
        // Inverse of segment area fraction – approximate using binary search
        double low = 0, high = dim1;
        for (int i = 0; i < 50; i++) {
          final mid = (low + high) / 2;
          final vol = volumeFromHeight(mid);
          if (vol < liters) {low = mid;}
          else {high = mid;}
        }
        return (low + high) / 2;
    }
  }
}