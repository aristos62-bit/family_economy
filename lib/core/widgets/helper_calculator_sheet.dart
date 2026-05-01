// helper_calculator_sheet.dart
import 'package:flutter/material.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';

import 'calculator_engine.dart';

typedef CalculatorResultCallback = void Function(double value);

class HelperCalculator {
  /// Opens responsive calculator sheet.
  /// Returns computed value on "=" and closes.
  static Future<void> open(
      BuildContext context, {
        required CalculatorResultCallback onResult,
        String? announceOpened, // optional a11y message
      }) async {
    if (announceOpened != null && announceOpened.trim().isNotEmpty) {
      AccessibilityService.announcePolite(announceOpened);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CalculatorSheet(onResult: onResult),
    );
  }
}

class _CalculatorSheet extends StatefulWidget {
  const _CalculatorSheet({required this.onResult});

  final CalculatorResultCallback onResult;

  @override
  State<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<_CalculatorSheet> {
  final CalculatorEngine _engine = CalculatorEngine();

  // For nice focus order in desktop/tablet (optional)
  final FocusNode _sheetFocus = FocusNode(debugLabel: 'calculator_sheet');

  @override
  void dispose() {
    _sheetFocus.dispose();
    super.dispose();
  }

  void _press(String key) {
    // A11y announce per action (short)
    void say(String msg) => AccessibilityService.announcePolite(msg);

    setState(() {
      switch (key) {
        case 'AC':
          _engine.allClear();
          say('Καθαρισμός');
          break;
        case '⌫':
          _engine.backspace();
          say('Διαγραφή');
          break;
        case '%':
          _engine.percent();
          say('Ποσοστό');
          break;
        case '+':
        case '-':
        case '*':
        case '/':
          _engine.setOperator(key);
          say('Τελεστής $key');
          break;
        case ',':
          _engine.inputDecimalComma();
          say('Δεκαδικό');
          break;
        case '±':
          _engine.toggleSign();
          say('Αλλαγή πρόσημου');
          break;
        case '=':
          final v = _engine.evaluate();
          if (v == null) {
            say('Σφάλμα');
            return;
          }
          // announce result and return to caller
          say('Αποτέλεσμα ${_engine.display}');
          // Navigator.of(context).pop();
          widget.onResult(v);
          break;
        default:
        // digits
          _engine.inputDigit(key);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;

    // responsive width
    final mq = MediaQuery.of(context);
    final w = mq.size.width;

    final double maxW = w >= 1100
        ? 520
        : w >= 700
        ? 460
        : double.infinity;

    final panelRadius = 22.0;

    return Focus(
      focusNode: _sheetFocus,
      autofocus: true,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: ColorsUI.getCard(b),
              borderRadius: BorderRadius.circular(panelRadius),
              boxShadow: [
                BoxShadow(
                  color: ColorsUI.byBrightness(
                    brightness: b,
                    light: ColorsUI.shadowLight,
                    dark: ColorsUI.shadowDark,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                )
              ],
              border: Border.all(color: ColorsUI.getBorder(b)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Header(
                      display: _engine.display,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 10),
                    _Keypad(
                      onKey: _press,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.display,
    required this.onClose,
  });

  final String display;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Οθόνη αριθμομηχανής',
            value: display,
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: ColorsUI.getSurface(b),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ColorsUI.getBorder(b)),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.moneyMd,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        AccessibilityService.accessibleButton(
          label: 'Κλείσιμο αριθμομηχανής',
          hint: 'Κλείνει το παράθυρο',
          onPressed: onClose,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColorsUI.getSurface(b),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorsUI.getBorder(b)),
            ),
            child: Icon(Icons.close, color: context.cText),
          ),
        ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});
  final void Function(String key) onKey;

  @override
  Widget build(BuildContext context) {

    // Layout:
    // Row1: AC  ⌫  %   /
    // Row2: 7   8  9   *
    // Row3: 4   5  6   -
    // Row4: 1   2  3   +
    // Row5: ±   0  ,   =
    final keys = const [
      ['AC', '⌫', '%', '/'],
      ['7', '8', '9', '*'],
      ['4', '5', '6', '-'],
      ['1', '2', '3', '+'],
      ['±', '0', ',', '='],
    ];

    // responsive button size
    final w = MediaQuery.of(context).size.width;
    final bool compact = w < 380;

    final double gap = compact ? 8 : 10;
    final double btnH = compact ? 46 : 52;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in keys) ...[
          Row(
            children: [
              for (final k in row) ...[
                Expanded(
                  child: _CalcKey(
                    label: _labelForKey(k),
                    hint: _hintForKey(k),
                    text: k,
                    height: btnH,
                    onTap: () => onKey(k),
                    kind: _kindForKey(k),
                  ),
                ),
                if (k != row.last) SizedBox(width: gap),
              ],
            ],
          ),
          if (row != keys.last) SizedBox(height: gap),
        ],
        const SizedBox(height: 6),
        Text(
          'Tip: Χρησιμοποίησε το % σαν ποσοστό. π.χ. 200 + 10% = 220',
          style: context.bodySm,
        ),
      ],
    );
  }

  String _labelForKey(String k) {
    switch (k) {
      case 'AC':
        return 'Καθαρισμός';
      case '⌫':
        return 'Διαγραφή χαρακτήρα';
      case '%':
        return 'Ποσοστό';
      case '/':
        return 'Διαίρεση';
      case '*':
        return 'Πολλαπλασιασμός';
      case '-':
        return 'Αφαίρεση';
      case '+':
        return 'Πρόσθεση';
      case '=':
        return 'Ίσον';
      case ',':
        return 'Δεκαδικό κόμμα';
      case '±':
        return 'Αλλαγή πρόσημου';
      default:
        return 'Ψηφίο $k';
    }
  }

  String? _hintForKey(String k) {
    if (k == '=') return 'Υπολογίζει και επιστρέφει το αποτέλεσμα';
    if (k == 'AC') return 'Μηδενίζει την αριθμομηχανή';
    if (k == '⌫') return 'Σβήνει τον τελευταίο χαρακτήρα';
    return null;
  }

  _KeyKind _kindForKey(String k) {
    if (k == '=' || k == 'AC') return _KeyKind.primary;
    if (k == '+' || k == '-' || k == '*' || k == '/' || k == '%' || k == '⌫') {
      return _KeyKind.secondary;
    }
    return _KeyKind.normal;
  }
}

enum _KeyKind { normal, secondary, primary }

class _CalcKey extends StatelessWidget {
  const _CalcKey({
    required this.label,
    required this.text,
    required this.height,
    required this.onTap,
    required this.kind,
    this.hint,
  });

  final String label;
  final String? hint;
  final String text;
  final double height;
  final VoidCallback onTap;
  final _KeyKind kind;

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;

    final Color bg = () {
      switch (kind) {
        case _KeyKind.primary:
          return context.cPrimary;
        case _KeyKind.secondary:
          return ColorsUI.getSurface(b);
        case _KeyKind.normal:
          return ColorsUI.getCard(b);
      }
    }();

    final Color fg = () {
      switch (kind) {
        case _KeyKind.primary:
          return context.cOnPrimary;
        case _KeyKind.secondary:
        case _KeyKind.normal:
          return context.cText;
      }
    }();

    return AccessibilityService.accessibleButton(
      label: label,
      hint: hint,
      onPressed: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kind == _KeyKind.primary ? Colors.transparent : ColorsUI.getBorder(b),
          ),
        ),
        child: Text(
          text,
          style: context.titleMd.withColor(fg),
        ),
      ),
    );
  }
}
