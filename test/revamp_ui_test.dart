import 'package:content/features/content/discover_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> _openAmani(WidgetTester tester) => openCreator(tester, 'Amani');

void main() {
  testWidgets('a post tile reads its label and taps as one semantics node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    await _openAmani(tester);

    final data = tester
        .getSemantics(find.byType(PostTile).first)
        .getSemanticsData();
    expect(data.label, contains('Locked post'));
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('the creator app bar stops drawing white once scrolled', (
    tester,
  ) async {
    // Light mode: white over the cream page would be unreadable.
    await pumpApp(tester, prefs: {'theme.mode': 'light'});
    await _openAmani(tester);
    AppBar bar() => tester.widget<AppBar>(find.byType(AppBar));
    expect(bar().foregroundColor, Colors.white);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(bar().foregroundColor, isNot(Colors.white));
  });
}
