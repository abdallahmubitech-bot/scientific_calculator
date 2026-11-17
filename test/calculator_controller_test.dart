import 'package:flutter_test/flutter_test.dart';
import 'package:scientific_calculator/providers/calculator_controller.dart';
import 'package:scientific_calculator/services/math_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('live preview, evaluation and Ans continuation', () {
    final c = CalculatorController();
    c.insertAll(['2', '+', '3']);
    expect(c.resultText, '5');
    expect(c.isEvaluated, isFalse);

    c.evaluate();
    expect(c.isEvaluated, isTrue);
    expect(c.history.single.expression, '2+3');

    c.insert('×');
    expect(c.expression, 'Ans×');
    c.insert('2');
    c.evaluate();
    expect(c.resultText, '10');
    expect(c.history.first.expression, 'Ans×2');
  });

  test('auto-closes parentheses on evaluate', () {
    final c = CalculatorController();
    c.insertAll(['sin(', '3', '0']);
    c.evaluate();
    expect(c.expression, 'sin(30)');
    expect(c.resultText, '0.5');
  });

  test('friendly errors are not stored in history', () {
    final c = CalculatorController();
    c.insertAll(['1', '÷', '0']);
    c.evaluate();
    expect(c.error, 'Math Error');
    expect(c.history, isEmpty);

    c.clearAll();
    c.insertAll(['2', '+']);
    c.evaluate();
    expect(c.error, 'Syntax Error');
  });

  test('cursor editing', () {
    final c = CalculatorController();
    c.insertAll(['1', '2', '3']);
    c.moveCursorTo(1);
    c.insert('9');
    expect(c.expression, '1923');
    c.delete();
    expect(c.expression, '123');
    expect(c.cursor, 1);
  });

  test('modifiers reset after a key press', () {
    final c = CalculatorController();
    c.toggleShift();
    c.toggleHyp();
    c.insert('1');
    expect(c.isShift, isFalse);
    expect(c.isHyp, isFalse);
  });

  test('angle unit changes the preview', () {
    final c = CalculatorController();
    c.insertAll(['sin(', '9', '0', ')']);
    expect(c.resultText, '1');
    c.setAngleUnit(AngleUnit.rad);
    expect(c.resultText, isNot('1'));
  });

  test('fraction toggle', () {
    final c = CalculatorController();
    c.insertAll(['3', '÷', '4']);
    c.evaluate();
    expect(c.resultText, '0.75');
    c.toggleFraction();
    expect(c.resultText, '3/4');
    c.toggleFraction();
    expect(c.resultText, '0.75');
  });

  test('memory register', () {
    final c = CalculatorController();
    c.insert('5');
    c.memoryAdd();
    c.memoryAdd();
    c.memorySubtract();
    expect(c.memory, 5);
    c.clearAll();
    c.memoryRecall();
    expect(c.expression, '5');
    c.memoryClear();
    expect(c.hasMemory, isFalse);
  });

  test('history can be reused and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final c = CalculatorController();
    await c.load();
    c.insertAll(['6', '×', '7']);
    c.evaluate();

    final restored = CalculatorController();
    await restored.load();
    expect(restored.history.single.result, '42');
    expect(restored.ans, 42);

    restored.insert('1');
    restored.insert('+');
    restored.useHistoryResult(restored.history.single);
    expect(restored.expression, '1+42');
    restored.useHistoryExpression(restored.history.single);
    expect(restored.expression, '6×7');
  });
}
