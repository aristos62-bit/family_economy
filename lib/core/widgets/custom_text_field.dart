import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import '../accessibility/accessibility_service.dart';

/// Custom Text Field
/// Standard text input with validation and full accessibility
class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool required;
  final int? maxLength;
  final int? minLength;
  final int? maxLines;
  final int? minLines;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onTap;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;


  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.required = false,
    this.maxLength,
    this.minLength,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onEditingComplete,
    this.onTap,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.inputFormatters,
    this.autovalidateMode,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isInternalController = false;
  bool _isInternalFocusNode = false;
  bool _obscureText = false;
  String? _errorText;

  bool _clearedOnFocus = false;

  @override
  void initState() {
    super.initState();

    _obscureText = widget.obscureText;

    if (widget.controller == null) {
      _controller = TextEditingController(text: widget.initialValue);
      _isInternalController = true;
    } else {
      _controller = widget.controller!;
    }


    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _isInternalFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }

    _focusNode.addListener(_onFocusChange);
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
    if (_focusNode.hasFocus) {
      if (!_clearedOnFocus && _controller.text.isNotEmpty) {
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
        _clearedOnFocus = true;
      }

      final fieldTypeEl = widget.obscureText ? 'Κωδικός' : 'Κείμενο';
      AccessibilityService.announcePolite(
        '${widget.label ?? fieldTypeEl} πεδίο επιλεγμένο.',
      );
    } else {
      _validate();
    }


    setState(() {
    });
  }

  void _validate() {
    String? error;

    if (widget.validator != null) {
      error = widget.validator!(_controller.text);
    }

    error ??= _getBuiltInValidationError();

    setState(() {
      _errorText = error;
    });

    if (error != null) {
      AccessibilityService.announceError(error);
    }
  }

  String? _getBuiltInValidationError() {
    final text = _controller.text;

    if (widget.required && text.isEmpty) {
      return '${widget.label ?? 'Αυτό το πεδίο'} είναι υποχρεωτικό';
    }

    if (widget.minLength != null && text.length < widget.minLength!) {
      return 'Ελάχιστο ${widget.minLength} χαρακτήρες απαιτούνται';
    }

    if (widget.maxLength != null && text.length > widget.maxLength!) {
      return 'Μέγιστο ${widget.maxLength} χαρακτήρες επιτρέπονται';
    }

    if (widget.keyboardType == TextInputType.emailAddress && text.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(text)) {
        return 'Εισάγετε έγκυρη διεύθυνση email';
      }
    }

    if (widget.keyboardType == TextInputType.phone && text.isNotEmpty) {
      final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
      if (!phoneRegex.hasMatch(text.replaceAll(RegExp(r'[\s-]'), ''))) {
        return 'Εισάγετε έγκυρο αριθμό τηλεφώνου';
      }
    }

    if (widget.keyboardType == TextInputType.url && text.isNotEmpty) {
      final urlRegex = RegExp(
        r'^(https?://)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*/?$',
      );
      if (!urlRegex.hasMatch(text)) {
        return 'Εισάγετε έγκυρο URL';
      }
    }

    return null;
  }

  void _onChanged(String value) {
    widget.onChanged?.call(value);

    if (_errorText != null) {
      setState(() {
        _errorText = null;
      });
    }
  }

  void _toggleObscureText() {
    setState(() {
      _obscureText = !_obscureText;
    });

    AccessibilityService.announcePolite(
      _obscureText ? 'Κωδικός κρυμμένος' : 'Κωδικός εμφανής',
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isError = _errorText != null;

    return Semantics(
      label: widget.label ?? 'Εισαγωγή Κειμένου',
      hint: widget.hint,
      textField: true,
      obscured: _obscureText,
      enabled: widget.enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    widget.label!,
                    style: TypographyUI.labelLarge(brightness),
                  ),
                  if (widget.required)
                    Text(
                      ' *',
                      style: TypographyUI.labelLarge(brightness).copyWith(
                        color: ColorsUI.getError(brightness),
                      ),
                    ),
                ],
              ),
            ),
          TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            obscureText: _obscureText,
            maxLength: widget.maxLength,
            maxLines: _obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.inputFormatters,
            autovalidateMode: widget.autovalidateMode,
            onChanged: _onChanged,
            onEditingComplete: widget.onEditingComplete,
            onTap: widget.onTap,
            style: TypographyUI.bodyLarge(brightness),
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helperText,
              errorText: _errorText,
              counterText: widget.maxLength != null
                  ? '${_controller.text.length}/${widget.maxLength}'
                  : null,
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon, semanticLabel: widget.label)
                  : null,
              suffixIcon: widget.obscureText
                  ? IconButton(
                icon: Icon(
                  _obscureText
                      ? Icons.visibility
                      : Icons.visibility_off,
                  semanticLabel: _obscureText
                      ? 'Εμφάνιση κωδικού'
                      : 'Απόκρυψη κωδικού',
                ),
                onPressed: _toggleObscureText,
              )
                  : widget.suffixIcon != null
                  ? IconButton(
                icon: Icon(
                  widget.suffixIcon,
                  semanticLabel: 'Ενέργεια',
                ),
                onPressed: widget.onSuffixIconPressed,
              )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: ColorsUI.inputBorderLight,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isError
                      ? ColorsUI.getError(brightness)
                      : ColorsUI.inputFocusBorderLight,
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
          if (widget.minLength != null && widget.maxLength == null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                'Ελάχιστο ${widget.minLength} χαρακτήρες',
                style: TypographyUI.labelMedium(context.brightness),
              ),
            ),
        ],
      ),
    );
  }
}

/// Common validators
class TextFieldValidators {
  static FormFieldValidator<String> email({String? errorMessage}) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      final emailRegex = RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value)) {
        return errorMessage ?? 'Εισάγετε έγκυρη διεύθυνση email';
      }
      return null;
    };
  }

  static FormFieldValidator<String> phone({String? errorMessage}) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
      if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'[\s-]'), ''))) {
        return errorMessage ?? 'Εισάγετε έγκυρο αριθμό τηλεφώνου';
      }
      return null;
    };
  }

  static FormFieldValidator<String> url({String? errorMessage}) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      final urlRegex = RegExp(
        r'^(https?://)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*/?$',
      );
      if (!urlRegex.hasMatch(value)) {
        return errorMessage ?? 'Εισάγετε έγκυρο URL';
      }
      return null;
    };
  }

  static FormFieldValidator<String> minLength(
      int length, {
        String? errorMessage,
      }) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      if (value.length < length) {
        return errorMessage ?? 'Ελάχιστο $length χαρακτήρες απαιτούνται';
      }
      return null;
    };
  }

  static FormFieldValidator<String> maxLength(
      int length, {
        String? errorMessage,
      }) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      if (value.length > length) {
        return errorMessage ?? 'Μέγιστο $length χαρακτήρες επιτρέπονται';
      }
      return null;
    };
  }

  static FormFieldValidator<String> required({String? errorMessage}) {
    return (value) {
      if (value == null || value.isEmpty) {
        return errorMessage ?? 'Αυτό το πεδίο είναι υποχρεωτικό';
      }
      return null;
    };
  }

  static FormFieldValidator<String> match(
      String otherValue, {
        String? errorMessage,
      }) {
    return (value) {
      if (value != otherValue) {
        return errorMessage ?? 'Το περιεχόμενο δεν ταιριάζει';
      }
      return null;
    };
  }

  static FormFieldValidator<String> combine(
      List<FormFieldValidator<String>> validators,
      ) {
    return (value) {
      for (var validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}
