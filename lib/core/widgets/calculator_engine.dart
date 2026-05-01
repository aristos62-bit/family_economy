// calculator_engine.dart

/// Lightweight calculator engine (no UI)
/// Supports: AC, backspace, + - * / %, =
/// Decimal separator: comma (,) for display, but accepts both , and .
class CalculatorEngine {
  String _display = '0';

  // current number user is typing (normalized with '.' decimal)
  String _input = '';

  double? _acc; // accumulator / left operand
  String? _op; // '+', '-', '*', '/'
  double? _lastRight; // for repeated '=' (optional)
  String? _lastOp;

  bool _justEvaluated = false;

  String get display => _display;

  // ---------- Public API ----------

  void allClear() {
    _display = '0';
    _input = '';
    _acc = null;
    _op = null;
    _lastRight = null;
    _lastOp = null;
    _justEvaluated = false;
  }

  void backspace() {
    if (_justEvaluated) {
      // after evaluation, backspace edits the displayed result
      _input = _normalize(_display);
      _justEvaluated = false;
    }

    if (_input.isEmpty) {
      _display = '0';
      return;
    }

    _input = _input.substring(0, _input.length - 1);

    if (_input.isEmpty || _input == '-' || _input == '-0') {
      _input = '';
      _display = '0';
      return;
    }

    _display = _formatDisplay(_input);
  }

  void inputDigit(String d) {
    if (d.length != 1 || d.codeUnitAt(0) < 48 || d.codeUnitAt(0) > 57) return;

    if (_justEvaluated) {
      // start new number
      _input = '';
      _acc = null;
      _op = null;
      _justEvaluated = false;
    }

    // prevent leading zeros like 0002
    if (_input == '0') {
      _input = d;
    } else if (_input == '-0') {
      _input = '-$d';
    } else {
      _input += d;
    }

    _display = _formatDisplay(_input);
  }

  void inputDecimalComma() {
    if (_justEvaluated) {
      _input = '';
      _acc = null;
      _op = null;
      _justEvaluated = false;
    }

    if (_input.isEmpty) {
      _input = '0.';
      _display = '0,';
      return;
    }
    if (_input.contains('.')) return;

    _input += '.';
    _display = _formatDisplay(_input);
  }

  void toggleSign() {
    if (_justEvaluated) {
      _input = _normalize(_display);
      _justEvaluated = false;
    }

    if (_input.isEmpty) {
      // toggle 0 => -0 (so next digits become negative)
      _input = '-0';
      _display = '-0';
      return;
    }

    if (_input.startsWith('-')) {
      _input = _input.substring(1);
    } else {
      _input = '-$_input';
    }
    _display = _formatDisplay(_input);
  }

  /// operator in: '+', '-', '*', '/'
  void setOperator(String operator) {
    if (!['+', '-', '*', '/'].contains(operator)) return;

    // If we just evaluated, keep accumulator as displayed value
    if (_justEvaluated) {
      _acc = _toDoubleSafe(_normalize(_display));
      _op = operator;
      _input = '';
      _justEvaluated = false;
      return;
    }

    // If user has input, fold it into accumulator first
    if (_input.isNotEmpty && _input != '-' && _input != '-0') {
      final right = _toDoubleSafe(_input);
      if (_acc == null) {
        _acc = right;
      } else if (_op != null) {
        _acc = _apply(_acc!, _op!, right);
      } else {
        _acc = right;
      }
      _display = _formatNumber(_acc!);
      _input = '';
    } else {
      // no input: change operator only
      if (_lastOp != null) {
        _op = _lastOp;
      }
    }

    _op = operator;
  }

  /// Percent behavior:
  /// - If there is an accumulator and operator, percentage is relative to accumulator:
  ///   e.g. 200 + 10% => 200 + (200*0.10)
  /// - Otherwise, just divide current input by 100.
  void percent() {
    if (_justEvaluated) {
      _input = _normalize(_display);
      _justEvaluated = false;
    }

    // decide base
    final current = _input.isNotEmpty ? _toDoubleSafe(_input) : null;

    if (_acc != null && _op != null && current != null) {
      final p = _acc! * (current / 100.0);
      _input = _trimDouble(p);
      _display = _formatNumber(p);
      return;
    }

    if (current != null) {
      final p = current / 100.0;
      _input = _trimDouble(p);
      _display = _formatNumber(p);
      return;
    }

    // if nothing typed, treat display as value
    final v = _toDoubleSafe(_normalize(_display)) / 100.0;
    _input = _trimDouble(v);
    _display = _formatNumber(v);
  }

  /// Returns the computed value (or null if invalid)
  double? evaluate() {
    double left;

    // repeated '=' behavior (optional)
    if (_justEvaluated && _lastOp != null && _lastRight != null) {
      final base = _toDoubleSafe(_normalize(_display));
      final out = _apply(base, _lastOp!, _lastRight!);
      _display = _formatNumber(out);
      _input = '';
      _acc = out;
      _op = null;
      return out;
    }

    if (_acc == null && _op == null) {
      // just a number
      final v = _input.isNotEmpty ? _toDoubleSafe(_input) : _toDoubleSafe(_normalize(_display));
      _display = _formatNumber(v);
      _input = '';
      _justEvaluated = true;
      return v;
    }

    left = _acc ?? 0.0;

    final right = (_input.isNotEmpty && _input != '-' && _input != '-0')
        ? _toDoubleSafe(_input)
        : left;

    if (_op == null) {
      _display = _formatNumber(right);
      _acc = right;
      _input = '';
      _justEvaluated = true;
      return right;
    }

    // store for repeated '='
    _lastOp = _op;
    _lastRight = right;

    final out = _apply(left, _op!, right);

    _display = _formatNumber(out);
    _acc = out;
    _input = '';
    _op = null;
    _justEvaluated = true;

    return out;
  }

  // ---------- Internals ----------

  double _apply(double a, String op, double b) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
      // avoid crash; show inf but keep stable
        if (b == 0) return double.infinity;
        return a / b;
      default:
        return b;
    }
  }

  double _toDoubleSafe(String s) {
    final n = double.tryParse(s);
    return n ?? 0.0;
  }

  String _normalize(String s) {
    // display uses comma, normalize to '.' for parsing
    return s.replaceAll('.', '').replaceAll(',', '.');
  }

  String _trimDouble(double v) {
    if (!v.isFinite) return v.toString();
    final str = v.toStringAsPrecision(15);
    // remove trailing zeros
    var out = str;
    if (out.contains('.')) {
      out = out.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return out;
  }

  String _formatDisplay(String normalizedInput) {
    // normalizedInput uses '.' decimal
    if (normalizedInput == '0.') return '0,';
    if (normalizedInput == '-0') return '-0';
    if (normalizedInput.endsWith('.')) {
      final base = normalizedInput.substring(0, normalizedInput.length - 1);
      return '${_formatNumber(_toDoubleSafe(base))},';
    }
    return _formatNumber(_toDoubleSafe(normalizedInput));
  }

  String _formatNumber(double v) {
    if (!v.isFinite) return '∞';

    // keep a practical precision
    final abs = v.abs();
    String raw;

    if (abs >= 1e12) {
      raw = v.toStringAsExponential(6);
      return raw.replaceAll('.', ',');
    }

    // up to 10 decimals max, trimmed
    raw = v.toStringAsFixed(10);
    raw = raw.replaceFirst(RegExp(r'\.?0+$'), '');

    // thousands with dot, decimals with comma
    final parts = raw.split('.');
    final intPart = parts[0];
    final frac = parts.length > 1 ? parts[1] : '';

    final sign = intPart.startsWith('-') ? '-' : '';
    final digits = intPart.replaceAll('-', '');

    final sb = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final idxFromEnd = digits.length - i;
      sb.write(digits[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
        sb.write('.');
      }
    }

    if (frac.isEmpty) return '$sign${sb.toString()}';
    return '$sign${sb.toString()},$frac';
  }
}
