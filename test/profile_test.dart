import 'package:content/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppNavBar), matching: find.text(label));

void main() {
  testWidgets('both roles: workspace cards switch between fan and creator', (
    tester,
  ) async {
    await pumpApp(tester, signedInAs: 'creator@demo.ke');
    await _tap(tester, _tab('Profile'));
    await _tap(tester, find.byKey(const ValueKey('workspace-creator')));
    expect(_tab('Studio'), findsOneWidget);
    expect(_tab('Discover'), findsNothing);

    await _tap(tester, _tab('Profile'));
    expect(find.text('Earnings'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('workspace-fan')));
    expect(_tab('Discover'), findsOneWidget);
    expect(_tab('Studio'), findsNothing);
  });

  testWidgets('fan only: no identifier, creator card becomes a creator', (
    tester,
  ) async {
    await pumpApp(tester);
    await _tap(tester, _tab('Profile'));
    expect(find.text('fan@demo.ke'), findsNothing);
    expect(find.text('Fan account'), findsOneWidget);
    final creator = find.byKey(const ValueKey('workspace-creator'));
    expect(
      find.descendant(of: creator, matching: find.text('Become a creator')),
      findsOneWidget,
    );

    await _tap(tester, creator);
    expect(_tab('Studio'), findsOneWidget);
  });

  testWidgets('fan: counts stay three columns at default text on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    await _tap(tester, _tab('Profile'));
    final tops = [
      for (final l in ['Subscriptions', 'Purchases', 'Following'])
        tester.getTopLeft(find.text(l).first).dy,
    ];
    expect(tops[1], tops[0]);
    expect(tops[2], tops[0]);
  });

  testWidgets('fan: Subscriptions count opens My library on Subscriptions', (
    tester,
  ) async {
    await pumpApp(tester);
    await _tap(tester, _tab('Profile'));
    await _tap(tester, find.text('Subscriptions'));

    expect(find.text('My library'), findsOneWidget);
    final tabs = DefaultTabController.of(
      tester.element(find.byType(TabBarView)),
    );
    expect(tabs.index, 1);
  });
}
