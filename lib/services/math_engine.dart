import 'dart:math' as math;

/// Angle unit used by trigonometric functions.
enum AngleUnit { deg, rad, grad }

extension AngleUnitX on AngleUnit {
  String get label => switch (this) {
        AngleUnit.deg => 'DEG',
        AngleUnit.rad => 'RAD',
        AngleUnit.grad => 'GRAD',
      };

  AngleUnit get next => AngleUnit.values[(index + 1) % AngleUnit.values.length];
}

enum CalcErrorType { math, syntax }

/// The only exception type the engine throws. Carries a user-friendly message.
class CalcException implements Exception {
  const CalcException(this.type);
  const CalcException.math() : type = CalcErrorType.math;
  const CalcException.syntax() : type = CalcErrorType.syntax;

  final CalcErrorType type;

  String get message =>
      type == CalcErrorType.math ? 'Math Error' : 'Syntax Error';

  @override
  String toString() => message;
}

/// Outcome of [MathEngine.tryEvaluate]: either a value or an error.
class EvaluationResult {
  const EvaluationResult.success(double this.value) : error = null;
  const EvaluationResult.failure(CalcException this.error) : value = null;

  final double? value;
  final CalcException? error;

  bool get isSuccess => value != null;
}

enum _Kind {
  number,
  constant,
  function,
  operator,
  postfix,
  leftParen,
  rightParen,
  comma,
}

class _Token {
  const _Token(this.kind, this.text, [this.value]);

  final _Kind kind;
  final String text;
  final double? value;
}

/// Pure-Dart recursive-descent expression evaluator.
///
/// Grammar (lowest to highest precedence):
/// ```
/// expr    := term (('+' | '-') term)*
/// term    := combi (('×' | '÷' | 'mod') combi | <implicit ×> combi)*
/// combi   := unary (('C' | 'P') unary)*
/// unary   := ('-' | '+') unary | power
/// power   := postfix ('^' unary | 'ʸ√' unary)?
/// postfix := primary ('!' | '%' | '²' | '³')*
/// primary := number | constant | function '(' expr (',' expr)* ')' | '(' expr ')'
/// ```
/// Missing closing parentheses at the end of the input are closed automatically.
class MathEngine {
  const MathEngine();

  static const Map<String, _Token> _names = {
    // Functions (display names and ASCII aliases).
    'sinh⁻¹': _Token(_Kind.function, 'asinh'),
    'cosh⁻¹': _Token(_Kind.function, 'acosh'),
    'tanh⁻¹': _Token(_Kind.function, 'atanh'),
    'sin⁻¹': _Token(_Kind.function, 'asin'),
    'cos⁻¹': _Token(_Kind.function, 'acos'),
    'tan⁻¹': _Token(_Kind.function, 'atan'),
    'asinh': _Token(_Kind.function, 'asinh'),
    'acosh': _Token(_Kind.function, 'acosh'),
    'atanh': _Token(_Kind.function, 'atanh'),
    'asin': _Token(_Kind.function, 'asin'),
    'acos': _Token(_Kind.function, 'acos'),
    'atan': _Token(_Kind.function, 'atan'),
    'sinh': _Token(_Kind.function, 'sinh'),
    'cosh': _Token(_Kind.function, 'cosh'),
    'tanh': _Token(_Kind.function, 'tanh'),
    'sin': _Token(_Kind.function, 'sin'),
    'cos': _Token(_Kind.function, 'cos'),
    'tan': _Token(_Kind.function, 'tan'),
    'logₐ': _Token(_Kind.function, 'logb'),
    'log': _Token(_Kind.function, 'log'),
    'ln': _Token(_Kind.function, 'ln'),
    'sqrt': _Token(_Kind.function, 'sqrt'),
    'cbrt': _Token(_Kind.function, 'cbrt'),
    'abs': _Token(_Kind.function, 'abs'),
    '√': _Token(_Kind.function, 'sqrt'),
    '∛': _Token(_Kind.function, 'cbrt'),
    // Word / letter operators.
    'mod': _Token(_Kind.operator, 'mod'),
    'ʸ√': _Token(_Kind.operator, 'root'),
    'C': _Token(_Kind.operator, 'nCr'),
    'P': _Token(_Kind.operator, 'nPr'),
    // Constants.
    'Ans': _Token(_Kind.constant, 'ans'),
    'π': _Token(_Kind.constant, 'pi'),
    'pi': _Token(_Kind.constant, 'pi'),
    'e': _Token(_Kind.constant, 'e'),
  };

  /// Names ordered longest-first so that e.g. `sinh⁻¹` wins over `sin`.
  static final List<String> _sortedNames = _names.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  /// Evaluates [expression]. Throws [CalcException] on any failure.
  double evaluate(
    String expression, {
    AngleUnit angleUnit = AngleUnit.deg,
    double ans = 0,
  }) {
    final tokens = _tokenize(expression);
    if (tokens.isEmpty) throw const CalcException.syntax();
    final value = _Parser(tokens, angleUnit, ans).parse();
    if (value.isNaN || value.isInfinite) throw const CalcException.math();
    return value == 0 ? 0.0 : value; // Normalises -0.0.
  }

  /// Like [evaluate] but never throws.
  EvaluationResult tryEvaluate(
    String expression, {
    AngleUnit angleUnit = AngleUnit.deg,
    double ans = 0,
  }) {
    try {
      return EvaluationResult.success(
        evaluate(expression, angleUnit: angleUnit, ans: ans),
      );
    } on CalcException catch (e) {
      return EvaluationResult.failure(e);
    } catch (_) {
      return const EvaluationResult.failure(CalcException.syntax());
    }
  }

  /// Formats [value] with up to [precision] significant digits.
  ///
  /// Very large / small magnitudes use `E` notation (`1.5E-7`), which the
  /// engine can parse back.
  static String formatNumber(double value, {int precision = 10}) {
    if (value.isNaN || value.isInfinite) return 'Math Error';
    if (value == 0) return '0';
    final raw = value.toStringAsPrecision(precision);
    final ePos = raw.indexOf('e');
    if (ePos < 0) return _trimZeros(raw);
    final mantissa = _trimZeros(raw.substring(0, ePos));
    final exponent = int.parse(raw.substring(ePos + 1));
    return '${mantissa}E$exponent';
  }

  static String _trimZeros(String s) {
    if (!s.contains('.')) return s;
    var end = s.length;
    while (end > 0 && s[end - 1] == '0') {
      end--;
    }
    if (end > 0 && s[end - 1] == '.') end--;
    return s.substring(0, end);
  }

  /// Returns [value] as a reduced fraction `n/d`, or `null` when the value is
  /// an integer or has no exact-enough fraction with a small denominator.
  static String? toFraction(double value, {int maxDenominator = 10000}) {
    if (value.isNaN || value.isInfinite) return null;
    if (value == value.roundToDouble()) return null;
    final x = value.abs();
    if (x > 1e9 || x < 1e-9) return null;

    var h0 = 0, h1 = 1, k0 = 1, k1 = 0;
    var frac = x;
    for (var i = 0; i < 32; i++) {
      final a = frac.floor();
      final h2 = a * h1 + h0;
      final k2 = a * k1 + k0;
      if (k2 > maxDenominator) break;
      h0 = h1;
      h1 = h2;
      k0 = k1;
      k1 = k2;
      if ((h1 / k1 - x).abs() <= 1e-12 * math.max(1.0, x)) {
        return '${value < 0 ? '-' : ''}$h1/$k1';
      }
      final rem = frac - a;
      if (rem < 1e-14) break;
      frac = 1 / rem;
    }
    return null;
  }

  static bool _isDigit(String ch) {
    final c = ch.codeUnitAt(0);
    return c >= 0x30 && c <= 0x39;
  }

  List<_Token> _tokenize(String src) {
    final out = <_Token>[];
    final n = src.length;
    var i = 0;
    while (i < n) {
      final ch = src[i];
      if (ch == ' ') {
        i++;
        continue;
      }

      if (_isDigit(ch) || ch == '.') {
        final start = i;
        var digits = 0;
        while (i < n && _isDigit(src[i])) {
          i++;
          digits++;
        }
        if (i < n && src[i] == '.') {
          i++;
          while (i < n && _isDigit(src[i])) {
            i++;
            digits++;
          }
        }
        if (digits == 0) throw const CalcException.syntax();
        var text = src.substring(start, i);
        if (text.startsWith('.')) text = '0$text';
        if (text.endsWith('.')) text = '${text}0';

        if (i < n && src[i] == 'E') {
          var j = i + 1;
          var sign = '';
          if (j < n && (src[j] == '-' || src[j] == '−' || src[j] == '+')) {
            if (src[j] != '+') sign = '-';
            j++;
          }
          final expStart = j;
          while (j < n && _isDigit(src[j])) {
            j++;
          }
          if (j == expStart) throw const CalcException.syntax();
          text = '${text}e$sign${src.substring(expStart, j)}';
          i = j;
        }
        if (i < n && (src[i] == '.' || src[i] == 'E' || _isDigit(src[i]))) {
          throw const CalcException.syntax();
        }
        final value = double.tryParse(text);
        if (value == null) throw const CalcException.syntax();
        out.add(_Token(_Kind.number, text, value));
        continue;
      }

      _Token? symbol;
      switch (ch) {
        case '+':
          symbol = const _Token(_Kind.operator, '+');
        case '-':
        case '−':
          symbol = const _Token(_Kind.operator, '-');
        case '×':
        case '*':
          symbol = const _Token(_Kind.operator, '*');
        case '÷':
        case '/':
          symbol = const _Token(_Kind.operator, '/');
        case '^':
          symbol = const _Token(_Kind.operator, '^');
        case '(':
          symbol = const _Token(_Kind.leftParen, '(');
        case ')':
          symbol = const _Token(_Kind.rightParen, ')');
        case ',':
          symbol = const _Token(_Kind.comma, ',');
        case '!':
        case '%':
        case '²':
        case '³':
          symbol = _Token(_Kind.postfix, ch);
      }
      if (symbol != null) {
        out.add(symbol);
        i++;
        continue;
      }

      String? matched;
      for (final name in _sortedNames) {
        if (src.startsWith(name, i)) {
          matched = name;
          break;
        }
      }
      if (matched == null) throw const CalcException.syntax();
      out.add(_names[matched]!);
      i += matched.length;
    }
    return out;
  }
}

class _Parser {
  _Parser(this._tokens, this._unit, this._ans);

  static const int _maxDepth = 200;

  final List<_Token> _tokens;
  final AngleUnit _unit;
  final double _ans;
  int _pos = 0;
  int _depth = 0;

  _Token? get _peek => _pos < _tokens.length ? _tokens[_pos] : null;

  bool _peekOp(String op) {
    final t = _peek;
    return t != null && t.kind == _Kind.operator && t.text == op;
  }

  double parse() {
    final value = _expr();
    if (_pos < _tokens.length) throw const CalcException.syntax();
    return value;
  }

  double _expr() {
    if (++_depth > _maxDepth) throw const CalcException.syntax();
    var value = _term();
    while (true) {
      if (_peekOp('+')) {
        _pos++;
        value += _term();
      } else if (_peekOp('-')) {
        _pos++;
        value -= _term();
      } else {
        break;
      }
    }
    _depth--;
    return value;
  }

  double _term() {
    var value = _combi();
    while (true) {
      final t = _peek;
      if (t == null) break;
      if (_peekOp('*')) {
        _pos++;
        value *= _combi();
      } else if (_peekOp('/')) {
        _pos++;
        final d = _combi();
        if (d == 0) throw const CalcException.math();
        value /= d;
      } else if (_peekOp('mod')) {
        _pos++;
        final d = _combi();
        if (d == 0) throw const CalcException.math();
        value = value - d * (value / d).floorToDouble();
      } else if (t.kind == _Kind.number ||
          t.kind == _Kind.constant ||
          t.kind == _Kind.function ||
          t.kind == _Kind.leftParen) {
        // Implicit multiplication: 2π, 3sin(30), (2+3)(4+5).
        value *= _combi();
      } else {
        break;
      }
    }
    return value;
  }

  double _combi() {
    var value = _unary();
    while (true) {
      if (_peekOp('nCr')) {
        _pos++;
        value = _combinations(value, _unary());
      } else if (_peekOp('nPr')) {
        _pos++;
        value = _permutations(value, _unary());
      } else {
        break;
      }
    }
    return value;
  }

  double _unary() {
    if (_peekOp('-')) {
      _pos++;
      if (++_depth > _maxDepth) throw const CalcException.syntax();
      final v = -_unary();
      _depth--;
      return v;
    }
    if (_peekOp('+')) {
      _pos++;
      if (++_depth > _maxDepth) throw const CalcException.syntax();
      final v = _unary();
      _depth--;
      return v;
    }
    return _power();
  }

  double _power() {
    final base = _postfix();
    if (_peekOp('^')) {
      _pos++;
      return _pow(base, _unary());
    }
    if (_peekOp('root')) {
      _pos++;
      return _root(_unary(), base);
    }
    return base;
  }

  double _postfix() {
    var value = _primary();
    while (true) {
      final t = _peek;
      if (t == null || t.kind != _Kind.postfix) break;
      _pos++;
      switch (t.text) {
        case '!':
          value = _factorial(value);
        case '%':
          value = value / 100;
        case '²':
          value = _check(value * value);
        case '³':
          value = _check(value * value * value);
      }
    }
    return value;
  }

  double _primary() {
    final t = _peek;
    if (t == null) throw const CalcException.syntax();
    _pos++;
    switch (t.kind) {
      case _Kind.number:
        return t.value!;
      case _Kind.constant:
        return switch (t.text) {
          'pi' => math.pi,
          'e' => math.e,
          _ => _ans,
        };
      case _Kind.leftParen:
        final value = _expr();
        _closeParen();
        return value;
      case _Kind.function:
        final open = _peek;
        if (open == null || open.kind != _Kind.leftParen) {
          throw const CalcException.syntax();
        }
        _pos++;
        final args = <double>[_expr()];
        while (_peek?.kind == _Kind.comma) {
          _pos++;
          args.add(_expr());
        }
        _closeParen();
        return _apply(t.text, args);
      case _Kind.operator:
      case _Kind.postfix:
      case _Kind.rightParen:
      case _Kind.comma:
        throw const CalcException.syntax();
    }
  }

  /// Consumes `)`. Reaching the end of input auto-closes the parenthesis.
  void _closeParen() {
    final t = _peek;
    if (t == null) return;
    if (t.kind != _Kind.rightParen) throw const CalcException.syntax();
    _pos++;
  }

  double _toRadians(double x) => switch (_unit) {
        AngleUnit.deg => x * math.pi / 180,
        AngleUnit.rad => x,
        AngleUnit.grad => x * math.pi / 200,
      };

  double _fromRadians(double x) => switch (_unit) {
        AngleUnit.deg => x * 180 / math.pi,
        AngleUnit.rad => x,
        AngleUnit.grad => x * 200 / math.pi,
      };

  static double _clean(double v) => v.abs() < 1e-15 ? 0 : v;

  static double _check(double v) {
    if (v.isNaN || v.isInfinite) throw const CalcException.math();
    return v;
  }

  double _apply(String name, List<double> args) {
    final arity = name == 'logb' ? 2 : 1;
    if (args.length != arity) throw const CalcException.syntax();
    final x = args[0];
    switch (name) {
      case 'sin':
        return _clean(math.sin(_toRadians(x)));
      case 'cos':
        return _clean(math.cos(_toRadians(x)));
      case 'tan':
        final r = _toRadians(x);
        if (math.cos(r).abs() < 1e-15) throw const CalcException.math();
        return _clean(math.tan(r));
      case 'asin':
        if (x.abs() > 1) throw const CalcException.math();
        return _fromRadians(math.asin(x));
      case 'acos':
        if (x.abs() > 1) throw const CalcException.math();
        return _fromRadians(math.acos(x));
      case 'atan':
        return _fromRadians(math.atan(x));
      case 'sinh':
        return _check((math.exp(x) - math.exp(-x)) / 2);
      case 'cosh':
        return _check((math.exp(x) + math.exp(-x)) / 2);
      case 'tanh':
        if (x > 20) return 1;
        if (x < -20) return -1;
        final e2 = math.exp(2 * x);
        return (e2 - 1) / (e2 + 1);
      case 'asinh':
        final a = x.abs();
        final v = math.log(a + math.sqrt(a * a + 1));
        return x < 0 ? -v : v;
      case 'acosh':
        if (x < 1) throw const CalcException.math();
        return math.log(x + math.sqrt(x * x - 1));
      case 'atanh':
        if (x.abs() >= 1) throw const CalcException.math();
        return 0.5 * math.log((1 + x) / (1 - x));
      case 'ln':
        if (x <= 0) throw const CalcException.math();
        return math.log(x);
      case 'log':
        if (x <= 0) throw const CalcException.math();
        return math.log(x) / math.ln10;
      case 'logb':
        final b = args[1];
        if (x <= 0 || x == 1 || b <= 0) throw const CalcException.math();
        return math.log(b) / math.log(x);
      case 'sqrt':
        if (x < 0) throw const CalcException.math();
        return math.sqrt(x);
      case 'cbrt':
        final v = math.pow(x.abs(), 1 / 3).toDouble();
        return x < 0 ? -v : v;
      case 'abs':
        return x.abs();
    }
    throw const CalcException.syntax();
  }

  static double _pow(double base, double exponent) {
    if (base == 0 && exponent < 0) throw const CalcException.math();
    return _check(math.pow(base, exponent).toDouble());
  }

  /// The [degree]-th root of [radicand].
  static double _root(double radicand, double degree) {
    if (degree == 0) throw const CalcException.math();
    if (radicand < 0) {
      final isOddInteger =
          degree == degree.roundToDouble() && degree.abs() % 2 == 1;
      if (!isOddInteger) throw const CalcException.math();
      return -_check(math.pow(-radicand, 1 / degree).toDouble());
    }
    if (radicand == 0 && degree < 0) throw const CalcException.math();
    return _check(math.pow(radicand, 1 / degree).toDouble());
  }

  static bool _isNonNegativeInteger(double v) =>
      v >= 0 && v.isFinite && v == v.floorToDouble();

  static double _factorial(double n) {
    if (!_isNonNegativeInteger(n) || n > 170) throw const CalcException.math();
    var result = 1.0;
    for (var i = 2; i <= n; i++) {
      result *= i;
    }
    return result;
  }

  static double _combinations(double n, double r) {
    if (!_isNonNegativeInteger(n) || !_isNonNegativeInteger(r) || r > n) {
      throw const CalcException.math();
    }
    final k = math.min(r, n - r);
    // C(n, k) >= 2^k, so anything beyond this overflows a double.
    if (k > 1024) throw const CalcException.math();
    var result = 1.0;
    for (var i = 1; i <= k; i++) {
      result = result * (n - k + i) / i;
    }
    return _check(result).roundToDouble();
  }

  static double _permutations(double n, double r) {
    if (!_isNonNegativeInteger(n) || !_isNonNegativeInteger(r) || r > n) {
      throw const CalcException.math();
    }
    // P(n, r) >= r!, which overflows a double beyond 170.
    if (r > 170) throw const CalcException.math();
    var result = 1.0;
    for (var i = 0; i < r; i++) {
      result *= n - i;
    }
    return _check(result);
  }
}
