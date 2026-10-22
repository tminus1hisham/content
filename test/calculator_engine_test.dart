import 'package:content/features/disguise/calculator_engine.dart';
import 'package:flutter_test/flutter_test.dart';

String run(String keys) {
  final engine = CalculatorEngine();
  for (final key in keys.split(' ')) {
    engine.press(key);
  }
  return engine.display;
}

void main() {
  test('basic arithmetic', () {
    expect(run('2 + 3 ='), '5');
    expect(run('7 ÷ 2 ='), '3.5');
    expect(run('9 − 1 2 ='), '-3');
  });

  test('divide by zero shows Error; the next digit starts fresh', () {
    expect(run('1 ÷ 0 ='), 'Error');
    expect(run('1 ÷ 0 = +'), 'Error');
    expect(run('1 ÷ 0 = 4'), '4');
  });

  test('chained operators apply left to right, like phone calculators', () {
    expect(run('2 + 3 × 4 ='), '20');
    expect(run('2 + 3 ×'), '5'); // Running total shown on the next operator.
    expect(run('2 + × 3 ='), '6'); // The last operator pressed wins.
    expect(run('2 + ='), '4'); // No second operand: reuses the display.
  });

  test('± toggles the sign of the entry', () {
    expect(run('5 ±'), '-5');
    expect(run('± 5'), '-5');
    expect(run('3 + 5 ± ='), '-2');
    expect(run('5 ± ±'), '5');
  });

  test('% divides by 100, or takes a percentage of the total for + and −', () {
    expect(run('5 0 %'), '0.5');
    expect(run('2 0 0 + 1 0 % ='), '220');
    expect(run('5 0 × 1 0 % ='), '5');
  });

  test('decimals', () {
    expect(run('. 5'), '0.5');
    expect(run('1 . . 2'), '1.2');
    expect(run('0 . 1 + 0 . 2 ='), '0.3');
    expect(run('1 ÷ 3 ='), '0.3333333333');
    expect(run('0 0 7'), '7');
  });

  test('AC resets everything', () {
    expect(run('9 + 4 AC'), '0');
    expect(run('9 + 4 AC 2 ='), '2');
  });
}
