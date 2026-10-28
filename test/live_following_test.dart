import 'package:content/app/router.dart';
import 'package:content/features/auth/fake_auth.dart';
import 'package:content/features/content/fake_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Drags the visible tab's list until [finder] is on screen.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(CustomScrollView).first,
    const Offset(0, -200),
  );
  await tester.pumpAndSettle();
  expect(finder, findsOneWidget);
}

Future<void> _openTab(WidgetTester tester, String tab) => _tap(
  tester,
  find.descendant(of: find.byType(AppNavBar), matching: find.text(tab)),
);

/// Follows Zuri, Kofi and Neema; subscribes to Kofi.
String _seedFollows() {
  final fan = fakeAuthDb.userIdFor('fan@demo.ke');
  for (final id in ['c10', 'c11', 'c12']) {
    fakeContentDb.grantFollow(fan, id);
  }
  fakeContentDb.grantSubscription(fan, 'c11');
  return fan;
}

void main() {
  testWidgets('Live puts the open room on stage and the rest on the rail', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openTab(tester, 'Live');

    // The free room is the one the fan can open, so it takes the stage.
    expect(find.text('Join Zuri Wambui'), findsOneWidget);
    await _scrollTo(tester, find.text('Also live'));
    expect(find.text('Studio session: new beats'), findsOneWidget);
    expect(find.text('KSh 200'), findsOneWidget);

    await _tap(tester, find.text('Join Zuri Wambui'));
    expect(find.byKey(const ValueKey('live-viewers')), findsOneWidget);
  });

  testWidgets('Following pins favourites and slides to subscriptions', (
    tester,
  ) async {
    await pumpApp(tester);
    final fan = _seedFollows();
    await _openTab(tester, 'Following');

    expect(find.text('Keep favourites close'), findsOneWidget);
    expect(find.text('Pinned'), findsNothing);

    await tester.longPress(find.text('Neema Mushi'));
    await tester.pumpAndSettle();
    expect(find.text('Pinned Neema Mushi'), findsOneWidget);
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Everyone else'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('following.pins.$fan'), ['c12']);

    await _tap(tester, find.text('Subscribed'));
    expect(find.text('Kofi Mensah'), findsOneWidget);
    expect(find.text('Zuri Wambui'), findsNothing);
    expect(find.text('Neema Mushi'), findsNothing);

    await _tap(tester, find.text('Following').first);
    await _tap(tester, find.text('Edit pins'));
    await _tap(tester, find.byTooltip('Unpin Neema Mushi'));
    expect(prefs.getStringList('following.pins.$fan'), isEmpty);
  });

  group('large text (200%)', () {
    setUp(() {
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
      dispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(dispatcher.clearTextScaleFactorTestValue);
    });

    testWidgets('stage, rail and shelves lay out without overflow', (
      tester,
    ) async {
      await pumpApp(tester);
      _seedFollows();
      await _openTab(tester, 'Live');
      await _scrollTo(tester, find.text('Studio session: new beats'));
      await _openTab(tester, 'Following');
      await _scrollTo(tester, find.text('Neema Mushi'));
      await tester.longPress(find.text('Neema Mushi'));
      await tester.pumpAndSettle();
      expect(find.text('Pinned Neema Mushi'), findsOneWidget);
    });
  });
}
