import 'package:flutter/material.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';

double? parseDouble(String text) => double.tryParse(text.replaceAll(',', '.'));

Widget buildNumberField({
  required String label,
  required TextEditingController controller,
  required IconData icon,
  required VoidCallback onEditingComplete,
  required Brightness brightness,
  bool enableTapOutside = true,
}) {
  return Semantics(
    label: label,
    hint: 'Πληκτρολογήστε τιμή σε αριθμούς',
    textField: true,
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
      onEditingComplete: () {
        onEditingComplete();
        // Ανακοίνωση της τιμής μετά την ολοκλήρωση
        final value = controller.text;
        AccessibilityService.announceLiveRegion(
            '$label: ${value.isEmpty ? 'κενό' : value}'
        );
      },
      onTapOutside: enableTapOutside ? (_) {
        onEditingComplete();
        final value = controller.text;
        AccessibilityService.announceLiveRegion(
            '$label: ${value.isEmpty ? 'κενό' : value}'
        );
      } : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: ExcludeSemantics(child: Icon(icon, size: 20)),
      ),
    ),
  );
}