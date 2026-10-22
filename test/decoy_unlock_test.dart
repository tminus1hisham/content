import 'package:content/features/disguise/disguise_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Cold start with [disguise] active and PIN 1234 set.
Future<void> _pumpDisguised(WidgetTester tester, Disguise disguise) =>
    pumpApp(tester, prefs: {disguiseKey: disguise.name}, pin: '1234');

Future<void> _tapAll(WidgetTester tester, String prefix, String keys) async {
  for (final key in keys.split(' ')) {
    await tester.tap(find.byKey(ValueKey('$prefix-$key')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('calculator: typing the PIN then = opens the real app', (
    tester,
  ) async {
    await _pumpDisguised(tester, Disguise.calculator);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Discover'), findsNothing);

    await _tapAll(tester, 'calc', '1 2 3 4 =');
    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Calculator'), findsNothing);
  });

  testWidgets('calculator: ordinary sums calculate and stay in the decoy', (
    tester,
  ) async {
    await _pumpDisguised(tester, Disguise.calculator);
    await _tapAll(tester, 'calc', '1 2 + 3 =');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('calc-display'))).data,
      '15',
    );
    await _tapAll(tester, 'calc', 'AC 4 3 2 1 =');
    expect(find.text('Discover'), findsNothing);
    expect(find.text('Calculator'), findsOneWidget);
  });

  testWidgets('notes: long-press title, enter PIN, opens the real app', (
    tester,
  ) async {
    await _pumpDisguised(tester, Disguise.notes);
    expect(find.text('No notes yet'), findsOneWidget);

    await tester.longPress(find.text('Notes'));
    await tester.pumpAndSettle();
    await _tapAll(tester, 'pin', '9 9 9 9 ok');
    expect(find.text('Wrong PIN'), findsOneWidget);
    await _tapAll(tester, 'pin', '1 2 3 4 ok');

    expect(find.text('Discover'), findsWidgets);
    expect(find.text('No notes yet'), findsNothing);
  });
}
