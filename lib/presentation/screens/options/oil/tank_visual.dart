import 'package:flutter/material.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'tank_type.dart';
import 'dart:math';

class TankVisual extends StatelessWidget {
  final TankType type;
  final double fillFraction;
  final double? dim1; // length/diameter
  final double? dim2; // width/height/length
  final double? dim3; // height (only for rectangular)

  const TankVisual({
    super.key,
    required this.type,
    required this.fillFraction,
    this.dim1,
    this.dim2,
    this.dim3,
  });

  @override
  Widget build(BuildContext context) {
    final hasDims = dim1 != null && dim1! > 0 &&
        (type == TankType.rectangular ? (dim2 != null && dim2! > 0 && dim3 != null && dim3! > 0) : (dim2 != null && dim2! > 0));

    return AccessibilityService.accessibleContainer(
      label: 'Δεξαμενή πετρελαίου',
      hint: hasDims
          ? 'Γεμάτη περίπου στο ${(fillFraction * 100).round()} τοις εκατό'
          : 'Συμπληρώστε πρώτα τις διαστάσεις',
      isImage: true,
      child: AspectRatio(
        aspectRatio: 3 / 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.cText2.withValues(alpha:0.4),
              width: 2,
            ),
            color: ColorsUI.getSurface(context.brightness),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CustomPaint(
              painter: _TankPainter(
                type: type,
                fillFraction: fillFraction,
                dim1: dim1,
                dim2: dim2,
                dim3: dim3,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _TankPainter extends CustomPainter {
  final TankType type;
  final double fillFraction;
  final double? dim1;
  final double? dim2;
  final double? dim3;

  _TankPainter({
    required this.type,
    required this.fillFraction,
    this.dim1,
    this.dim2,
    this.dim3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade700
      ..style = PaintingStyle.fill;

    final tankPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;

    switch (type) {
      case TankType.rectangular:
      // Υπάρχον σχέδιο για ορθογώνια δεξαμενή
        final fillHeight = size.height * fillFraction;
        canvas.drawRect(
          Rect.fromLTWH(0, size.height - fillHeight, size.width, fillHeight),
          paint,
        );
        break;

      case TankType.verticalCylinder:
      // Σχεδίαση κυκλικής δεξαμενής (κάτοψη)
        final center = Offset(size.width / 2, size.height / 2);
        final radius = min(size.width, size.height) / 2.5;
        final tankRect = Rect.fromCenter(center: center, width: radius * 2, height: radius * 2);

        // Περίγραμμα δεξαμενής
        canvas.drawCircle(center, radius, Paint()..color = Colors.grey.shade300..style = PaintingStyle.fill);

        // Υγρό: γέμισμα από κάτω προς τα πάνω, αποκοπή μέσα στον κύκλο
        final fillHeight = tankRect.height * fillFraction;
        if (fillHeight > 0) {
          final fillRect = Rect.fromLTWH(
            tankRect.left,
            tankRect.bottom - fillHeight,
            tankRect.width,
            fillHeight,
          );
          canvas.save();
          canvas.clipPath(Path()..addOval(tankRect));
          canvas.drawRect(fillRect, Paint()..color = Colors.blue.shade700);
          canvas.restore();
        }
        break;

      case TankType.horizontalCylinder:
      // Σχεδίαση οριζόντιου κυλίνδρου (στρογγυλεμένο ορθογώνιο)
        final tankHeight = size.height * 0.6;
        final tankWidth = size.width * 0.8;
        final tankRect = Rect.fromLTWH(
          (size.width - tankWidth) / 2,
          (size.height - tankHeight) / 2,
          tankWidth,
          tankHeight,
        );
        final radius = tankHeight / 2; // ακτίνα για στρογγυλοποίηση
        final tankRRect = RRect.fromRectAndRadius(tankRect, Radius.circular(radius));
        canvas.drawRRect(tankRRect, tankPaint);

        final fillHeightPx = tankHeight * fillFraction;
        if (fillHeightPx > 0) {
          final fillRect = Rect.fromLTWH(
            tankRect.left,
            tankRect.bottom - fillHeightPx,
            tankWidth,
            fillHeightPx,
          );
          canvas.save();
          canvas.clipRRect(tankRRect);
          canvas.drawRect(fillRect, paint);
          canvas.restore();
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}