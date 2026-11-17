import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calculation_history.dart';
import '../services/math_engine.dart';

/// Holds all calculator state: the token-based expression, cursor, modes,
/// live result, memory register and persisted history.
class CalculatorController extends ChangeNotifier {
  CalculatorController({MathEngine engine = const MathEngine()})
      : _engine = engine;

  static const int maxHistoryItems = 200;

  static const String _historyKey = 'calc_history';
  static const String _angleKey = 'calc_angle_unit';
  static const String _memoryKey = 'calc_memory';
  static const String _ansKey = 'calc_ans';

  /// Tokens that continue from the previous answer when typed right after `=`.
  static const Set<String> _continuingTokens = {
    '+', '−', '×', '÷', '^', 'mod', 'C', 'P', '!', '%', '²', '³', 'ʸ√',
  };

  final MathEngine _engine;
  SharedPreferences? _prefs;
  bool _disposed = false;

  final List<String> _tokens = [];
  int _cursor = 0;
  AngleUnit _angleUnit = AngleUnit.deg;
  bool _shift = false;
  bool _hyp = false;
  double? _resultValue;
  String? _error;
  bool _evaluated = false;
  bool _showFraction = false;
  double _ans = 0;
  double _memory = 0;
  List<CalculationHistory> _history = [];

  List<String> get tokens => List.unmodifiable(_tokens);
  int get cursor => _cursor;
  String get expression => _tokens.join();
  AngleUnit get angleUnit => _angleUnit;
  bool get isShift => _shift;
  bool get isHyp => _hyp;
  double get ans => _ans;
  double get memory => _memory;
  bool get hasMemory => _memory != 0;
  String? get error => _error;

  /// True when the bottom line shows a committed result (after `=`),
  /// false when it shows a live preview.
  bool get isEvaluated => _evaluated;
  bool get isShowingFraction => _showFraction && isFractionAvailable;
  List<CalculationHistory> get history => List.unmodifiable(_history);

  bool get isFractionAvailable {
    final v = _resultValue;
    return _error == null && v != null && MathEngine.toFraction(v) != null;
  }

  /// Text for the bottom display line: error, fraction or decimal result.
  String get resultText {
    final error = _error;
    if (error != null) return error;
    final v = _resultValue;
    if (v == null) return '';
    if (_showFraction) {
      final fraction = MathEngine.toFraction(v);
      if (fraction != null) return fraction;
    }
    return MathEngine.formatNumber(v);
  }

  /// Restores history, angle unit, memory and last answer from storage.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      _history = CalculationHistory.decodeList(prefs.getString(_historyKey));
      final angleIndex = prefs.getInt(_angleKey);
      if (angleIndex != null &&
          angleIndex >= 0 &&
          angleIndex < AngleUnit.values.length) {
        _angleUnit = AngleUnit.values[angleIndex];
      }
      _memory = prefs.getDouble(_memoryKey) ?? 0;
      _ans = prefs.getDouble(_ansKey) ?? 0;
    } catch (_) {
      // Storage is optional: the calculator keeps working without it.
    }
    _updatePreview();
    _notify();
  }

  // ---------------------------------------------------------------- editing

  void insert(String token) => insertAll([token]);

  /// Inserts [newTokens] at the cursor.
  void insertAll(List<String> newTokens) {
    if (newTokens.isEmpty) return;
    if (_evaluated) {
      _tokens.clear();
      if (_continuingTokens.contains(newTokens.first)) _tokens.add('Ans');
      _cursor = _tokens.length;
      _evaluated = false;
    }
    _tokens.insertAll(_cursor, newTokens);
    _cursor += newTokens.length;
    _afterEdit();
  }

  /// Deletes the token before the cursor.
  void delete() {
    if (_evaluated) {
      _evaluated = false;
    } else if (_cursor > 0) {
      _tokens.removeAt(_cursor - 1);
      _cursor--;
    }
    _afterEdit();
  }

  void clearAll() {
    _tokens.clear();
    _cursor = 0;
    _resultValue = null;
    _error = null;
    _evaluated = false;
    _showFraction = false;
    _shift = false;
    _hyp = false;
    _notify();
  }

  void moveCursorTo(int index) {
    final clamped = index.clamp(0, _tokens.length).toInt();
    if (clamped == _cursor && !_evaluated) return;
    _cursor = clamped;
    _evaluated = false;
    _notify();
  }

  void cursorLeft() => moveCursorTo(_cursor - 1);

  void cursorRight() => moveCursorTo(_cursor + 1);

  void _afterEdit() {
    _error = null;
    _showFraction = false;
    _shift = false;
    _hyp = false;
    _updatePreview();
    _notify();
  }

  void _updatePreview() {
    if (_tokens.isEmpty) {
      _resultValue = null;
      return;
    }
    _resultValue = _evaluateCurrent().value;
  }

  EvaluationResult _evaluateCurrent() =>
      _engine.tryEvaluate(expression, angleUnit: _angleUnit, ans: _ans);

  // ------------------------------------------------------------- evaluation

  /// Commits the expression: auto-closes parentheses, stores the answer and
  /// records it in the history, or shows a friendly error.
  void evaluate() {
    if (_tokens.isEmpty) return;
    _shift = false;
    _hyp = false;
    _showFraction = false;

    var open = 0;
    for (final t in _tokens) {
      if (t.endsWith('(')) {
        open++;
      } else if (t == ')') {
        open--;
      }
    }
    for (var i = 0; i < open; i++) {
      _tokens.add(')');
    }
    _cursor = _tokens.length;

    final result = _evaluateCurrent();
    final value = result.value;
    if (value == null) {
      _error = result.error?.message ?? 'Syntax Error';
      _resultValue = null;
      _evaluated = false;
      _notify();
      return;
    }

    _error = null;
    _resultValue = value;
    _ans = value;
    _evaluated = true;
    _history.insert(
      0,
      CalculationHistory(
        tokens: List<String>.of(_tokens),
        result: MathEngine.formatNumber(value),
        timestamp: DateTime.now(),
      ),
    );
    if (_history.length > maxHistoryItems) {
      _history.removeRange(maxHistoryItems, _history.length);
    }
    _persistHistory();
    _prefs?.setDouble(_ansKey, _ans);
    _notify();
  }

  /// Switches the result between decimal and fraction form (S<=>D).
  void toggleFraction() {
    if (!isFractionAvailable) return;
    _showFraction = !_showFraction;
    _notify();
  }

  // ------------------------------------------------------------------ modes

  void toggleShift() {
    _shift = !_shift;
    _notify();
  }

  void toggleHyp() {
    _hyp = !_hyp;
    _notify();
  }

  void cycleAngleUnit() => setAngleUnit(_angleUnit.next);

  void setAngleUnit(AngleUnit unit) {
    if (unit == _angleUnit) return;
    _angleUnit = unit;
    _evaluated = false;
    _error = null;
    _showFraction = false;
    _updatePreview();
    _prefs?.setInt(_angleKey, unit.index);
    _notify();
  }

  // ----------------------------------------------------------------- memory

  void memoryClear() {
    _memory = 0;
    _prefs?.setDouble(_memoryKey, _memory);
    _notify();
  }

  void memoryRecall() => insertAll(_numberTokens(MathEngine.formatNumber(_memory)));

  void memoryAdd() => _memoryApply(1);

  void memorySubtract() => _memoryApply(-1);

  void _memoryApply(int sign) {
    if (_tokens.isEmpty) return;
    final result = _evaluateCurrent();
    final value = result.value;
    if (value == null) {
      _error = result.error?.message ?? 'Syntax Error';
      _resultValue = null;
      _evaluated = false;
      _notify();
      return;
    }
    final updated = _memory + sign * value;
    if (updated.isFinite) _memory = updated;
    _shift = false;
    _hyp = false;
    _prefs?.setDouble(_memoryKey, _memory);
    _notify();
  }

  /// Splits a formatted number such as `-1.5E-7` into display tokens.
  List<String> _numberTokens(String formatted) =>
      formatted.split('').map((ch) => ch == '-' ? '−' : ch).toList();

  // ---------------------------------------------------------------- history

  /// Replaces the current expression with the one from [item].
  void useHistoryExpression(CalculationHistory item) {
    _tokens
      ..clear()
      ..addAll(item.tokens);
    _cursor = _tokens.length;
    _evaluated = false;
    _afterEdit();
  }

  /// Inserts the result of [item] at the cursor.
  void useHistoryResult(CalculationHistory item) =>
      insertAll(_numberTokens(item.result));

  void removeHistoryItem(CalculationHistory item) {
    if (_history.remove(item)) {
      _persistHistory();
      _notify();
    }
  }

  void clearHistory() {
    if (_history.isEmpty) return;
    _history.clear();
    _persistHistory();
    _notify();
  }

  void _persistHistory() {
    _prefs?.setString(_historyKey, CalculationHistory.encodeList(_history));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
