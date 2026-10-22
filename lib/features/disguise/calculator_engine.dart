/// A phone-style calculator. Operators apply left to right as they are
/// pressed (2 + 3 × 4 = 20), like basic phone calculators; no precedence.
///
/// Keys: `0`-`9`, `.`, `+`, `−`, `×`, `÷`, `=`, `%`, `±`, `AC`.
class CalculatorEngine {
  static const error = 'Error';

  String _display = '0';
  double? _acc;
  String? _op;
  bool _fresh = true; // The next digit starts a new number.

  String get display => _display;
  String? get pendingOp => _op;

  void press(String key) {
    if (_display == error && key != 'AC') {
      if (!_isDigit(key) && key != '.') return;
      _reset();
    }
    switch (key) {
      case 'AC':
        _reset();
      case '.':
        if (_fresh) {
          _display = '0.';
          _fresh = false;
        } else if (!_display.contains('.')) {
          _display += '.';
        }
      case '±':
        _negate();
      case '%':
        final v = _value;
        final base = _acc;
        _show(
          base != null && (_op == '+' || _op == '−') ? base * v / 100 : v / 100,
        );
        _fresh = false;
      case '=':
        if (_op != null && _apply()) {
          _op = null;
          _acc = null;
        }
        _fresh = true;
      case '+' || '−' || '×' || '÷':
        if (_op != null && !_fresh) {
          if (!_apply()) return;
        } else if (_op == null) {
          _acc = _value;
        }
        _op = key;
        _fresh = true;
      default:
        if (!_isDigit(key)) throw ArgumentError.value(key, 'key');
        _digit(key);
    }
  }

  static bool _isDigit(String key) => RegExp(r'^\d$').hasMatch(key);

  void _reset() {
    _display = '0';
    _acc = null;
    _op = null;
    _fresh = true;
  }

  void _digit(String d) {
    if (_fresh) {
      _display = d;
      _fresh = false;
    } else if (_display == '0') {
      _display = d;
    } else if (_display == '-0') {
      _display = '-$d';
    } else if (_display.replaceAll(RegExp(r'[-.]'), '').length < 15) {
      _display += d;
    }
  }

  void _negate() {
    if (_fresh && (_op != null || _display == '0')) {
      _display = '-0';
      _fresh = false;
    } else {
      _display = _display.startsWith('-')
          ? _display.substring(1)
          : '-$_display';
    }
  }

  double get _value =>
      double.parse(_display.endsWith('.') ? '${_display}0' : _display);

  /// Applies the pending operator; false (and shows Error) on divide by zero.
  bool _apply() {
    final a = _acc!, b = _value;
    final result = switch (_op) {
      '+' => a + b,
      '−' => a - b,
      '×' => a * b,
      _ => b == 0 ? double.nan : a / b,
    };
    if (!result.isFinite) {
      _reset();
      _display = error;
      return false;
    }
    _acc = result;
    _show(result);
    return true;
  }

  void _show(double v) => _display = format(v);

  static String format(double v) {
    if (v == v.truncateToDouble() && v.abs() < 1e15) {
      return v.toInt().toString();
    }
    final parts = v.toStringAsPrecision(10).split('e');
    var mantissa = parts[0];
    if (mantissa.contains('.')) {
      mantissa = mantissa.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return parts.length == 2 ? '${mantissa}e${parts[1]}' : mantissa;
  }
}
