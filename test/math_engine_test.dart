import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:scientific_calculator/services/math_engine.dart';

void main() {
  const engine = MathEngine();

  double eval(String s, {AngleUnit unit = AngleUnit.deg, double ans = 0}) =>
      engine.evaluate(s, angleUnit: unit, ans: ans);

  Matcher throwsCalc(CalcErrorType type) => throwsA(
        isA<CalcException>().having((e) => e.type, 'type', type),
      );

  group('arithmetic and precedence', () {
    test('basic operators', () {
      expect(eval('2+3×4'), 14);
      expect(eval('(2+3)×4'), 20);
      expect(eval('10÷4'), 2.5);
      expect(eval('10mod3'), 1);
      expect(eval('50%'), 0.5);
    });

    test('powers and unary minus', () {
      expect(eval('−2²'), -4);
      expect(eval('2^3^2'), 512);
      expect(eval('2^−1'), 0.5);
      expect(eval('2³'), 8);
    });

    test('scientific notation', () {
      expect(eval('1.5E3'), 1500);
      expect(eval('2E−3'), closeTo(0.002, 1e-15));
    });

    test('Ans', () {
      expect(eval('Ans×2', ans: 21), 42);
    });
  });

  group('implicit multiplication and auto-closing', () {
    test('implicit multiplication', () {
      expect(eval('2π'), closeTo(2 * math.pi, 1e-12));
      expect(eval('3sin(30)'), closeTo(1.5, 1e-12));
      expect(eval('(2+3)(4+5)'), 45);
    });

    test('unclosed parentheses are closed', () {
      expect(eval('sin(30'), closeTo(0.5, 1e-12));
      expect(eval('2×(3+4'), 14);
    });
  });

  group('functions', () {
    test('angle units', () {
      expect(eval('sin(π÷2)', unit: AngleUnit.rad), closeTo(1, 1e-12));
      expect(eval('sin(100)', unit: AngleUnit.grad), closeTo(1, 1e-12));
      expect(eval('sin(180)'), 0);
      expect(eval('sin⁻¹(1)'), closeTo(90, 1e-9));
      expect(eval('tan⁻¹(1)', unit: AngleUnit.grad), closeTo(50, 1e-9));
    });

    test('hyperbolic', () {
      expect(eval('sinh(0)'), 0);
      expect(eval('cosh(0)'), 1);
      expect(eval('tanh⁻¹(0.5)'), closeTo(0.5493061443, 1e-9));
    });

    test('logs and roots', () {
      expect(eval('log(1000)'), closeTo(3, 1e-12));
      expect(eval('ln(e)'), closeTo(1, 1e-12));
      expect(eval('logₐ(2,8)'), closeTo(3, 1e-12));
      expect(eval('√(16)'), 4);
      expect(eval('∛(−8)'), closeTo(-2, 1e-12));
      expect(eval('3ʸ√27'), closeTo(3, 1e-12));
      expect(eval('abs(−5)'), 5);
    });

    test('factorial and combinatorics', () {
      expect(eval('5!'), 120);
      expect(eval('5C2'), 10);
      expect(eval('5P2'), 20);
      expect(eval('170!').isFinite, isTrue);
    });
  });

  group('errors', () {
    test('math errors', () {
      expect(() => eval('1÷0'), throwsCalc(CalcErrorType.math));
      expect(() => eval('tan(90)'), throwsCalc(CalcErrorType.math));
      expect(() => eval('√(−1)'), throwsCalc(CalcErrorType.math));
      expect(() => eval('171!'), throwsCalc(CalcErrorType.math));
      expect(() => eval('3.5!'), throwsCalc(CalcErrorType.math));
      expect(() => eval('ln(0)'), throwsCalc(CalcErrorType.math));
    });

    test('syntax errors', () {
      expect(() => eval(''), throwsCalc(CalcErrorType.syntax));
      expect(() => eval('2+'), throwsCalc(CalcErrorType.syntax));
      expect(() => eval('2××3'), throwsCalc(CalcErrorType.syntax));
      expect(() => eval('()'), throwsCalc(CalcErrorType.syntax));
      expect(() => eval('1.2.3'), throwsCalc(CalcErrorType.syntax));
      expect(() => eval('2)'), throwsCalc(CalcErrorType.syntax));
    });

    test('tryEvaluate never throws', () {
      expect(engine.tryEvaluate('1÷0').error?.message, 'Math Error');
      expect(engine.tryEvaluate('2+').error?.message, 'Syntax Error');
      expect(engine.tryEvaluate('2+2').value, 4);
    });
  });

  group('formatting', () {
    test('formatNumber', () {
      expect(MathEngine.formatNumber(0.1 + 0.2), '0.3');
      expect(MathEngine.formatNumber(1234.5), '1234.5');
      expect(MathEngine.formatNumber(1 / 3), '0.3333333333');
      expect(MathEngine.formatNumber(1e21), '1E21');
      expect(MathEngine.formatNumber(1.5e-7), '1.5E-7');
      expect(MathEngine.formatNumber(-42), '-42');
    });

    test('toFraction', () {
      expect(MathEngine.toFraction(0.75), '3/4');
      expect(MathEngine.toFraction(-1 / 3), '-1/3');
      expect(MathEngine.toFraction(2), isNull);
      expect(MathEngine.toFraction(math.pi), isNull);
    });
  });
}
