import 'package:content/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatKes', () {
    expect(formatKes(0), 'KSh 0');
    expect(formatKes(125000), 'KSh 1,250');
    expect(formatKes(125050), 'KSh 1,250.50');
    expect(formatKes(1000), 'KSh 10');
  });
}
