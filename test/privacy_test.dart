import 'package:content/app/router.dart';
import 'package:content/features/auth/fake_auth.dart';
import 'package:content/features/disguise/lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openPrivacy(WidgetTester tester) async {
  await _tap(tester, find.text('Profile'));
  await _tap(tester, find.text('Settings'));
  await _tap(tester, find.text('Privacy'));
}

void main() {
  testWidgets('discreet notifications are saved on the server', (tester) async {
    await pumpApp(tester);
    await _openPrivacy(tester);
    final toggle = find.byKey(const ValueKey('pref-discreetNotifications'));
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    await _tap(tester, toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });

  testWidgets('another session can be signed out; this one logs you out', (
    tester,
  ) async {
    await pumpApp(tester);
    fakeAuthDb.sessionFor('fan@demo.ke'); // a second device
    await _openPrivacy(tester);
    expect(find.text('Sign out'), findsNWidgets(2));

    await _tap(tester, find.text('Sign out').last);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.textContaining('(this device)'), findsOneWidget);

    await _tap(tester, find.text('Sign out'));
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('deleting the account needs DELETE typed, then signs out', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openPrivacy(tester);
    await tester.scrollUntilVisible(find.text('Delete my account'), 200);
    await _tap(tester, find.text('Delete my account'));
    final confirm = find.widgetWithText(TextButton, 'Delete account');
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm')),
      'DELETE',
    );
    await tester.pump();
    await _tap(tester, confirm);
    expect(find.text('Create account'), findsOneWidget);
    expect(fakeAuthDb.deletionRequests.containsKey('u1'), isTrue);
  });

  testWidgets('with "lock immediately", leaving the app locks it', (
    tester,
  ) async {
    await pumpApp(tester, pin: '1234', prefs: {relockKey: 0});
    // Cold start asks for the PIN.
    expect(find.text('Enter PIN'), findsOneWidget);
    for (final d in '1234'.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-$d')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('pin-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Discover'), findsWidgets);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN'), findsOneWidget);
  });

  group('large text (200%) lays out without overflow', () {
    setUp(() {
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
      dispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(dispatcher.clearTextScaleFactorTestValue);
    });

    testWidgets('fan screens', (tester) async {
      await pumpApp(tester);
      for (final tab in ['Following', 'Live', 'Inbox', 'Profile', 'Discover']) {
        await _tap(
          tester,
          find.descendant(of: find.byType(AppNavBar), matching: find.text(tab)),
        );
      }
      await openCreator(tester, 'Amani');
      await tester.pageBack();
      await tester.pumpAndSettle();
      // Back from the creator lands on search, which covers the nav bar.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _openPrivacy(tester);
    });

    testWidgets('creator screens', (tester) async {
      await pumpApp(
        tester,
        signedInAs: 'creator@demo.ke',
        prefs: {roleKey: 'creator'},
      );
      for (final tab in ['Studio', 'Go live', 'Messages', 'Profile']) {
        await _tap(
          tester,
          find.descendant(of: find.byType(AppNavBar), matching: find.text(tab)),
        );
      }
      await _tap(tester, find.text('Earnings'));
    });
  });
}
