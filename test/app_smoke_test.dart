import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('Profile > Settings > Appearance > Dark switches theme mode', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Discover'), findsWidgets);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('accent swatches are buttons named for the colour', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    final sunset = tester.getSemantics(find.bySemanticsLabel('Sunset'));
    expect(sunset.flagsCollection.isButton, isTrue);
    expect(sunset.flagsCollection.isSelected, Tristate.isTrue);
    final purple = tester.getSemantics(find.bySemanticsLabel('Purple'));
    expect(purple.flagsCollection.isButton, isTrue);
    expect(purple.flagsCollection.isSelected, Tristate.isFalse);
    semantics.dispose();
  });

  testWidgets('an account with both roles can switch to the creator tabs', (
    tester,
  ) async {
    await pumpApp(tester, signedInAs: 'creator@demo.ke');
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Creator view'));
    await tester.pumpAndSettle();

    expect(find.text('Studio'), findsOneWidget);
    expect(find.text('Discover'), findsNothing);
  });
}
