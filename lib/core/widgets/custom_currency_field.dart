import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/currency_formatter.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import '../accessibility/accessibility_service.dart';

/// Custom Currency Input Field
/// Formats input as € 1.500,20 with full validation and accessibility
class CustomCurrencyField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final double? initialValue;
  final ValueChanged<double?>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool compact;
  final bool required;
  final double? minValue;
  final double? maxValue;
  final bool allowNegative;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final String currency;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;

  const CustomCurrencyField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.required = false,
    this.minValue,
    this.maxValue,
    this.allowNegative = false,
    this.enabled = true,
    this.compact = false,
    this.focusNode,
    this.textInputAction,
    this.onEditingComplete,
    this.currency = CurrencyFormatter.defaultCurrency,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
  });

  @override
  State<CustomCurrencyField> createState() => _CustomCurrencyFieldState();
}

class _CustomCurrencyFieldState extends State<CustomCurrencyField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isInternalController = false;
  bool _isInternalFocusNode = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();

    // Initialize controller
    if (widget.controller == null) {
      _controller = TextEditingController();
      _isInternalController = true;

      // Set initial value if provided
      if (widget.initialValue != null) {
        _controller.text = CurrencyFormatter.formatWithoutSymbol(
          widget.initialValue!,
        );
      }
    } else {
      _controller = widget.controller!;
    }

    // Initialize focus node
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _isInternalFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }

    // Add focus listener
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant CustomCurrencyField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ Αν αλλάξει controller από parent, ανανεώνουμε την αναφορά
    if (widget.controller != oldWidget.controller) {
      if (_isInternalController) {
        _controller.dispose();
        _isInternalController = false;
      }
      _controller = widget.controller ?? TextEditingController();
      _isInternalController = widget.controller == null;
    }

    // ✅ Αν αλλάξει initialValue, συγχρονίζουμε το UI
    if (oldWidget.initialValue != widget.initialValue) {
      final newVal = widget.initialValue;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (newVal == null) {
          _controller.clear();
        } else {
          _controller.text = CurrencyFormatter.formatWithoutSymbol(newVal);
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);

    if (_isInternalController) {
      _controller.dispose();
    }

    if (_isInternalFocusNode) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;

    setState(() {});

    if (hasFocus) {
      // ✅ ΠΑΝΤΑ καθάρισμα στο focus/tap
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );

      AccessibilityService.announcePolite(
        '${widget.label ?? 'Ποσό'}. Εισάγετε ποσό σε ${widget.currency}.',
      );
    } else {
      // ✅ ΜΟΝΟ validation στο blur (χωρίς format)
      _validate();
    }
  }

  void _formatInput() {
    final text = _controller.text;
    if (text.isEmpty) return;

    final amount = CurrencyFormatter.parseAmount(text);
    if (amount != null) {
      final formatted = CurrencyFormatter.formatWithoutSymbol(amount);

      // Update text
      _controller.text = formatted;

      // Move cursor to end
      _controller.selection = TextSelection.collapsed(offset: formatted.length);
    }
  }

  void _validate() {
    String? error;

    // Custom validator first (null-aware)
    error = widget.validator?.call(_controller.text);

    // Built-in validation only if no custom error
    error ??= CurrencyFormatter.getValidationError(
      _controller.text,
      required: widget.required,
      min: widget.minValue,
      max: widget.maxValue,
      allowNegative: widget.allowNegative,
    );

    setState(() {
      _errorText = error;
    });

    // Announce error to screen reader
    if (error != null) {
      AccessibilityService.announceError(error);
    }
  }

  void _onChanged(String value) {
    // Notify parent
    if (widget.onChanged != null) {
      final amount = CurrencyFormatter.parseAmount(value);
      widget.onChanged!(amount);
    }

    // Clear error when user types
    if (_errorText != null) {
      setState(() {
        _errorText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isError = _errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (!widget.compact && widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(widget.label!, style: TypographyUI.labelLarge(brightness)),
                if (widget.required)
                  Text(
                    ' *',
                    style: TypographyUI.labelLarge(
                      brightness,
                    ).copyWith(color: ColorsUI.getError(brightness)),
                  ),
              ],
            ),
          ),

        // Input Field
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
          inputFormatters: [
            // ✅ Επιτρέπουμε "-" μόνο αν allowNegative == true
            FilteringTextInputFormatter.allow(
              widget.allowNegative ? RegExp(r'[0-9.,\-]') : RegExp(r'[0-9.,]'),
            ),

            // Limit decimal places to 2
            _DecimalTextInputFormatter(decimalRange: 2),
          ],

          textInputAction: widget.textInputAction ?? TextInputAction.done,
          onChanged: _onChanged,
          onEditingComplete: () {
            _formatInput();
            _validate();
            widget.onEditingComplete?.call();
          },
          style: TypographyUI.bodyLarge(brightness),
          decoration: InputDecoration(
            // ✅ πιο “λεπτό”
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),

            labelText: widget.compact ? widget.label : null,

            hintText: widget.hint ?? '0,00',

            // ✅ ΣΤΑΘΕΡΟ ΥΨΟΣ: error εμφανίζεται στο helperText
            helperText: _errorText ?? (widget.helperText ?? ' '),
            errorText: null,
            errorStyle: const TextStyle(height: 0, fontSize: 0),

            helperStyle: TypographyUI.labelMedium(brightness).copyWith(
              color: _errorText != null
                  ? ColorsUI.getError(brightness)
                  : ColorsUI.getTextSecondary(brightness),
            ),

            // Prefix (currency symbol)
            prefixIcon: widget.prefixIcon != null
                ? ExcludeSemantics(child: Icon(widget.prefixIcon))
                : null,
            prefix: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                widget.currency,
                style: TypographyUI.bodyLarge(
                  brightness,
                ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
              ),
            ),

            // Suffix (optional icon)
            suffixIcon: widget.suffixIcon != null
                ? IconButton(
                    tooltip: 'Ενέργεια',
                    icon: ExcludeSemantics(child: Icon(widget.suffixIcon)),
                    onPressed: widget.onSuffixIconPressed,
                  )
                : null,

            // Borders
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: ColorsUI.getInputBorder(brightness),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isError
                    ? ColorsUI.getError(brightness)
                    : ColorsUI.getInputFocusBorder(brightness),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: ColorsUI.getError(brightness),
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: ColorsUI.getError(brightness),
                width: 2,
              ),
            ),
          ),
        ),

        // Min/Max hint
        if (widget.minValue != null || widget.maxValue != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              _getRangeText(),
              style: TypographyUI.labelMedium(context.brightness),
            ),
          ),
      ],
    );
  }

  String _getRangeText() {
    if (widget.minValue != null && widget.maxValue != null) {
      return 'Εύρος: ${CurrencyFormatter.format(widget.minValue!)} - ${CurrencyFormatter.format(widget.maxValue!)}';
    } else if (widget.minValue != null) {
      return 'Ελάχιστο: ${CurrencyFormatter.format(widget.minValue!)}';
    } else if (widget.maxValue != null) {
      return 'Μέγιστο: ${CurrencyFormatter.format(widget.maxValue!)}';
    }
    return '';
  }
}

/// Custom formatter to limit decimal places
class _DecimalTextInputFormatter extends TextInputFormatter {
  final int decimalRange;

  _DecimalTextInputFormatter({required this.decimalRange});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Check for decimal separator (, or .)
    final separators = [',', '.'];
    String text = newValue.text;

    for (var sep in separators) {
      if (text.contains(sep)) {
        final parts = text.split(sep);

        // Only one separator allowed
        if (parts.length > 2) {
          return oldValue;
        }

        // Limit decimal places
        if (parts.length == 2 && parts[1].length > decimalRange) {
          return oldValue;
        }
      }
    }

    return newValue;
  }
}

/// Helper extension
extension CurrencyFieldExtension on TextEditingController {
  /// Get amount as double
  double? get amount => CurrencyFormatter.parseAmount(text);

  /// Set amount
  set amount(double? value) {
    if (value == null) {
      text = '';
    } else {
      text = CurrencyFormatter.formatWithoutSymbol(value);
    }
  }
}
